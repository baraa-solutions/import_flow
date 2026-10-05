@echo off
rem Double-click launcher for promote_user_to_admin.ps1 (keep both files in the same folder).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0promote_user_to_admin.ps1" %*
