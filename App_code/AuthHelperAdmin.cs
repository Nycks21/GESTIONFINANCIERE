using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web;

/// <summary>
/// AuthHelperAdmin — MENUS ADMIN DE LA TOPBAR
/// ------------------------------------------------------------
/// Gère les entrées du menu déroulant de la barre supérieure :
///   • Utilisateurs          (gestion des comptes)
///   • Changer mot de passe  (page personnelle)
///   • Requête               (requêtes / support)
///
/// Chaque entrée est filtrée par AuthHelper.HasPermission(code).
/// Délègue toute la sécurité à AuthHelper.
/// </summary>
public static class AuthHelperAdmin
{
  // ============================================================
  // MENUS — Admin (Topbar dropdown)
  // ============================================================
  public static readonly List<AuthHelper.MenuItem> AllMenus = new List<AuthHelper.MenuItem>
    {
          new AuthHelper.MenuItem { Code = "accueil",   Text = "menu.accueil",   Url = "/pages/accueil/index.aspx",                         Icon = "fas fa-chalkboard",       Section = "section.accueil",      Order = 1  },

        new AuthHelper.MenuItem {
            Code    = "utilisateurs",
            Text    = "menu.utilisateurs",
            Url     = "/pages/administrations/utilisateur/utilisateur.aspx",
            Icon    = "fas fa-users",
            Section = "section.administration",
            Order   = 1
        },
        new AuthHelper.MenuItem {
            Code    = "changepwd",
            Text    = "menu.changepwd",
            Url     = "/pages/administrations/utilisateur/changepwd.aspx",
            Icon    = "fas fa-key",
            Section = "section.administration",
            Order   = 2
        },
        new AuthHelper.MenuItem {
            Code    = "requete",
            Text    = "menu.requete",
            Url     = "/pages/administrations/requete/requetes.aspx",
            Icon    = "fas fa-question-circle",
            Section = "section.administration",
            Order   = 3
        },
    };

  // ============================================================
  // MAPPING CODE → ID de checkbox (page de gestion des droits)
  // ============================================================
  public static readonly Dictionary<string, string> CheckboxIdByCode = new Dictionary<string, string>
    {
        { "utilisateurs", "permUtilisateurs" },
        { "changepwd",    "permChangePwd"    },
        { "requete",      "permRequete"      },
    };

  // ============================================================
  // RESSOURCES i18n & emoji
  // ============================================================
  private static readonly Dictionary<string, string> SectionIcons = new Dictionary<string, string>
    {
        { "section.administration", "fas fa-user-cog" },
    };

  private static readonly Dictionary<string, string> EmojiByCode = new Dictionary<string, string>
    {
        { "utilisateurs", "👥" },
        { "changepwd",    "🔑" },
        { "requete",      "❓" },
    };

  // ============================================================
  // UTILITAIRES INTERNES
  // ============================================================

  /// <summary>Retourne l'ID de checkbox associé à un code de menu.</summary>
  public static string GetCheckboxId(string menuCode)
  {
    if (string.IsNullOrEmpty(menuCode)) return "";
    return CheckboxIdByCode.ContainsKey(menuCode)
        ? CheckboxIdByCode[menuCode]
        : "perm_" + menuCode;
  }

  /// <summary>Normalise un chemin d'URL pour comparaison fiable.</summary>
  private static string NormalizePath(string url)
  {
    if (string.IsNullOrEmpty(url)) return "";
    string p = url.ToLowerInvariant().TrimEnd('/');
    if (p.EndsWith(".aspx"))
      p = p.Substring(0, p.Length - 5);
    return p;
  }

  /// <summary>Retourne le chemin courant de la requête (normalisé).</summary>
  private static string GetCurrentPath()
  {
    try
    {
      if (HttpContext.Current != null
       && HttpContext.Current.Request != null
       && HttpContext.Current.Request.Url != null)
      {
        return NormalizePath(HttpContext.Current.Request.Url.AbsolutePath);
      }
    }
    catch { /* ignore */ }
    return "";
  }

