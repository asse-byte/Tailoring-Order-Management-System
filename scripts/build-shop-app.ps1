# Build the web app + signed APK for ONE shop in a single command.
# Runs on the DEV MACHINE (Windows), not the VPS.
#
#   .\scripts\build-shop-app.ps1 -ShopSlug rayan-couture `
#       -AppId com.rayancouture.app -AppName "Rayan Couture" `
#       -ApiUrl https://api.rayan-couture.couturepro.app
#
# What it does:
#   1. Backs up android/gradle.properties, sets appName/appId for this shop.
#   2. flutter build web  --dart-define=API_URL=<ApiUrl>  -> dist/<slug>/web/
#   3. flutter build apk  --dart-define=API_URL=<ApiUrl>  -> dist/<slug>/<slug>-v<version>.apk
#   4. RESTORES gradle.properties exactly as it was (even on failure), so the
#      repo never silently stays branded for the last shop built.
#
# Switches: -SkipWeb / -SkipApk to build only one artifact,
#           -DryRun to test the gradle.properties swap without building.
#
# REMINDER: appId is permanent per shop — never change it after delivery.
param(
    [Parameter(Mandatory = $true)][string]$ShopSlug,
    [Parameter(Mandatory = $true)][string]$AppId,
    [Parameter(Mandatory = $true)][string]$AppName,
    [Parameter(Mandatory = $true)][string]$ApiUrl,
    [switch]$SkipWeb,
    [switch]$SkipApk,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

if ($AppId -notmatch '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$') {
    throw "AppId invalide: '$AppId' (attendu: com.exemple.monsalon, minuscules)"
}
if ($ApiUrl -notmatch '^https?://') { throw "ApiUrl doit commencer par http(s)://" }

$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir   = Join-Path $repoRoot 'tailoring_app'
$gradle   = Join-Path $appDir 'android\gradle.properties'
if (-not (Test-Path $gradle)) { throw "introuvable: $gradle" }

$distDir  = Join-Path $repoRoot "dist\$ShopSlug"
$original = [IO.File]::ReadAllText($gradle)

# Version from pubspec.yaml (e.g. "version: 1.0.0+1" -> 1.0.0)
$pubspec = Get-Content (Join-Path $appDir 'pubspec.yaml')
$verLine = ($pubspec | Where-Object { $_ -match '^version:' } | Select-Object -First 1)
$version = 'unknown'
if ($verLine -match '^version:\s*([0-9.]+)') { $version = $Matches[1] }

Write-Host ""
Write-Host "=== Build salon '$AppName' ($ShopSlug) v$version ===" -ForegroundColor Cyan
Write-Host "  appId  : $AppId"
Write-Host "  API    : $ApiUrl"
Write-Host "  sortie : dist\$ShopSlug\"
Write-Host ""

# --- brand gradle.properties for this shop ---------------------------------
$branded = $original `
    -replace '(?m)^appName=.*$', "appName=$AppName" `
    -replace '(?m)^appId=.*$',   "appId=$AppId"
if ($branded -notmatch "(?m)^appId=$([regex]::Escape($AppId))$") {
    throw "échec du remplacement appId dans gradle.properties"
}

$failed = $false
try {
    [IO.File]::WriteAllText($gradle, $branded)
    Write-Host "gradle.properties -> appName='$AppName', appId='$AppId'" -ForegroundColor Yellow

    if ($DryRun) {
        Write-Host "(dry-run) builds sautés." -ForegroundColor Yellow
    }
    else {
        New-Item -ItemType Directory -Force $distDir | Out-Null
        Push-Location $appDir
        try {
            if (-not $SkipWeb) {
                Write-Host "[1/2] flutter build web..." -ForegroundColor Cyan
                flutter build web --release --dart-define=API_URL=$ApiUrl
                if ($LASTEXITCODE -ne 0) { throw "build web a échoué" }
                $webOut = Join-Path $distDir 'web'
                if (Test-Path $webOut) { Remove-Item -Recurse -Force $webOut }
                Copy-Item -Recurse (Join-Path $appDir 'build\web') $webOut
            }
            if (-not $SkipApk) {
                Write-Host "[2/2] flutter build apk..." -ForegroundColor Cyan
                flutter build apk --release --dart-define=API_URL=$ApiUrl
                if ($LASTEXITCODE -ne 0) { throw "build apk a échoué" }
                Copy-Item (Join-Path $appDir 'build\app\outputs\flutter-apk\app-release.apk') `
                          (Join-Path $distDir "$ShopSlug-v$version.apk") -Force
            }
        }
        finally { Pop-Location }
    }
}
catch { $failed = $true; throw }
finally {
    [IO.File]::WriteAllText($gradle, $original)
    Write-Host "gradle.properties restauré a l'identique." -ForegroundColor Yellow
    if ($failed) { Write-Host "BUILD EN ECHEC — aucun artefact fiable produit." -ForegroundColor Red }
}

Write-Host ""
Write-Host "=== Termine ===" -ForegroundColor Green
if (-not $SkipWeb -and -not $DryRun) { Write-Host "  Web : dist\$ShopSlug\web\   (scp -r vers /var/www/$ShopSlug-web/ sur le VPS)" }
if (-not $SkipApk -and -not $DryRun) { Write-Host "  APK : dist\$ShopSlug\$ShopSlug-v$version.apk   (WhatsApp / cable vers le telephone)" }
