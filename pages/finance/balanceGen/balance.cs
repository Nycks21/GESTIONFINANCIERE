using System;
using System.Web;
using System.Web.UI;

public partial class balance : Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        // ─── Session obligatoire ───
        if (Session["IDUSER"] == null && Session["USERNAME"] == null)
        {
            Response.Redirect("~/Default.aspx");
            return;
        }

        // ─── Vérifier la permission "saisie" ───
        try
        {
            if (!AuthHelper.HasPermission("saisie"))
            {
                Response.Redirect("~/pages/administrations/utilisateur/NoAccess.aspx");
                return;
            }
        }
        catch
        {
            // Fallback : ne pas bloquer si le helper échoue
        }
    }
}
