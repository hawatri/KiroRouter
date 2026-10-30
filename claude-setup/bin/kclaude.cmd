@echo off
rem Claude Code through kiro-gateway. Plain "claude" stays on your Claude Pro login.
rem The key is read from the gateway's .env every time, so the two can never drift apart.
setlocal
if defined KIRO_GATEWAY_DIR (set "GW_DIR=%KIRO_GATEWAY_DIR%") else (set "GW_DIR=E:\Opus\kiro-gateway")
set "GW_ENV=%GW_DIR%\.env"

call "%~dp0kiro-gw.cmd" || exit /b 1

set "ANTHROPIC_API_KEY="
for /f "usebackq eol=# tokens=1,* delims==" %%a in ("%GW_ENV%") do (
  if /i "%%a"=="PROXY_API_KEY" set "ANTHROPIC_API_KEY=%%~b"
)
if not defined ANTHROPIC_API_KEY (
  echo PROXY_API_KEY not found in %GW_ENV%
  exit /b 1
)

set "ANTHROPIC_BASE_URL=http://127.0.0.1:8000"
set "ANTHROPIC_AUTH_TOKEN="
set "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1"
set "ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-5-5"
set "ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-5-5"
set "ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-5-5"

call claude %*
