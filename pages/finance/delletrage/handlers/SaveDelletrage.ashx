<%@ WebHandler Language="C#" Class="SaveDelletrage" %>
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SaveDelletrage : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json; charset=utf-8";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }
        if (!AuthHelper.HasPermission("saisie"))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Permission refusée\"}"); return; }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);
            if (data == null) { ctx.Response.Write("{\"success\":false,\"message\":\"Corps invalide.\"}"); return; }

            var lineIds = new List<Guid>();
            if (data.ContainsKey("lineIds") && data["lineIds"] != null)
            {
                var arr = data["lineIds"] as System.Collections.IList;
                if (arr != null)
                {
                    foreach (var item in arr)
                    {
                        Guid g;
                        if (item != null && Guid.TryParse(item.ToString(), out g))
                            lineIds.Add(g);
                    }
                }
            }

            if (lineIds.Count == 0)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Aucune ligne sélectionnée.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            // ⭐ Construction du IN clause : @id0,@id1,...
            var sqlIn = new List<string>();
            var sqlParams = new List<SqlParameter>();
            for (int i = 0; i < lineIds.Count; i++)
            {
                string pname = "@id" + i;
                sqlIn.Add(pname);
                sqlParams.Add(new SqlParameter(pname, SqlDbType.UniqueIdentifier) { Value = lineIds[i] });
            }
            string inClause = string.Join(",", sqlIn);

            int lignesSupprimees = 0;
            int entetesSupprimees = 0;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        // ⭐ 1. Récupérer les LETTRAGE_ID impactés
                        //    (nécessaire pour savoir quels entêtes vérifier après suppression)
                        var lettrageIds = new List<Guid>();
                        using (var cmd = new SqlCommand(
                            "SELECT DISTINCT LETTRAGE_ID FROM FLETTRAGE_LIGNE WHERE ECRITURE_LIGNE_ID IN (" + inClause + ")",
                            conn, tx))
                        {
                            cmd.Parameters.AddRange(CloneParameters(sqlParams));
                            using (var r = cmd.ExecuteReader())
                            {
                                while (r.Read())
                                    lettrageIds.Add(Guid.Parse(r["LETTRAGE_ID"].ToString()));
                            }
                        }

                        if (lettrageIds.Count == 0)
                        {
                            ctx.Response.Write("{\"success\":false,\"message\":\"Aucun lettrage trouvé pour ces lignes.\"}");
                            return;
                        }

                        // ⭐ 2. DELETE physique dans FLETTRAGE_LIGNE (les enfants d'abord)
                        using (var cmd = new SqlCommand(
                            "DELETE FROM FLETTRAGE_LIGNE WHERE ECRITURE_LIGNE_ID IN (" + inClause + ")",
                            conn, tx))
                        {
                            cmd.Parameters.AddRange(CloneParameters(sqlParams));
                            lignesSupprimees = cmd.ExecuteNonQuery();
                        }

                        // ⭐ 3. DELETE physique des entêtes FLETTRAGE devenues vides
                        //    On ne supprime QUE les entêtes qui n'ont plus aucune ligne.
                        //    Un entête partagé (avec d'autres lignes non délettrées) est préservé.
                        foreach (var lId in lettrageIds)
                        {
                            using (var cmd = new SqlCommand(@"
                                DELETE FROM FLETTRAGE
                                WHERE ID = @lid
                                  AND NOT EXISTS (
                                      SELECT 1 FROM FLETTRAGE_LIGNE WHERE LETTRAGE_ID = @lid
                                  )", conn, tx))
                            {
                                cmd.Parameters.AddWithValue("@lid", lId);
                                entetesSupprimees += cmd.ExecuteNonQuery();
                            }
                        }

                        // ⭐ Audit
                        try
                        {
                            string ip = ctx.Request.UserHostAddress ?? "";
                            using (var cmdLog = new SqlCommand(@"
                                INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                                VALUES (@u, @a, @d, @ip, GETDATE())", conn, tx))
                            {
                                cmdLog.Parameters.AddWithValue("@u", userId);
                                cmdLog.Parameters.AddWithValue("@a", "DELLETTRAGE");
                                cmdLog.Parameters.AddWithValue("@d",
                                    lignesSupprimees + " ligne(s) délettrée(s), "
                                  + entetesSupprimees + " entête(s) supprimé(s)");
                                cmdLog.Parameters.AddWithValue("@ip", ip);
                                cmdLog.ExecuteNonQuery();
                            }
                        }
                        catch { /* audit non bloquant */ }

                        tx.Commit();
                    }
                    catch
                    {
                        try { tx.Rollback(); } catch { }
                        throw;
                    }
                }
            }

            ctx.Response.Write(serializer.Serialize(new
            {
                success = true,
                message = "Délettrage effectué avec succès.",
                lignesSupprimees = lignesSupprimees,
                entetesSupprimees = entetesSupprimees
            }));
        }
        catch (SqlException sqlEx)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = false,
                message = "SQL Error " + sqlEx.Number + " : " + sqlEx.Message,
                line = sqlEx.LineNumber
            }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = false, message = ex.Message, type = ex.GetType().Name }));
        }
    }

    /// <summary>
    /// Clone une liste de SqlParameter pour permettre son utilisation
    /// dans plusieurs SqlCommand successifs (un paramètre ne peut
    /// appartenir qu'à une seule SqlParameterCollection à la fois).
    /// </summary>
    private static SqlParameter[] CloneParameters(List<SqlParameter> source)
    {
        var clones = new SqlParameter[source.Count];
        for (int i = 0; i < source.Count; i++)
        {
            var p = source[i];
            var clone = new SqlParameter(p.ParameterName, p.SqlDbType);
            clone.Value = p.Value ?? DBNull.Value;
            clone.Direction = p.Direction;
            if (p.Size > 0) clone.Size = p.Size;
            if (p.Precision > 0) clone.Precision = p.Precision;
            if (p.Scale > 0) clone.Scale = p.Scale;
            clones[i] = clone;
        }
        return clones;
    }

    public bool IsReusable { get { return false; } }
}
