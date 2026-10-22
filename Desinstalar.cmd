@echo off
rem Remove o CRM Twenty. Pede confirmacao e guarda um ultimo backup em Documentos\CRM Twenty\backups.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalador\desinstalar.ps1"
echo.
pause
