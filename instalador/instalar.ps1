# Instala ou atualiza o CRM Twenty nesta máquina. Não pede administrador, exceto para ativar o WSL, se ele faltar.
# Precisa de internet: baixa a imagem oficial do Twenty (se não estiver em ..\imagem\) e o banco de dados (PostgreSQL e Redis).
$ErrorActionPreference = 'Continue'
$aqui    = $PSScriptRoot
$pacote  = Split-Path $aqui -Parent
$VERSAO  = (Get-Content (Join-Path $aqui 'versao.txt') -Raw).Trim()
$DISTRO  = 'twenty-crm'
$PORTA   = 3020
# portas internas próprias: todas as distros WSL dividem a mesma rede, e 5432/6379 podem ser de outro Postgres/Redis da máquina
$PG_PORTA    = 5442
$REDIS_PORTA = 6389
$destino = Join-Path $env:LOCALAPPDATA 'Programs\CRM Twenty'
# PowerShell de 32 bits enxerga o System32 como SysWOW64, onde o wsl.exe não existe
$wsl     = Join-Path $env:SystemRoot $(if ([Environment]::Is64BitProcess) { 'System32\wsl.exe' } else { 'Sysnative\wsl.exe' })

function Passo($t) { Write-Host ''; Write-Host "==> $t" -ForegroundColor Cyan }
function Aviso($t) { Write-Host "Atenção: $t" -ForegroundColor Yellow }
function Falha($t) { Write-Host ''; Write-Host "ERRO: $t" -ForegroundColor Red; exit 1 }
# comando dentro da distro; --exec evita que o wsl expanda variáveis antes da hora. Sem aspas duplas dentro de $cmd.
function Linux($cmd) { & $wsl -d $DISTRO -u root --exec sh -c $cmd | Out-Host; return $LASTEXITCODE }
# caminho do Windows visto de dentro da distro (para usar entre aspas simples: os caminhos têm espaço)
function CaminhoLinux($p) { return ((& $wsl -d $DISTRO -u root --exec wslpath -u $p) -join '').Trim() }
function NoAr { try { (Invoke-WebRequest "http://localhost:$PORTA/healthz" -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200 } catch { $false } }
# scripts de ligar/desligar e a configuração dentro da distro; antes de qualquer parada, para a parada já usar as portas certas
function GravarScripts {
    $lw = CaminhoLinux (Join-Path $aqui 'linux')
    $r = Linux "mkdir -p /opt/twenty && for f in iniciar parar; do tr -d '\r' < '$lw'/`$f.sh > /opt/twenty/`$f.sh; done && chmod +x /opt/twenty/*.sh && printf 'PORTA=%s\nPG_PORTA=%s\nREDIS_PORTA=%s\n' $PORTA $PG_PORTA $REDIS_PORTA > /opt/twenty/config.env"
    if ($r -ne 0) { Falha 'não consegui copiar os scripts para o ambiente.' }
}

Write-Host "CRM Twenty $VERSAO — instalação" -ForegroundColor White

Passo 'Liberando os arquivos do pacote'
# pacote vindo de zip baixado (WhatsApp, Drive, e-mail) chega marcado, e o Windows barra o CRM.exe
Get-ChildItem $pacote -Recurse -File | Unblock-File -ErrorAction SilentlyContinue

Passo 'Conferindo o Windows'
if ([Environment]::OSVersion.Version.Build -lt 19041) { Falha 'é preciso Windows 10 versão 2004 ou mais novo, ou Windows 11.' }
if (-not [Environment]::Is64BitOperatingSystem) { Falha 'é preciso Windows de 64 bits.' }
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$pc  = Get-CimInstance Win32_ComputerSystem
if ($cpu.Architecture -eq 12 -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') {
    Falha 'este computador tem processador ARM (por exemplo, Snapdragon). O CRM só roda em processador Intel ou AMD.'
}
$disco = $env:LOCALAPPDATA.Substring(0, 1)
$livre = (Get-PSDrive $disco).Free
if ($livre -lt 5GB) { Falha ('é preciso 5 GB livres no disco {0}:, e há {1:N1} GB.' -f $disco, ($livre / 1GB)) }
if ($pc.TotalPhysicalMemory -lt 7GB) { Aviso ('este computador tem {0:N0} GB de memória. O CRM roda, mas com 8 GB ou mais fica bem mais leve.' -f ($pc.TotalPhysicalMemory / 1GB)) }

Passo 'Conferindo a virtualização (o WSL precisa dela)'
# com o WSL já ativo o Windows esconde o dado da BIOS, e o hipervisor no ar já prova que ela está ligada
if (-not $pc.HypervisorPresent -and $cpu.VirtualizationFirmwareEnabled -eq $false) {
    Falha 'a virtualização está desligada na BIOS do computador (Intel VT-x ou AMD-V). Ligue-a na BIOS e rode o Instalar de novo: o README explica.'
}

Passo 'Conferindo o WSL (o Linux do Windows, onde o CRM roda)'
$temWsl = $false
if (Test-Path $wsl) { & $wsl --status *> $null; $temWsl = ($LASTEXITCODE -eq 0) }
if (-not $temWsl) {
    Write-Host 'O WSL não está ativo. Vou pedir permissão de administrador para ativá-lo (pode levar alguns minutos).'
    # dism ativa os dois recursos em qualquer Windows 10/11, inclusive onde o wsl.exe ainda nem existe
    $ativar = @'
$r = 0
foreach ($f in 'Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform') {
    dism.exe /online /enable-feature /featurename:$f /all /norestart | Out-Null
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) { $r = 1 }
}
exit $r
'@
    $cod = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ativar))
    try { $adm = Start-Process powershell.exe -ArgumentList '-NoProfile', '-EncodedCommand', $cod -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop }
    catch { Falha 'sem a permissão de administrador não dá para ativar o WSL. Rode o Instalar de novo e clique em "Sim".' }
    if ($adm.ExitCode -ne 0) { Falha 'o Windows não ativou o WSL. Rode o Windows Update, reinicie e tente de novo.' }
    # depois do reinício, a instalação continua sozinha quando a pessoa entrar no Windows
    $runOnce = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
    if (-not (Test-Path $runOnce)) { New-Item $runOnce | Out-Null }
    Set-ItemProperty $runOnce -Name 'CRM Twenty' -Value ('cmd.exe /c ""{0}""' -f (Join-Path $pacote 'Instalar.cmd'))
    Write-Host ''
    Write-Host 'WSL ativado. REINICIE o computador: a instalação continua sozinha quando você entrar no Windows.' -ForegroundColor Yellow
    Write-Host 'Não mova nem apague esta pasta antes disso.' -ForegroundColor Yellow
    exit 0
}
# WSL que veio com o Windows (sem a versão da Store) não importa ambiente WSL 2 direito: atualizar
& $wsl --version *> $null
if ($LASTEXITCODE -ne 0) {
    Passo 'Atualizando o WSL'
    & $wsl --update
    & $wsl --version *> $null
    if ($LASTEXITCODE -ne 0) { Falha 'não consegui atualizar o WSL. Rode o Windows Update, reinicie e tente de novo.' }
}

