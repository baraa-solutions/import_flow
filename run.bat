@echo off
setlocal
title ImportFlow ERP Launcher

echo ===============================================================================
echo                 ImportFlow ERP - Enterprise Launcher
echo ===============================================================================
echo.

:: Backend port. The installed production app uses 28080: on a machine that also runs it,
:: set PORT to another value first, e.g.  set PORT=28090
if not defined PORT set PORT=28080

:: 1. Free web port 3000 (the backend port is never killed: it may be the production app)
echo [1/3] Backend port: %PORT%. Freeing web port 3000...
for /f "tokens=5" %%p in ('netstat -ano ^| findstr ":3000"') do taskkill /f /pid %%p >nul 2>&1

:: 2. Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python is not found in system PATH.
    echo Please install Python 3.12+ and ensure it is added to PATH.
    pause
    exit /b 1
)

echo.
echo ===============================================================================
echo   Select Launch Mode:
echo ===============================================================================
echo   [1] Desktop Application (Native Windows Release EXE) - [Default]
echo   [2] Web Application (Chrome / Browser at http://localhost:3000)
echo   [3] Backend API Only (FastAPI + Swagger Docs at http://localhost:%PORT%/docs)
echo   [4] Run Backend Unit Tests
echo ===============================================================================
echo.

choice /c 1234 /t 6 /d 1 /m "Select option [1-4] (Auto-launching Desktop in 6s):"
if errorlevel 4 goto launch_tests
if errorlevel 3 goto launch_backend_only
if errorlevel 2 goto launch_web
if errorlevel 1 goto launch_desktop

:launch_desktop
echo.
set "CLIENT_EXE=%~dp0frontend\build\windows\x64\runner\Release\frontend.exe"
call "%~dp0scripts\check_backend_port.bat" "%CLIENT_EXE%"
if errorlevel 2 exit /b 1
if errorlevel 1 goto launch_desktop_client
echo [2/3] Starting FastAPI Backend on http://127.0.0.1:%PORT%...
start "ImportFlow Backend" /min cmd /c "cd /d %~dp0 && python -m uvicorn main:app --host 127.0.0.1 --port %PORT%"
ping 127.0.0.1 -n 3 >nul 2>&1

:launch_desktop_client

echo [3/3] Launching ImportFlow Desktop...
:: USE_RELEASE_EXE comes from check_backend_port.bat (1 only on PORT 28080: the prebuilt exe always talks to 28080)
if "%USE_RELEASE_EXE%"=="1" (
    start "" "%CLIENT_EXE%"
    echo.
    echo ===============================================================================
    echo [SUCCESS] ImportFlow ERP Desktop is running!
    echo    - Backend API: http://127.0.0.1:%PORT%
    echo    - API Docs:    http://127.0.0.1:%PORT%/docs
    echo ===============================================================================
    ping 127.0.0.1 -n 3 >nul 2>&1
    exit /b 0
) else (
    echo [INFO] Launching via Flutter Desktop Debug against http://127.0.0.1:%PORT%...
    start "ImportFlow Desktop" cmd /k "cd /d %~dp0frontend && flutter run -d windows --dart-define=IMPORTFLOW_SERVER_URL=http://127.0.0.1:%PORT%"
    exit /b 0
)

:launch_web
echo.
:: The LAN web client always talks to <host>:28080 (no per-port define here): on another PORT it would
:: pair a dev backend with the production backend. Refuse before starting anything.
if "%PORT%"=="28080" goto launch_web_backend
echo [ERROR] Web / LAN mode only supports the default backend port 28080, but PORT is %PORT%.
echo         The browser client would talk to port 28080 = the installed production app on the production laptop.
echo         For development on that laptop use Desktop mode [1] or Backend API Only [3] with PORT=%PORT%.
pause
exit /b 1

:launch_web_backend
call "%~dp0scripts\check_backend_port.bat"
if errorlevel 2 exit /b 1
if errorlevel 1 goto launch_web_client
echo [2/3] Starting FastAPI Backend on http://0.0.0.0:%PORT%...
start "ImportFlow Backend" /min cmd /c "cd /d %~dp0 && python -m uvicorn main:app --host 0.0.0.0 --port %PORT%"

:launch_web_client

echo [3/3] Starting Flutter Web on http://localhost:3000...
start "ImportFlow Frontend" cmd /k "cd /d %~dp0frontend && flutter run -d web-server --web-port 3000 --web-hostname 0.0.0.0"

echo Waiting for Web Server to initialize...
ping 127.0.0.1 -n 5 >nul 2>&1
start http://localhost:3000

echo.
echo ===============================================================================
echo [SUCCESS] ImportFlow Web is launching at http://localhost:3000
echo ===============================================================================
ping 127.0.0.1 -n 3 >nul 2>&1
exit /b 0

:launch_backend_only
echo.
call "%~dp0scripts\check_backend_port.bat"
if errorlevel 2 exit /b 1
if errorlevel 1 goto launch_backend_docs
echo Starting FastAPI Backend on http://127.0.0.1:%PORT%...
start "ImportFlow Backend" cmd /k "cd /d %~dp0 && python -m uvicorn main:app --host 127.0.0.1 --port %PORT% --reload"
ping 127.0.0.1 -n 3 >nul 2>&1

:launch_backend_docs
start http://127.0.0.1:%PORT%/docs
exit /b 0

:launch_tests
echo.
echo Running Unit Tests...
python -m pytest -v
echo.
pause
exit /b 0
