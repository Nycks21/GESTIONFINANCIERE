using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Web;
using System.Web.UI;

public partial class ConfigurationBDD : Page
{
    private const string TestedNewConnectionKey = "DATABASE_SETUP_TESTED_CONNECTION";
    private static readonly object RateLock = new object();
    private static readonly Dictionary<string, RateState> RateLimits =
        new Dictionary<string, RateState>(StringComparer.Ordinal);
    private bool postbackAllowed = true;
    private string submittedExistingUsername = String.Empty;
    private string submittedExistingPassword = String.Empty;
    private string submittedNewUsername = String.Empty;
    private string submittedNewPassword = String.Empty;
    private string submittedAdminPassword = String.Empty;

    private sealed class RateState
    {
        public DateTime WindowStarted;
        public int Count;
    }

    protected void Page_Init(object sender, EventArgs e)
    {
        ViewStateUserKey = Session.SessionID;
    }

    protected void Page_Load(object sender, EventArgs e)
    {
        Response.Cache.SetCacheability(HttpCacheability.NoCache);
        Response.Cache.SetNoStore();
        Response.AppendHeader("X-Content-Type-Options", "nosniff");
        Response.AppendHeader("X-Frame-Options", "DENY");
        Response.AppendHeader("Referrer-Policy", "same-origin");

        if (!IsPostBack)
            hfCsrf.Value = CreateCsrfToken();
        else
        {
            postbackAllowed = ValidatePostback();
            submittedExistingUsername = txtUsername.Text;
            submittedExistingPassword = txtPassword.Text;
            submittedNewUsername = txtNewUsername.Text;
            submittedNewPassword = txtNewPassword.Text;
            submittedAdminPassword = txtAdminPassword.Text;
            txtUsername.Text = String.Empty;
            txtPassword.Text = String.Empty;
            txtNewUsername.Text = String.Empty;
            txtNewPassword.Text = String.Empty;
            txtAdminPassword.Text = String.Empty;
        }

        if (!AuthHelper.GetLicenceInfo().IsValid)
        {
            ShowLicenseError();
            return;
        }

        DatabaseHealth health = DatabaseConnectionHelper.GetCachedHealth();
        if (health.IsConnected)
        {
            if (!AuthHelper.IsAuthenticated(Context) ||
                (!AuthHelper.IsSuperAdmin() && !AuthHelper.IsAdmin()))
            {
                Response.Redirect(VirtualPathUtility.ToAbsolute("~/auth/Login.aspx"), false);
                Context.ApplicationInstance.CompleteRequest();
                return;
            }
            ShowSetup(health);
            return;
        }

        if (!IsLocalSetupRequest())
        {
            Response.StatusCode = 403;
            Response.TrySkipIisCustomErrors = true;
            pnlSetup.Visible = false;
            return;
        }

        ShowSetup(health);
    }

    protected void btnShowExisting_Click(object sender, EventArgs e)
    {
        if (!CanConfigure()) return;
        pnlExisting.Visible = true;
        pnlNew.Visible = false;
        lblMessage.Text = String.Empty;
    }

    protected void btnShowNew_Click(object sender, EventArgs e)
    {
        if (!CanConfigure()) return;
        pnlNew.Visible = true;
        pnlExisting.Visible = false;
        lblMessage.Text = String.Empty;
    }

    protected void ddlAuthentication_SelectedIndexChanged(object sender, EventArgs e)
    {
        if (!CanConfigure()) return;
        UpdateSqlCredentialVisibility();
    }

    protected void btnTestExisting_Click(object sender, EventArgs e)
    {
        if (!CanConfigure() || !AllowOperation("test_existing")) return;
        try
        {
            string connectionString = BuildExistingConnectionString();
            DatabaseSetupResult result = DatabaseConfigurationService.TestConnection(connectionString, true);
            SetMessage(result.Message, result.Success ? "success" : "error");
            LogOperation(result.Success ? "existing_connection_test_succeeded" : "existing_connection_test_failed");
        }
        catch (ArgumentException exception)
        {
            SetMessage(exception.Message, "error");
        }
        finally
        {
            txtUsername.Text = String.Empty;
            txtPassword.Text = String.Empty;
        }
    }

    protected void btnSaveExisting_Click(object sender, EventArgs e)
    {
        if (!CanConfigure() || !AllowOperation("save_existing")) return;
        try
        {
            DatabaseSetupResult result =
                DatabaseConfigurationService.SaveExistingConnection(BuildExistingConnectionString());
            SetMessage(result.Message, result.Success ? "success" : "error");
            LogOperation(result.Success ? "existing_connection_saved" : "existing_connection_save_failed");
            if (result.Success)
                RedirectToLogin();
        }
        catch (ArgumentException exception)
        {
            SetMessage(exception.Message, "error");
        }
        finally
        {
            txtUsername.Text = String.Empty;
            txtPassword.Text = String.Empty;
        }
    }

