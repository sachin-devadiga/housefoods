@echo off
echo ============================================
echo  Building all 3 Mealin APKs
echo ============================================
echo.

mkdir build\apk-output 2>nul

echo [1/3] Building Mealin Customer APK...
powershell -Command "(Get-Content android\gradle.properties) -notmatch 'APP_ROLE=' | Set-Content android\gradle.properties; Add-Content android\gradle.properties 'APP_ROLE=customer'"
flutter build apk --release --dart-define=APP_ROLE=customer
if %errorlevel% neq 0 (
    echo ERROR: Customer build failed!
    exit /b 1
)
copy build\app\outputs\flutter-apk\app-release.apk build\apk-output\mealin-customer.apk
echo.

echo [2/3] Building Mealin Kitchen APK...
powershell -Command "(Get-Content android\gradle.properties) -notmatch 'APP_ROLE=' | Set-Content android\gradle.properties; Add-Content android\gradle.properties 'APP_ROLE=chef'"
flutter build apk --release --dart-define=APP_ROLE=chef
if %errorlevel% neq 0 (
    echo ERROR: Kitchen build failed!
    exit /b 1
)
copy build\app\outputs\flutter-apk\app-release.apk build\apk-output\mealin-kitchen.apk
echo.

echo [3/3] Building Mealin Delivery APK...
powershell -Command "(Get-Content android\gradle.properties) -notmatch 'APP_ROLE=' | Set-Content android\gradle.properties; Add-Content android\gradle.properties 'APP_ROLE=delivery_partner'"
flutter build apk --release --dart-define=APP_ROLE=delivery_partner
if %errorlevel% neq 0 (
    echo ERROR: Delivery build failed!
    exit /b 1
)
copy build\app\outputs\flutter-apk\app-release.apk build\apk-output\mealin-delivery.apk
echo.

powershell -Command "(Get-Content android\gradle.properties) -notmatch 'APP_ROLE=' | Set-Content android\gradle.properties"
echo ============================================
echo  All 3 APKs built successfully!
echo ============================================
echo.
echo  build\apk-output\mealin-customer.apk
echo  build\apk-output\mealin-kitchen.apk
echo  build\apk-output\mealin-delivery.apk
