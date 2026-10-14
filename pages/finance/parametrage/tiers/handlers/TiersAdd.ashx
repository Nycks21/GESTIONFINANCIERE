<%@ WebHandler Language="C#" Class="TiersAdd" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class TiersAdd : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }
        if (!AuthHelper.HasPermission("tiers"))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Permission refusée\"}"); return; }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);
            if (data == null) { ctx.Response.Write("{\"success\":false,\"message\":\"Corps invalide.\"}"); return; }

            string code           = (GetString(data, "code") ?? "").Trim().ToUpperInvariant();
            string nom            = (GetString(data, "nom") ?? "").Trim();
            string typeTiers      = (GetString(data, "typeTiers") ?? "").Trim().ToUpperInvariant();
            string planElementId  = GetString(data, "planElementId");
            int    planOrder      = GetInt(data, "planOrder", 0);
            string email          = (GetString(data, "email") ?? "").Trim();
            string telephone      = (GetString(data, "telephone") ?? "").Trim();
            string adresse        = (GetString(data, "adresse") ?? "").Trim();
            bool   active         = GetBool(data, "active", true);

            if (string.IsNullOrEmpty(code) || code.Length > 50)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Code obligatoire (max 50).\"}"); return; }
            if (string.IsNullOrEmpty(nom))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Nom obligatoire.\"}"); return; }

            string[] validTypes = { "FOURNISSEUR", "CLIENT", "AGENT", "PARTENAIRE", "AUTRE" };
            if (Array.IndexOf(validTypes, typeTiers) < 0)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Type invalide.\"}"); return; }

            Guid tmp;
            if (string.IsNullOrEmpty(planElementId) || !Guid.TryParse(planElementId, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Compte collectif obligatoire.\"}"); return; }

            if (planOrder < 1 || planOrder > 10)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Plan invalide (1..10).\"}"); return; }

            // ✅ Vérification dynamique dans PLAN{planOrder}
            string tableName = AuthHelperPlan.GetPlanTableName(planOrder);

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            string newId = Guid.NewGuid().ToString();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // 🔒 Vérifie que le compte existe, actif, auxiliaire, dernier niveau
                string sqlChk = @"
                    SELECT COUNT(1)
                    FROM " + tableName + @"
                    WHERE ID = @id
                      AND EST_AUXILIAIRE = 1
                      AND ACTIVE = 1
                      AND DELETION_AT IS NULL
                      AND NOT EXISTS (
                          SELECT 1 FROM " + tableName + @" c
                          WHERE c.PARENT_ID = " + tableName + @".ID AND c.DELETION_AT IS NULL
                      )";
                using (var cmdChk = new SqlCommand(sqlChk, conn))
                {
                    cmdChk.Parameters.AddWithValue("@id", planElementId);
                    if (Convert.ToInt32(cmdChk.ExecuteScalar()) == 0)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Ce compte n'est pas autorisé à recevoir des auxiliaires.\"}"); return; }
                }

                // Unicité CODE
                using (var cmdDup = new SqlCommand(
                    "SELECT COUNT(1) FROM FTIERS WHERE CODE = @code AND DELETION_AT IS NULL", conn))
                {
                    cmdDup.Parameters.AddWithValue("@code", code);
                    if (Convert.ToInt32(cmdDup.ExecuteScalar()) > 0)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Ce code tiers existe déjà.\"}"); return; }
                }

                string sql = @"
                    INSERT INTO FTIERS
                        (ID, CODE, NOM, TYPE_TIERS, PLAN_ELEMENT_ID, PLAN_ORDER,
                         EMAIL, TELEPHONE, ADRESSE, ACTIVE,
                         CREATED_BY, CREATED_AT)
                    VALUES
                        (@id, @code, @nom, @type, @compte, @planOrder,
                         @email, @tel, @adresse, @active,
                         @userId, GETDATE())";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", newId);
                    cmd.Parameters.AddWithValue("@code", code);
                    cmd.Parameters.AddWithValue("@nom", nom);
                    cmd.Parameters.AddWithValue("@type", typeTiers);
                    cmd.Parameters.AddWithValue("@compte", planElementId);
                    cmd.Parameters.AddWithValue("@planOrder", planOrder);
                    cmd.Parameters.AddWithValue("@email", string.IsNullOrEmpty(email) ? (object)DBNull.Value : email);
                    cmd.Parameters.AddWithValue("@tel", string.IsNullOrEmpty(telephone) ? (object)DBNull.Value : telephone);
                    cmd.Parameters.AddWithValue("@adresse", string.IsNullOrEmpty(adresse) ? (object)DBNull.Value : adresse);
                    cmd.Parameters.AddWithValue("@active", active ? 1 : 0);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    cmd.ExecuteNonQuery();
                }

                // Audit
                try
                {
                    string ip = ctx.Request.UserHostAddress ?? "";
                    using (var cmdLog = new SqlCommand(@"
                        INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                        VALUES (@uid, 'TIERS_ADD', @det, @ip, GETDATE())", conn))
                    {
                        cmdLog.Parameters.AddWithValue("@uid", userId);
                        cmdLog.Parameters.AddWithValue("@det", code + " - " + nom + " (PLAN" + planOrder + ")");
                        cmdLog.Parameters.AddWithValue("@ip", ip);
                        cmdLog.ExecuteNonQuery();
                    }
                }
                catch { }
            }

            ctx.Response.Write(serializer.Serialize(new
            { success = true, id = newId, message = "Tiers ajouté avec succès (" + code + ")." }));
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = false, message = "SQL Error " + sqlEx.Number + " : " + sqlEx.Message }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = false, message = ex.Message }));
        }
    }

    private string GetString(Dictionary<string, object> data, string key)
    { return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null; }
    private int GetInt(Dictionary<string, object> data, string key, int def)
    {
        int v;
        if (data.ContainsKey(key) && data[key] != null && int.TryParse(data[key].ToString(), out v))
            return v;
        return def;
    }
    private bool GetBool(Dictionary<string, object> data, string key, bool def)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            bool v; if (bool.TryParse(data[key].ToString(), out v)) return v;
            string s = data[key].ToString().Trim();
            if (s == "1" || s == "true") return true;
            if (s == "0" || s == "false") return false;
        }
        return def;
    }

    public bool IsReusable { get { return false; } }
}
