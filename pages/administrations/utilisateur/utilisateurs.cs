using System;
using System.Web;                    // ✅ AJOUT
using System.Web.UI;

public partial class utilisateurs : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        // Vérifier les droits d'accès
        if (!AuthHelper.IsAdmin() && !AuthHelper.IsSuperAdmin())
        {
            Response.Redirect("../../accueil/dashboards/index.aspx");
        }

        // Ajouter une classe CSS au body via JavaScript
        if (AuthHelper.IsSuperAdmin())
        {
            string script = "document.body.classList.add('superadmin-mode');";
            ClientScript.RegisterStartupScript(this.GetType(), "superadmin", script, true);
        }

        if (!AuthHelper.HasPermission("sites"))
        {
            Response.Redirect("~/pages/error/Error500.aspx", false);
            Context.ApplicationInstance.CompleteRequest();
        }

        // ✅ Maintenant HttpContext est reconnu
        hfUserRole.Value = AuthHelper.GetUserRole(HttpContext.Current).ToString();
    }
}
