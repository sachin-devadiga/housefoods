param(
    [string]$Role = "all"
)

# Always run from the repo root regardless of where this script lives.
Set-Location (Join-Path $PSScriptRoot "..")

# Google Maps key comes from the environment; never hardcode it here.
if ([string]::IsNullOrWhiteSpace($env:MAPS_API_KEY)) {
    Write-Host "ERROR: MAPS_API_KEY is not set. Google Maps will be blank in release builds." -ForegroundColor Red
    Write-Host "  Set it for this session with:  `$env:MAPS_API_KEY = 'your_key'" -ForegroundColor Red
    Write-Host "  Or set it permanently in System Environment Variables." -ForegroundColor Red
    exit 1
}

# AppConstants.razorpayKey falls back to the literal placeholder
# rzp_test_YOUR_KEY_HERE, so a release build without this ships a broken
# payment key. CI guards the same way - see .github/workflows/build-android.yml.
if ([string]::IsNullOrWhiteSpace($env:RAZORPAY_KEY)) {
    Write-Host "ERROR: RAZORPAY_KEY is not set." -ForegroundColor Red
    Write-Host "  A release build without it embeds the placeholder rzp_test_YOUR_KEY_HERE." -ForegroundColor Red
    Write-Host "  Set it for this session with:  `$env:RAZORPAY_KEY = 'rzp_live_xxxx'" -ForegroundColor Red
    exit 1
}
if ($env:RAZORPAY_KEY -like "*YOUR_KEY*") {
    Write-Host "ERROR: RAZORPAY_KEY still holds the placeholder value. Set the real key." -ForegroundColor Red
    exit 1
}
if ($env:RAZORPAY_KEY -like "rzp_test_*") {
    Write-Host "WARNING: RAZORPAY_KEY is a TEST key. Fine for sideloading, a Play Store violation if published." -ForegroundColor Yellow
}

$roles = @{
    "customer"         = @{ appName = "MEALIN";           dartDefine = "customer";         gradleProp = "customer";         file = "mealin-customer" }
    "chef"             = @{ appName = "MEALIN RESTO";     dartDefine = "chef";             gradleProp = "chef";             file = "mealin-kitchen" }
    "delivery_partner" = @{ appName = "MEALIN RIDER";     dartDefine = "delivery_partner"; gradleProp = "delivery_partner"; file = "mealin-delivery" }
}

# Version comes from pubspec.yaml so the file name matches the APK.
$versionLine = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*(.+)$' | Select-Object -First 1
if ($null -eq $versionLine) {
    Write-Host "ERROR: could not read version from pubspec.yaml" -ForegroundColor Red
    exit 1
}
$version = $versionLine.Matches[0].Groups[1].Value.Trim()

$buildDir = "build\apk-output"
$latestDir = "apks\latest"
$archiveDir = "apks\archive"
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$archiveStampDir = Join-Path $archiveDir $timestamp

foreach ($d in @($buildDir, $latestDir, $archiveDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

function Write-Checksums($dir) {
    $apks = Get-ChildItem $dir -Filter "*.apk" -ErrorAction SilentlyContinue
    if ($null -eq $apks -or $apks.Count -eq 0) {
        $sumFile = Join-Path $dir "SHA256SUMS"
        if (Test-Path $sumFile) { Remove-Item $sumFile -Force }
        return
    }
    $lines = foreach ($a in $apks) {
        "{0}  ./{1}" -f (Get-FileHash $a.FullName -Algorithm SHA256).Hash.ToLower(), $a.Name
    }
    Set-Content -Path (Join-Path $dir "SHA256SUMS") -Value $lines -Encoding UTF8
}

# Move the outgoing APKs for a role into apks\archive\<timestamp>\ so
# apks\latest always holds the newest build and no build is lost. The
# publishing logic lives in publish-apk.ps1 so build_all_apks.bat behaves
# identically.
function Publish-Apk($stem, $sourceApk) {
    & (Join-Path $PSScriptRoot "publish-apk.ps1") -Stem $stem -SourceApk $sourceApk -Version $version
}

function Build-Role($roleKey) {
    $r = $roles[$roleKey]
    Write-Host "`n=== Building $($r.appName) ($roleKey) ===" -ForegroundColor Cyan

    # 1. Write strings.xml
    $stringsXml = @"
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$($r.appName)</string>
</resources>
"@
    Set-Content -Path "android\app\src\main\res\values\strings.xml" -Value $stringsXml -Encoding UTF8

    # 2. Update gradle.properties
    (Get-Content android\gradle.properties) -replace 'APP_ROLE=.*', "APP_ROLE=$($r.gradleProp)" | Set-Content android\gradle.properties

    # 3. Build
    flutter build apk --release --dart-define=APP_ROLE=$($r.dartDefine) --dart-define=RAZORPAY_KEY=$env:RAZORPAY_KEY -PMAPS_API_KEY=$env:MAPS_API_KEY

    if ($LASTEXITCODE -eq 0) {
        $built = "build\app\outputs\flutter-apk\app-release.apk"
        if (-not (Test-Path $built)) {
            Write-Host "=> FAILED: $built not produced" -ForegroundColor Red
            return $false
        }
        Copy-Item $built (Join-Path $buildDir "$($r.file).apk") -Force
        Publish-Apk $r.file $built
        return $true
    } else {
        Write-Host "=> FAILED to build $($r.file)" -ForegroundColor Red
        return $false
    }
}

$failed = $false
switch ($Role) {
    "all" {
        if (-not (Build-Role "customer")) { $failed = $true }
        if (-not (Build-Role "chef")) { $failed = $true }
        if (-not (Build-Role "delivery_partner")) { $failed = $true }
    }
    "customer"     { if (-not (Build-Role "customer")) { $failed = $true } }
    "chef"         { if (-not (Build-Role "chef")) { $failed = $true } }
    "delivery_partner" { if (-not (Build-Role "delivery_partner")) { $failed = $true } }
    default { Write-Host "Unknown role: $Role. Use: customer, chef, delivery_partner, or all" -ForegroundColor Red; exit 1 }
}

# Restore default
(Get-Content android\gradle.properties) -replace 'APP_ROLE=.*', 'APP_ROLE=customer' | Set-Content android\gradle.properties

Write-Checksums $latestDir

Write-Host "`n=== All done ===" -ForegroundColor Cyan
Get-ChildItem "$latestDir\*.apk" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  $($_.Name) - $([math]::Round($_.Length/1MB,1)) MB"
}
Write-Host ""
Write-Host "  Legacy copies also in: $buildDir"

if ($failed) { exit 1 }
exit 0