Passo 'Conferindo o WebView2 (o motor da janela)'
$wv2 = 'SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
$temWv2 = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\$($wv2.Substring(9))" -Name pv -ErrorAction SilentlyContinue) -or
          (Get-ItemProperty "HKCU:\$wv2" -Name pv -ErrorAction SilentlyContinue)
if (-not $temWv2) {
    $boot = Join-Path $env:TEMP 'MicrosoftEdgeWebview2Setup.exe'
    Invoke-WebRequest 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $boot -UseBasicParsing
    Start-Process $boot -ArgumentList '/silent', '/install' -Wait
}

& $wsl -d $DISTRO --exec true *> $null
$atualizar = ($LASTEXITCODE -eq 0)
$versaoInstalada = ''
if ($atualizar) { $versaoInstalada = (& $wsl -d $DISTRO -u root --exec cat /opt/twenty/versao 2>$null) -join '' }

# a imagem oficial: do pacote, se vier junto (instalação offline), ou baixada agora
$tar = Join-Path $pacote "imagem\twenty-$VERSAO.tar"
$baixada = $false
if ((-not $atualizar) -or ($versaoInstalada -ne $VERSAO)) {
    if (-not (Test-Path $tar)) {
        Passo "Baixando o Twenty $VERSAO (imagem oficial, ~260 MB)"
        $tar = Join-Path $env:TEMP "crm-twenty-$VERSAO.tar"
        & (Join-Path $aqui 'ferramentas\crane.exe') export --platform linux/amd64 "twentycrm/twenty:$VERSAO" $tar
        if ($LASTEXITCODE -ne 0) { Falha 'não consegui baixar a imagem do Twenty. Confira a internet.' }
        $baixada = $true
    }
}

