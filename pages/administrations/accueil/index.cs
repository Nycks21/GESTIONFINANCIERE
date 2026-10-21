using System;
using System.Collections.Generic;
using System.Web;
using System.Web.UI;

public partial class administrations_accueil : Page
{
    protected class AdminCard
    {
        public string Code    { get; set; }
        public string Url     { get; set; }
        public string Icon    { get; set; }
        public string TextKey { get; set; }
        public string DescKey { get; set; }
    }

    /// <summary>
    /// Liste des cartes visibles pour l'utilisateur courant.
    /// Filtrée selon les permissions (AuthHelper.HasPermission).
    /// </summary>
    protected List<AdminCard> AdminCards { get; private set; }

    protected void Page_Load(object sender, EventArgs e)
    {
        // ─── Sécurité : session obligatoire ───
        if (Session["IDUSER"] == null && Session["USERNAME"] == null)
        {
            Response.Redirect("~/Default.aspx");
            return;
        }

        AdminCards = new List<AdminCard>();

        // ─── Construction des cartes selon les permissions ───
        // ⭐ Chaque carte correspond à un sous-menu réel de l'application.
        //    Les URL et codes sont ceux déjà utilisés dans AuthHelperAdmin.

        TryAddCard(
            code:    "utilisateurs",
            url:     "~/pages/administrations/utilisateur/utilisateur.aspx",
            icon:    "fas fa-users",
            textKey: "menu.utilisateurs",
            descKey: "admin.card.utilisateurs_desc"
        );

        TryAddCard(
            code:    "changepwd",
            url:     "~/pages/administrations/utilisateur/changepwd.aspx",
            icon:    "fas fa-key",
            textKey: "menu.changepwd",
            descKey: "admin.card.changepwd_desc"
        );

        TryAddCard(
            code:    "requete",
            url:     "~/pages/administrations/requete/requete.aspx",
            icon:    "fas fa-question-circle",
            textKey: "menu.requete",
            descKey: "admin.card.requete_desc"
        );
    }

    private void TryAddCard(string code, string url, string icon, string textKey, string descKey)
    {
        bool allowed = false;

        try
        {
            // "changepwd" est généralement accessible à tous les utilisateurs connectés
            if (code == "changepwd")
                allowed = true;
            else
                allowed = AuthHelper.HasPermission(code);
        }
        catch
        {
            // Fallback prudent : si le helper échoue, on masque la carte
            allowed = false;
        }

        if (!allowed) return;

        AdminCards.Add(new AdminCard
        {
            Code    = code,
            Url     = url,
            Icon    = icon,
            TextKey = textKey,
            DescKey = descKey
        });
    }
}
