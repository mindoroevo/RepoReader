# PowerShell Script: Build signed Android App Bundle for RepoReader
# Usage: Run from repository root in PowerShell
#   .\scripts\build_release.ps1 -VersionName 0.1.1 -VersionCode 2
# Updates pubspec.yaml version, builds appbundle, outputs path.
param(
    [Parameter(Mandatory=$true)][string]$VersionName,
    [Parameter(Mandatory=$true)][int]$VersionCode
)

$ErrorActionPreference = 'Stop'

Write-Host "[1/5] Validating key.properties presence" -ForegroundColor Cyan
if (-not (Test-Path 'android/key.properties')) {
    Write-Error 'android/key.properties fehlt – bitte anlegen (siehe docs/build_android_signing.md).'
}

Write-Host "[2/5] Updating pubspec.yaml version" -ForegroundColor Cyan
$pubspec = Get-Content pubspec.yaml -Raw
$pubspec = [regex]::Replace($pubspec, 'version:\s*.*', "version: $VersionName+$VersionCode")
Set-Content pubspec.yaml $pubspec -Encoding UTF8

Write-Host "[3/5] Flutter clean & pub get" -ForegroundColor Cyan
flutter clean | Out-Null
flutter pub get | Out-Null

Write-Host "[4/5] Building release appbundle" -ForegroundColor Cyan
flutter build appbundle --release

if ($LASTEXITCODE -ne 0) { Write-Error "Build fehlgeschlagen" }

$bundlePath = 'build/app/outputs/bundle/release/app-release.aab'
if (-not (Test-Path $bundlePath)) { Write-Error "App Bundle nicht gefunden: $bundlePath" }

Write-Host "[5/5] Fertig. AAB: $bundlePath" -ForegroundColor Green

Write-Host "SHA-256 Signatur (zur Kontrolle, extrahiert über keytool nach Erstellung des Keystores möglich)" -ForegroundColor DarkGray
Write-Host "Hinweis: Für Upload einfach in Play Console verwenden." -ForegroundColor DarkGray
