﻿using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;

/// <summary>
/// AuthHelper — SOCLE DE SÉCURITÉ UNIQUE
/// ------------------------------------------------------------
/// Contient :
///   - Session (VerifySession, ValidateSessionToken, ForceLogout, Logout)
///   - Garde-fous API (RequireApiAuth, RequirePermission, RequireCsrfSafePost...)
///   - CSRF (token, validation, meta tag)
///   - Rôles (IsSuperAdmin, IsAdmin, ...)
///   - Permissions (HasPermission, SaveUserPermissions, ...)
///   - Licence (CheckLicence, GetExpirationDateString, ...)
///   - Widgets layout (RenderUserProfileHTML, RenderTopBarHTML, RenderControlSidebarHTML)
///   - DTO partagé MenuItem (utilisé par AuthHelperDashboard / Finance / Stock)
///
/// NE CONTIENT PAS (délégué aux modules) :
///   - AllMenus, CheckboxIdByCode, SectionIcons, EmojiByCode
///   - GetCheckboxId, RenderPermissionsUI, GetAuthorizedMenus, RenderMenuHTML
/// </summary>
public static class AuthHelper
{
  // ============================================================
  // CONSTANTES ET CHAMPS PRIVÉS
  // ============================================================
  private static readonly string connStr;
  private const string SK_AUTHENTICATED = "authenticated";
  private const string SK_USERNAME = "username";
  private const string SK_IDUSER = "IDUSER";
  private const string SK_USERROLE = "USERROLE";
  private const string SK_SESSION_TOKEN = "SESSION_TOKEN";
  private const string SK_USER_PERMISSIONS = "USER_PERMISSIONS";
  private const string SK_CSRF_TOKEN = "CSRF_TOKEN";
  private const string CSRF_HEADER_NAME = "X-CSRF-Token";

  static AuthHelper()
  {
    try
    {
      var connSetting = ConfigurationManager.ConnectionStrings["MaConnexion"];
      connStr = connSetting != null && connSetting.ConnectionString != null
          ? connSetting.ConnectionString
          : "";
    }
    catch { connStr = ""; }
  }

  public static string ConnectionString { get { return connStr; } }

  // ============================================================
  // DTO PARTAGÉ (utilisé par les modules de menus)
  // ============================================================
  public class MenuItem
  {
    public string Code { get; set; }
    public string Text { get; set; }
    public string Url { get; set; }
    public string Icon { get; set; }
    public string Section { get; set; }
    public int Order { get; set; }
    public List<MenuItem> Children { get; set; }

    public MenuItem() { Children = new List<MenuItem>(); }
  }

  // ============================================================
  // AUTHENTIFICATION
  // ============================================================
  public static bool IsAuthenticated(HttpContext context)
  {
    if (context == null || context.Session == null) return false;
    return context.Session[SK_AUTHENTICATED] != null &&
           (bool)context.Session[SK_AUTHENTICATED];
  }

  // ============================================================
  // GARDE-FOUS API
  // ============================================================
  public static bool RequireApiAuth(HttpContext context, int minRole = -1)
  {
    if (context == null || context.Session == null) return false;
    if (context.Session[SK_AUTHENTICATED] == null || !(bool)context.Session[SK_AUTHENTICATED]) return false;
    if (!ValidateSessionToken(context)) return false;

    if (minRole >= 0)
    {
      int userRole = GetUserRole(context);
      if (userRole == 0) return true;
      if (userRole > minRole) return false;
    }
    return true;
  }

  public static bool RequirePermission(HttpContext context, string permissionCode)
  {
    if (context == null || context.Session == null) return false;
    if (context.Session[SK_AUTHENTICATED] == null || !(bool)context.Session[SK_AUTHENTICATED]) return false;
    if (!ValidateSessionToken(context)) return false;
    return HasPermission(permissionCode);
  }

  public static bool CanManageEmploi(HttpContext context)
  {
    if (context == null || context.Session == null) return false;
    int userRole = GetUserRole(context);
    return userRole == 0 || userRole == 1;
  }

  // ============================================================
  // CSRF
  // ============================================================
  public static string GetOrCreateCsrfToken()
  {
    var session = HttpContext.Current != null ? HttpContext.Current.Session : null;
    if (session == null) return "";
    if (session[SK_CSRF_TOKEN] == null) session[SK_CSRF_TOKEN] = GenerateCsrfToken();
    return session[SK_CSRF_TOKEN].ToString();
  }

  private static string GenerateCsrfToken()
  {
    byte[] buffer = new byte[32];
    using (var rng = new RNGCryptoServiceProvider()) rng.GetBytes(buffer);
    return Convert.ToBase64String(buffer).Replace("+", "-").Replace("/", "_").Replace("=", "");
  }

  public static bool ValidateCsrfToken(HttpContext context)
  {
    if (context == null || context.Session == null) return false;
    string sessionToken = context.Session[SK_CSRF_TOKEN] as string;
    if (string.IsNullOrEmpty(sessionToken)) { LogAuthError("ValidateCsrfToken: aucun token en session"); return false; }

    string headerToken = context.Request.Headers[CSRF_HEADER_NAME];
    if (string.IsNullOrEmpty(headerToken)) headerToken = context.Request.Headers["HTTP_X_CSRF_TOKEN"];
    if (string.IsNullOrEmpty(headerToken)) { LogAuthError("ValidateCsrfToken: aucun header X-CSRF-Token"); return false; }

    return FixedTimeEquals(sessionToken, headerToken);
  }

