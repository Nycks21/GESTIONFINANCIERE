<%@ Page Language="C#" AutoEventWireup="true" ResponseEncoding="utf-8" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Web.Script.Serialization" %>
<%@ Import Namespace="System.Collections.Generic" %>

<script runat="server">
protected void Page_Load(object sender, EventArgs e)
{
    // ────────────────────────────────────────────────────────────
    // Préparation de la réponse JSON
    // ────────────────────────────────────────────────────────────
    // IMPORTANT : TrySkipIisCustomErrors = true empêche IIS de
    // remplacer nos réponses JSON d'erreur par sa propre page HTML
    // (ce qui était une cause probable du "<!DOCTYPE" reçu côté client).
    // ────────────────────────────────────────────────────────────
    Response.Clear();
    Response.ContentType   = "application/json";
    Response.ContentEncoding = System.Text.Encoding.UTF8;
    Response.TrySkipIisCustomErrors = true;

    Response.AddHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    Response.AddHeader("Pragma", "no-cache");
    Response.AddHeader("Expires", "0");
    Response.Cache.SetNoStore();

    try
    {
        // ────────────────────────────────────────────────────────
        // Auth : Admin (1) ou SuperAdmin (0)
        // ────────────────────────────────────────────────────────
        // ⚠️ À VÉRIFIER : si AuthHelper.RequireApiAuth fait un
        //    Response.Redirect(...) en interne, il faut le modifier
        //    pour qu'il écrive du JSON + StatusCode, et retourne false.
        //    Sinon le client recevra du HTML de Login.aspx.
        // ────────────────────────────────────────────────────────
        if (!AuthHelper.RequireApiAuth(Context, 1))
        {
            Response.StatusCode = 401;
            Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }

        // ────────────────────────────────────────────────────────
        // Chaîne de connexion
        // ────────────────────────────────────────────────────────
        string connStr = ConfigurationManager
            .ConnectionStrings["MaConnexion"]
            .ConnectionString;

        if (string.IsNullOrEmpty(connStr))
        {
            Response.StatusCode = 500;
            Response.Write("{\"success\":false,\"message\":\"Erreur de configuration\"}");
            return;
        }

        // ────────────────────────────────────────────────────────
        // Récupération des utilisateurs
        // ────────────────────────────────────────────────────────
        var users      = new List<Dictionary<string, object>>();
        var serializer = new JavaScriptSerializer();

        using (SqlConnection conn = new SqlConnection(connStr))
        {
            conn.Open();

            // Filtres stricts :
            //   - DELETION_AT IS NULL  → jamais supprimé logiquement
            //   - DELETION_BY IS NULL  → aucune trace de suppression
            //   - ROLEID != 99         → exclure les comptes techniques
            // Ne pas exposer les mots de passe.
            string query = @"
                SELECT IDUSER, USERNAME, NOM,
                       ISNULL(EMAIL, '')      AS EMAIL,
                       ISNULL(TELEPHONE, '')  AS TELEPHONE,
                       ROLEID, CREATED_AT,
                       CAST(ISNULL(ACTIVE, 0) AS BIT) AS ACTIVE
                FROM USERS
                WHERE DELETION_AT IS NULL
                  AND DELETION_BY IS NULL
                  AND ROLEID != 99
                ORDER BY NOM ASC";

            using (SqlCommand cmd = new SqlCommand(query, conn))
            using (SqlDataReader reader = cmd.ExecuteReader())
            {
                while (reader.Read())
                {
                    var user = new Dictionary<string, object>();
                    user["IDUSER"]     = reader["IDUSER"];
                    user["USERNAME"]   = reader["USERNAME"];
                    user["NOM"]        = reader["NOM"];
                    user["EMAIL"]      = reader["EMAIL"];
                    user["TELEPHONE"]  = reader["TELEPHONE"];
                    user["ROLEID"]     = reader["ROLEID"];
                    user["CREATED_AT"] = Convert.ToDateTime(reader["CREATED_AT"]);
                    user["ACTIVE"]     = reader["ACTIVE"];
                    users.Add(user);
                }
            }
        }

        Response.StatusCode = 200;
        Response.Write(serializer.Serialize(users));
    }
    catch (SqlException sqlEx)
    {
        // Log serveur (visible dans les traces, pas dans la réponse HTTP)
        System.Diagnostics.Trace.TraceError(
            "ListUser.SqlException: " + sqlEx.Message + Environment.NewLine + sqlEx.StackTrace);

        Response.StatusCode = 500;
        Response.Write("{\"success\":false,\"message\":\"Erreur base de données\"}");
    }
    catch (Exception ex)
    {
        System.Diagnostics.Trace.TraceError(
            "ListUser.Exception: " + ex.ToString());

        Response.StatusCode = 500;
        Response.Write("{\"success\":false,\"message\":\"Erreur serveur\"}");
    }

    // ❌ NE PAS appeler Response.End() ici :
    //    - inutile (la page se termine naturellement)
    //    - provoque ThreadAbortException, considérée comme mauvaise pratique
    //    - peut casser le pipeline IIS si un module écoute EndRequest
}
</script>