  // ============================================================
  // FILTRAGE PAR PERMISSION
  // ============================================================

  /// <summary>Retourne les menus admin auxquels l'utilisateur a accès.</summary>
  public static List<AuthHelper.MenuItem> GetAuthorizedMenus()
  {
    return AllMenus
        .Where(m => AuthHelper.HasPermission(m.Code))
        .OrderBy(m => m.Order)
        .ToList();
  }

  /// <summary>
  /// Indique si l'utilisateur possède au moins une permission admin.
  /// Utile pour masquer complètement le menu déroulant si vide.
  /// </summary>
  public static bool HasAnyAdminPermission()
  {
    try { return GetAuthorizedMenus().Count > 0; }
    catch { return false; }
  }

  // ============================================================
  // RENDER — Dropdown topbar (items à injecter)
  // ============================================================
  /// <summary>
  /// Retourne les <li> à injecter dans le menu déroulant utilisateur
  /// de la topbar (ex : dropdown AdminLTE "user-menu").
  ///
  /// Retourne une chaîne vide si l'utilisateur n'a aucun droit admin,
  /// ce qui évite d'afficher un séparateur orphelin.
  /// </summary>
  public static string RenderTopBarDropdownHTML()
  {
    try
    {
      var menus = GetAuthorizedMenus();
      if (menus == null || menus.Count == 0) return "";

      string currentPath = GetCurrentPath();

      var html = new StringBuilder();

      // Séparateur avant les entrées admin
      html.Append(@"<li><hr class=""dropdown-divider""></li>");

      foreach (var menu in menus)
      {
        bool isActive = false;
        if (!string.IsNullOrEmpty(currentPath) && !string.IsNullOrEmpty(menu.Url))
          isActive = (currentPath == NormalizePath(menu.Url));

        string activeClass = isActive ? " active" : "";

        html.AppendFormat(
            @"<li>
                        <a href=""{0}"" class=""dropdown-item{1}"" data-menu=""{2}"">
                            <i class=""{3} mr-2""></i>
                            <span data-i18n=""{4}"">{5}</span>
                        </a>
                      </li>",
            HttpUtility.HtmlAttributeEncode(menu.Url),
            activeClass,
            HttpUtility.HtmlAttributeEncode(menu.Code),
            menu.Icon,
            HttpUtility.HtmlAttributeEncode(menu.Text),
            HttpUtility.HtmlEncode(AuthHelper.T(menu.Text)));
      }

      return html.ToString();
    }
    catch (Exception ex)
    {
      return @"<li class=""dropdown-item text-danger"">Erreur menu admin : "
           + HttpUtility.HtmlEncode(ex.Message) + "</li>";
    }
  }

  // ============================================================
  // RENDER — Variante sans séparateur (pour intégration manuelle)
  // ============================================================
  /// <summary>
  /// Identique à RenderTopBarDropdownHTML() mais sans le séparateur
  /// initial. À utiliser si vous placez vous-même le divider.
  /// </summary>
  public static string RenderAdminMenuHTML()
  {
    try
    {
      var menus = GetAuthorizedMenus();
      if (menus == null || menus.Count == 0) return "";

      string currentPath = GetCurrentPath();
      var html = new StringBuilder();

      foreach (var menu in menus)
      {
        bool isActive = false;
        if (!string.IsNullOrEmpty(currentPath) && !string.IsNullOrEmpty(menu.Url))
          isActive = (currentPath == NormalizePath(menu.Url));
        string activeClass = isActive ? " active" : "";

        html.AppendFormat(
            @"<a href=""{0}"" class=""dropdown-item{1}"" data-menu=""{2}"">
                        <i class=""{3} mr-2""></i>
                        <span data-i18n=""{4}"">{5}</span>
                      </a>",
            HttpUtility.HtmlAttributeEncode(menu.Url),
            activeClass,
            HttpUtility.HtmlAttributeEncode(menu.Code),
            menu.Icon,
            HttpUtility.HtmlAttributeEncode(menu.Text),
            HttpUtility.HtmlEncode(AuthHelper.T(menu.Text)));
      }

      return html.ToString();
    }
    catch (Exception ex)
    {
      return "<span class='text-danger'>Erreur menu admin : "
           + HttpUtility.HtmlEncode(ex.Message) + "</span>";
    }
  }

