@echo off
REM graft-pause.cmd - SOFT pause of all Graft project activity (use before gaming).
REM Blocks new worker/review/dsh runs and unloads all Ollama models (frees VRAM/RAM).
REM A run already in progress finishes its current attempt, then stops.
REM Undo with graft-resume.cmd. See README.md in this folder.
wsl.exe -d Ubuntu -u mark -- /home/mark/graft/ops/scripts/graft pause --reason "gaming / GPU needed"
echo.
pause