  private static bool FixedTimeEquals(string a, string b)
  {
    if (a == null || b == null || a.Length != b.Length) return false;
    int diff = 0;
    for (int i = 0; i < a.Length; i++) diff |= a[i] ^ b[i];
    return diff == 0;
  }

  public static bool ValidateOrigin(HttpContext context)
  {
    if (context == null || context.Request == null) return false;
    string host = context.Request.Url != null ? context.Request.Url.Host : null;
    if (string.IsNullOrEmpty(host)) return false;

    string origin = context.Request.Headers["Origin"];
    if (!string.IsNullOrEmpty(origin))
    {
      try { return string.Equals(new Uri(origin).Host, host, StringComparison.OrdinalIgnoreCase); }
      catch { return false; }
    }

    string referer = context.Request.Headers["Referer"];
    if (!string.IsNullOrEmpty(referer))
    {
      try { return string.Equals(new Uri(referer).Host, host, StringComparison.OrdinalIgnoreCase); }
      catch { return false; }
    }

    LogAuthError("ValidateOrigin: ni Origin ni Referer");
    return false;
  }

  public static bool RequireCsrfSafePost(HttpContext context, int minRole = -1)
  {
    if (!RequireApiAuth(context, minRole)) return false;
    if (!ValidateCsrfToken(context)) return false;
    if (!ValidateOrigin(context)) return false;
    return true;
  }

  public static bool RequireCsrfPermission(HttpContext context, string permissionCode)
  {
    if (!RequireCsrfSafePost(context, -1)) return false;
    return HasPermission(permissionCode);
  }

  public static bool RequireCsrfPermission(HttpContext context, string resource, string action)
  {
    if (!RequireCsrfSafePost(context, -1)) return false;
    if (!string.IsNullOrEmpty(action) && HasPermission(resource + "." + action)) return true;
    return HasPermission(resource);
  }

  public static bool RequireApiPermission(HttpContext context, string permissionCode)
  {
    if (!RequireApiAuth(context, -1)) return false;
    return HasPermission(permissionCode);
  }

  public static string RenderCsrfMetaTag()
  {
    try
    {
      string token = GetOrCreateCsrfToken();
      return "<meta name=\"csrf-token\" content=\"" + HttpUtility.HtmlAttributeEncode(token) + "\">";
    }
    catch (Exception ex) { LogAuthError("RenderCsrfMetaTag: " + ex.Message); return ""; }
  }

  // ============================================================
  // TRANSFERT D'AUTHENTIFICATION ENTRE SESSIONS
  // ============================================================
  private const string AUTH_TRANSFER_CACHE_PREFIX = "AUTH_TRANSFER_";

  public static string StorePendingAuth(Dictionary<string, object> authData)
  {
    string token = Guid.NewGuid().ToString("N");
    HttpRuntime.Cache.Insert(AUTH_TRANSFER_CACHE_PREFIX + token, authData, null,
        DateTime.Now.AddSeconds(60), System.Web.Caching.Cache.NoSlidingExpiration);
    return token;
  }

  public static Dictionary<string, object> RetrievePendingAuth(string token)
  {
    if (string.IsNullOrEmpty(token)) return null;
    string key = AUTH_TRANSFER_CACHE_PREFIX + token;
    var data = HttpRuntime.Cache[key] as Dictionary<string, object>;
    if (data != null) HttpRuntime.Cache.Remove(key);
    return data;
  }

  // ============================================================
  // VALIDATION TOKEN DE SESSION
  // ============================================================
  private static bool ValidateSessionToken(HttpContext context)
  {
    try
    {
      int userId = GetUserId(context);
      string sessionToken = context.Session[SK_SESSION_TOKEN] as string;
      if (userId <= 0 || string.IsNullOrEmpty(sessionToken)) return false;
      if (string.IsNullOrEmpty(connStr)) return false;

      using (SqlConnection conn = new SqlConnection(connStr))
      {
        conn.Open();
        string sql = "SELECT COUNT(*) FROM USERS WHERE IDUSER = @userId AND SESSION_TOKEN = @token";
        using (SqlCommand cmd = new SqlCommand(sql, conn))
        {
          cmd.Parameters.AddWithValue("@userId", userId);
          cmd.Parameters.AddWithValue("@token", sessionToken);
          return (int)cmd.ExecuteScalar() > 0;
        }
      }
    }
    catch (Exception ex) { LogAuthError("ValidateSessionToken exception: " + ex.Message); return false; }
  }

  private static void LogAuthError(string message)
  {
    try
    {
      string logFile = HttpContext.Current.Server.MapPath("~/App_Data/auth_token.log");
      File.AppendAllText(logFile, string.Format("[{0}] {1}\n", DateTime.Now, message));
    }
    catch { }
  }

