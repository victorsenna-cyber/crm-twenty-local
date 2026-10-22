# Remove o CRM Twenty desta máquina. Antes, salva uma última cópia do banco em Documentos\CRM Twenty\backups (que fica).
param([switch]$Sim)
$ErrorActionPreference = 'Continue'
$DISTRO  = 'twenty-crm'
$destino = Join-Path $env:LOCALAPPDATA 'Programs\CRM Twenty'
$bk      = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'CRM Twenty\backups'

if (-not $Sim) {
    Write-Host 'Isto apaga o CRM e TODOS os dados dele nesta máquina.' -ForegroundColor Yellow
    Write-Host "Antes, uma última cópia do banco vai para $bk, e essa pasta fica."
    if ((Read-Host 'Digite APAGAR para confirmar') -ne 'APAGAR') { Write-Host 'Nada foi apagado.'; exit 0 }
}

Get-Process CRM -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$destino*" } | Stop-Process -Force

& wsl.exe -d $DISTRO --exec true *> $null
if ($LASTEXITCODE -eq 0) {
    & wsl.exe -d $DISTRO -u root --exec sh -c "su-exec postgres pg_ctl -D /data/postgres -o '-c listen_addresses=127.0.0.1 -c port=5442' -w start > /dev/null 2>&1; /opt/twenty/parar.sh '$bk'"
    & wsl.exe --terminate $DISTRO | Out-Null
    & wsl.exe --unregister $DISTRO | Out-Null
}
foreach ($pasta in [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs')) {
    Remove-Item (Join-Path $pasta 'CRM Twenty.lnk') -ErrorAction SilentlyContinue
}
Remove-Item $destino -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:LOCALAPPDATA 'CRM Twenty') -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "CRM Twenty removido. Os backups continuam em $bk" -ForegroundColor Green
