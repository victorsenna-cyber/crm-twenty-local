# Só para quem monta o pacote: recompila app\CRM.exe a partir de app\CRM.cs.
# O csc do .NET Framework 4 vem em todo Windows; as DLLs do WebView2 já estão em app\.
$app = Join-Path $PSScriptRoot 'app'
& 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe' /nologo /target:winexe /platform:x64 /optimize+ `
    "/win32icon:$app\twenty.ico" "/out:$app\CRM.exe" `
    /r:System.Windows.Forms.dll /r:System.Drawing.dll `
    "/r:$app\Microsoft.Web.WebView2.Core.dll" "/r:$app\Microsoft.Web.WebView2.WinForms.dll" "$app\CRM.cs"
if ($LASTEXITCODE) { throw 'falhou a compilação' } else { 'CRM.exe compilado' }
