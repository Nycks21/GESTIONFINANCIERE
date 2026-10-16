<%@ WebHandler Language="C#" Class="PlanElementSave" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class PlanElementSave : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }
        if (!AuthHelper.HasPermission("generale"))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Permission refusée\"}"); return; }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);
            if (data == null)
            { ctx.Response.Write("{\"success\":false,\"message\":\"Corps invalide.\"}"); return; }

            string id = GetString(data, "id");

            int ordre;
            if (!int.TryParse(GetString(data, "planOrder"), out ordre) || ordre < 1 || ordre > 10)
            { ctx.Response.Write("{\"success\":false,\"message\":\"planOrder invalide.\"}"); return; }

            string code          = (GetString(data, "code") ?? "").Trim().ToUpperInvariant();
            string libelle       = (GetString(data, "libelle") ?? "").Trim();
            string parentId      = GetString(data, "parentId");
            bool   actif         = GetBool(data, "active", true);
            bool   estAuxiliaire = GetBool(data, "estAuxiliaire", false);

            if (string.IsNullOrEmpty(code))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Le code est obligatoire.\"}"); return; }
            if (string.IsNullOrEmpty(libelle))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Le libellé est obligatoire.\"}"); return; }

            // ✅ C# 4.0 : variable nommée au lieu du discard `out _`
            Guid tmpGuid;
            bool isEdit = !string.IsNullOrEmpty(id) && Guid.TryParse(id, out tmpGuid);

            Guid tmpParent;
            Guid? parentGuid = null;
            if (!string.IsNullOrEmpty(parentId) && Guid.TryParse(parentId, out tmpParent))
                parentGuid = tmpParent;

            string tableName = AuthHelperPlan.GetPlanTableName(ordre);
            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            string finalId = isEdit ? id : Guid.NewGuid().ToString();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        // ─── Niveau max du plan ───
                        int maxNiveau;
                        using (var cmd = new SqlCommand(
                            "SELECT NIVEAU FROM FPLAN_HEADER WHERE ORDRE = @o", conn, tx))
                        {
                            cmd.Parameters.AddWithValue("@o", ordre);
                            object r = cmd.ExecuteScalar();
                            if (r == null) throw new Exception("Plan introuvable.");
                            maxNiveau = Convert.ToInt32(r);
                        }

                        // ─── Niveau de l'élément ───
                        int niveau = 1;
                        if (parentGuid.HasValue)
                        {
                            string sqlParent = "SELECT NIVEAU FROM " + tableName +
                                " WHERE ID = @pid AND DELETION_AT IS NULL";
                            using (var cmd = new SqlCommand(sqlParent, conn, tx))
                            {
                                cmd.Parameters.AddWithValue("@pid", parentGuid.Value);
                                object r = cmd.ExecuteScalar();
                                if (r == null) throw new Exception("Parent introuvable.");
                                niveau = Convert.ToInt32(r) + 1;
                            }
                        }

                        if (niveau > maxNiveau)
                            throw new Exception("Niveau maximum du plan (" + maxNiveau + ") dépassé.");

                        // ─── Nombre d'enfants (si édition) ───
                        int nbEnfants = 0;
                        if (isEdit)
                        {
                            string sqlCh = "SELECT COUNT(1) FROM " + tableName +
                                " WHERE PARENT_ID = @id AND DELETION_AT IS NULL";
                            using (var cmdCh = new SqlCommand(sqlCh, conn, tx))
                            {
                                cmdCh.Parameters.AddWithValue("@id", id);
                                nbEnfants = Convert.ToInt32(cmdCh.ExecuteScalar());
                            }
                        }

                        if (estAuxiliaire && nbEnfants > 0)
                            throw new Exception("Seuls les comptes de dernier niveau peuvent être marqués 'Auxiliaire'.");

                        // ─── Vérification tiers rattachés ───
                        if (isEdit && !estAuxiliaire)
                        {
                            using (var cmdTiers = new SqlCommand(@"
                                SELECT COUNT(1) FROM FTIERS
                                WHERE PLAN_ELEMENT_ID = @id AND PLAN_ORDER = @ordre AND DELETION_AT IS NULL", conn, tx))
                            {
                                cmdTiers.Parameters.AddWithValue("@id", id);
                                cmdTiers.Parameters.AddWithValue("@ordre", ordre);
                                int nbTiers = Convert.ToInt32(cmdTiers.ExecuteScalar());
                                if (nbTiers > 0)
                                    throw new Exception("Impossible de désactiver 'Auxiliaire' : "
                                            + nbTiers + " tiers sont rattachés à ce compte.");
                            }
                        }

                        // ─── Anti-doublon CODE ───
                        string sqlDup = "SELECT COUNT(1) FROM " + tableName +
                            " WHERE CODE = @code AND DELETION_AT IS NULL AND (@eid IS NULL OR ID <> @eid)";
                        using (var cmd = new SqlCommand(sqlDup, conn, tx))
                        {
                            cmd.Parameters.AddWithValue("@code", code);
                            cmd.Parameters.AddWithValue("@eid", isEdit ? (object)id : DBNull.Value);
                            if (Convert.ToInt32(cmd.ExecuteScalar()) > 0)
                                throw new Exception("Le code '" + code + "' existe déjà dans ce plan.");
                        }

                        // ─── ORDRE = max + 1 ───
                        string sqlOrdre = "SELECT ISNULL(MAX(ORDRE), 0) + 1 FROM " + tableName +
                            " WHERE NIVEAU = @niv AND DELETION_AT IS NULL";
                        int ordreElement = 0;
                        using (var cmd = new SqlCommand(sqlOrdre, conn, tx))
                        {
                            cmd.Parameters.AddWithValue("@niv", niveau);
                            ordreElement = Convert.ToInt32(cmd.ExecuteScalar());
                        }

                        if (isEdit)
                        {
                            string sqlUpdate = @"
                                UPDATE " + tableName + @"
                                SET CODE = @code,
                                    LIBELLE = @lib,
                                    PARENT_ID = @parent,
                                    NIVEAU = @niv,
                                    ACTIVE = @act,
                                    EST_AUXILIAIRE = @aux,
                                    UPDATED_BY = @uid,
                                    UPDATED_AT = GETDATE()
                                WHERE ID = @id AND DELETION_AT IS NULL";
                            using (var cmd = new SqlCommand(sqlUpdate, conn, tx))
                            {
                                cmd.Parameters.AddWithValue("@id", id);
                                cmd.Parameters.AddWithValue("@code", code);
                                cmd.Parameters.AddWithValue("@lib", libelle);
                                cmd.Parameters.AddWithValue("@parent", (object)parentGuid ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@niv", niveau);
                                cmd.Parameters.AddWithValue("@act", actif ? 1 : 0);
                                cmd.Parameters.AddWithValue("@aux", estAuxiliaire ? 1 : 0);
                                cmd.Parameters.AddWithValue("@uid", userId);
                                cmd.ExecuteNonQuery();
                            }
                        }
                        else
                        {
                            string sqlInsert = @"
                                INSERT INTO " + tableName + @"
                                    (ID, CODE, LIBELLE, PARENT_ID, NIVEAU, ORDRE,
                                     TYPE_ELEMENT, ACTIVE, EST_AUXILIAIRE,
                                     CREATED_BY, CREATED_AT)
                                VALUES
                                    (@id, @code, @lib, @parent, @niv, @ordre,
                                     'DETAIL', @act, @aux, @uid, GETDATE())";
                            using (var cmd = new SqlCommand(sqlInsert, conn, tx))
                            {
                                cmd.Parameters.AddWithValue("@id", finalId);
                                cmd.Parameters.AddWithValue("@code", code);
                                cmd.Parameters.AddWithValue("@lib", libelle);
                                cmd.Parameters.AddWithValue("@parent", (object)parentGuid ?? DBNull.Value);
                                cmd.Parameters.AddWithValue("@niv", niveau);
                                cmd.Parameters.AddWithValue("@ordre", ordreElement);
                                cmd.Parameters.AddWithValue("@act", actif ? 1 : 0);
                                cmd.Parameters.AddWithValue("@aux", estAuxiliaire ? 1 : 0);
                                cmd.Parameters.AddWithValue("@uid", userId);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        // ─── Parent devient RUBRIQUE ───
                        if (parentGuid.HasValue)
                        {
                            string sqlParentType = "UPDATE " + tableName +
                                " SET TYPE_ELEMENT = 'RUBRIQUE' WHERE ID = @pid";
                            using (var cmd = new SqlCommand(sqlParentType, conn, tx))
                            {
                                cmd.Parameters.AddWithValue("@pid", parentGuid.Value);
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

                // ─── Audit ───
                try
                {
                    string ip = ctx.Request.UserHostAddress ?? "";
                    using (var cmdLog = new SqlCommand(@"
                        INSERT INTO SECURITY_LOG (USER_ID, ACTION, DETAILS, IP_ADDRESS, CREATED_AT)
                        VALUES (@uid, @act, @det, @ip, GETDATE())", conn))
                    {
                        cmdLog.Parameters.AddWithValue("@uid", userId);
                        cmdLog.Parameters.AddWithValue("@act", isEdit ? "ELEMENT_EDIT" : "ELEMENT_ADD");
                        cmdLog.Parameters.AddWithValue("@det", "PLAN" + ordre + " / " + code + " - " + libelle);
                        cmdLog.Parameters.AddWithValue("@ip", ip);
                        cmdLog.ExecuteNonQuery();
                    }
                }
                catch { }
            }

            ctx.Response.Write(serializer.Serialize(new
            {
                success = true,
                id = finalId,
                message = isEdit ? "Élément modifié." : "Élément ajouté."
            }));
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
