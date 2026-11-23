@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js nao foi encontrado. Abrindo a landing diretamente no navegador.
  echo Para testar o site completo sem restricoes de arquivo, instale o Node.js LTS.
  start "" "%~dp0frontend\entrada.html"
  pause
  exit /b 0
)
node "tools\servidor-local.cjs" --site
if errorlevel 1 (
  echo.
  echo Nao foi possivel iniciar o servidor. Revise a mensagem acima.
  pause
)
