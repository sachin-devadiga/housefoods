@echo off
REM Always run from the repo root regardless of where this script lives.
cd /d "%~dp0.."

REM Google Maps key comes from the environment; never hardcode it here.
if "%MAPS_API_KEY%"=="" (
    echo ERROR: MAPS_API_KEY is not set. Google Maps will be blank in release builds.
    echo    Set it in this session first:  set MAPS_API_KEY=your_key
    echo    Or set it permanently in System Environment Variables.
    exit /b 1
)

REM Without this the app embeds the literal placeholder rzp_test_YOUR_KEY_HERE
REM and payments break. CI guards the same way - see .github/workflows/build-android.yml.
if "%RAZORPAY_KEY%"=="" (
    echo ERROR: RAZORPAY_KEY is not set.
    echo    A release build without it embeds the placeholder rzp_test_YOUR_KEY_HERE.
    echo    Set it in this session first:  set RAZORPAY_KEY=rzp_live_xxxx
    exit /b 1
)
echo %RAZORPAY_KEY% | findstr /C:"YOUR_KEY" >nul
if not errorlevel 1 (
    echo ERROR: RAZORPAY_KEY still holds the placeholder value. Set the real key.
    exit /b 1
)
echo %RAZORPAY_KEY% | findstr /B /C:"rzp_test_" >nul
if not errorlevel 1 (
    echo WARNING: RAZORPAY_KEY is a TEST key. Fine for sideloading, a Play Store violation if published.
)

REM Version comes from pubspec.yaml so the published file name matches the APK.
set APK_VERSION=
for /f "tokens=*" %%v in ('powershell -NoProfile -Command "(Get-Content pubspec.yaml | Select-String -Pattern '^version:\s*(.+)$' | Select-Object -First 1).Matches[0].Groups[1].Value.Trim()"') do set APK_VERSION=%%v
if "%APK_VERSION%"=="" (
    echo ERROR: could not read version from pubspec.yaml
    exit /b 1
)

echo ============================================
echo  Building all 3 Mealin APKs + AABs
echo  Version: %APK_VERSION%
echo ============================================
echo.

mkdir build\apk-output 2>nul
mkdir apks\latest 2>nul
mkdir apks\archive 2>nul

echo [1/3] Building Mealin Customer...
powershell -Command "(Get-Content android\gradle.properties) -notmatch 'APP_ROLE=' | Set-Content android\gradle.properties; Add-Content android\gradle.properties 'APP_ROLE=customer'"
flutter build apk --release --dart-define=APP_ROLE=customer --dart-define=RAZORPAY_KEY=%RAZORPAY_KEY% -PMAPS_API_KEY=%MAPS_API_KEY%
if %errorlevel% neq 0 (
    echo ERROR: Customer APK build failed!
    exit /b 1
)
copy build\app\outputs\flutter-apk\app-release.apk build\apk-output\mealin-customer.apk
powershell -ExecutionPolicy Bypass -File scripts\windows\publish-apk.ps1 -Stem mealin-customer -SourceApk build\app\outputs\flutter-apk\app-release.apk -Version %APK_VERSION%
flutter build appbundle --release --dart-define=APP_ROLE=customer --dart-define=RAZORPAY_KEY=%RAZORPAY_KEY% -PMAPS_API_KEY=%MAPS_API_KEY%
if %errorlevel% neq 0 (
    echo ERROR: Customer AAB build failed!
    exit /b 1
)
copy build\app\outputs\bundle\release\app-release.aab build\apk-output\mealin-customer.aab
echo.

echo [2/3] Building Mealin Kitchen...
powershell -Command "(Get-Content android\gradle.properties) -notmatch 'APP_ROLE=' | Set-Content android\gradle.properties; Add-Content android\gradle.properties 'APP_ROLE=chef'"
flutter build apk --release --dart-define=APP_ROLE=chef --dart-define=RAZORPAY_KEY=%RAZORPAY_KEY% -PMAPS_API_KEY=%MAPS_API_KEY%
if %errorlevel% neq 0 (
    echo ERROR: Kitchen APK build failed!
    exit /b 1
)
copy build\app\outputs\flutter-apk\app-release.apk build\apk-output\mealin-kitchen.apk
powershell -ExecutionPolicy Bypass -File scripts\windows\publish-apk.ps1 -Stem mealin-kitchen -SourceApk build\app\outputs\flutter-apk\app-release.apk -Version %APK_VERSION%
flutter build appbundle --release --dart-define=APP_ROLE=chef --dart-define=RAZORPAY_KEY=%RAZORPAY_KEY% -PMAPS_API_KEY=%MAPS_API_KEY%
if %errorlevel% neq 0 (
    echo ERROR: Kitchen AAB build failed!
    exit /b 1
)
copy build\app\outputs\bundle\release\app-release.aab build\apk-output\mealin-kitchen.aab
echo.

echo [3/3] Building Mealin Delivery...
powershell -Command "(Get-Content android\gradle.properties) -notmatch 'APP_ROLE=' | Set-Content android\gradle.properties; Add-Content android\gradle.properties 'APP_ROLE=delivery_partner'"
flutter build apk --release --dart-define=APP_ROLE=delivery_partner --dart-define=RAZORPAY_KEY=%RAZORPAY_KEY% -PMAPS_API_KEY=%MAPS_API_KEY%
if %errorlevel% neq 0 (
    echo ERROR: Delivery APK build failed!
    exit /b 1
)
copy build\app\outputs\flutter-apk\app-release.apk build\apk-output\mealin-delivery.apk
powershell -ExecutionPolicy Bypass -File scripts\windows\publish-apk.ps1 -Stem mealin-delivery -SourceApk build\app\outputs\flutter-apk\app-release.apk -Version %APK_VERSION%
flutter build appbundle --release --dart-define=APP_ROLE=delivery_partner --dart-define=RAZORPAY_KEY=%RAZORPAY_KEY% -PMAPS_API_KEY=%MAPS_API_KEY%
if %errorlevel% neq 0 (
    echo ERROR: Delivery AAB build failed!
    exit /b 1
)
copy build\app\outputs\bundle\release\app-release.aab build\apk-output\mealin-delivery.aab
echo.

powershell -Command "(Get-Content android\gradle.properties) -notmatch 'APP_ROLE=' | Set-Content android\gradle.properties"
echo ============================================
echo  All 3 APKs + AABs built successfully!
echo ============================================
echo.
echo  APKs (newest build, versioned):
echo    apks\latest\mealin-customer-%APK_VERSION%.apk
echo    apks\latest\mealin-kitchen-%APK_VERSION%.apk
echo    apks\latest\mealin-delivery-%APK_VERSION%.apk
echo.
echo  Previous builds are kept in apks\archive\
echo.
echo  Legacy copies also in: build\apk-output
echo.
echo  AABs (Google Play Store):
echo    build\apk-output\mealin-customer.aab
echo    build\apk-output\mealin-kitchen.aab
echo    build\apk-output\mealin-delivery.aab
