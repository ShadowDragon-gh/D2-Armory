<#
.SYNOPSIS
  Build, package, and prepare a Windows release of D2 Armory for a GitHub Release.

.DESCRIPTION
  Runs the release build, zips the Release folder's CONTENTS (not the folder
  itself - the self-updater extracts the zip directly over the install dir, so a
  nested Release/ folder would break the swap), computes the SHA-256 the updater
  verifies against, and prints the exact `gh release create` command with the
  checksum line the updater looks for.

  This does NOT publish anything. It stops before `gh release create` so you can
  review the artifacts and run the printed command yourself.

.PARAMETER Version
  Release version tag, e.g. v1.1.0. Should match pubspec.yaml's version.

.EXAMPLE
  pwsh tool/package_release.ps1 -Version v1.1.0
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$Version
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$envFile = 'env/release.json'
if (-not (Test-Path $envFile)) {
  throw "Missing $envFile. Create it with your release Bungie credentials first."
}

Write-Host "==> Cleaning previous build so the exe version resource regenerates" -ForegroundColor Cyan
# The Windows FILEVERSION/ProductVersion is stamped from pubspec into the CMake
# cache at configure time. An incremental `flutter build` reuses that cache and
# re-links the exe with the STALE version, so a version bump would ship an exe
# whose embedded version (what PackageInfo.fromPlatform reads) is the old one.
# A clean forces CMake to reconfigure and pick up the current pubspec version.
flutter clean
if ($LASTEXITCODE -ne 0) { throw "flutter clean failed ($LASTEXITCODE)." }

Write-Host "==> Building release with $envFile" -ForegroundColor Cyan
flutter build windows --release --dart-define-from-file=$envFile
if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)." }

$releaseDir = 'build/windows/x64/runner/Release'
if (-not (Test-Path $releaseDir)) { throw "Build output not found at $releaseDir." }

$distDir = 'dist'
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$zipPath = Join-Path $distDir "D2Armory-$Version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Write-Host "==> Zipping contents of $releaseDir -> $zipPath" -ForegroundColor Cyan
# Zip the folder's CONTENTS (trailing \*) so the exe/DLLs/data sit at the zip
# root - required by the self-updater's extract-over-install-dir step.
Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $zipPath -Force

$hash = (Get-FileHash -Algorithm SHA256 -Path $zipPath).Hash.ToLower()
$size = (Get-Item $zipPath).Length

Write-Host ""
Write-Host "==> Packaged:" -ForegroundColor Green
Write-Host "    zip    : $zipPath"
Write-Host "    size   : $size bytes"
Write-Host "    sha256 : $hash"
Write-Host ""
Write-Host "==> Publish with (review first, then run):" -ForegroundColor Yellow
Write-Host ""
$cmd = @"
gh release create $Version "$zipPath" --title "D2 Armory $Version" --notes "sha256: $hash"
"@
Write-Host $cmd
Write-Host ""
Write-Host "The 'sha256: <hash>' line in the notes is REQUIRED - the in-app"
Write-Host "updater reads it to verify the download before installing."
