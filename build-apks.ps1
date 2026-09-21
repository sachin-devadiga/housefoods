param(
    [string]$Role = "all"
)

$roles = @{
    "customer"         = @{ appName = "MEALIN";           dartDefine = "customer";         gradleProp = "customer";         file = "mealin-customer.apk" }
    "chef"             = @{ appName = "MEALIN RESTO";     dartDefine = "chef";             gradleProp = "chef";             file = "mealin-kitchen.apk" }
    "delivery_partner" = @{ appName = "MEALIN RIDER";     dartDefine = "delivery_partner"; gradleProp = "delivery_partner"; file = "mealin-delivery.apk" }
}

$buildDir = "build\apk-output"
if (-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir -Force | Out-Null }

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
    flutter build apk --release --dart-define=APP_ROLE=$($r.dartDefine)

    if ($LASTEXITCODE -eq 0) {
        Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "$buildDir\$($r.file)" -Force
        Write-Host "=> $($r.file) built successfully" -ForegroundColor Green
    } else {
        Write-Host "=> FAILED to build $($r.file)" -ForegroundColor Red
    }
}

switch ($Role) {
    "all" {
        Build-Role "customer"
        Build-Role "chef"
        Build-Role "delivery_partner"
    }
    "customer"     { Build-Role "customer" }
    "chef"         { Build-Role "chef" }
    "delivery_partner" { Build-Role "delivery_partner" }
    default { Write-Host "Unknown role: $Role. Use: customer, chef, delivery_partner, or all" -ForegroundColor Red }
}

# Restore default
(Get-Content android\gradle.properties) -replace 'APP_ROLE=.*', 'APP_ROLE=customer' | Set-Content android\gradle.properties

Write-Host "`n=== All done ===" -ForegroundColor Cyan
Get-ChildItem "$buildDir\*.apk" | ForEach-Object {
    Write-Host "  $($_.Name) - $([math]::Round($_.Length/1MB,1)) MB"
}
