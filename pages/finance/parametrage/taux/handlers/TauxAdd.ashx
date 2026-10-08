<%@ WebHandler Language="C#" Class="TauxAdd" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class TauxAdd : IHttpHandler, IRequiresSessionState
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

            string sourceId   = GetString(data, "monnaieSourceId");
            string cibleId    = GetString(data, "monnaieCibleId");
            string dateEffetS = GetString(data, "dateEffet");
            string sourceInfo = (GetString(data, "source") ?? "").Trim();
            bool   actif      = GetBool(data, "actif", true);
            decimal taux;

            if (!Guid.TryParse(sourceId, out _) || !Guid.TryParse(cibleId, out _))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Monnaies invalides.\"}");
                return;
            }
            if (sourceId == cibleId)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Les monnaies source et cible doivent être différentes.\"}");
                return;
            }

            var rawTaux = GetString(data, "taux");
            if (!decimal.TryParse(rawTaux, System.Globalization.NumberStyles.Any,
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
            string newId = Guid.NewGuid().ToString();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // Anti-doublon : unicité (source, cible, date)
                using (var cmdCheck = new SqlCommand(@"
                    SELECT COUNT(1) FROM FTAUX_CHANGE
                    WHERE MONNAIE_SOURCE_ID = @src
                      AND MONNAIE_CIBLE_ID = @cib
                      AND DATE_EFFET = @date
                      AND DELETION_AT IS NULL", conn))
                {
                    cmdCheck.Parameters.AddWithValue("@src", sourceId);
                    cmdCheck.Parameters.AddWithValue("@cib", cibleId);
                    cmdCheck.Parameters.AddWithValue("@date", dateEffet);
                    if (Convert.ToInt32(cmdCheck.ExecuteScalar()) > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Un taux existe déjà pour ce couple de monnaies à cette date."
                        }));
                        return;
                    }
                }

                string sqlInsert = @"
                    INSERT INTO FTAUX_CHANGE
                        (ID, MONNAIE_SOURCE_ID, MONNAIE_CIBLE_ID, DATE_EFFET, TAUX, SOURCE,
                         ACTIVE, CREATED_BY, CREATED_AT)
                    VALUES
                        (@id, @src, @cib, @date, @taux, @source, @active, @userId, GETDATE())";

                using (var cmd = new SqlCommand(sqlInsert, conn))
                {
                    cmd.Parameters.AddWithValue("@id", newId);
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
                id = newId,
                message = "Taux ajouté avec succès."
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
