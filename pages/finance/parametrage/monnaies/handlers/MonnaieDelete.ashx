<%@ WebHandler Language="C#" Class="MonnaieDelete" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class MonnaieDelete : IHttpHandler, IRequiresSessionState
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

            string id = GetString(data, "id");
            if (string.IsNullOrEmpty(id))
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"ID manquant.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // 1) Vérifier si c'est la monnaie de référence
                using (var cmd = new SqlCommand(
                    "SELECT EST_REFERENCE FROM FMONNAIE WHERE ID = @id AND DELETION_AT IS NULL", conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    object result = cmd.ExecuteScalar();
                    if (result == null)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Monnaie introuvable ou déjà supprimée.\"}");
                        return;
                    }
                    if (Convert.ToBoolean(result))
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer la monnaie de référence."
                        }));
                        return;
                    }
                }

                // 2) Vérifier les références (FTAUX_CHANGE, FECRITURE, FJOURNAL, FRELEVE...)
                string referenceSql = @"
                    SELECT
                        (SELECT COUNT(*) FROM FTAUX_CHANGE WHERE MONNAIE_SOURCE_ID = @id OR MONNAIE_CIBLE_ID = @id) +
                        (SELECT COUNT(*) FROM FECRITURE    WHERE MONNAIE_ID = @id) +
                        (SELECT COUNT(*) FROM FJOURNAL     WHERE MONNAIE_ID = @id)";
                using (var refCmd = new SqlCommand(referenceSql, conn))
                {
                    refCmd.Parameters.AddWithValue("@id", id);
                    if (Convert.ToInt32(refCmd.ExecuteScalar()) > 0)
                    {
                        ctx.Response.Write(serializer.Serialize(new
                        {
                            success = false,
                            message = "Impossible de supprimer, monnaie référencée"
                        }));
                        return;
                    }
                }

                // 3) Soft delete
                string sql = @"
                    UPDATE FMONNAIE
                    SET DELETION_AT = GETDATE(),
                        DELETION_BY = @userId
                    WHERE ID = @id AND DELETION_AT IS NULL";
                using (var cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddWithValue("@id", id);
                    cmd.Parameters.AddWithValue("@userId", userId);
                    int rows = cmd.ExecuteNonQuery();
                    if (rows == 0)
                    {
                        ctx.Response.Write("{\"success\":false,\"message\":\"Monnaie introuvable ou déjà supprimée.\"}");
                        return;
                    }
                }
            }

            ctx.Response.Write(serializer.Serialize(new { success = true, message = "Monnaie supprimée." }));
        }
        catch (SqlException ex)
        {
            if (ex.Number == 547)
            {
                ctx.Response.Write(new JavaScriptSerializer().Serialize(new
                {
                    success = false,
                    message = "Impossible de supprimer, monnaie réfé