  // ============================================================
  // PERMISSIONS
  // ============================================================
  public static List<string> GetUserPermissions()
  {
    var session = HttpContext.Current.Session;
    if (session != null && session[SK_USER_PERMISSIONS] != null)
      return session[SK_USER_PERMISSIONS] as List<string>;

    if (IsSuperAdmin())
    {
      // SuperAdmin : toutes les permissions connues sont dynamiques par module.
      // On retourne une liste vide par défaut : HasPermission court-circuite.
      var empty = new List<string>();
      if (session != null) session[SK_USER_PERMISSIONS] = empty;
      return empty;
    }

    if (IsAdmin())
    {
      var empty = new List<string>();
      if (session != null) session[SK_USER_PERMISSIONS] = empty;
      return empty;
    }

    int? userId = GetCurrentUserId();
    if (userId.HasValue && userId.Value > 0)
    {
      var permissions = LoadPermissionsFromDatabase(userId.Value);
      if (session != null) session[SK_USER_PERMISSIONS] = permissions;
      return permissions;
    }
    return new List<string>();
  }

  private static List<string> LoadPermissionsFromDatabase(int userId)
  {
    var permissions = new List<string>();
    try
    {
      if (string.IsNullOrEmpty(connStr)) return permissions;
      using (SqlConnection conn = new SqlConnection(connStr))
      {
        conn.Open();
        string checkColumnQuery = @"
                    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_NAME = 'USERS' AND COLUMN_NAME = 'MENU_PERMISSIONS'";
        using (SqlCommand checkCmd = new SqlCommand(checkColumnQuery, conn))
        {
          int columnExists = (int)checkCmd.ExecuteScalar();
          if (columnExists > 0)
          {
            string sql = "SELECT MENU_PERMISSIONS FROM USERS WHERE IDUSER = @id";
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
              cmd.Parameters.AddWithValue("@id", userId);
              object result = cmd.ExecuteScalar();
              if (result != null && result != DBNull.Value && !string.IsNullOrEmpty(result.ToString()))
              {
                try { permissions = new JavaScriptSerializer().Deserialize<List<string>>(result.ToString()); }
                catch { }
              }
            }
          }
          else
          {
            string sql = "SELECT PERMISSION_NAME FROM USER_PERMISSIONS WHERE USER_ID = @id";
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
              cmd.Parameters.AddWithValue("@id", userId);
              using (SqlDataReader reader = cmd.ExecuteReader())
                while (reader.Read()) permissions.Add(reader["PERMISSION_NAME"].ToString());
            }
          }
        }
      }
    }
    catch { }
    return permissions;
  }

  public static bool HasPermission(string permissionCode)
  {
    if (IsSuperAdmin()) return true;
    if (IsAdmin() && permissionCode != "requetes") return true;
    return GetUserPermissions().Contains(permissionCode);
  }

  public static bool SaveUserPermissions(int userId, List<string> permissions)
  {
    try
    {
      if (string.IsNullOrEmpty(connStr)) return false;
      using (SqlConnection conn = new SqlConnection(connStr))
      {
        conn.Open();
        string checkColumnQuery = @"
                    SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
                    WHERE TABLE_NAME = 'USERS' AND COLUMN_NAME = 'MENU_PERMISSIONS'";
        using (SqlCommand checkCmd = new SqlCommand(checkColumnQuery, conn))
        {
          int columnExists = (int)checkCmd.ExecuteScalar();
          if (columnExists > 0)
          {
            string permissionsJson = new JavaScriptSerializer().Serialize(permissions);
            string sql = "UPDATE USERS SET MENU_PERMISSIONS = @permissions WHERE IDUSER = @id";
            using (SqlCommand cmd = new SqlCommand(sql, conn))
            {
              cmd.Parameters.AddWithValue("@permissions", permissionsJson);
              cmd.Parameters.AddWithValue("@id", userId);
              cmd.ExecuteNonQuery();
            }
          }
          else
          {
            using (SqlCommand deleteCmd = new SqlCommand("DELETE FROM USER_PERMISSIONS WHERE USER_ID = @id", conn))
            {
              deleteCmd.Parameters.AddWithValue("@id", userId);
              deleteCmd.ExecuteNonQuery();
            }
            foreach (string perm in permissions)
            {
              using (SqlCommand insertCmd = new SqlCommand("INSERT INTO USER_PERMISSIONS (USER_ID, PERMISSION_NAME) VALUES (@id, @perm)", conn))
              {
                insertCmd.Parameters.AddWithValue("@id", userId);
                insertCmd.Parameters.AddWithValue("@perm", perm);
                insertCmd.ExecuteNonQuery();
              }
            }
          }
        }
        var session = HttpContext.Current.Session;
        if (session != null && session[SK_IDUSER] != null && Convert.ToInt32(session[SK_IDUSER]) == userId)
          session[SK_USER_PERMISSIONS] = permissions;
        return true;
      }
    }
    catch { return false; }
  }

  // ============================================================
  // MULTI-LANGAGE
  // ============================================================
  public static string T(string key) { return LocalizationHelper.GetString(key); }
  public static string T(string key, params object[] args) { return LocalizationHelper.GetString(key, args); }
  public static string RenderLanguageSelector() { return LocalizationHelper.RenderLanguageSelector(); }

  // ============================================================
  // WIDGETS LAYOUT (profil, topbar, control sidebar)
  // ============================================================
  public static string RenderUserProfileHTML()
  {
    try
    {
      string userName = GetUserName();
      string roleName = GetRoleName();
      if (string.IsNullOrEmpty(userName)) userName = T("User");

      var html = new StringBuilder();
      html.Append(@"
            <div class=""user-profile-nav"">
                <div class=""user-avatar"">
                    <i class=""fas fa-user-tie""></i>
                    <span class=""status-indicator""></span>
                </div>
                <div class=""user-info"">
                    <span id=""profilUsername"" class=""user-role"">");
      html.Append(HttpUtility.HtmlEncode(roleName));
      html.Append(@"</span>
                    <span id=""navbarUsername"" class=""user-name"">");
      html.Append(HttpUtility.HtmlEncode(userName));
      html.Append(@"</span>
                </div>
            </div>");
      return html.ToString();
    }
    catch (Exception ex)
    {
      return "<div style='color:red;padding:10px;'>Erreur profil: " + HttpUtility.HtmlEncode(ex.Message) + "</div>";
    }
  }

  public static string RenderTopBarHTML()
  {
    try
    {
      var html = new StringBuilder();
      string currentPage = "";
      bool isUsersPage = false;

      try
      {
        if (HttpContext.Current != null && HttpContext.Current.Request != null && HttpContext.Current.Request.Url != null)
          currentPage = HttpContext.Current.Request.Url.AbsolutePath.ToLower();
      }
      catch { }

      if (!string.IsNullOrEmpty(currentPage))
        isUsersPage = currentPage.Contains("utilisateur.aspx") || currentPage.Contains("users.aspx");

      html.Append(@"
        <nav class=""main-header modern-topbar"">
            <ul class=""navbar-nav topbar-left"">
                <li class=""nav-item"">
                    <a class=""nav-link topbar-icon-btn"" id=""menuToggle"" role=""button"" title=""Menu"">
                        <i class=""fas fa-bars""></i>
                    </a>
                </li>
            </ul>");

      string projetCode = GetProjectCode(HttpContext.Current);
      html.AppendFormat(@"
            <div class=""topbar-center"">
                <span class=""project-badge-modern"" title=""{1}"">
                    <i class=""fas fa-project-diagram""></i>
                    <span class=""project-badge-label"">PROJET</span>
                    <span class=""project-badge-sep"">:</span>
                    <span class=""project-badge-code"">{0}</span>
                </span>
            </div>",
          HttpUtility.HtmlEncode(projetCode),
          HttpUtility.HtmlEncode(T("ProjetCourant")));

      html.Append(@"<ul class=""navbar-nav topbar-right"">");

      if (HasPermission("requetes"))
      {
        html.Append(@"
                <li class=""nav-item"">
                    <a class=""nav-link topbar-icon-btn"" id=""notifToggle"" title=""" + T("Notifications") + @""">
                        <i class=""fas fa-bell""></i>
                        <span class=""topbar-badge"">3</span>
                    </a>
                    <div class=""dropdown-menu topbar-dropdown"" id=""notifDropdown"">
                        <div class=""topbar-dropdown-header"">
                            <i class=""fas fa-bell""></i>
                            <span>3 " + T("Notifications") + @"</span>
                        </div>
                        <div class=""topbar-dropdown-divider""></div>
                        <a href=""#"" class=""topbar-dropdown-item"">
                            <span class=""topbar-dropdown-icon icon-success""><i class=""fas fa-user-plus""></i></span>
                            <span class=""topbar-dropdown-text"">" + T("N") + @"</span>
                            <span class=""topbar-dropdown-time"">" + T("TimeAgo") + @" 23 min</span>
                        </a>
                        <a href=""#"" class=""topbar-dropdown-item"">
                            <span class=""topbar-dropdown-icon icon-danger""><i class=""fas fa-exclamation-circle""></i></span>
                            <span class=""topbar-dropdown-text"">" + T("A") + @"</span>
                            <span class=""topbar-dropdown-time"">" + T("TimeAgo") + @" 1h</span>
                        </a>
                        <a href=""#"" class=""topbar-dropdown-item"">
                            <span class=""topbar-dropdown-icon icon-warning""><i class=""fas fa-money-bill""></i></span>
                            <span class=""topbar-dropdown-text"">" + T("P") + @"</span>
                            <span class=""topbar-dropdown-time"">" + T("TimeAgo") + @" 2h</span>
                        </a>
                    </div>
                </li>");
      }

      html.Append(@"
                  <li class=""nav-item"">
                    <a href=""/pages/accueil/index.aspx"" class=""nav-link topbar-icon-btn topbar-logout"" title=""" + T("Application") + @""">
                        <i class=""fas fa-server""></i>
                    </a>
                  </li>
      ");

      html.Append(@"
                  <li class=""nav-item"">
                    <a href=""/pages/administrations/accueil/index.aspx"" class=""nav-link topbar-icon-btn topbar-logout"" title=""" + T("Application") + @""">
                        <i class=""fas fa-users""></i>
                    </a>
                  </li>
      ");

      html.Append(@"
                  <li class=""nav-item"">
                    <a href=""/pages/generale/generale.aspx"" class=""nav-link topbar-icon-btn topbar-logout"" title=""" + T("Setting") + @""">
                        <i class=""fas fa-cog""></i>
                    </a>
                  </li>
      ");

      string currentCulture = LocalizationHelper.CurrentCultureCode;
      html.Append(@"
                <li class=""nav-item"">
                    <div class=""lang-selector-modern"">
                        <i class=""fas fa-globe lang-selector-icon""></i>
                        <select id=""langSelect"" class=""lang-select-modern"">");
      for (int i = 0; i < LocalizationHelper.SupportedCultures.Length; i++)
      {
        string code = LocalizationHelper.SupportedCultures[i];
        string name = LocalizationHelper.CultureNames[i];
        string selected = (code == currentCulture) ? " selected" : "";
        html.AppendFormat(@"<option value=""{0}""{1}>{2}</option>", code, selected, HttpUtility.HtmlEncode(name));
      }
      html.Append(@"</select>
                    </div>
                </li>");

      html.Append(@"
                <li class=""nav-item"">
                    <label class=""switch switch-modern"" for=""toggleDarkMode"" title=""Mode sombre"">
                        <input type=""checkbox"" id=""toggleDarkMode"">
                        <span class=""slider-modern round""></span>
                    </label>
                </li>");

      html.Append(@"
                <li class=""nav-item"">
                    <a href=""../../../../auth/Logout.aspx"" class=""nav-link topbar-icon-btn topbar-logout"" title=""" + T("Logout") + @""">
                        <i class=""fas fa-sign-out-alt""></i>
                    </a>
                </li>");

      html.Append(@"
                <li class=""nav-item"">
                    <a class=""nav-link topbar-icon-btn"" id=""fullscreenToggle"" title=""" + T("Fullscreen") + @""">
                        <i class=""fas fa-expand-arrows-alt""></i>
                    </a>
                </li>");

      if (isUsersPage && HasPermission("utilisateurs"))
      {
        html.Append(@"
                <li class=""nav-item"">
                    <a class=""nav-link topbar-icon-btn"" id=""toggleSidebarBtn"" title=""" + T("Settings") + @""">
                        <i class=""fas fa-database""></i>
                    </a>
                </li>");
      }

      html.Append(@"
            </ul>
        </nav>");

      html.Append(LocalizationHelper.RenderDictionaryScript());
      html.Append(RenderCsrfMetaTag());

      return html.ToString();
    }
    catch (Exception ex)
    {
      return "<div style='color:red;padding:10px;'>Erreur topbar: " + HttpUtility.HtmlEncode(ex.Message) + "</div>";
    }
  }

  public static string RenderControlSidebarHTML()
  {
    try
    {
      var html = new StringBuilder();
      html.Append(@"
            <aside class=""control-sidebar-modern"" id=""controlSidebar"">
                <div class=""control-sidebar-inner"">

                    <div class=""control-sidebar-header"">
                        <h5 class=""control-sidebar-title"">
                            <i class=""fas fa-database""></i>
                            <span>" + T("Settings") + @"</span>
                        </h5>
                        <button type=""button"" id=""closeSidebarBtn"" class=""control-sidebar-close"" title=""Fermer"">
                            <i class=""fas fa-times""></i>
                        </button>
                    </div>

                    <div class=""control-sidebar-info"">
                        <div class=""control-info-item"">
                            <i class=""fas fa-calendar-alt""></i>
                            <span>" + T("LicenceExpires") + @" :</span>
                            <strong id=""expirationDateStr"">" + GetExpirationDateString() + @"</strong>
                        </div>
                        <div class=""control-info-item"">
                            <i class=""fas fa-users""></i>
                            <span>" + T("MaxUsers") + @" :</span>
                            <strong id=""maxUsersCount"">" + GetMaxUsersString() + @"</strong>
                        </div>
                    </div>");

      if (IsSuperAdmin())
{
    html.Append(@"
                <div class=""control-sidebar-actions"">
                    <button type=""button"" id=""btnCheckUpdates"" class=""control-btn control-btn-primary"" onclick=""checkForUpdates()"">
                        <i class=""fas fa-sync-alt""></i>
                        <span>" + T("CheckUpdates") + @"</span>
                    </button>

                    <button type=""button"" id=""btnUpdateDatabase"" class=""control-btn control-btn-info"" onclick=""updateDatabase()"">
                        <i class=""fas fa-database""></i>
                        <span>" + T("UpdateDatabase") + @"</span>
                    </button>

                    <button type=""button"" id=""btnBackup"" class=""control-btn control-btn-success"" onclick=""backupDatabase()"">
                        <i class=""fas fa-save""></i>
                        <span>" + T("Backup") + @"</span>
                    </button>

                    <button type=""button"" id=""btnRestore"" class=""control-btn control-btn-warning"" onclick=""openRestoreModal()"">
                        <i class=""fas fa-undo-alt""></i>
                        <span>" + T("Restore") + @"</span>
                    </button>
                </div>");
}

      html.Append(@"
                </div>
            </aside>

            <div id=""sidebarOverlay"" class=""control-sidebar-overlay""></div>");
      return html.ToString();
    }
    catch (Exception ex)
    {
      return "<div style='color:red;padding:10px;'>Erreur control sidebar: " + HttpUtility.HtmlEncode(ex.Message) + "</div>";
    }
  }

  // ============================================================
  // SESSION — VerifySession / ForceLogout / Logout
  // ============================================================
  public static void VerifySession(Page page)
  {
    if (page.Session[SK_AUTHENTICATED] == null || !(bool)page.Session[SK_AUTHENTICATED])
    {
      page.Response.Redirect("~/auth/Login.aspx");
      return;
    }
    if (!IsTokenValid()) { ForceLogout(page, true); return; }
    if (!page.IsPostBack) { SetUsername(page); SetRolename(page); }
  }

  private static bool IsTokenValid()
  {
    var session = HttpContext.Current.Session;
    if (session == null || session[SK_IDUSER] == null || session[SK_SESSION_TOKEN] == null) return false;

    try
    {
      int idUser = (int)session[SK_IDUSER];
      string tokenSession = session[SK_SESSION_TOKEN].ToString();
      if (string.IsNullOrEmpty(connStr)) return false;

      try
      {
        var app = HttpContext.Current != null ? HttpContext.Current.Application : null;
        if (app != null && app["RestoreInProgress"] is bool && (bool)app["RestoreInProgress"]) return true;
      }
      catch { }

      using (SqlConnection conn = new SqlConnection(connStr))
      {
        using (SqlCommand cmd = new SqlCommand("SELECT SESSION_TOKEN FROM USERS WHERE IDUSER=@id", conn))
        {
          cmd.Parameters.AddWithValue("@id", idUser);
          conn.Open();
          object tokenDb = cmd.ExecuteScalar();
          return tokenDb != null && tokenDb.ToString() == tokenSession;
        }
      }
    }
    catch { return false; }
  }

  private static void SetUsername(Page page)
  {
    var session = HttpContext.Current.Session;
    if (session == null || session[SK_USERNAME] == null) return;
    string script = "var el=document.getElementById('navbarUsername'); if(el){el.textContent="
        + HttpUtility.JavaScriptStringEncode(session[SK_USERNAME].ToString(), true) + ";}";
    page.ClientScript.RegisterStartupScript(page.GetType(), "username", script, true);
  }

  private static void SetRolename(Page page)
  {
    string script = "var el=document.getElementById('profilUsername'); if(el){el.textContent="
        + HttpUtility.JavaScriptStringEncode(GetRoleName(), true) + ";}";
    page.ClientScript.RegisterStartupScript(page.GetType(), "rolename", script, true);
  }

  private static void ForceLogout(Page page, bool otherPc)
  {
    bool isRestoreContext = false;
    try
    {
      var app = HttpContext.Current != null ? HttpContext.Current.Application : null;
      if (app != null && app["RestoreInProgress"] is bool && (bool)app["RestoreInProgress"])
      {
        if (app["RestoreCompletedAt"] is DateTime)
        {
          DateTime completed = (DateTime)app["RestoreCompletedAt"];
          if ((DateTime.Now - completed).TotalSeconds < 60) isRestoreContext = true;
          else
          {
            app.Lock(); app["RestoreInProgress"] = false;
            app.Remove("RestoreStartedAt"); app.Remove("RestoreCompletedAt"); app.UnLock();
          }
        }
        else if (app["RestoreStartedAt"] is DateTime)
        {
          DateTime started = (DateTime)app["RestoreStartedAt"];
          if ((DateTime.Now - started).TotalSeconds < 300) isRestoreContext = true;
        }
      }
    }
    catch { }

    HttpContext.Current.Session.Clear();
    HttpContext.Current.Session.Abandon();

    string url = isRestoreContext ? "~/auth/Login.aspx?msg=restore"
               : otherPc           ? "~/auth/Login.aspx?msg=other_pc"
               :                     "~/auth/Login.aspx";
    page.Response.Redirect(url, true);
  }

  public static void Logout(HttpContext context)
  {
    if (context == null || context.Session == null) return;
    int userId = GetUserId(context);
    if (userId > 0)
    {
      try
      {
        using (SqlConnection conn = new SqlConnection(connStr))
        {
          using (SqlCommand cmd = new SqlCommand("UPDATE USERS SET SESSION_TOKEN = NULL WHERE IDUSER = @id", conn))
          {
            cmd.Parameters.AddWithValue("@id", userId);
            conn.Open(); cmd.ExecuteNonQuery();
          }
        }
      }
      catch { }
    }

    context.Session.Clear();
    context.Session.Abandon();

    if (context.Request.Cookies["ASP.NET_SessionId"] != null)
    {
      var cookie = new HttpCookie("ASP.NET_SessionId") { Expires = DateTime.Now.AddDays(-1) };
      context.Response.Cookies.Add(cookie);
    }

    try
    {
      System.Web.Security.FormsAuthentication.SignOut();
      string authCookieName = System.Web.Security.FormsAuthentication.FormsCookieName;
      if (context.Request.Cookies[authCookieName] != null)
      {
        var authCookie = new HttpCookie(authCookieName) { Expires = DateTime.Now.AddDays(-1) };
        context.Response.Cookies.Add(authCookie);
      }
    }
    catch { }

    context.Response.Cache.SetCacheability(HttpCacheability.NoCache);
    context.Response.Cache.SetNoStore();
    context.Response.Cache.SetExpires(DateTime.UtcNow.AddYears(-1));
    context.Response.AppendHeader("Pragma", "no-cache");
    context.Response.AppendHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    context.Response.AppendHeader("Expires", "0");
  }

  // ============================================================
  // GETTERS
  // ============================================================
  public static int GetUserId(HttpContext context)
  {
    if (context == null || context.Session == null) return 0;
    object val = context.Session[SK_IDUSER];
    return (val != null) ? Convert.ToInt32(val) : 0;
  }

  public static string GetUserName()
  {
    var session = HttpContext.Current.Session;
    if (session == null) return "Inconnu";
    return session[SK_USERNAME] as string ?? "Inconnu";
  }

  public static string GetUserFullName()
  {
    int? userId = GetCurrentUserId();
    if (!userId.HasValue || userId.Value <= 0) return "";
    try
    {
      if (string.IsNullOrEmpty(connStr)) return "";
      using (SqlConnection conn = new SqlConnection(connStr))
      {
        conn.Open();
        using (SqlCommand cmd = new SqlCommand("SELECT NOM FROM USERS WHERE IDUSER = @id", conn))
        {
          cmd.Parameters.AddWithValue("@id", userId.Value);
          object result = cmd.ExecuteScalar();
          if (result != null && result != DBNull.Value) return result.ToString().Trim();
        }
      }
    }
    catch (Exception ex) { LogAuthError("GetUserFullName exception: " + ex.Message); }
    return "";
  }

  public static int GetUserRole(HttpContext context)
  {
    if (context == null || context.Session == null) return -1;
    object val = context.Session[SK_USERROLE];
    return (val != null) ? Convert.ToInt32(val) : -1;
  }

  public static string GetProjectCode(HttpContext ctx)
  {
    try
    {
      string code = ConfigurationManager.AppSettings["ProjectCode"];
      if (string.IsNullOrEmpty(code)) code = "TALIM";
      return code.Trim().ToUpperInvariant().Replace(" ", "");
    }
    catch { return "TALIM"; }
  }

  private static int? GetUserRoleId()
  {
    var session = HttpContext.Current.Session;
    if (session == null || session[SK_USERROLE] == null) return null;
    try { return Convert.ToInt32(session[SK_USERROLE]); } catch { return null; }
  }

  private static int? GetCurrentUserId()
  {
    var session = HttpContext.Current.Session;
    if (session == null || session[SK_IDUSER] == null) return null;
    try { return Convert.ToInt32(session[SK_IDUSER]); } catch { return null; }
  }

  // ============================================================
  // RÔLES
  // ============================================================
  public static bool IsSuperAdmin() { var r = GetUserRoleId(); return r.HasValue && r.Value == 0; }
  public static bool IsAdmin() { var r = GetUserRoleId(); return r.HasValue && r.Value == 1; }
  public static bool IsUser() { var r = GetUserRoleId(); return r.HasValue && r.Value == 2; }
  public static bool IsLogisticien() { var r = GetUserRoleId(); return r.HasValue && r.Value == 3; }
  public static bool IsComptable() { var r = GetUserRoleId(); return r.HasValue && r.Value == 4; }

  public static string GetRoleName()
  {
    var roleId = GetUserRoleId();
    if (!roleId.HasValue) return T("Unknown");
    switch (roleId.Value)
    {
      case 0: return T("SuperAdmin");
      case 1: return T("Admin");
      case 2: return T("User");
      case 3: return T("Logisticien");
      case 4: return T("Comptable");
      default: return T("Unknown");
    }
  }

  public static string Version
  {
    get
    {
      var version = ConfigurationManager.AppSettings["Version"];
      return string.IsNullOrEmpty(version) ? "1.0.0" : version;
    }
  }

  // ============================================================
  // LICENCE
  // ============================================================
  private enum LicenceStatus { Valide, Manquante, Expiree, Invalide }

  private static readonly object _licenceLock = new object();
  private static DateTime _cachedExpirationDate = DateTime.MinValue;
  private static int _cachedMaxUsers = 0;
  private static DateTime _cacheTime = DateTime.MinValue;
  private static readonly TimeSpan _cacheDuration = TimeSpan.FromMinutes(5);

  public static string GetExpirationDateString()
  {
    DateTime exp; int max;
    var status = CheckLicence(out exp, out max);
    if (status == LicenceStatus.Valide || status == LicenceStatus.Expiree) return exp.ToString("dd/MM/yyyy");
    if (status == LicenceStatus.Manquante) return T("LicenceMissing");
    return T("LicenceInvalid");
  }

  public static string GetMaxUsersString()
  {
    DateTime exp; int max;
    var status = CheckLicence(out exp, out max);
    if (status == LicenceStatus.Valide || status == LicenceStatus.Expiree) return max.ToString();
    return "0";
  }

  public static bool IsMaxUsersReached()
  {
    DateTime exp; int max;
    var status = CheckLicence(out exp, out max);
    if (status != LicenceStatus.Valide) return true;
    try
    {
      if (string.IsNullOrEmpty(connStr)) return true;
      using (SqlConnection conn = new SqlConnection(connStr))
      {
        using (SqlCommand cmd = new SqlCommand("SELECT COUNT(*) FROM USERS WHERE SESSION_TOKEN IS NOT NULL", conn))
        {
          conn.Open();
          return (int)cmd.ExecuteScalar() >= max;
        }
      }
    }
    catch { return false; }
  }

  public static bool IsLicenceValid()
  {
    DateTime exp; int max;
    return CheckLicence(out exp, out max) == LicenceStatus.Valide;
  }

  public static SidebarInfo GetSidebarInfo()
  {
    DateTime exp; int max;
    var status = CheckLicence(out exp, out max);
    string expText, maxText;
    if (status == LicenceStatus.Valide || status == LicenceStatus.Expiree)
    { expText = exp.ToString("dd/MM/yyyy"); maxText = max.ToString(); }
    else if (status == LicenceStatus.Manquante) { expText = T("LicenceMissing"); maxText = "0"; }
    else { expText = T("LicenceInvalid"); maxText = "0"; }

    return new SidebarInfo
    {
      ExpirationDate = expText,
      MaxUsers = maxText,
      IsValid = (status == LicenceStatus.Valide),
      IsExpired = (status == LicenceStatus.Expiree)
    };
  }

  private static LicenceStatus CheckLicence(out DateTime expirationDate, out int maxUsers)
  {
    expirationDate = DateTime.MinValue;
    maxUsers = 0;

    lock (_licenceLock)
    {
      if (_cacheTime > DateTime.Now.Subtract(_cacheDuration))
      {
        expirationDate = _cachedExpirationDate;
        maxUsers = _cachedMaxUsers;
        if (_cachedExpirationDate == DateTime.MinValue) return LicenceStatus.Invalide;
        if (DateTime.Now.Date > _cachedExpirationDate.Date) return LicenceStatus.Expiree;
        return LicenceStatus.Valide;
      }
    }

    if (HttpContext.Current == null) return LicenceStatus.Invalide;
    string path = HttpContext.Current.Server.MapPath("~/bin/licence.key");
    if (!File.Exists(path)) return LicenceStatus.Manquante;

    string secret = ConfigurationManager.AppSettings["LicenceSecret"];
    if (string.IsNullOrEmpty(secret)) return LicenceStatus.Invalide;

    try
    {
      string[] lines = File.ReadAllLines(path);
      string expClear = GetValueFromLines(lines, "EXPIRATIONS", false);
      string maxClear = GetValueFromLines(lines, "MAX_USERSS", false);
      string expHash = GetValueFromLines(lines, "EXPIRATION", true);
      string maxHash = GetValueFromLines(lines, "MAX_USERS", true);
      string sigHash = GetValueFromLines(lines, "SIGNATURE", true);

      if (!DateTime.TryParseExact(expClear, "yyyy-MM-dd",
          System.Globalization.CultureInfo.InvariantCulture,
          System.Globalization.DateTimeStyles.None, out expirationDate))
        return LicenceStatus.Invalide;
      if (!int.TryParse(maxClear, out maxUsers) || maxUsers <= 0) return LicenceStatus.Invalide;

      string expCalc = ComputeHmacSha256(expClear, secret);
      string maxCalc = ComputeHmacSha256(maxUsers.ToString(), secret);
      string sigCalc = ComputeHmacSha256(expCalc + maxCalc, secret);

      if (expCalc != expHash || maxCalc != maxHash || sigCalc != sigHash)
        return LicenceStatus.Invalide;

      lock (_licenceLock)
      {
        _cachedExpirationDate = expirationDate;
        _cachedMaxUsers = maxUsers;
        _cacheTime = DateTime.Now;
      }
      return DateTime.Now.Date > expirationDate.Date ? LicenceStatus.Expiree : LicenceStatus.Valide;
    }
    catch { return LicenceStatus.Invalide; }
  }

  private static string GetValueFromLines(string[] lines, string key, bool first)
  {
    var values = new List<string>();
    foreach (var line in lines) if (line.StartsWith(key + "=")) values.Add(line.Substring(key.Length + 1).Trim());
    if (values.Count == 0) return null;
    return first ? values[0] : values[values.Count - 1];
  }

  private static string ComputeHmacSha256(string data, string key)
  {
    using (var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(key)))
    {
      byte[] hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(data));
      return BitConverter.ToString(hash).Replace("-", "").ToLower();
    }
  }

  public class LicenceInfo
  {
    public DateTime ExpirationDate { get; set; }
    public int MaxUsers { get; set; }
    public bool IsValid { get; set; }
    public bool IsExpired { get; set; }
    public int DaysLeft { get; set; }
  }

  public static LicenceInfo GetLicenceInfo()
  {
    DateTime exp; int max;
    var status = CheckLicence(out exp, out max);
    var info = new LicenceInfo
    {
      ExpirationDate = exp,
      MaxUsers = max,
      IsValid = (status == LicenceStatus.Valide),
      IsExpired = (status == LicenceStatus.Expiree)
    };
    info.DaysLeft = (exp.Date - DateTime.Now.Date).Days;
    return info;
  }

  public class SidebarInfo
  {
    public string ExpirationDate { get; set; }
    public string MaxUsers { get; set; }
    public bool IsValid { get; set; }
    public bool IsExpired { get; set; }
  }
}