  // ============================================================
  // RENDER — Permissions UI (pour la page de gestion des droits)
  // ============================================================
  public static string RenderPermissionsUI()
  {
    try
    {
      var html = new StringBuilder();
      html.Append(@"<div class=""perm-sections"">");

      var bySection = AllMenus
          .GroupBy(m => m.Section)
          .OrderBy(g => g.Min(m => m.Order));

      foreach (var grp in bySection)
      {
        string sectionKey = grp.Key;
        string sectionIcon = SectionIcons.ContainsKey(sectionKey)
                             ? SectionIcons[sectionKey]
                             : "fas fa-circle";

        html.AppendFormat(
            @"<div class=""perm-section"">
                        <div class=""perm-section-header"">
                            <i class=""{0}""></i>
                            <span data-i18n=""{1}"">{2}</span>
                        </div>
                        <div class=""perm-section-body"">",
            sectionIcon,
            HttpUtility.HtmlAttributeEncode(sectionKey),
            HttpUtility.HtmlEncode(AuthHelper.T(sectionKey)));

        foreach (var menu in grp.OrderBy(m => m.Order))
        {
          string checkboxId = GetCheckboxId(menu.Code);
          string emoji = EmojiByCode.ContainsKey(menu.Code) ? EmojiByCode[menu.Code] : "";

          html.AppendFormat(
              @"<label class=""perm-item"" for=""{0}"">
                            <input type=""checkbox"" id=""{0}"" value=""{1}"">
                            <span class=""perm-emoji"">{2}</span>
                            <span data-i18n=""{3}"">{4}</span>
                          </label>",
              HttpUtility.HtmlAttributeEncode(checkboxId),
              HttpUtility.HtmlAttributeEncode(menu.Code),
              emoji,
              HttpUtility.HtmlAttributeEncode(menu.Text),
              HttpUtility.HtmlEncode(AuthHelper.T(menu.Text)));
        }

        html.Append(@"</div></div>");
      }

      html.Append(@"</div>");
      return html.ToString();
    }
    catch (Exception ex)
    {
      return "<div style='color:red;padding:10px;'>Erreur permissions admin : "
           + HttpUtility.HtmlEncode(ex.Message) + "</div>";
    }
  }

  // ============================================================
  // UTILITAIRE — Fusion Finance + Admin (menu complet)
  // ============================================================
  /// <summary>
  /// Retourne un menu déroulant complet contenant :
  ///   • les entrées admin (ce helper)
  ///   • puis un séparateur
  ///   • puis "Déconnexion" (géré par AuthHelper)
  ///
  /// Exemple d'utilisation dans AuthHelper.RenderTopBarHTML() :
  ///   html.Append(AuthHelperAdmin.RenderTopBarDropdownWithLogoutHTML());
  /// </summary>
  public static string RenderTopBarDropdownWithLogoutHTML()
  {
    var html = new StringBuilder();
    html.Append(RenderTopBarDropdownHTML());

    html.Append(@"<li><hr class=""dropdown-divider""></li>");
    html.AppendFormat(
        @"<li>
                <a href=""{0}"" class=""dropdown-item text-danger"" data-menu=""logout"">
                    <i class=""fas fa-sign-out-alt mr-2""></i>
                    <span data-i18n=""menu.logout"">{1}</span>
                </a>
              </li>",
        HttpUtility.HtmlAttributeEncode(
            (HttpContext.Current != null
                ? VirtualPathUtility.ToAbsolute("~/Logout.aspx")
                : "/Logout.aspx")),
        HttpUtility.HtmlEncode(AuthHelper.T("menu.logout")));

    return html.ToString();
  }
}
