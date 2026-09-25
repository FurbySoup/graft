@echo off
REM graft-resume.cmd - resume Graft project activity after a pause.
REM Removes the pause flag so scheduled runs work again. Does not preload models;
REM Ollama loads one only when Graft next needs it.
wsl.exe -d Ubuntu -u mark -- /home/mark/graft/ops/scripts/graft resume
echo.
pause
