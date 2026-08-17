@echo off
REM Mealin backend server - use THIS script only (prevents duplicate instances)
cd /d "%~dp0"

for /f "tokens=5" %%p in ('netstat -ano ^| findstr /R /C:"0.0.0.0:8000.*LISTENING"') do (
    echo Port 8000 already in use by PID %%p - stopping it first...
    taskkill /PID %%p /F >nul 2>&1
)

echo Starting Mealin server on 0.0.0.0:8000 (--noreload, single instance)...
start "MealinServer" /min cmd /c "cd /d ""%~dp0backend"" && python manage.py runserver 0.0.0.0:8000 --noreload"
timeout /t 3 >nul
echo.
echo Verify with: netstat -ano | findstr :8000  (must show exactly ONE LISTENING)
