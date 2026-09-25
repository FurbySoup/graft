@echo off
REM graft-pause-hard.cmd - HARD pause of all Graft project activity.
REM Same as graft-pause.cmd, and also stops an in-flight worker/review run now
REM (cleanly: its claim is released and the backlog item stays open).
REM Undo with graft-resume.cmd. See README.md in this folder.
wsl.exe -d Ubuntu -u mark -- /home/mark/graft/ops/scripts/graft pause --hard --reason "gaming / GPU needed"
echo.
pause
