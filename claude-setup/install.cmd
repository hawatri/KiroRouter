@echo off
rem Copies the kclaude and kiro-gw commands into %USERPROFILE%\.local\bin (already on PATH).
setlocal
set "DEST=%USERPROFILE%\.local\bin"
if not exist "%DEST%" mkdir "%DEST%"
copy /Y "%~dp0bin\kclaude.cmd" "%DEST%\" >NUL || exit /b 1
copy /Y "%~dp0bin\kiro-gw.cmd" "%DEST%\" >NUL || exit /b 1
echo Installed kclaude and kiro-gw to %DEST%
echo If "kclaude" is not found, add %DEST% to your user PATH and open a new terminal.
