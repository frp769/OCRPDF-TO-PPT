@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\setup.ps1" -ForceDependencies
if errorlevel 1 (
  echo.
  echo Check or repair failed. Read the concrete error above.
  pause
  exit /b 1
)
echo.
echo Check and repair completed.
pause
endlocal
