<%@ Page Language="C#" AutoEventWireup="true" CodeFile="ConfigurationBDD.aspx.cs" Inherits="ConfigurationBDD" EnableViewStateMac="true" ValidateRequest="true" %>
<!DOCTYPE html>
<html lang="fr">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="color-scheme" content="light dark" />
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
    <title>Configuration de la base de données — GESTION FINANCIERE</title>
    <script>
        (function () {
            try {
                var theme = localStorage.getItem('theme');
                if (theme === 'dark' || localStorage.getItem('darkMode') === 'true')
                    document.documentElement.className += ' dark-mode';
            } catch (e) { }
        }());
    </script>
    <style>
        :root { color-scheme: light; --bg:#f3f6fb; --surface:#fff; --text:#17243a; --muted:#5e6b7e; --line:#dce3ed; --primary:#175cd3; --soft:#edf4ff; --danger:#a4262c; --success:#067647; }
        :root.dark-mode, body.dark-mode { color-scheme: dark; --bg:#111827; --surface:#1f2937; --text:#f3f4f6; --muted:#b7c1d0; --line:#374151; --primary:#7aa7ff; --soft:#26364f; --danger:#ff8f91; --success:#6ce9a6; }
        @media (prefers-color-scheme: dark) {
            :root:not(.light-mode) { color-scheme:dark; --bg:#111827; --surface:#1f2937; --text:#f3f4f6; --muted:#b7c1d0; --line:#374151; --primary:#7aa7ff; --soft:#26364f; --danger:#ff8f91; --success:#6ce9a6; }
        }
        * { box-sizing:border-box; }
        html, body { min-height:100%; margin:0; background:var(--bg); color:var(--text); font:15px/1.5 "Segoe UI",Arial,sans-serif; }
        body { transition:none; }
        .shell { width:min(1040px, calc(100% - 32px)); margin:38px auto; }
        .header { display:flex; align-items:center; gap:16px; margin-bottom:24px; }
        .header img { width:64px; height:64px; object-fit:contain; border-radius:14px; background:var(--surface); }
        h1 { margin:0; font-size:clamp(23px,4vw,32px); letter-spacing:-.4px; }
        .subtitle { margin:5px 0 0; color:var(--muted); }
        .status, .message { padding:13px 16px; margin:16px 0; border:1px solid var(--line); border-radius:12px; background:var(--surface); }
        .status { display:flex; align-items:flex-start; gap:10px; }
        .message:empty { display:none; }
        .message.error { color:var(--danger); border-color:var(--danger); }
        .message.success { color:var(--success); border-color:var(--success); }
        .message.warning { color:#9a6700; border-color:#d7a300; }
        .cards { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:16px; margin:20px 0; }
        .card { background:var(--surface); border:1px solid var(--line); border-radius:16px; padding:22px; box-shadow:0 8px 26px rgba(16,24,40,.06); }
        .card h2 { margin:0 0 8px; font-size:19px; }
        .card p, .hint { color:var(--muted); }
        .card p { min-height:46px; margin:0 0 18px; }
        .form-panel { margin-top:16px; }
        .fields { display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:14px; }
        .field { display:flex; flex-direction:column; gap:6px; min-width:0; }
        .field.full { grid-column:1/-1; }
        label { font-size:13px; font-weight:650; }
        input[type=text], input[type=password], input[type=email], select { width:100%; padding:11px 12px; border:1px solid var(--line); border-radius:9px; background:var(--bg); color:var(--text); font:inherit; }
        input:focus, select:focus { outline:2px solid var(--primary); outline-offset:1px; }
        .check { display:flex; align-items:center; gap:9px; color:var(--muted); }
        .actions { display:flex; flex-wrap:wrap; gap:10px; margin-top:18px; }
        .button { display:inline-flex; justify-content:center; align-items:center; min-height:42px; border:1px solid transparent; border-radius:9px; padding:9px 15px; background:var(--primary); color:#fff; font:600 14px "Segoe UI",Arial,sans-serif; text-decoration:none; cursor:pointer; }
        .button.secondary { background:var(--soft); color:var(--text); border-color:var(--line); }
        .button:disabled { opacity:.6; cursor:wait; }
        .hidden { display:none; }
        .security { margin-top:22px; font-size:13px; color:var(--muted); }
        @media (max-width:700px) { .shell { margin:20px auto; } .cards,.fields { grid-template-columns:1fr; } .field.full { grid-column:auto; } .card p { min-height:0; } }
    </style>
    <script>
        function beginSetup(button) {
            if (!button) return true;
            var buttons = document.querySelectorAll('input[type=submit],button');
            for (var i = 0; i < buttons.length; i++) buttons[i].disabled = true;
            var progress = document.getElementById('operationLoading');
            if (progress) progress.hidden = false;
            return true;
        }
        function confirmCreate() {
            return window.confirm('Confirmez-vous la création de cette nouvelle base ? Une base existante ne sera jamais écrasée.');
        }
    </script>
</head>
<body>
    <form id="form1" runat="server">
        <asp:HiddenField ID="hfCsrf" runat="server" />
        <main class="shell">
            <header class="header">
                <img src="img/Logo1.png" alt="Logo GESTION FINANCIERE" />
                <div>
                    <h1>Configuration de la base de données</h1>
                    <p class="subtitle">Rétablissez ou configurez la connexion SQL Server de l’application.</p>
                </div>
            </header>

            <asp:Panel ID="pnlLicenseError" runat="server" Visible="false" CssClass="message error">
                <asp:Literal ID="litLicenseError" runat="server" />
            </asp:Panel>

            <asp:Panel ID="pnlSetup" runat="server" Visible="false">
                <div class="status"><strong>État :</strong><asp:Literal ID="litStatus" runat="server" /></div>
                <asp:Label ID="lblMessage" runat="server" CssClass="message" />
                <p id="operationLoading" class="message" hidden role="status" aria-live="polite">Opération en cours, veuillez patienter…</p>
                <div class="cards">
                    <section class="card">
                        <h2>Base de données existante</h2>
                        <p>Connectez l'application à une base de données SQL Server existante.</p>
                        <asp:Button ID="btnShowExisting" runat="server" CssClass="button secondary" Text="Connecter une base existante" OnClick="btnShowExisting_Click" />
                    </section>
                    <section class="card">
                        <h2>Nouvelle installation</h2>
                        <p>Créez une nouvelle base, initialisez son schéma et définissez le premier compte administrateur.</p>
                        <asp:Button ID="btnShowNew" runat="server" CssClass="button secondary" Text="Configurer une nouvelle base" OnClick="btnShowNew_Click" />
                    </section>
                </div>

                <asp:Panel ID="pnlExisting" runat="server" Visible="false" CssClass="card form-panel">
                    <h2>Connexion à une base existante</h2>
                    <div class="fields">
                        <div class="field"><label for="txtServer">Serveur SQL Server</label><asp:TextBox ID="txtServer" runat="server" MaxLength="128" /><small class="hint">Pour PC-NYCKS\SQL2017, indiquez PC-NYCKS comme serveur et SQL2017 comme instance.</small></div>
                        <div class="field"><label for="txtInstance">Instance (facultative)</label><asp:TextBox ID="txtInstance" runat="server" MaxLength="128" /></div>
                        <div class="field full"><label for="txtDatabase">Nom de la base de données</label><asp:TextBox ID="txtDatabase" runat="server" MaxLength="128" /></div>
                        <div class="field"><label for="ddlAuthentication">Mode d’authentification</label><asp:DropDownList ID="ddlAuthentication" runat="server" AutoPostBack="true" OnSelectedIndexChanged="ddlAuthentication_SelectedIndexChanged"><asp:ListItem Value="sql">Authentification SQL Server</asp:ListItem><asp:ListItem Value="windows">Authentification Windows (IIS)</asp:ListItem></asp:DropDownList></div>
                        <div class="field"><label for="txtUsername">Nom d’utilisateur SQL</label><asp:TextBox ID="txtUsername" runat="server" MaxLength="128" autocomplete="off" /></div>
                        <div class="field"><label for="txtPassword">Mot de passe SQL</label><asp:TextBox ID="txtPassword" runat="server" TextMode="Password" MaxLength="128" autocomplete="new-password" /></div>
                        <div class="field full"><label class="check"><asp:CheckBox ID="chkEncrypt" runat="server" Checked="true" />Chiffrer la connexion (recommandé)</label></div>
                        <div class="field full"><label class="check"><asp:CheckBox ID="chkTrustCertificate" runat="server" />Faire confiance au certificat du serveur (uniquement si le certificat ne peut pas être validé)</label></div>
                    </div>
                    <div class="actions">
                        <asp:Button ID="btnTestExisting" runat="server" CssClass="button secondary" Text="Tester la connexion" OnClick="btnTestExisting_Click" OnClientClick="return beginSetup(this);" />
                        <asp:Button ID="btnSaveExisting" runat="server" CssClass="button" Text="Enregistrer la configuration" OnClick="btnSaveExisting_Click" OnClientClick="return beginSetup(this);" />
                        <asp:HyperLink ID="lnkCancel" runat="server" CssClass="button secondary" NavigateUrl="~/auth/Login.aspx" Text="Annuler" Visible="false" />
                    </div>
                </asp:Panel>

                <asp:Panel ID="pnlNew" runat="server" Visible="false" CssClass="card form-panel">
                    <h2>Nouvelle base de données</h2>
                    <p class="hint">Le compte doit pouvoir créer une base. Le schéma officiel sera adapté à cette base et aucun contenu d’une base existante ne sera supprimé.</p>
                    <div class="fields">
                        <div class="field"><label for="txtNewServer">Serveur SQL Server</label><asp:TextBox ID="txtNewServer" runat="server" MaxLength="128" /></div>
                        <div class="field"><label for="txtNewInstance">Instance (facultative)</label><asp:TextBox ID="txtNewInstance" runat="server" MaxLength="128" /></div>
                        <div class="field full"><label for="txtNewDatabase">Nom de la nouvelle base</label><asp:TextBox ID="txtNewDatabase" runat="server" MaxLength="128" /></div>
                        <div class="field"><label for="ddlNewAuthentication">Mode d’authentification</label><asp:DropDownList ID="ddlNewAuthentication" runat="server" AutoPostBack="true" OnSelectedIndexChanged="ddlAuthentication_SelectedIndexChanged"><asp:ListItem Value="sql">Authentification SQL Server</asp:ListItem><asp:ListItem Value="windows">Authentification Windows (IIS)</asp:ListItem></asp:DropDownList></div>
                        <div class="field"><label for="txtNewUsername">Nom d’utilisateur SQL</label><asp:TextBox ID="txtNewUsername" runat="server" MaxLength="128" autocomplete="off" /></div>
                        <div class="field"><label for="txtNewPassword">Mot de passe SQL</label><asp:TextBox ID="txtNewPassword" runat="server" TextMode="Password" MaxLength="128" autocomplete="new-password" /></div>
                        <div class="field full"><label class="check"><asp:CheckBox ID="chkNewEncrypt" runat="server" Checked="true" />Chiffrer la connexion (recommandé)</label></div>
                        <div class="field full"><label class="check"><asp:CheckBox ID="chkNewTrustCertificate" runat="server" />Faire confiance au certificat du serveur</label></div>
                    </div>
                    <h3>Premier compte administrateur</h3>
                    <div class="fields">
                        <div class="field"><label for="txtAdminUsername">Nom d’utilisateur</label><asp:TextBox ID="txtAdminUsername" runat="server" MaxLength="100" autocomplete="username" /></div>
                        <div class="field"><label for="txtAdminName">Nom affiché</label><asp:TextBox ID="txtAdminName" runat="server" MaxLength="100" /></div>
                        <div class="field"><label for="txtAdminEmail">Courriel</label><asp:TextBox ID="txtAdminEmail" runat="server" MaxLength="100" /></div>
                        <div class="field"><label for="txtAdminPassword">Mot de passe (12 caractères minimum)</label><asp:TextBox ID="txtAdminPassword" runat="server" TextMode="Password" MaxLength="128" autocomplete="new-password" /></div>
                        <div class="field full"><label class="check"><asp:CheckBox ID="chkConfirmCreate" runat="server" />Je confirme la création de cette base de données, qui n’existe pas encore.</label></div>
                    </div>
                    <div class="actions">
                        <asp:Button ID="btnTestNew" runat="server" CssClass="button secondary" Text="Tester le serveur et les permissions" OnClick="btnTestNew_Click" OnClientClick="return beginSetup(this);" />
                        <asp:Button ID="btnCreateNew" runat="server" CssClass="button" Text="Créer et initialiser la base" OnClick="btnCreateNew_Click" OnClientClick="return confirmCreate() && beginSetup(this);" />
                    </div>
                </asp:Panel>
                <p class="security">Les identifiants SQL ne sont ni affichés après enregistrement ni journalisés. La section de connexion de web.config est protégée par chiffrement IIS.</p>
            </asp:Panel>
        </main>
    </form>
</body>
</html>
