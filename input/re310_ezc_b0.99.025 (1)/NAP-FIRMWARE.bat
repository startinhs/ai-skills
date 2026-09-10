@echo off
REM Nhap doi file nay de nap firmware cho may in TSC RE310.
REM
REM Goi update-firmware.ps1 kem -ExecutionPolicy Bypass, vi mac dinh Win11 chan
REM chay script .ps1 tai ve tu noi khac — user nhap doi thang vao .ps1 se bi tu choi
REM ma khong hien ly do.
title Nap firmware may in TSC RE310
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-firmware.ps1"
echo.
pause
