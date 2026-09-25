@echo off
REM graft-status.cmd - show whether Graft is PAUSED or ACTIVE.
REM Also lists running runs, loaded models, GPU memory and the cron schedule.
REM Read-only: changes nothing.
wsl.exe -d Ubuntu -u mark -- /home/mark/graft/ops/scripts/graft status
echo.
pause
