@echo off
rem Start kiro-gateway in its own window if it is not running,
rem then wait until /health answers. Exit code 0 = ready, 1 = failed.
rem Override the defaults with the KIRO_GATEWAY_DIR / KIRO_GATEWAY_PYTHON environment variables.
setlocal
if defined KIRO_GATEWAY_DIR (set "GW_DIR=%KIRO_GATEWAY_DIR%") else (set "GW_DIR=E:\Opus\kiro-gateway")
if defined KIRO_GATEWAY_PYTHON (set "GW_PY=%KIRO_GATEWAY_PYTHON%") else (set "GW_PY=C:\ProgramData\anaconda3\python.exe")
set "GW_HEALTH=http://127.0.0.1:8000/health"

curl.exe -s -f -o NUL --max-time 3 "%GW_HEALTH%" && exit /b 0

netstat -ano | findstr /r /c:":8000 .*LISTENING" >NUL
if not errorlevel 1 (
  echo Port 8000 is taken by another program that is not kiro-gateway:
  netstat -ano | findstr /r /c:":8000 .*LISTENING"
  echo Close it, or run: taskkill /PID ^<last number above^> /F
  exit /b 1
)

if not exist "%GW_PY%" set "GW_PY=python"
echo Starting kiro-gateway in a new window...
start "kiro-gateway" /D "%GW_DIR%" "%GW_PY%" main.py

for /l %%i in (1,1,40) do (
  timeout /t 1 /nobreak >NUL
  curl.exe -s -f -o NUL --max-time 2 "%GW_HEALTH%" && (echo kiro-gateway is ready. & exit /b 0)
)
echo kiro-gateway did not start within 40 seconds. Check its window for the error.
exit /b 1
