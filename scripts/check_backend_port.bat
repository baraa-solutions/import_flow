@echo off
:: Shared backend-port guard for the dev launchers. It NEVER kills the process on the port: on the
:: production laptop the installed backend.exe owns 127.0.0.1:28080.
::
:: Usage:  call "%ROOT%scripts\check_backend_port.bat" ["<path to Release frontend.exe>"]
:: Sets (no setlocal, the variables survive the call):
::   PORT             28080 when not defined
::   USE_RELEASE_EXE  1 only when the given Release exe exists and PORT is 28080
::                    (the prebuilt exe cannot take --dart-define, it always talks to 28080)
:: Exit code: 0 = port free (start a backend), 1 = a backend already answers there (reuse it),
::            2 = port busy with something that does not answer the health check (abort).
:: Callers may run with delayed expansion enabled: keep exclamation marks out of this file.

if not defined PORT set "PORT=28080"

set "USE_RELEASE_EXE=0"
if not "%~1"=="" if exist "%~1" (
    if "%PORT%"=="28080" (
        set "USE_RELEASE_EXE=1"
    ) else (
        echo [INFO] PORT is %PORT%: skipping the prebuilt Release frontend.exe because it always talks to port 28080.
    )
)

netstat -ano | findstr /c:":%PORT% " | findstr "LISTENING" >nul 2>&1
if errorlevel 1 exit /b 0

curl -s -m 2 http://127.0.0.1:%PORT%/api/v1/health 2>nul | findstr /c:"Sorour Logistics ERP" >nul 2>&1
if errorlevel 1 goto port_busy

echo [OK] A backend is already running and responding on port %PORT%: reusing it.
if "%PORT%"=="28080" goto warn_production
echo [WARN] If you did not start it from this checkout, it may be the installed production app.
echo        In that case close the launcher, run  set PORT=28090  and start it again.
exit /b 1

:warn_production
echo [WARN] PORT is 28080, the production port. On the production laptop this IS the PRODUCTION backend:
echo        the dev client will write to REAL data. Close the launcher, run  set PORT=28090  and re-run it.
exit /b 1

:port_busy
echo [ERROR] Port %PORT% is already in use by another process that does not answer the health check.
echo         It may be the installed production app: this launcher will NOT stop it.
echo         Choose another port, e.g.  set PORT=28090  then run the launcher again.
pause
exit /b 2
