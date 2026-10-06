@echo off
setlocal enabledelayedexpansion
title Sorour Logistics ERP ? Track 1 (Fast Iteration Dev Mode)

set "ROOT_DIR=%~dp0"
cd /d "%ROOT_DIR%"

:: Backend port: PORT, default 28080 (set by scripts\check_backend_port.bat). The installed production
:: app uses 28080: on a machine that also runs it, set PORT to another value first, e.g.  set PORT=28090
if not defined PORT set PORT=28080

echo ===============================================================================
echo        Sorour Logistics ERP ? Track 1: Fast Iteration (Dev Mode)
echo ===============================================================================
echo.

:: 1. Safety Backup (Non-negotiable 0.05s habit)
echo [1/3] Creating instant safety snapshot of real database...
python scripts/daily_backup.py --test
if errorlevel 1 (
    echo [WARN] Backup script had an issue, but proceeding with caution.
)
echo.

:: 2. Start / Verify Backend on Port %PORT% (never kill whatever already listens there)
echo [2/3] Checking Backend API Server on port %PORT%...
call "%ROOT_DIR%scripts\check_backend_port.bat"
if errorlevel 2 exit /b 1
if not errorlevel 1 (
    echo       [+] Starting Live Backend with auto-reload on port %PORT%...
    start "Sorour Logistics - Backend API Server (Track 1)" cmd /k "cd /d "%ROOT_DIR%" && python -m uvicorn main:app --host 127.0.0.1 --port %PORT% --reload"

    :: Wait for backend to be ready
    set "READY=0"
    for /L %%i in (1,1,12) do (
        if "!READY!"=="0" (
            ping 127.0.0.1 -n 2 >nul 2>&1
            curl -s -m 1 http://127.0.0.1:%PORT%/api/v1/health 2>nul | findstr /c:"Sorour Logistics ERP" >nul 2>&1
            if not errorlevel 1 (
                set "READY=1"
            )
        )
    )
    if "!READY!"=="1" (
        echo       [OK] Backend API is ready on http://127.0.0.1:%PORT%
    ) else (
        echo       [INFO] Backend is initializing in background window...
    )
)
echo.

:: 3. Choose Client & Launch with Hot Reload
echo [3/3] Client Target Selection...
echo ===============================================================================
echo  Select Frontend Client Mode:
echo    [1] Windows Desktop Client  (flutter run -d windows)  [Standard]
echo    [2] Google Chrome Web       (flutter run -d chrome)   [Ultra-stable, No GPU crash]
echo    [3] Backend API Only        (FastAPI Interactive Docs)
echo ===============================================================================
set "TARGET_MODE=1"
set /p "TARGET_MODE=Enter choice [1, 2, or 3 - Press ENTER for 1]: "

cd /d "%ROOT_DIR%frontend"

if "%TARGET_MODE%"=="2" (
    echo.
    echo [*] Launching Google Chrome Web Client on port 3000...
    echo  CONTROLS: Press [r] for Hot Reload, [R] for Hot Restart, [q] to Quit.
    flutter run -d chrome --web-port 3000 --dart-define=IMPORTFLOW_SERVER_URL=http://127.0.0.1:%PORT%
) else if "%TARGET_MODE%"=="3" (
    echo.
    echo [*] Opening API Documentation in default browser...
    start http://127.0.0.1:%PORT%/docs
    echo Backend is running at http://127.0.0.1:%PORT%. Press any key to exit.
    pause >nul
) else (
    echo.
    echo [*] Launching Windows Desktop Client ^(Debug Mode^)...
    echo  CONTROLS: Press [r] for Hot Reload, [R] for Hot Restart, [q] to Quit.
    flutter run -d windows --dart-define=IMPORTFLOW_SERVER_URL=http://127.0.0.1:%PORT%
)

pause
