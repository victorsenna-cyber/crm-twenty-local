// CRM Twenty: janela própria, ícone na barra de tarefas. Liga a distro WSL ao abrir;
// ao fechar, salva o banco em Documentos\CRM Twenty\backups e desliga tudo.
// Compilado por ../compilar-app.ps1 (só quem monta o pacote; quem instala recebe o .exe pronto).
using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

class CrmApp : Form
{
    [DllImport("user32.dll")]
    static extern bool SetProcessDpiAwarenessContext(IntPtr valor);
    [DllImport("dwmapi.dll")]
    static extern int DwmSetWindowAttribute(IntPtr janela, int atributo, ref int valor, int tamanho);

    const string DISTRO = "twenty-crm";
    const string URL = "http://localhost:3020";
    static readonly string BACKUPS = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "CRM Twenty", "backups");

    readonly WebView2 web = new WebView2();
    Process servidor;
    bool desligando;

    CrmApp()
    {
        Text = "CRM Twenty";
        Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        WindowState = FormWindowState.Maximized;
        string dados = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "CRM Twenty", "WebView2");
        web.CreationProperties = new CoreWebView2CreationProperties { UserDataFolder = dados };
        web.Dock = DockStyle.Fill;
        Controls.Add(web);
        web.CoreWebView2InitializationCompleted += (s, e) =>
        {
            if (!e.IsSuccess) { MessageBox.Show("Não consegui abrir o motor do Edge (WebView2).\n\n" + e.InitializationException.Message, Text); Close(); return; }
            web.CoreWebView2.NewWindowRequested += (s2, e2) => { e2.Handled = true; Process.Start(e2.Uri); };
            web.CoreWebView2.NavigateToString(Espera("Ligando o CRM…"));
            Ligar();
        };
        Shown += (s, e) => web.EnsureCoreWebView2Async(null);
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        int escuro = 1;
        DwmSetWindowAttribute(Handle, 20, ref escuro, sizeof(int));
    }

    static string Espera(string msg)
    {
        return "<html><body style='margin:0;height:100vh;display:flex;align-items:center;justify-content:center;font:16px Segoe UI,sans-serif;color:#999;background:#1b1b1b'>" + msg + "</body></html>";
    }

    static bool NoAr()
    {
        try
        {
            var r = (HttpWebRequest)WebRequest.Create(URL + "/healthz");
            r.Timeout = 2000;
            using (var resp = (HttpWebResponse)r.GetResponse()) return resp.StatusCode == HttpStatusCode.OK;
        }
        catch { return false; }
    }

    static Process Wsl(string args)
    {
        var p = new ProcessStartInfo("wsl.exe", args) { CreateNoWindow = true, UseShellExecute = false, WindowStyle = ProcessWindowStyle.Hidden };
        return Process.Start(p);
    }

    async void Ligar()
    {
        if (!NoAr()) servidor = Wsl("-d " + DISTRO + " -u root --exec /opt/twenty/iniciar.sh");
        var ate = DateTime.Now.AddMinutes(5);
        while (DateTime.Now < ate)
        {
            if (await Task.Run(() => NoAr())) { web.CoreWebView2.Navigate(URL); return; }
            await Task.Delay(1000);
        }
        web.CoreWebView2.NavigateToString(Espera("O CRM não respondeu em 5 minutos. Os registros ficam em \\\\wsl$\\" + DISTRO + "\\data\\logs"));
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        if (desligando) { base.OnFormClosing(e); return; }
        desligando = true;
        e.Cancel = true;
        Hide();
        Task.Run(() =>
        {
            try { Wsl("-d " + DISTRO + " -u root --exec /opt/twenty/parar.sh \"" + BACKUPS + "\"").WaitForExit(120000); } catch { }
            try { if (servidor != null && !servidor.HasExited) servidor.Kill(); } catch { }
            try { Wsl("--terminate " + DISTRO).WaitForExit(30000); } catch { }
        }).ContinueWith(t => BeginInvoke((Action)Close));
    }

    [STAThread]
    static void Main()
    {
        bool novo;
        using (new Mutex(true, "Continuum.CrmTwenty.App", out novo))
        {
            if (!novo) return;
            SetProcessDpiAwarenessContext(new IntPtr(-4));
            Application.EnableVisualStyles();
            Application.Run(new CrmApp());
        }
    }
}
