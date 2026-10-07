﻿﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web;

/// <summary>
/// AuthHelperDashboard — MENUS DU TABLEAU DE BORD + ADMINISTRATION
/// ------------------------------------------------------------
/// Délègue toute la sécurité à AuthHelper.
/// Contient :
///   - Les menus du Dashboard / Accueil
///   - Les menus d'Administration (resetpwd, utilisateurs, requetes)
/// </summary>
public static class AuthHelperDashboard
{
  // ============================================================
  // MENUS — Dashboard / Accueil + Administration
  // ============================================================
  public static readonly List<AuthHelper.MenuItem> AllMenus = new List<AuthHelper.MenuItem>
  {
    // ---- Accueil / Applications ----
    new AuthHelper.MenuItem { Code = "accueil",      Text = "menu.accueil",      Url = "/pages/accueil/index.aspx",                            Icon = "fas fa-chalkboard",   Section = "section.accueil",        Order = 1  },
    new AuthHelper.MenuItem { Code = "accueils",     Text = "menu.accueils",     Url = "/pages/stock/accueil/index.aspx",                      Icon = "fas fa-box-open",   Section = "section.applications",   Order = 2  },
    new AuthHelper.MenuItem { Code = "accueilc",     Text = "menu.accueilc",     Url = "/pages/finance/accueil/index.aspx",                    Icon = "fas fa-save",   Section = "section.applications",   Order = 3  },

    // ---- Administration ----
    new AuthHelper.MenuItem { Code = "resetpwd",     Text = "menu.resetpwd",     Url = "/pages/administrations/reset/resetpwd.aspx",           Icon = "fas fa-key",          Section = "section.administration", Order = 4 },
    new AuthHelper.MenuItem { Code = "utilisateurs", Text = "menu.utilisateurs", Url = "/pages/administrations/utilisateur/utilisateur.aspx",  Icon = "fas fa-user-cog",     Section = "section.administration", Order = 5 },
    new AuthHelper.MenuItem { Code = "requetes",     Text = "menu.requetes",     Url = "/pages/administrations/requete/requetes.aspx",         Icon = "fas fa-terminal",     Section = "section.administration", Order = 6 },
  };

  public static readonly Dictionary<string, string> CheckboxIdByCode = new Dictionary<string, string>
  {
    { "accueil",      "permDashboard"  },
    { "accueils",     "permDashboards" },
    { "accueilc",     "permDashboardc" },
    { "resetpwd",     "permResetpwd"   },
    { "utilisateurs", "permUser"       },
    { "requetes",     "permRequetes"   },
  };

  private static readonly Dictionary<string, string> SectionIcons = new Dictionary<string, string>
  {
    { "section.accueil",        "fas fa-chalkboard" },
    { "section.accueils",       "fas fa-chalkboard" },
    { "section.accueilc",       "fas fa-chalkboard" },
    { "section.applications",   "fas fa-chalkboard" },
    { "section.administration", "fas fa-shield-alt" },
  };

  private static readonly Dictionary<string, string> EmojiByCode = new Dictionary<string, string>
  {
    { "accueil",      "📊" },
    { "accueils",     "📊" },
    { "accueilc",     "📊" },
    { "resetpwd",     "🔑" },
    { "utilisateurs", "📖" },
    { "requetes",     "💻" },
  };

  public static string GetCheckboxId(string menuCode)
  {
    if (string.IsNullOrEmpty(menuCode)) return "";
    return CheckboxIdByCode.ContainsKey(menuCode) ? CheckboxIdByCode[menuCode] : "perm_" + menuCode;
  }

  // ============================================================
  // ✅ UTILITAIRE INTERNE : normalise un chemin d'URL pour
  //    comparaison fiable.
  //    - minuscules
  //    - suppression du slash final
  //    - suppression de l'extension .aspx (support clean URL)
  // ============================================================
  private static string NormalizePath(string url)
  {
    if (string.IsNullOrEmpty(url)) return "";
    string p = url.ToLowerInvariant().TrimEnd('/');
    if (p.EndsWith(".aspx"))
      p = p.Substring(0, p.Length - 5);
    return p;
  }

  // ============================================================
  // FILTRAGE PAR PERMISSION
  // ============================================================
  public static List<AuthHelper.MenuItem> GetAuthorizedMenus()
  {
    return AllMenus.Where(m => AuthHelper.HasPermission(m.Code)).OrderBy(m => m.Order).ToList();
  }

