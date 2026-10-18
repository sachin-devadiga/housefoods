param(
    [Parameter(Mandatory = $true)][string]$Stem,
    [Parameter(Mandatory = $true)][string]$SourceApk,
    [Parameter(Mandatory = $true)][string]$Version,
    [string]$LatestDir = "apks\latest",
    [string]$ArchiveDir = "apks\archive"
)

# Publish one built APK into apks\latest, archiving whatever was there before.
# Shared by build-apks.ps1 and build_all_apks.bat so both landing paths behave
# the same. See apks/README.md.

Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Test-Path $LatestDir)) { New-Item -ItemType Directory -Path $LatestDir -Force | Out-Null }
if (-not (Test-Path $ArchiveDir)) { New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null }

$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$archiveStampDir = Join-Path $ArchiveDir $timestamp

# Move the outgoing APKs for this role into archive\<timestamp>\ so latest
# always holds the newest build and no build is lost.
Get-ChildItem $LatestDir -Filter "$Stem-*.apk" -ErrorAction SilentlyContinue | ForEach-Object {
    if (-not (Test-Path $archiveStampDir)) { New-Item -ItemType Directory -Path $archiveStampDir -Force | Out-Null }
    Move-Item $_.FullName (Join-Path $archiveStampDir $_.Name) -Force
    Write-Host "  archived $($_.Name) -> archive\$timestamp\" -ForegroundColor Yellow
}

if (-not (Test-Path $SourceApk)) {
    Write-Host "ERROR: $SourceApk not found" -ForegroundColor Red
    exit 1
}

$dest = Join-Path $LatestDir "$Stem-$Version.apk"
Copy-Item $SourceApk $dest -Force
Write-Host "=> $LatestDir\$Stem-$Version.apk" -ForegroundColor Green

# Refresh checksums for everything in latest.
$apks = Get-ChildItem $LatestDir -Filter "*.apk" -ErrorAction SilentlyContinue
$sumFile = Join-Path $LatestDir "SHA256SUMS"
if ($null -eq $apks -or $apks.Count -eq 0) {
    if (Test-Path $sumFile) { Remove-Item $sumFile -Force }
} else {
    $lines = foreach ($a in $apks) {
        "{0}  ./{1}" -f (Get-FileHash $a.FullName -Algorithm SHA256).Hash.ToLower(), $a.Name
    }
    Set-Content -Path $sumFile -Value $lines -Encoding UTF8
}