    protected void btnTestNew_Click(object sender, EventArgs e)
    {
        if (!CanConfigure() || !AllowOperation("test_new")) return;
        try
        {
            string connectionString = BuildNewConnectionString();
            DatabaseSetupResult result =
                DatabaseConfigurationService.TestServer(connectionString, txtNewDatabase.Text.Trim());
            Session[TestedNewConnectionKey] = result.Success
                ? HashConnectionString(connectionString, txtNewDatabase.Text.Trim())
                : null;
            SetMessage(result.Message, result.Success ? "success" : "error");
            LogOperation(result.Success ? "new_database_test_succeeded" : "new_database_test_failed");
        }
        catch (ArgumentException exception)
        {
            Session.Remove(TestedNewConnectionKey);
            SetMessage(exception.Message, "error");
        }
        finally
        {
            txtNewUsername.Text = String.Empty;
            txtNewPassword.Text = String.Empty;
        }
    }

    protected void btnCreateNew_Click(object sender, EventArgs e)
    {
        if (!CanConfigure() || !AllowOperation("create_database")) return;
        if (!chkConfirmCreate.Checked)
        {
            SetMessage("Cochez la confirmation avant de créer la base.", "warning");
            return;
        }
        try
        {
            string connectionString = BuildNewConnectionString();
            string databaseName = txtNewDatabase.Text.Trim();
            string testedHash = Session[TestedNewConnectionKey] as string;
            if (String.IsNullOrEmpty(testedHash) ||
                !FixedTimeTokenEquals(testedHash, HashConnectionString(connectionString, databaseName)))
            {
                SetMessage("Testez le serveur avec ces paramètres avant de confirmer la création.", "warning");
                return;
            }

            DatabaseSetupResult result = DatabaseConfigurationService.CreateAndInitialize(
                connectionString, databaseName, txtAdminUsername.Text, txtAdminName.Text,
                txtAdminEmail.Text, submittedAdminPassword);
            SetMessage(result.Message, result.Success ? "success" : "error");
            LogOperation(result.Success ? "new_database_created" : "new_database_creation_failed");
            Session.Remove(TestedNewConnectionKey);
            if (result.Success)
                RedirectToLogin();
        }
        catch (ArgumentException exception)
        {
            SetMessage(exception.Message, "error");
        }
        finally
        {
            txtNewUsername.Text = String.Empty;
            txtNewPassword.Text = String.Empty;
            txtAdminPassword.Text = String.Empty;
        }
    }

    private void ShowSetup(DatabaseHealth health)
    {
        pnlSetup.Visible = true;
        litStatus.Text = HttpUtility.HtmlEncode(GetStatusMessage(health.Status));
        lnkCancel.Visible = health.IsConnected;
        if (!IsPostBack)
        {
            pnlExisting.Visible = false;
            pnlNew.Visible = false;
        }
        UpdateSqlCredentialVisibility();
    }

    private void ShowLicenseError()
    {
        pnlLicenseError.Visible = true;
        pnlSetup.Visible = false;
        var licence = AuthHelper.GetLicenceInfo();
        litLicenseError.Text = HttpUtility.HtmlEncode(licence.IsExpired
            ? "La licence de l’application a expiré. La configuration de la base reste indisponible jusqu’au rétablissement de la licence."
            : "La licence de l’application est absente ou invalide. La configuration de la base n’est pas autorisée.");
    }

    private string GetStatusMessage(DatabaseConnectionStatus status)
    {
        switch (status)
        {
            case DatabaseConnectionStatus.MissingConfiguration:
                return "Aucune chaîne de connexion n’est configurée.";
            case DatabaseConnectionStatus.InvalidConfiguration:
                return "La configuration de connexion SQL Server est incomplète ou invalide.";
            case DatabaseConnectionStatus.IncompatibleSchema:
                return "Le serveur répond, mais le schéma de la base n’est pas compatible.";
            default:
                return "Le serveur SQL Server est inaccessible ou la connexion a échoué.";
        }
    }

    private bool CanConfigure()
    {
        if (!postbackAllowed || !AuthHelper.GetLicenceInfo().IsValid)
            return false;

        DatabaseHealth health = DatabaseConnectionHelper.GetCachedHealth();
        if (health.IsConnected)
            return AuthHelper.IsAuthenticated(Context) &&
                   (AuthHelper.IsSuperAdmin() || AuthHelper.IsAdmin());

        if (IsLocalSetupRequest())
            return true;

        Response.StatusCode = 403;
        Response.TrySkipIisCustomErrors = true;
        return false;
    }

    private bool AllowOperation(string operation)
    {
        string key = operation + ":" + (Request.UserHostAddress ?? "local");
        if (AllowAttempt(key, 10, TimeSpan.FromMinutes(1)))
            return true;
        SetMessage("Trop d’opérations rapprochées. Attendez une minute avant de réessayer.", "warning");
        return false;
    }

    private bool IsLocalSetupRequest()
    {
        return Request.IsLocal &&
               String.IsNullOrEmpty(Request.Headers["X-Forwarded-For"]) &&
               String.IsNullOrEmpty(Request.Headers["Forwarded"]);
    }

