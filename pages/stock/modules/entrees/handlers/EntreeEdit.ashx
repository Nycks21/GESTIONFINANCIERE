﻿<%@ WebHandler Language="C#" Class="EntreeEdit" %>
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class EntreeEdit : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        {
            ctx.Response.StatusCode = 403;
            WriteJson(ctx, new { success = false, message = "Accès non autorisé" });
            return;
        }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);

            if (data == null)
            {
                WriteJson(ctx, new { success = false, message = "Corps de requête invalide." });
                return;
            }

            string id = GetString(data, "id");
            if (string.IsNullOrEmpty(id))
                throw new Exception("ID manquant");

            string dateEntreeStr = GetString(data, "dateEntree");
            DateTime dateEntree;
            if (string.IsNullOrEmpty(dateEntreeStr) || !DateTime.TryParse(dateEntreeStr, out dateEntree))
                dateEntree = DateTime.Now;

            string fournisseurId = GetString(data, "fournisseurId");
            if (string.IsNullOrEmpty(fournisseurId))
                throw new Exception("Fournisseur manquant");

            string reference = GetString(data, "reference") ?? "";
            string notes = GetString(data, "notes") ?? "";
            ArrayList lignes = data.ContainsKey("lignes")
                ? (ArrayList)data["lignes"] : new ArrayList();

            if (lignes.Count == 0)
                throw new Exception("Au moins une ligne d'article est requise.");

            if (!CanEdit(ctx, id))
                throw new Exception("Impossible de modifier un bon validé ou annulé.");

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var trans = conn.BeginTransaction())
                {
                    try
                    {
                        // ⭐ NOUVEAU : valider que le fournisseur existe bien dans FTIERS
                        using (var cmdFour = new SqlCommand(
                            @"SELECT COUNT(1) FROM FTIERS
                              WHERE ID = @id AND ACTIVE = 1 AND DELETION_AT IS NULL",
                            conn, trans))
                        {
                            cmdFour.Parameters.AddWithValue("@id", fournisseurId);
                            int existe = Convert.ToInt32(cmdFour.ExecuteScalar());
                            if (existe == 0)
                                throw new Exception("FOURNISSEUR_NOT_FOUND");
                        }

                        string sqlEntete = @"
                            UPDATE SENTREE SET DATE_ENTREE = @date, FOURNISSEUR_ID = @four,
                                REFERENCE = @ref, NOTES = @notes, UPDATED_BY = @userId, UPDATED_AT = GETDATE()
                            WHERE ID = @id AND STATUT = 'BROUILLON' AND DELETION_AT IS NULL";
                        using (var cmd = new SqlCommand(sqlEntete, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.Parameters.AddWithValue("@date", dateEntree);
                            cmd.Parameters.AddWithValue("@four", fournisseurId);
                            cmd.Parameters.AddWithValue("@ref", reference);
                            cmd.Parameters.AddWithValue("@notes", notes);
                            cmd.Parameters.AddWithValue("@userId", userId);
                            if (cmd.ExecuteNonQuery() != 1)
                                throw new Exception("Impossible de modifier un bon validé ou annulé.");
                        }

                        using (var cmd = new SqlCommand(
                            "DELETE FROM MLENTREE WHERE BON_ENTREE_ID = @id", conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.ExecuteNonQuery();
                        }

                        decimal totalHT = 0, totalTVA = 0, totalTTC = 0;
                        foreach (Dictionary<string, object> ligne in lignes)
                        {
                            if (ligne == null) continue;

                            string articleId = null;
                            if (ligne.ContainsKey("articleId") && ligne["articleId"] != null)
                                articleId = ligne["articleId"].ToString();
                            if (string.IsNullOrEmpty(articleId)) continue;

                            decimal quantite = 0, prixHT = 0, tva = 0;
                            if (ligne.ContainsKey("quantite") && ligne["quantite"] != null)
                                decimal.TryParse(ligne["quantite"].ToString(), out quantite);
                            if (ligne.ContainsKey("prixHT") && ligne["prixHT"] != null)
                                decimal.TryParse(ligne["prixHT"].ToString(), out prixHT);
                            if (ligne.ContainsKey("tva") && ligne["tva"] != null)
                                decimal.TryParse(ligne["tva"].ToString(), out tva);

                            if (quantite <= 0 || prixHT <= 0) continue;

                            decimal ht = quantite * prixHT;
                            decimal tvaAmount = ht * (tva / 100);
                            decimal ttc = ht + tvaAmount;

                            totalHT += ht;
                            totalTVA += tvaAmount;
                            totalTTC += ttc;

                            string sqlLigne = @"
                                INSERT INTO MLENTREE (ID, BON_ENTREE_ID, ARTICLE_ID, QUANTITE, PRIX_UNITAIRE_HT, TVA_TX, PRIX_UNITAIRE_TTC, TOTAL_HT, TOTAL_TVA, TOTAL_TTC)
                                VALUES (NEWID(), @bonId, @articleId, @qte, @prixHT, @tva, @prixTTC, @totalHT, @totalTVA, @totalTTC)";

                            using (var cmd = new SqlCommand(sqlLigne, conn, trans))
                            {
                                cmd.Parameters.AddWithValue("@bonId", id);
                                cmd.Parameters.AddWithValue("@articleId", articleId);
                                cmd.Parameters.AddWithValue("@qte", quantite);
                                cmd.Parameters.AddWithValue("@prixHT", prixHT);
                                cmd.Parameters.AddWithValue("@tva", tva);
                                cmd.Parameters.AddWithValue("@prixTTC", prixHT * (1 + tva / 100));
                                cmd.Parameters.AddWithValue("@totalHT", ht);
                                cmd.Parameters.AddWithValue("@totalTVA", tvaAmount);
                                cmd.Parameters.AddWithValue("@totalTTC", ttc);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        string sqlUpdateTotaux = @"
                            UPDATE SENTREE SET TOTAL_HT = @totalHT, TOTAL_TVA = @totalTVA, TOTAL_TTC = @totalTTC
                            WHERE ID = @id";
                        using (var cmd = new SqlCommand(sqlUpdateTotaux, conn, trans))
                        {
                            cmd.Parameters.AddWithValue("@totalHT", totalHT);
                            cmd.Parameters.AddWithValue("@totalTVA", totalTVA);
                            cmd.Parameters.AddWithValue("@totalTTC", totalTTC);
                            cmd.Parameters.AddWithValue("@id", id);
                            cmd.ExecuteNonQuery();
                        }

                        trans.Commit();
                        WriteJson(ctx, new { success = true, message = "Bon modifié avec succès." });
                    }
                    catch (SqlException sex)
                    {
                        try { trans.Rollback(); } catch { }
                        HandleSqlException(ctx, sex);
                    }
                    catch (Exception tex)
                    {
                        try { trans.Rollback(); } catch { }
                        if (tex.Message == "FOURNISSEUR_NOT_FOUND")
                        {
                            ctx.Response.StatusCode = 400;
                            WriteJson(ctx, new {
                                success = false,
                                message = "Le fournisseur sélectionné est introuvable dans FTIERS (ID : "
                                          + fournisseurId + "). Rechargez la page et réessayez."
                            });
                            return;
                        }
                        throw;
                    }
                }
            }
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            WriteJson(ctx, new { success = false, message = ex.Message.Replace("\"", "\\\"") });
        }
    }

    private bool CanEdit(HttpContext ctx, string bonId)
    {
        using (var conn = new SqlConnection(AuthHelper.ConnectionString))
        {
            conn.Open();
            using (var cmd = new SqlCommand(
                "SELECT STATUT FROM SENTREE WHERE ID = @id AND DELETION_AT IS NULL", conn))
            {
                cmd.Parameters.AddWithValue("@id", bonId);
                var statut = cmd.ExecuteScalar() as string;
                return statut == "BROUILLON";
            }
        }
    }

    private static void HandleSqlException(HttpContext ctx, SqlException sex)
    {
        ctx.Response.StatusCode = 400;
        string msg;
        switch (sex.Number)
        {
            case 547:
                msg = "Référence invalide : le fournisseur, l'article ou la ligne n'existe pas. "
                    + "Vérifiez que la FK SENTREE.FOURNISSEUR_ID pointe bien sur FTIERS.";
                break;
            case 245:
            case 8114:
                msg = "Format d'identifiant incompatible avec le schéma de la base.";
                break;
            default:
                msg = "Erreur SQL (" + sex.Number + ") : " + sex.Message;
                break;
        }
        WriteJson(ctx, new { success = false, message = msg, sqlError = sex.Number });
    }

    private static string GetString(Dictionary<string, object> data, string key)
    {
        return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null;
    }

    private static void WriteJson(HttpContext ctx, object obj)
    {
        var ser = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
        ctx.Response.Write(ser.Serialize(obj));
    }

    public bool IsReusable { get { return false; } }
}
