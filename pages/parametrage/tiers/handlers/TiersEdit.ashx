<%@ WebHandler Language="C#" Class="TiersEdit" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class TiersEdit : IHttpHandler, IRequiresSessionState
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

            string id = GetString(data, "id");
            Guid tmp;
            if (string.IsNullOrEmpty(id) || !Guid.TryParse(id, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"ID invalide.\"}"); return; }

            string code           = (GetString(data, "code") ?? "").Trim().ToUpperInvariant();
            string nom            = (GetString(data, "nom") ?? "").Trim();
            string typeTiers      = (GetString(data, "typeTiers") ?? "").Trim().ToUpperInvariant();
            string planElementId  = GetString(data, "planElementId");
            int    planOrder      = GetInt(data, "planOrder", 0);
            string email          = (GetString(data, "email") ?? "").Trim();
            string telephone      = (GetString(data, "telephone") ?? "").Trim();
            string adresse        = (GetString(data, "adresse") ?? "").Trim();
            bool   active         = GetBool(data, "active", true);

            if (string.IsNullOrEmpty(code)) { ctx.Response.Write("{\"success\":false,\"message\":\"Code obligatoire.\"}"); return; }
            if (string.IsNullOrEmpty(nom))  { ctx.Response.Write("{\"success\":false,\"message\":\"Nom obligatoire.\"}"); return; }

            string[] validTypes = { "FOURNISSEUR", "CLIENT", "AGENT", "PARTENAIRE", "AUTRE" };
            if (Array.IndexOf(validTypes, typeTiers) < 0)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Type invalide.\"}"); return; }

            if (string.IsNullOrEmpty(planElementId) || !Guid.TryParse(planElementId, out tmp))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Compte collectif obligatoire.\"}"); return; }

            if (planOrder < 1 || planOrder > 10)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Plan invalide (1..10).\"}"); return; }

            string tableName = AuthHelperPlan.GetPlanTableName(planOrder);

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Existence
                using (var cmdEx = new SqlCommand(
                    "SELECT COUNT(1) FROM FTIERS WHERE ID = @id AND DELETION_AT IS NULL", conn))
                {
                    cmdEx.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(cmdEx.ExecuteScalar()) == 0)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Tiers introuvable.\"}"); return; }
                }

                // Validation compte (dynamique)
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
                    "SELECT COUNT(1) FROM FTIERS WHERE CODE = @code AND ID <> @id AND DELETION_AT IS NULL", conn))
                {
                    cmdDup.Parameters.AddWithValue("@code", code);
                    cmdDup.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(cmdDup.ExecuteScalar()) > 0)
                    { ctx.Response.Write("{\"success\":false,\"message\":\"Ce code est utilisé par un autre tiers.\"}"); return; }
                }

                string sql = @"
                    UPDATE FTIERS
                    SET CODE = @code,
                        NOM = @nom,
                        TYPE_TIERS = @type,
                        PLAN_ELEMENT_ID = @compte,
                        PLAN_ORDER = @planOrder,
                        EMAIL = @email,
                        TELEPHONE = @tel,
                        ADRESSE = @adresse,
                        ACTIVE = @active,
                        UPDATED_BY = @userId,
                        UPDATED_AT = GETDATE()
                    WHERE ID = @id AND DELETION_AT IS NULL";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
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

                try
                {
                    string ip = ctx.Request.UserHostAddress ?? "";
                    using (var cmdLog = new SqlCommand(@"
                        INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                        VALUES (@uid, 'TIERS_EDIT', @det, @ip, GETDATE())", conn))
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
            { success = true, message = "Tiers modifié avec succès." }));
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
