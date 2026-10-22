@echo off
rem Dois cliques aqui instalam (ou atualizam) o CRM Twenty.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalador\instalar.ps1"
echo.
pause
