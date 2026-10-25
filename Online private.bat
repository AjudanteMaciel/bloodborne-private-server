@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Open-Online.ps1" -Mode Private
if errorlevel 1 pause
