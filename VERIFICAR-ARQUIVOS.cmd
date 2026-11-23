@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Para executar a verificacao e necessario Node.js.
  pause
  exit /b 1
)
node "tools\verificar-arquivos.cjs"
echo.
pause
