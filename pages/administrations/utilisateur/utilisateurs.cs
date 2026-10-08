using System;
using System.Web;
using System.Web.UI;

public partial class utilisateurs : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        // 1) Contrôle d'accès par rôle : Admin ou SuperAdmin
        if (!AuthHelper.IsAdmin() && !AuthHelper.IsSuperAdmin())
        {
            Response.Redirect("../../accueil/dashboards/index.aspx", false);
            Context.ApplicationInstance.CompleteRequest();
            return;
        }

        // 2) Contrôle de permission fine (signature à un seul argument)
        if (!AuthHelper.HasPermission("utilisateurs"))
        {
            Response.Redirect("~/pages/error/Error500.aspx", false);
            Context.ApplicationInstance.CompleteRequest();
            return;
        }

        // 3) Mode SuperAdmin : classe CSS sur <body>
        if (AuthHelper.IsSuperAdmin())
        {
            const string script = "document.body.classList.add('superadmin-mode');";
            ClientScript.RegisterStartupScript(
                this.GetType(), "superadmin", script, true);
        }

        // 4) Rôle de l'utilisateur courant exposé au client
        if (hfUserRole != null)
        {
            int roleId = AuthHelper.GetUserRole(HttpContext.Current);
            hfUserRole.Value = roleId.ToString();
        }
    }
}
