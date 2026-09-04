@echo off
echo ============================================
echo  Building all 3 Mealin APKs + AABs
echo ============================================
echo.

mkdir build\apk-output 2>nul

echo [1/3] Building Mealin Customer...
powershell -Command "(Get-Content android\gradle.properties) -notmatch 'APP_ROLE=' | Set-Content android\gradle.properties; Add-Content android\gradle.properties 'APP_ROLE=customer'"
flutter build apk --release --dart-define=APP_ROLE=customer
if %errorlevel% neq 0 (
    echo ERROR: Customer APK build failed!
    exit /b 1
)
copy build\app\outputs\flutter-apk\app-release.apk build\apk-output\mealin-customer.apk
flutter build appbundle --release --dart-define=APP_ROLE=customer
if %errorlevel% neq 0 (
    echo ERROR: Customer AAB build failed!
    exit /b 1
)
copy build\app\outputs\bundle\release\app-release.aab build\apk-output\mealin-customer.aab
echo.

echo [2/3] Building Mealin Kitchen...
powershell -Command "(Get-Content android\gradle.properties) -notmatch 'APP_ROLE=' | Set-Content android\gradle.properties; Add-Content android\gradle.properties 'APP_ROLE=chef'"
flutter build apk --release --dart-define=APP_ROLE=chef
if %errorlevel% neq 0 (
    echo ERROR: Kitchen APK build failed!
    exit /b 1
)
copy build\app\outputs\flutter-apk\app-release.apk build\apk-output\mealin-kitchen.apk
flutter build appbundle --release --dart-define=APP_ROLE=chef
if %errorlevel% neq 0 (
    echo ERROR: Kitchen AAB build failed!
    exit /b 1
)
copy build\app\outputs\bundle\release\app-release.aab build\apk-output\mealin-kitchen.aab
echo.

echo [3/3] Building Mealin Delivery...
powershell -Command "(Get-Content android\gradle.properties) -notmatch 'APP_ROLE=' | Set-Content android\gradle.properties; Add-Content android\gradle.properties 'APP_ROLE=delivery_partner'"
flutter build apk --release --dart-define=APP_ROLE=delivery_partner
if %errorlevel% neq 0 (
    echo ERROR: Delivery APK build failed!
    exit /b 1
)
copy build\app\outputs\flutter-apk\app-release.apk build\apk-output\mealin-delivery.apk
flutter build appbundle --release --dart-define=APP_ROLE=delivery_partner
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
echo  APKs (direct install / GitHub release):
echo    build\apk-output\mealin-customer.apk
echo    build\apk-output\mealin-kitchen.apk
echo    build\apk-output\mealin-delivery.apk
echo.
echo  AABs (Google Play Store):
echo    build\apk-output\mealin-customer.aab
echo    build\apk-output\mealin-kitchen.aab
echo    build\apk-output\mealin-delivery.aab
