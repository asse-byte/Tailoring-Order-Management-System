# Deploy the web (PWA) build of EVERY shop from this dev machine, in one command.
#
#   .\scripts\deploy-all-web.ps1 -Server root@1.2.3.4
#   .\scripts\deploy-all-web.ps1 -Server root@1.2.3.4 -IncludeBackend
#   .\scripts\deploy-all-web.ps1 -Server root@1.2.3.4 -ShopSlug rayan-couture
#   .\scripts\deploy-all-web.ps1 -Server root@1.2.3.4 -DryRun
#
# Set COUTURE_SERVER once and you can drop -Server:
#   $env:COUTURE_SERVER = 'root@1.2.3.4'
#
# SOURCE OF TRUTH = THE SERVER, never a hand-maintained list.
# Shops are discovered from /srv/*/ (folders that really have a
# docker-compose.yml + .env). For each one we read SHOP_NAME and API_PORT from
# its .env, then locate its nginx site by grepping for `127.0.0.1:<that port>`
# — the port is unique per shop, so this links shop -> nginx without relying on
# file-naming conventions (the demo does not follow them). From that nginx file
# we read the real api domain, app domain and web root.
# docs/shops-registry-template.csv is deliberately NOT used: it is a template
# and already drifted (it lists api.rayan.couturepro.app while the live host is
# api.rayan-couture.couturepro.app).
#
# APK is NOT touched here — see scripts/README.md.
param(
    [string]$Server = $env:COUTURE_SERVER,
    [string]$ShopSlug,                 # optional: deploy a single shop
    [switch]$IncludeBackend,           # run update-all.sh (backend) first
    [switch]$DryRun,                   # discover + report, change nothing
    [string]$ShopsDir   = '/srv',
    [switch]$SkipVerify                # skip the post-deploy HTTPS check
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Say  ($m) { Write-Host $m -ForegroundColor Cyan }
function Warn ($m) { Write-Host "  ! $m" -ForegroundColor Yellow }
function Bad  ($m) { Write-Host "  x $m" -ForegroundColor Red }
function Good ($m) { Write-Host "  + $m" -ForegroundColor Green }

# ---------------------------------------------------------------- preflight
foreach ($exe in @('tar', 'ssh', 'scp', 'flutter')) {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
        throw "Commande manquante: '$exe'. Installez-la (tar/ssh/scp sont fournis avec Windows 10+)."
    }
}
if ([string]::IsNullOrWhiteSpace($Server)) {
    throw "Serveur non defini. Utilisez -Server root@IP ou definissez `$env:COUTURE_SERVER."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$builder  = Join-Path $PSScriptRoot 'build-shop-app.ps1'
if (-not (Test-Path $builder)) { throw "introuvable: $builder" }

Say ""
Say "=== Deploiement web — serveur $Server ==="

# Key-based auth? (only informational: we always scp a real file, never a pipe,
# because tar|ssh over an interactive password prompt corrupted the stream.)
& ssh -o BatchMode=yes -o ConnectTimeout=8 $Server 'echo ok' > $null
if ($LASTEXITCODE -eq 0) {
    Good "Cle SSH detectee (pas de mot de passe a saisir)."
} else {
    Warn "Pas de cle SSH: chaque commande demandera le mot de passe."
}

# ---------------------------------------------------------------- discovery
Say ""
Say "[1] Decouverte des salons sur $Server`:$ShopsDir ..."

$discoverSh = @'
for d in SHOPSDIR/*/; do
  s=$(basename "$d")
  [ -f "$d/docker-compose.yml" ] || continue
  [ -f "$d/.env" ] || continue
  name=$(grep -m1 "^SHOP_NAME=" "$d/.env" | cut -d= -f2- | tr -d "\r")
  port=$(grep -m1 "^API_PORT=" "$d/.env" | cut -d= -f2 | tr -d " \t\r")
  conf=""
  if [ -n "$port" ]; then
    conf=$(grep -rl "127\.0\.0\.1:$port" /etc/nginx/sites-enabled/ 2>/dev/null | head -1)
    if [ -z "$conf" ]; then
      conf=$(grep -rl "127\.0\.0\.1:$port" /etc/nginx/sites-available/ 2>/dev/null | head -1)
    fi
  fi
  api=""; app=""; root=""
  if [ -n "$conf" ]; then
    api=$(grep -B6 "proxy_pass" "$conf" | grep -m1 "server_name" | sed "s/.*server_name[[:space:]]*//; s/;.*//" | tr -d " \r")
    root=$(grep -m1 -E "^[[:space:]]*root[[:space:]]" "$conf" | sed "s/.*root[[:space:]]*//; s/;.*//" | tr -d " \r")
    app=$(grep -B4 -E "^[[:space:]]*root[[:space:]]" "$conf" | grep -m1 "server_name" | sed "s/.*server_name[[:space:]]*//; s/;.*//" | tr -d " \r")
  fi
  printf "%s|%s|%s|%s|%s\n" "$s" "$name" "$api" "$app" "$root"
done
'@ -replace 'SHOPSDIR', $ShopsDir

$raw = & ssh $Server $discoverSh
if ($LASTEXITCODE -ne 0) { throw "La decouverte SSH a echoue (verifiez -Server et l'acces)." }

$shops = @()
foreach ($line in ($raw -split "`n")) {
    $line = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $p = $line -split '\|'
    if ($p.Count -lt 5) { continue }
    $shops += [pscustomobject]@{
        Slug = $p[0]; Name = $p[1]; Api = $p[2]; App = $p[3]; Root = $p[4]
    }
}
if ($shops.Count -eq 0) { throw "Aucun salon trouve dans $ShopsDir sur $Server." }

if ($ShopSlug) {
    $shops = @($shops | Where-Object { $_.Slug -eq $ShopSlug })
    if ($shops.Count -eq 0) { throw "Salon '$ShopSlug' introuvable sur le serveur." }
}

Write-Host ""
Write-Host ("  {0,-18} {1,-20} {2,-38} {3}" -f 'SLUG', 'NOM', 'API', 'WEB ROOT')
foreach ($s in $shops) {
    Write-Host ("  {0,-18} {1,-20} {2,-38} {3}" -f $s.Slug, $s.Name, $s.Api, $s.Root)
}
Write-Host ""

# ---------------------------------------------------------------- backend
if ($IncludeBackend) {
    Say "[2] Backend — update-all.sh (sauvegarde + pull + rebuild + health)"
    if ($DryRun) {
        Warn "(dry-run) backend saute."
    } else {
        $anchor = $shops[0].Slug
        $cmd = "cd $ShopsDir/$anchor && git pull --ff-only && SHOPS_DIR=$ShopsDir ./scripts/update-all.sh"
        & ssh $Server $cmd
        if ($LASTEXITCODE -ne 0) {
            Warn "update-all.sh a signale au moins un echec — voir ci-dessus. On continue avec le web."
        } else {
            Good "Backend a jour sur tous les salons."
        }
    }
    Write-Host ""
}

# ---------------------------------------------------------------- web loop
$ok = @(); $failed = @()
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$step = 3
if (-not $IncludeBackend) { $step = 2 }

foreach ($s in $shops) {
    Say "[$step] === $($s.Slug) ($($s.Name)) ==="
    try {
        if ([string]::IsNullOrWhiteSpace($s.Api) -or [string]::IsNullOrWhiteSpace($s.Root)) {
            throw "nginx illisible pour ce salon (api='$($s.Api)' root='$($s.Root)'). Verifiez son site nginx."
        }

        $apiUrl = "https://$($s.Api)"
        # appId is irrelevant for a web build (APK is built separately); derive a
        # deterministic placeholder so the builder's validation passes.
        $appId  = 'com.couturepro.' + ($s.Slug -replace '[^a-z0-9]', '')
        $webDir = Join-Path $repoRoot "dist\$($s.Slug)\web"

        Write-Host "  build : $apiUrl"
        if ($DryRun) {
            Warn "(dry-run) build + upload sautes."
            $ok += $s.Slug
        }
        else {

        # 1) build web only. The builder throws on failure (its own
        #    ErrorActionPreference=Stop); we then assert the artefact really
        #    exists rather than trusting an exit code.
        & $builder -ShopSlug $s.Slug -AppId $appId -AppName $s.Name -ApiUrl $apiUrl -SkipApk
        if (-not (Test-Path (Join-Path $webDir 'version.json'))) {
            throw "build introuvable/incomplet: $webDir"
        }

        # 2) archive + verify it is non-empty (a silent tar failure shipped an
        #    empty file more than once).
        $archName = "$($s.Slug)-web-$stamp.tar.gz"
        $archPath = Join-Path $env:TEMP $archName
        if (Test-Path $archPath) { Remove-Item -Force $archPath }
        & tar -czf $archPath -C $webDir .
        if ($LASTEXITCODE -ne 0) { throw "tar a echoue" }
        if (-not (Test-Path $archPath)) { throw "archive non creee: $archPath" }
        $size = (Get-Item $archPath).Length
        if ($size -le 0) { throw "archive vide (0 octet) — upload annule" }
        Write-Host ("  archive: {0} ({1:N0} Ko)" -f $archName, ($size / 1KB))

        # 3) upload as a real file (never `tar | ssh`: with an interactive
        #    password the stream got corrupted -> 'gzip: not in gzip format').
        & scp $archPath "${Server}:/tmp/$archName"
        if ($LASTEXITCODE -ne 0) { throw "scp a echoue" }

        # 4) one compound remote command: clean, extract, fix perms, count, cleanup.
        #    chmod -R o+rX is mandatory: a 700 web root makes nginx serve HTML
        #    for every asset (root cause of a real outage on this project).
        $r = $s.Root
        $remote = "set -e; mkdir -p '$r'; rm -rf '$r'/*; tar -xzf '/tmp/$archName' -C '$r'; chmod -R o+rX '$r'; echo FILES=`$(find '$r' -type f | wc -l); rm -f '/tmp/$archName'"
        $out = & ssh $Server $remote
        if ($LASTEXITCODE -ne 0) { throw "deploiement distant a echoue" }
        $count = 'n/a'
        foreach ($l in ($out -split "`n")) {
            if ($l -match 'FILES=(\d+)') { $count = $Matches[1] }
        }
        Good "$count fichiers deployes dans $r"

        # 5) verify over real HTTPS (not just 'no error')
        if (-not $SkipVerify -and -not [string]::IsNullOrWhiteSpace($s.App)) {
            $base = "https://$($s.App)"
            try {
                $v = Invoke-WebRequest -Uri "$base/version.json" -UseBasicParsing -TimeoutSec 20
                $i = Invoke-WebRequest -Uri "$base/icons/Icon-192.png" -UseBasicParsing -TimeoutSec 20
                if ($v.StatusCode -eq 200 -and $i.StatusCode -eq 200 -and $v.Content -match '"version"') {
                    Good "verifie: $base/version.json -> $($v.Content.Trim())"
                    Good "verifie: icons/Icon-192.png -> HTTP $($i.StatusCode)"
                } else {
                    throw "reponse inattendue (version=$($v.StatusCode) icon=$($i.StatusCode))"
                }
            } catch {
                throw "verification HTTPS echouee sur $base : $($_.Exception.Message)"
            }
        }

        Remove-Item -Force $archPath -ErrorAction SilentlyContinue
        $ok += $s.Slug
        } # end else (not DryRun)
    }
    catch {
        Bad "$($s.Slug): $($_.Exception.Message)"
        $failed += $s.Slug
        # deliberately continue with the next shop (same philosophy as update-all.sh)
    }
    Write-Host ""
}

# ---------------------------------------------------------------- summary
Say "=== Resume ==="
if ($ok.Count)     { Good "reussis : $($ok -join ', ')" }     else { Write-Host "  reussis : aucun" }
if ($failed.Count) { Bad  "ECHECS  : $($failed -join ', ')" } else { Write-Host "  echecs  : aucun" }
Write-Host ""
Write-Host "Rappel: l'APK n'est PAS mis a jour par ce script (voir scripts/README.md)."
if ($failed.Count) { exit 1 }
