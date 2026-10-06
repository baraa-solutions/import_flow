@echo off
setlocal enabledelayedexpansion
title Sorour Logistics ERP - Live Launcher

set "ROOT_DIR=%~dp0"
cd /d "%ROOT_DIR%"

:: Backend port. The installed production app uses 28080: on a machine that also runs it,
:: set PORT to another value first, e.g.  set PORT=28090
if not defined PORT set PORT=28080

echo ===============================================================================
echo        Sorour Logistics ERP - Live System Launcher
echo ===============================================================================
echo.

:: 1. Verify Python
echo [1/4] Checking Python environment...
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH.
    echo Please install Python 3.12+ and add it to system PATH.
    pause
    exit /b 1
)
echo       [OK] Python is available.

:: 2. Apply Database Migrations
echo [2/4] Verifying database schema (sorour_logistics.db)...
python -m alembic upgrade head >nul 2>&1
echo       [OK] Database schema verified.

:: 3. Check / Start Backend API Server on Port %PORT% (never kill whatever already listens there)
echo [3/4] Checking Backend API Server on port %PORT%...
set "RELEASE_DIR=%ROOT_DIR%frontend\build\windows\x64\runner\Release"
set "CLIENT_EXE=%RELEASE_DIR%\frontend.exe"
call "%ROOT_DIR%scripts\check_backend_port.bat" "%CLIENT_EXE%"
if errorlevel 2 exit /b 1
if not errorlevel 1 (
    echo       [+] Starting FastAPI backend on http://127.0.0.1:%PORT%...
    start "SorourLogistics Backend" /min python -m uvicorn main:app --host 127.0.0.1 --port %PORT% --reload

    :: Wait up to 10 seconds for backend to start
    set "READY=0"
    for /L %%i in (1,1,10) do (
        if "!READY!"=="0" (
            ping 127.0.0.1 -n 2 >nul 2>&1
            for /f "tokens=5" %%p in ('netstat -ano -p tcp ^| findstr /c:":%PORT% " ^| findstr "LISTENING"') do (
                set "READY=1"
            )
        )
    )
    if "!READY!"=="1" (
        echo       [OK] Backend API is ready and listening!
    ) else (
        echo       [INFO] Backend is initializing in background...
    )
)

:: 4. Launch Flutter Windows Desktop App
echo [4/4] Launching Sorour Logistics Desktop Client...
:: USE_RELEASE_EXE comes from check_backend_port.bat (1 only on PORT 28080: the prebuilt exe always talks to 28080)
if "%USE_RELEASE_EXE%"=="1" (
    start "" /D "%RELEASE_DIR%" "%CLIENT_EXE%"
    echo       [OK] Desktop application started successfully!
) else (
    echo       [INFO] Launching with Flutter engine against http://127.0.0.1:%PORT%...
    start "Sorour Logistics Desktop" /D "%ROOT_DIR%frontend" cmd /c "flutter run -d windows --dart-define=IMPORTFLOW_SERVER_URL=http://127.0.0.1:%PORT%"
)

echo.
echo ===============================================================================
echo    Sorour Logistics ERP is LIVE!
echo    - Backend API: http://127.0.0.1:%PORT%
echo    - API Docs:    http://127.0.0.1:%PORT%/docs
echo ===============================================================================
ping 127.0.0.1 -n 4 >nul 2>&1
exit /b 0