New-Item -ItemType Directory -Force $destino | Out-Null
if (-not $atualizar) {
    Passo 'Criando o ambiente do CRM'
    & $wsl --import $DISTRO (Join-Path $destino 'distro') $tar --version 2
    if ($LASTEXITCODE -ne 0) { Falha 'o WSL não importou o ambiente. Quase sempre é a virtualização desligada na BIOS: veja o README.' }
    GravarScripts
} elseif ($versaoInstalada -ne $VERSAO) {
    Passo "Atualizando de $versaoInstalada para $VERSAO (os dados ficam)"
    GravarScripts
    $bk = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'CRM Twenty\backups'
    Linux "su-exec postgres pg_ctl -D /data/postgres -o '-c listen_addresses=127.0.0.1 -c port=$PG_PORTA' -w start > /dev/null 2>&1; /opt/twenty/parar.sh '$bk'" | Out-Null
    $tw = CaminhoLinux $tar
    $r = Linux "rm -rf /novo && mkdir /novo && tar -xf '$tw' -C /novo app usr/local && rm -rf /app && mv /novo/app /app && cp -a /novo/usr/local/. /usr/local/ && rm -rf /novo"
    if ($r -ne 0) { Falha 'não consegui trocar a versão do app.' }
} else {
    Passo "Já está na versão ${VERSAO}: atualizando só o app e os scripts"
    GravarScripts
}

Passo 'Instalando o banco de dados (PostgreSQL 18 e Redis)'
if ((Linux 'apk update -q && apk add -q postgresql18 postgresql18-contrib redis su-exec > /dev/null') -ne 0) { Falha 'não consegui instalar o banco. Confira a internet.' }

Passo 'Copiando o programa'
foreach ($p in 'app', 'linux', 'licencas') { New-Item -ItemType Directory -Force (Join-Path $destino $p) | Out-Null }
Copy-Item (Join-Path $aqui 'app\*') (Join-Path $destino 'app') -Exclude '*.cs' -Force
Copy-Item (Join-Path $aqui 'linux\*') (Join-Path $destino 'linux') -Force
Copy-Item (Join-Path $pacote 'licencas\*') (Join-Path $destino 'licencas') -Force
Copy-Item (Join-Path $aqui 'desinstalar.ps1') $destino -Force
if ((Linux "echo $VERSAO > /opt/twenty/versao") -ne 0) { Falha 'não consegui registrar a versão no ambiente.' }

Passo 'Criando os atalhos'
$sh = New-Object -ComObject WScript.Shell
$exe = Join-Path $destino 'app\CRM.exe'
foreach ($pasta in [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs')) {
    $s = $sh.CreateShortcut((Join-Path $pasta 'CRM Twenty.lnk'))
    $s.TargetPath = $exe; $s.WorkingDirectory = (Split-Path $exe); $s.IconLocation = "$exe,0"; $s.Description = 'CRM Twenty'
    $s.Save()
}

Passo 'Primeira subida: preparando o banco (1 a 3 minutos)'
$proc = Start-Process $wsl -ArgumentList '-d', $DISTRO, '-u', 'root', '--exec', '/opt/twenty/iniciar.sh' -WindowStyle Hidden -PassThru
$ok = $false
for ($i = 0; $i -lt 300; $i++) { if (NoAr) { $ok = $true; break }; Start-Sleep 1 }
Linux '/opt/twenty/parar.sh' | Out-Null
if (-not $proc.HasExited) { $proc.Kill() }
& $wsl --terminate $DISTRO | Out-Null
if ($baixada) { Remove-Item $tar -ErrorAction SilentlyContinue }
if (-not $ok) { Falha "o CRM não respondeu. Os registros ficam em \\wsl$\$DISTRO\data\logs" }

Write-Host ''
Write-Host "Pronto. O CRM Twenty $VERSAO está instalado." -ForegroundColor Green
Write-Host 'Abra pelo atalho "CRM Twenty" na área de trabalho. Na primeira abertura, crie a sua conta.'
Write-Host 'Ao fechar a janela, uma cópia do banco vai para Documentos\CRM Twenty\backups.'
