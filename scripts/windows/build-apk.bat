@echo off
REM Interactive APK builder for MEALIN (Windows).
REM Asks which APK to build, then delegates to build-apks.ps1 (release).
cd /d "%~dp0.."

echo.
echo ============================================
echo   MEALIN APK builder
echo ============================================
echo.
echo Which APK do you want to build?
echo   1) customer   (MEALIN)
echo   2) restro     (MEALIN RESTO)
echo   3) delivery   (MEALIN RIDER)
echo   4) all        (all three)
echo.
set /p CHOICE="Enter choice [1-4]: "

if "%CHOICE%"=="1" set ROLE=customer
if "%CHOICE%"=="2" set ROLE=chef
if "%CHOICE%"=="3" set ROLE=delivery_partner
if "%CHOICE%"=="4" set ROLE=all
if not defined ROLE (
    echo Invalid choice: %CHOICE%
    exit /b 1
)

echo.
echo Building role=%ROLE% (release) ...
powershell -ExecutionPolicy Bypass -File scripts\windows\build-apks.ps1 -Role %ROLE%
EOF