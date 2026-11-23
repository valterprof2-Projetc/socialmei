@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js nao foi encontrado. Abrindo o aplicativo diretamente no navegador.
  echo Alguns recursos podem exigir o servidor local e/ou integracoes configuradas.
  start "" "%~dp0frontend\socialmei-app.html"
  pause
  exit /b 0
)
node "tools\servidor-local.cjs" --app
if errorlevel 1 (
  echo.
  echo Nao foi possivel iniciar o servidor. Revise a mensagem acima.
  pause
)
