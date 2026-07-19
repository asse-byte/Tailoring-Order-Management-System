# Install this machine's SSH public key on the shop server, so deployments stop
# asking for a password on every scp/ssh.
#
#   .\scripts\setup-ssh-key.ps1 -Server root@1.2.3.4
#
# You type the server password ONCE (twice at most). After that
# deploy-all-web.ps1 runs end-to-end unattended.
#
# Safety: it NEVER creates or overwrites a key if one already exists — your
# existing key may be the one you use for GitHub or another server. It only
# generates a new ed25519 key when you have none at all.
#
# Like everything else here, the key travels as a REAL FILE (scp) and is
# appended by a small uploaded script — never piped inline over ssh, which is
# what corrupted transfers earlier in this project.
param(
    [string]$Server = $env:COUTURE_SERVER,
    [string]$KeyPath = (Join-Path $env:USERPROFILE '.ssh\id_ed25519')
)
$ErrorActionPreference = 'Stop'

function Say  ($m) { Write-Host $m -ForegroundColor Cyan }
function Good ($m) { Write-Host "  + $m" -ForegroundColor Green }
function Warn ($m) { Write-Host "  ! $m" -ForegroundColor Yellow }

if ([string]::IsNullOrWhiteSpace($Server)) {
    throw "Serveur non defini. Utilisez -Server root@IP ou definissez `$env:COUTURE_SERVER."
}
foreach ($exe in @('ssh', 'scp', 'ssh-keygen')) {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) { throw "Commande manquante: $exe" }
}

$pub = "$KeyPath.pub"

Say ""
Say "=== Cle SSH -> $Server ==="

if (Test-Path $KeyPath) {
    Good "Cle existante reutilisee: $KeyPath (NON modifiee)"
} else {
    Warn "Aucune cle trouvee — generation d'une nouvelle cle ed25519 (sans phrase secrete)."
    & ssh-keygen -t ed25519 -N '""' -f $KeyPath -C "couture-deploy"
    if ($LASTEXITCODE -ne 0) { throw "ssh-keygen a echoue" }
    Good "Cle generee: $KeyPath"
}
if (-not (Test-Path $pub)) { throw "Cle publique introuvable: $pub" }

Write-Host ""
Write-Host "  Empreinte : " -NoNewline
& ssh-keygen -lf $pub
Write-Host ""

# --- upload the public key as a file, then append it remotely ---------------
$stamp   = Get-Date -Format 'yyyyMMddHHmmss'
$pubName = "couture-key-$stamp.pub"
$shName  = "couture-installkey-$stamp.sh"

Say "[1/3] Envoi de la cle publique (scp)..."
& scp $pub "${Server}:/tmp/$pubName"
if ($LASTEXITCODE -ne 0) { throw "scp de la cle a echoue (mot de passe correct ?)" }

# The installer script: idempotent (grep -qxF) so running twice adds nothing.
$installSh = @'
set -e
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
KEY=$(cat "/tmp/__PUB__")
if grep -qxF "$KEY" ~/.ssh/authorized_keys; then
  echo "RESULT=already-present"
else
  printf "%s\n" "$KEY" >> ~/.ssh/authorized_keys
  echo "RESULT=added"
fi
rm -f "/tmp/__PUB__"
'@ -replace '__PUB__', $pubName

$CR = [char]13
$NL = [char]10
$body = "trap 'rm -f `"`$0`"' EXIT$NL" + $installSh
$lf   = $body.Replace("$CR$NL", "$NL").Replace("$CR", "$NL")   # bash needs LF, no BOM
$localSh = Join-Path $env:TEMP $shName
[IO.File]::WriteAllText($localSh, $lf, (New-Object Text.UTF8Encoding $false))

try {
    Say "[2/3] Installation dans ~/.ssh/authorized_keys..."
    & scp $localSh "${Server}:/tmp/$shName"
    if ($LASTEXITCODE -ne 0) { throw "scp du script a echoue" }
    $out = & ssh $Server "bash /tmp/$shName"
    if ($LASTEXITCODE -ne 0) { throw "installation distante a echouee" }
    foreach ($l in ($out -split "`n")) {
        if ($l -match 'RESULT=(.+)') {
            if ($Matches[1].Trim() -eq 'added') { Good "cle ajoutee" } else { Good "cle deja presente (rien a faire)" }
        }
    }
}
finally {
    Remove-Item -Force $localSh -ErrorAction SilentlyContinue
}

# --- prove it actually works (no password) ----------------------------------
Say "[3/3] Verification (connexion sans mot de passe)..."
$probe = & ssh -o BatchMode=yes -o ConnectTimeout=10 $Server 'echo KEYOK'
if ($LASTEXITCODE -eq 0 -and ($probe -join '') -match 'KEYOK') {
    Write-Host ""
    Good "OK — connexion par cle, plus aucun mot de passe."
    Write-Host ""
    Write-Host "Vous pouvez maintenant lancer :" -ForegroundColor Cyan
    Write-Host "  `$env:COUTURE_SERVER = '$Server'"
    Write-Host "  .\scripts\deploy-all-web.ps1 -IncludeBackend"
} else {
    Write-Host ""
    Warn "La connexion par cle ne fonctionne pas encore."
    Warn "Causes frequentes : le serveur refuse PubkeyAuthentication, ou les"
    Warn "permissions de ~/.ssh sont trop larges. Verifiez sur le serveur :"
    Warn "  ls -ld ~/.ssh ; ls -l ~/.ssh/authorized_keys ; sudo sshd -T | grep -i pubkey"
    exit 1
}
