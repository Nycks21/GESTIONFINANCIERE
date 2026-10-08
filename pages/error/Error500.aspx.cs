using System;
using System.Web.UI;

public partial class Error500 : Page
{
    /// <summary>Bouton « Retour à l'accueil ».</summary>
    protected void btnRetourLogin_Click(object sender, EventArgs e)
    {
        Response.Redirect("~/auth/Login.aspx");
    }

    /// <summary>Bouton « Télécharger la sauvegarde » (conservé tel quel).</summary>
    protected void btnBackup_Click(object sender, EventArgs e)
    {
        // Code de génération du backup à insérer ici si nécessaire.
        Response.Redirect("~/auth/Login.aspx");
    }
}
