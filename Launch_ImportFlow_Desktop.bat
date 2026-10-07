@echo off
title Sorour Logistics ERP Desktop
setlocal

echo ====================================================
echo   Sorour Logistics ERP - Windows Desktop App
echo ====================================================
echo.

:: Backend port. The installed production app uses 28080: on a machine that also runs it,
:: set PORT to another value first, e.g.  set PORT=28090
if not defined PORT set PORT=28080

:: Never kill whatever listens on the port (it may be the production app)
set "CLIENT_EXE=%~dp0frontend\build\windows\x64\runner\Release\frontend.exe"
call "%~dp0scripts\check_backend_port.bat" "%CLIENT_EXE%"
if errorlevel 2 exit /b 1
if errorlevel 1 goto launch_client

:: Start Backend API in minimized background process
echo Starting Backend API on http://127.0.0.1:%PORT%...
start "Sorour Logistics Backend" /min cmd /c "cd /d %~dp0 && python -m uvicorn main:app --host 127.0.0.1 --port %PORT% --reload"

:: Wait 2 seconds for API server ready
ping 127.0.0.1 -n 3 >nul 2>&1

:launch_client

:: Launch Native Windows Desktop Executable (.EXE)
echo Launching Sorour Logistics Desktop Application...
:: USE_RELEASE_EXE comes from check_backend_port.bat (1 only on PORT 28080: the prebuilt exe always talks to 28080)
if "%USE_RELEASE_EXE%"=="1" (
    start "" "%CLIENT_EXE%"
) else (
    start "Sorour Logistics Desktop" cmd /k "cd /d %~dp0frontend && flutter run -d windows --dart-define=IMPORTFLOW_SERVER_URL=http://127.0.0.1:%PORT%"
)

exit /b 0
