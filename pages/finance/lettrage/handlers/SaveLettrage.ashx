<%@ WebHandler Language="C#" Class="SaveLettrage" %>
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class SaveLettrage : IHttpHandler, IRequiresSessionState
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
                        if (item != null && Guid.TryParse(item.ToString(), out g)) lineIds.Add(g);
                    }
                }
            }

            if (lineIds.Count < 2)
            {
                ctx.Response.Write("{\"success\":false,\"message\":\"Sélectionnez au moins 2 lignes.\"}");
                return;
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            string lettrageId = Guid.NewGuid().ToString();
            string lettrageCode = "L" + DateTime.Now.ToString("yyMMddHHmmss");

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        // 1. Vérification de l'équilibre
                        decimal totalDebit = 0m, totalCredit = 0m;
                        var sqlIn = new List<string>();
                        var sqlParams = new List<SqlParameter>();
                        for (int i = 0; i < lineIds.Count; i++)
                        {
                            string pname = "@id" + i;
                            sqlIn.Add(pname);
                            sqlParams.Add(new SqlParameter(pname, SqlDbType.UniqueIdentifier) { Value = lineIds[i] });
                        }
                        string inClause = string.Join(",", sqlIn);

                        string sqlVerif = @"
                            SELECT ID, SENS, MONTANT
                            FROM FECRITURE_LIGNE
                            WHERE ID IN (" + inClause + @")
                              AND LETTRABLE = 1
                              AND NOT EXISTS (SELECT 1 FROM FLETTRAGE_LIGNE fll INNER JOIN FLETTRAGE f ON f.ID=fll.LETTRAGE_ID WHERE fll.ECRITURE_LIGNE_ID = FECRITURE_LIGNE.ID AND f.DELETION_AT IS NULL)";

                        using (var cmd = new SqlCommand(sqlVerif, conn, tx))
                        {
                            cmd.Parameters.AddRange(sqlParams.ToArray());
                            using (var r = cmd.ExecuteReader())
                            {
                                while (r.Read())
                                {
                                    string sens = r["SENS"].ToString();
                                    decimal mnt = Convert.ToDecimal(r["MONTANT"]);
                                    if (sens == "D") totalDebit += mnt;
                                    if (sens == "C") totalCredit += mnt;
                                }
                            }
                        }

                        if (Math.Abs(totalDebit - totalCredit) > 0.01m)
                        {
                            throw new Exception("Le débit et le crédit sélectionnés ne sont pas équilibrés.");
                        }

                        // 2. Création de l'entête FLETTRAGE
                        using (var cmd = new SqlCommand(@"
                            INSERT INTO FLETTRAGE (ID, CODE, DATE_LETTRAGE, MONTANT, CREATED_BY, CREATED_AT)
                            VALUES (@id, @code, GETDATE(), @montant, @u, GETDATE())", conn, tx))
                        {
                            cmd.Parameters.AddWithValue("@id", lettrageId);
                            cmd.Parameters.AddWithValue("@code", lettrageCode);
                            cmd.Parameters.AddWithValue("@montant", totalDebit);
                            cmd.Parameters.AddWithValue("@u", userId);
                            cmd.ExecuteNonQuery();
                        }

                        // 3. Création des lignes FLETTRAGE_LIGNE
                        foreach (var id in lineIds)
                        {
                            using (var cmd = new SqlCommand(@"
                                INSERT INTO FLETTRAGE_LIGNE (ID, LETTRAGE_ID, ECRITURE_LIGNE_ID, MONTANT_LETTRE, CREATED_BY, CREATED_AT)
                                SELECT NEWID(), @lid, ID, MONTANT, @u, GETDATE()
                                FROM FECRITURE_LIGNE WHERE ID = @elid", conn, tx))
                            {
                                cmd.Parameters.AddWithValue("@lid", lettrageId);
                                cmd.Parameters.AddWithValue("@elid", id);
                                cmd.Parameters.AddWithValue("@u", userId);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        tx.Commit();
                    }
                    catch
                    {
                        try { tx.Rollback(); } catch { }
                        throw;
                    }
                }
            }

            ctx.Response.Write(serializer.Serialize(new { success = true, message = "Lettrage effectué avec succès." }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new { success = false, message = ex.Message }));
        }
    }

    public bool IsReusable { get { return false; } }
}