  // ============================================================
  // RENDER — Permissions UI
  // ============================================================
  public static string RenderPermissionsUI()
  {
    try
    {
      var html = new StringBuilder();
      html.Append(@"<div class=""perm-sections"">");

      var bySection = AllMenus.GroupBy(m => m.Section).OrderBy(g => g.Min(m => m.Order));

      foreach (var grp in bySection)
      {
        string sectionKey = grp.Key;
        string sectionIcon = SectionIcons.ContainsKey(sectionKey) ? SectionIcons[sectionKey] : "fas fa-circle";

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
          if (menu.Code == "requetes" && !AuthHelper.IsSuperAdmin()) continue;

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
      return "<div style='color:red;padding:10px;'>Erreur permissions: " + HttpUtility.HtmlEncode(ex.Message) + "</div>";
    }
  }

  // ============================================================
  // RENDER — Menu HTML (sidebar dashboard + admin)
  // ============================================================
  public static string RenderMenuHTML()
  {
    try
    {
      var menus = GetAuthorizedMenus();

      if (menus == null || menus.Count == 0)
        return "<div class='nav-section-modern' style='padding:15px;text-align:center;'>" +
               AuthHelper.T("NoData") + "<br><small>" + AuthHelper.T("ContactAdmin") + "</small></div>";

      // ✅ FIX : chemin COMPLET normalisé (au lieu du nom de fichier seul)
      string currentPath = "";
      try
      {
        if (HttpContext.Current != null && HttpContext.Current.Request != null && HttpContext.Current.Request.Url != null)
          currentPath = NormalizePath(HttpContext.Current.Request.Url.AbsolutePath);
      }
      catch { }

      var sections = new Dictionary<string, List<AuthHelper.MenuItem>>();
      foreach (var menu in menus)
      {
        if (!sections.ContainsKey(menu.Section)) sections[menu.Section] = new List<AuthHelper.MenuItem>();
        sections[menu.Section].Add(menu);
      }

      var html = new StringBuilder();

      string logoUrl = "";
      try { logoUrl = VirtualPathUtility.ToAbsolute("~/img/Logo4.png"); }
      catch { logoUrl = "/img/Logo4.png"; }

      html.AppendFormat(@"
                <a href=""#"" class=""brand-link"" onclick=""loadDashboard();return false;"">
                    <img src=""{0}"" alt=""Logo"" class=""brand-image"">
                    <span class=""brand-text"">Gestion financière</span>
                </a>", logoUrl);

      html.Append(AuthHelper.RenderUserProfileHTML());
      html.Append(@"<div class=""sidebar-nav-modern"">");

      var orderedSections = sections.OrderBy(kv => kv.Value.Min(m => m.Order));

      foreach (var section in orderedSections)
      {
        html.AppendFormat(@"
                <div class=""nav-section-modern"">
                    <span class=""nav-section-label"">{0}</span>
                </div>", HttpUtility.HtmlEncode(AuthHelper.T(section.Key)));

        html.Append(@"<ul class=""nav-list-modern"">");

        foreach (var menu in section.Value.OrderBy(m => m.Order))
        {
          // ✅ FIX : comparaison sur le chemin COMPLET normalisé
          bool isActive = false;
          if (!string.IsNullOrEmpty(currentPath) && !string.IsNullOrEmpty(menu.Url))
            isActive = (currentPath == NormalizePath(menu.Url));
          string activeClass = isActive ? " active" : "";

          html.AppendFormat(@"
                    <li class=""nav-item-modern"">
                        <a href=""{0}"" class=""nav-link-modern{1}"" data-menu=""{2}"">
                            <span class=""nav-icon-wrap""><i class=""{3}""></i></span>
                            <span class=""nav-link-text"">{4}</span>",
              menu.Url, activeClass, menu.Code, menu.Icon, HttpUtility.HtmlEncode(AuthHelper.T(menu.Text)));

          html.Append(@"</a></li>");
        }
        html.Append(@"</ul>");
      }

      html.Append(@"</div>");
      return html.ToString();
    }
    catch (Exception ex)
    {
      return "<div style='color:red;padding:10px;'>Erreur menu: " + HttpUtility.HtmlEncode(ex.Message) + "</div>";
    }
  }
}
