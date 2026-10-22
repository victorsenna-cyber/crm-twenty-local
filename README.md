# CRM Twenty — instalador local para Windows

O [**Twenty**](https://github.com/twentyhq/twenty) é um CRM de código aberto: contatos, empresas, oportunidades, funil, tarefas e notas. Este pacote o instala **no próprio computador**, como um programa comum: sem servidor, sem mensalidade de nuvem e sem Docker. Os dados ficam na sua máquina.

**Versão:** Twenty **v2.49.0** (imagem oficial `twentycrm/twenty`).

## Requisitos

- Windows 10 (versão 2004 ou mais nova) ou Windows 11, 64 bits, com **processador Intel ou AMD**. Processador ARM (Snapdragon) não roda: o instalador avisa e para.
- Internet **durante a instalação** (baixa ~300 MB). Depois, o CRM funciona sem internet.
- 5 GB livres em disco. Com o CRM aberto, ~2 GB de memória; fechado, nada. Recomendado: 8 GB de RAM ou mais.
- **Não precisa de Docker, nem de Linux instalado antes.** Se o WSL (o Linux do Windows) não estiver ativo, o instalador pede permissão de administrador, ativa e pede para **reiniciar: depois do reinício a instalação continua sozinha** (não mova a pasta antes disso).
- **Virtualização ligada na BIOS** (Intel VT-x ou AMD-V). A maioria dos PCs vem com ela ligada, e o instalador confere antes de baixar qualquer coisa. Para conferir: Gerenciador de Tarefas → Desempenho → CPU → "Virtualização: Habilitado".

## Instalar

1. Botão verde **Code → Download ZIP**, e descompacte a pasta.
2. Dois cliques em **`Instalar.cmd`**. Leva de 5 a 10 minutos e mostra cada passo.
3. Abra pelo atalho **"CRM Twenty"** (área de trabalho e menu Iniciar). Na primeira abertura, crie a sua conta (e-mail e senha).

O instalador não pede administrador, salvo para ativar o WSL. O programa vai para `%LOCALAPPDATA%\Programs\CRM Twenty`.

## No dia a dia

- **Abrir o atalho** liga o CRM (cerca de 1 minuto) e abre a janela.
- **Fechar a janela** salva uma cópia do banco em **`Documentos\CRM Twenty\backups`** (guarda as 14 mais recentes) e desliga tudo.
- Se a sua pasta Documentos estiver no OneDrive, os backups vão para a nuvem sozinhos. **Se não estiver, copie essa pasta para fora do computador de vez em quando**: o CRM local não tem outra cópia.

## Atualizar

1. Troque o número em `instalador\versao.txt` pela versão nova ([releases do Twenty](https://github.com/twentyhq/twenty/releases), formato `vX.Y.Z`).
2. Rode o `Instalar.cmd` de novo. Ele detecta a instalação, faz backup, troca só o programa e migra o banco. **Os dados ficam.**

## Desinstalar

**`Desinstalar.cmd`** pede para digitar `APAGAR`, salva uma última cópia do banco em `Documentos\CRM Twenty\backups` (essa pasta fica) e remove o resto.

## Instalação sem baixar a imagem

Coloque a imagem do Twenty em `imagem\twenty-<versão>.tar` (1,2 GB), gerada por:

```
instalador\ferramentas\crane.exe export --platform linux/amd64 twentycrm/twenty:v2.49.0 imagem\twenty-v2.49.0.tar
```

O instalador usa o arquivo em vez de baixar. O banco (PostgreSQL e Redis) ainda vem da internet.

## Licenças

- O **Twenty** é AGPLv3 (`licencas\TWENTY-LICENSE.txt`), e o código-fonte está em https://github.com/twentyhq/twenty. Os recursos marcados "Enterprise" exigem assinatura com a Twenty.com e não estão inclusos.
- **crane** (Google, Apache 2.0) e **WebView2 SDK** (Microsoft): licenças em `licencas\`.
- Este pacote (instalador, app de janela e scripts) é distribuído junto, sob as mesmas condições do Twenty.

## Arquivos

| Caminho | O que é |
|---|---|
| `Instalar.cmd` · `Desinstalar.cmd` | o que se usa |
| `instalador\instalar.ps1` · `desinstalar.ps1` | a lógica (PowerShell 5.1, que vem em todo Windows) |
| `instalador\versao.txt` | a versão do Twenty que o pacote instala |
| `instalador\app\` | o programa de janela (`CRM.exe`, fonte em `CRM.cs`; recompilar com `compilar-app.ps1`) |
| `instalador\linux\` | os scripts que ligam e desligam o CRM dentro do WSL |
| `instalador\ferramentas\crane.exe` | baixa a imagem oficial sem Docker |
| `imagem\` | opcional: a imagem para instalar sem baixar |
| `licencas\` | Twenty (AGPLv3), crane (Apache 2.0), WebView2 SDK |

## Detalhes técnicos

Distro WSL própria `twenty-crm` (Alpine, com o app oficial já compilado), PostgreSQL 18 na porta interna 5442, Redis na 6389, CRM em **http://localhost:3020**, que também abre no navegador com o CRM ligado. As portas internas não são as padrão de propósito: as distros WSL dividem a mesma rede, e com 5432/6379 o CRM se ligaria a outro Postgres/Redis da máquina. Tudo escuta só no próprio computador (127.0.0.1). As chaves de criptografia são geradas na primeira subida, só dentro da distro, em `/opt/twenty/segredos.env`. Registros em `\\wsl$\twenty-crm\data\logs`.
