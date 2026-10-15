using System;
using System.Web;
using System.Web.UI;

public partial class marche : Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        // Vérification de session
        if (Session["IDUSER"] == null && Session["USERNAME"] == null)
        {
            Response.Redirect("~/Default.aspx");
            return;
        }

        // Sécurité : vérifier la permission "marche"
        try
        {
            if (!AuthHelper.HasPermission("marche"))
            {
                Response.Redirect("~/pages/administrations/utilisateur/NoAccess.aspx");
                return;
            }
        }
        catch
        {
            // Fallback : ne rien bloquer si le helper échoue
        }

        // ⭐ Page.Title RETIRÉ (le <head> n'a pas runat="server")
    }
}