    private static bool AllowAttempt(string key, int limit, TimeSpan window)
    {
        lock (RateLock)
        {
            DateTime now = DateTime.UtcNow;
            RateState state;
            if (!RateLimits.TryGetValue(key, out state) || now - state.WindowStarted >= window)
            {
                state = new RateState { WindowStarted = now, Count = 0 };
                RateLimits[key] = state;
            }
            if (state.Count >= limit)
                return false;
            state.Count++;
            return true;
        }
    }

    private string BuildExistingConnectionString()
    {
        return DatabaseConfigurationService.BuildConnectionString(
            txtServer.Text, txtInstance.Text, txtDatabase.Text,
            ddlAuthentication.SelectedValue == "windows", submittedExistingUsername,
            submittedExistingPassword, chkEncrypt.Checked, chkTrustCertificate.Checked);
    }

    private string BuildNewConnectionString()
    {
        return DatabaseConfigurationService.BuildConnectionString(
            txtNewServer.Text, txtNewInstance.Text, txtNewDatabase.Text,
            ddlNewAuthentication.SelectedValue == "windows", submittedNewUsername,
            submittedNewPassword, chkNewEncrypt.Checked, chkNewTrustCertificate.Checked);
    }

    private void UpdateSqlCredentialVisibility()
    {
        bool existingSql = ddlAuthentication.SelectedValue == "sql";
        txtUsername.Enabled = existingSql;
        txtPassword.Enabled = existingSql;
        bool newSql = ddlNewAuthentication.SelectedValue == "sql";
        txtNewUsername.Enabled = newSql;
        txtNewPassword.Enabled = newSql;
    }

    private bool ValidatePostback()
    {
        string expected = Session["DATABASE_SETUP_CSRF"] as string;
        string supplied = hfCsrf.Value;
        if (String.IsNullOrEmpty(expected) || !FixedTimeTokenEquals(expected, supplied))
        {
            SetMessage("La demande a expiré. Rechargez la page avant de réessayer.", "error");
            return false;
        }

        string origin = Request.Headers["Origin"];
        if (String.IsNullOrEmpty(origin))
            origin = Request.Headers["Referer"];
        if (!String.IsNullOrEmpty(origin))
        {
            Uri parsedOrigin;
            if (!Uri.TryCreate(origin, UriKind.Absolute, out parsedOrigin) ||
                !String.Equals(parsedOrigin.Host, Request.Url.Host, StringComparison.OrdinalIgnoreCase) ||
                parsedOrigin.Port != Request.Url.Port)
            {
                SetMessage("La demande a été refusée car son origine n’est pas valide.", "error");
                return false;
            }
        }
        return true;
    }

    private string CreateCsrfToken()
    {
        byte[] bytes = new byte[32];
        using (RandomNumberGenerator random = RandomNumberGenerator.Create())
            random.GetBytes(bytes);
        string token = Convert.ToBase64String(bytes);
        Session["DATABASE_SETUP_CSRF"] = token;
        return token;
    }

    private static bool FixedTimeTokenEquals(string expected, string supplied)
    {
        if (expected == null || supplied == null)
            return false;
        using (SHA256 sha = SHA256.Create())
        {
            byte[] a = sha.ComputeHash(Encoding.UTF8.GetBytes(expected));
            byte[] b = sha.ComputeHash(Encoding.UTF8.GetBytes(supplied));
            int difference = 0;
            for (int i = 0; i < a.Length; i++)
                difference |= a[i] ^ b[i];
            return difference == 0;
        }
    }

    private static string HashConnectionString(string connectionString, string databaseName)
    {
        using (SHA256 sha = SHA256.Create())
        {
            byte[] hash = sha.ComputeHash(Encoding.UTF8.GetBytes(connectionString + "|" + databaseName));
            return Convert.ToBase64String(hash);
        }
    }

    private void SetMessage(string message, string type)
    {
        lblMessage.Text = HttpUtility.HtmlEncode(message);
        lblMessage.CssClass = "message " + type;
    }

    private void RedirectToLogin()
    {
        Response.Redirect(VirtualPathUtility.ToAbsolute("~/auth/Login.aspx"), false);
        Context.ApplicationInstance.CompleteRequest();
    }

    private void LogOperation(string operation)
    {
        string path = Path.Combine(AppDomain.CurrentDomain.BaseDirectory,
            "App_Data", "database_configuration.log");
        string entry = String.Format("[{0:yyyy-MM-dd HH:mm:ss} UTC] {1}; IP={2}{3}",
            DateTime.UtcNow, operation, Request.UserHostAddress ?? "unknown", Environment.NewLine);
        try
        {
            File.AppendAllText(path, entry, Encoding.UTF8);
        }
        catch (IOException exception)
        {
            System.Diagnostics.Trace.TraceError("Database configuration audit log could not be written: {0}", exception.Message);
        }
        catch (UnauthorizedAccessException exception)
        {
            System.Diagnostics.Trace.TraceError("Database configuration audit log could not be written: {0}", exception.Message);
        }
    }
}
