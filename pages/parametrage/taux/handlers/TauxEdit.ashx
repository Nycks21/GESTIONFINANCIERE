<%@ WebHandler Language="C#" Class="TauxEdit" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class TauxEdit : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}");
            return;
        }
        if (!AuthHelper.HasPermission("taux"))
        {
            ctx.Response.StatusCode = 403;
            ctx.Response.Write("{\"success\":false,\"message\":\"Permission refusée\"}");
            return;
        }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);

            if (data == null)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Corps de requête invalide.\"}");
                return;
            }

            string id         = GetString(data, "id");
            string sourceId   = GetString(data, "monnaieSourceId");
            string cibleId    = GetString(data, "monnaieCibleId");
            string dateEffetS = GetString(data, "dateEffet");
            string sourceInfo = (GetString(data, "source") ?? "").Trim();
            bool   actif      = GetBool(data, "actif", true);
            decimal taux;

            if (!Guid.TryParse(id, out _) ||
                !Guid.TryParse(sourceId, out _) ||
                !Guid.TryParse(cibleId, out _))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Identifiants invalides.\"}");
                return;
            }
            if (sourceId == cibleId)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Les monnaies source et cible doivent être différentes.\"}");
                return;
            }
            if (!decimal.TryParse(GetString(data, "taux"), System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture, out taux) || taux <= 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Le taux doit être un nombre positif.\"}");
                return;
            }
            DateTime dateEffet;
            if (!DateTime.TryParse(dateEffetS, out dateEffet))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Date d'effet invalide.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Existence
                using (var cmdCheck = new SqlCommand(
                    "SELECT COUNT(1) FROM FTAUX_CHANGE WHERE ID = @id AND DELETION_AT IS NULL", conn))
                {
                    cmdCheck.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(cmdCheck.ExecuteScalar()) == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Taux introuvable.\"}");
                        return;
                    }
                }

                // Anti-doublon (exclut l'ID courant)
                using (var cmdDup = new SqlCommand(@"
                    SELECT COUNT(1) FROM FTAUX_CHANGE
                    WHERE MONNAIE_SOURCE_ID = @src
                      AND MONNAIE_CIBLE_ID = @cib
                      AND DATE_EFFET = @date
                      AND ID <> @id
                      AND DELETION_AT IS NULL", conn))
                {
                    cmdDup.Parameters.AddWithValue("@src", sourceId);
                    cmdDup.Parameters.AddWithValue("@cib", cibleId);
                    cmdDup.Parameters.AddWithValue("@date", dateEffet);
                    cmdDup.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(cmdDup.ExecuteScalar()) > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Un autre taux existe déjà pour ce couple à cette date."
                        }));
                        return;
                    }
                }

                string sql = @"
                    UPDATE FTAUX_CHANGE
                    SET MONNAIE_SOURCE_ID = @src,
                        MONNAIE_CIBLE_ID  = @cib,
                        DATE_EFFET        = @date,
                        TAUX              = @taux,
                        SOURCE            = @source,
                        ACTIVE            = @active,
                        UPDATED_BY        = @userId,
                        UPDATED_AT        = GETDATE()
                    WHERE ID = @id AND DELETION_AT IS NULL";

                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@src", sourceId);
                    cmd.Parameters.AddWithValue("@cib", cibleId);
                    cmd.Parameters.AddWithValue("@date", dateEffet);
                    cmd.Parameters.AddWithValue("@taux", taux);
                    cmd.Parameters.AddWithValue("@source",
                        string.IsNullOrEmpty(sourceInfo) ? (object)DBNull.Value : sourceInfo);
                    cmd.Parameters.AddWithValue("@active", actif ? 1 : 0);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    cmd.ExecuteNonQuery();
                }
            }

            ctx.Response.Write(serializer.Serialize(new
            {
                success = true,
                message = "Taux modifié avec succès."
            }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = ex.Message.Replace("\"", "\\\"")
            }));
        }
    }

    private string GetString(Dictionary<string, object> data, string key)
    {
        return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null;
    }
    private bool GetBool(Dictionary<string, object> data, string key, bool defaultValue)
    {
        if (data.ContainsKey(key) && data[key] != null)
        {
            bool val;
            if (bool.TryParse(data[key].ToString(), out val)) return val;
            string s = data[key].ToString().Trim();
            if (s == "1" || s == "true") return true;
            if (s == "0" || s == "false") return false;
        }
        return defaultValue;
    }

    public bool IsReusable { get { return false; } }
}
