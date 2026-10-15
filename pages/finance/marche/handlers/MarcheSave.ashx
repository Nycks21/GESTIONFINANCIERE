<%@ WebHandler Language="C#" Class="MarcheSave" %>
using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class MarcheSave : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireCsrfSafePost(ctx, -1))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }
        if (!AuthHelper.HasPermission("marche"))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Permission refusée\"}"); return; }

        try
        {
            string json = new System.IO.StreamReader(ctx.Request.InputStream).ReadToEnd();
            var serializer = new JavaScriptSerializer();
            var data = serializer.Deserialize<Dictionary<string, object>>(json);
            if (data == null) { ctx.Response.Write("{\"success\":false,\"message\":\"Corps invalide.\"}"); return; }

            string id              = GetString(data, "id");
            string siteId          = GetString(data, "siteId");
            string numero          = (GetString(data, "numero") ?? "").Trim();
            string description     = (GetString(data, "description") ?? "").Trim();
            string typeMarche      = (GetString(data, "typeMarche") ?? "FOURNITURES").Trim().ToUpperInvariant();
            string modePassation   = (GetString(data, "modePassation") ?? "APPEL_OFFRES_NATIONAL").Trim().ToUpperInvariant();
            string statut          = (GetString(data, "statut") ?? "ATTRIBUE").Trim().ToUpperInvariant();
            string fournisseurId   = GetString(data, "fournisseurId");
            string fournisseurNom  = (GetString(data, "fournisseurNom") ?? "").Trim();
            string dateLancement   = GetString(data, "dateLancement");
            string dateAttribution = GetString(data, "dateAttribution");
            string dateSignature   = GetString(data, "dateSignature");
            string dateDebut       = GetString(data, "dateDebut");
            string dateFin         = GetString(data, "dateFin");

            if (string.IsNullOrEmpty(numero))
            { ctx.Response.Write("{\"success\":false,\"message\":\"Numéro obligatoire.\"}"); return; }

            Guid tmp;
            Guid siteGuid = Guid.Empty;
            bool hasSite = !string.IsNullOrEmpty(siteId) && Guid.TryParse(siteId, out siteGuid);

            Guid fourGuid = Guid.Empty;
            bool hasFour = !string.IsNullOrEmpty(fournisseurId) && Guid.TryParse(fournisseurId, out fourGuid);

            decimal coursDevise = GetDecimal(data, "coursDevise", 0);

            var lignes = GetObjectList(data, "lignes");

            // Calcul des totaux
            decimal totalLocHT = 0, totalLocTVA = 0, totalLocTTC = 0;
            decimal totalDevHT = 0, totalDevTVA = 0, totalDevTTC = 0;

            var parsedLignes = new List<Dictionary<string, object>>();
            foreach (var l in lignes)
            {
                decimal taxe = GetDecimal(l, "taxe", 0);
                decimal locHT = GetDecimal(l, "montantLocHT", 0);
                decimal locTVA = Math.Round(locHT * taxe / 100m, 4);
                decimal locTTC = locHT + locTVA;

                decimal rapHT = GetDecimal(l, "montantRapHT", 0);
                decimal rapTVA = Math.Round(rapHT * taxe / 100m, 4);
                decimal rapTTC = rapHT + rapTVA;

                totalLocHT += locHT; totalLocTVA += locTVA; totalLocTTC += locTTC;
                totalDevHT += rapHT; totalDevTVA += rapTVA; totalDevTTC += rapTTC;

                var pl = new Dictionary<string, object>();
                pl["ID"] = GetString(l, "id");
                pl["ARTICLE_ID"] = GetString(l, "articleId");
                pl["DESIGNATION"] = GetString(l, "designation");
                pl["REFERENCE_LIGNE"] = GetString(l, "referenceLigne");
                pl["EXERCICE_ID"] = GetString(l, "exerciceId");
                pl["DESCRIPTION"] = GetString(l, "description");
                pl["TAXE"] = taxe;
                pl["MONTANT_LOC_HT"] = locHT;
                pl["MONTANT_LOC_TVA"] = locTVA;
                pl["MONTANT_LOC_TTC"] = locTTC;
                pl["MONTANT_RAP_HT"] = rapHT;
                pl["MONTANT_RAP_TVA"] = rapTVA;
                pl["MONTANT_RAP_TTC"] = rapTTC;
                pl["OBSERVATIONS"] = GetString(l, "observations");

                for (int k = 1; k <= 10; k++)
                {
                    string plVal = GetString(l, "plan" + k);
                    if (!string.IsNullOrEmpty(plVal) && Guid.TryParse(plVal, out tmp))
                        pl["PLAN" + k] = tmp;
                    else
                        pl["PLAN" + k] = null;
                }
                pl["SOURCE_FINANCEMENT"] = GetString(l, "sourceFinancement");

                parsedLignes.Add(pl);
            }

            int userId = AuthHelper.GetUserId(ctx);
            string connStr = AuthHelper.ConnectionString;
            bool isEdit = !string.IsNullOrEmpty(id) && Guid.TryParse(id, out tmp);
            string finalId = isEdit ? id : Guid.NewGuid().ToString();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();
                using (var tx = conn.BeginTransaction())
                {
                    try
                    {
                        // Vérif unicité numéro
                        using (var cmdChk = new SqlCommand(@"
                            SELECT COUNT(1) FROM FMARCHE
                            WHERE NUMERO = @n AND (@id IS NULL OR ID <> @id)", conn, tx))
                        {
                            cmdChk.Parameters.AddWithValue("@n", numero);
                            cmdChk.Parameters.AddWithValue("@id", isEdit ? (object)id : DBNull.Value);
                            if (Convert.ToInt32(cmdChk.ExecuteScalar()) > 0)
                                throw new Exception("Ce numéro de marché existe déjà.");
                        }

                        if (isEdit)
                        {
                            using (var cmd = new SqlCommand(@"
                                UPDATE FMARCHE SET
                                    SITE_ID=@site, NUMERO=@n, DESCRIPTION=@desc, COURS_DEVISE=@cours,
                                    TYPE_MARCHE=@tm, MODE_PASSATION=@mp, STATUT=@st,
                                    DATE_LANCEMENT=@dl, DATE_ATTRIBUTION=@da, DATE_SIGNATURE=@ds,
                                    DATE_DEBUT=@dd, DATE_FIN=@df,
                                    FOURNISSEUR_ID=@fourId, FOURNISSEUR_NOM=@fourNom,
                                    MONTANT_LOC_HT=@tlh, MONTANT_LOC_TVA=@tlt, MONTANT_LOC_TTC=@ltt,
                                    MONTANT_DEV_HT=@tdh, MONTANT_DEV_TVA=@tdt, MONTANT_DEV_TTC=@dtt,
                                    UPDATED_BY=@u, UPDATED_AT=GETDATE()
                                WHERE ID=@id", conn, tx))
                            {
                                AddHeaderParams(cmd, siteGuid, hasSite, numero, description, coursDevise,
                                    typeMarche, modePassation, statut, dateLancement, dateAttribution,
                                    dateSignature, dateDebut, dateFin, fourGuid, hasFour, fournisseurNom,
                                    totalLocHT, totalLocTVA, totalLocTTC, totalDevHT, totalDevTVA, totalDevTTC, userId);
                                cmd.Parameters.AddWithValue("@id", id);
                                cmd.ExecuteNonQuery();
                            }

                            using (var cmdDel = new SqlCommand(
                                "UPDATE FMARCHE_LIGNE SET DELETION_AT = GETDATE(), DELETION_BY = @u WHERE MARCHE_ID = @id", conn, tx))
                            {
                                cmdDel.Parameters.AddWithValue("@id", id);
                                cmdDel.Parameters.AddWithValue("@u", userId);
                                cmdDel.ExecuteNonQuery();
                            }
                        }
                        else
                        {
                            using (var cmd = new SqlCommand(@"
                                INSERT INTO FMARCHE
                                    (ID, SITE_ID, NUMERO, DESCRIPTION, COURS_DEVISE,
                                     TYPE_MARCHE, MODE_PASSATION, STATUT,
                                     DATE_LANCEMENT, DATE_ATTRIBUTION, DATE_SIGNATURE,
                                     DATE_DEBUT, DATE_FIN,
                                     FOURNISSEUR_ID, FOURNISSEUR_NOM,
                                     MONTANT_LOC_HT, MONTANT_LOC_TVA, MONTANT_LOC_TTC,
                                     MONTANT_DEV_HT, MONTANT_DEV_TVA, MONTANT_DEV_TTC,
                                     CREATED_BY, CREATED_AT)
                                VALUES
                                    (@id, @site, @n, @desc, @cours,
                                     @tm, @mp, @st,
                                     @dl, @da, @ds,
                                     @dd, @df,
                                     @fourId, @fourNom,
                                     @tlh, @tlt, @ltt,
                                     @tdh, @tdt, @dtt,
                                     @u, GETDATE())", conn, tx))
                            {
                                AddHeaderParams(cmd, siteGuid, hasSite, numero, description, coursDevise,
                                    typeMarche, modePassation, statut, dateLancement, dateAttribution,
                                    dateSignature, dateDebut, dateFin, fourGuid, hasFour, fournisseurNom,
                                    totalLocHT, totalLocTVA, totalLocTTC, totalDevHT, totalDevTVA, totalDevTTC, userId);
                                cmd.Parameters.AddWithValue("@id", finalId);
                                cmd.ExecuteNonQuery();
                            }
                        }

                        // Insertion des lignes
                        int ordre = 1;
                        foreach (var l in parsedLignes)
                        {
                            using (var cmd = new SqlCommand(@"
                                INSERT INTO FMARCHE_LIGNE
                                    (ID, MARCHE_ID, ORDRE, ARTICLE_ID, DESIGNATION, REFERENCE_LIGNE,
                                     EXERCICE_ID, DESCRIPTION, TAXE,
                                     MONTANT_LOC_HT, MONTANT_LOC_TVA, MONTANT_LOC_TTC,
                                     MONTANT_RAP_HT, MONTANT_RAP_TVA, MONTANT_RAP_TTC,
                                     PLAN1, PLAN2, PLAN3, PLAN4, PLAN5, PLAN6, PLAN7, PLAN8, PLAN9, PLAN10,
                                     SOURCE_FINANCEMENT, OBSERVATIONS, CREATED_BY, CREATED_AT)
                                VALUES
                                    (@id, @mid, @o, @aid, @des, @ref,
                                     @exid, @desc, @taxe,
                                     @lh, @lt, @ltt,
                                     @rh, @rt, @rtt,
                                     @p1, @p2, @p3, @p4, @p5, @p6, @p7, @p8, @p9, @p10,
                                     @src, @obs, @u, GETDATE())", conn, tx))
                            {
                                cmd.Parameters.AddWithValue("@id", Guid.NewGuid().ToString());
                                cmd.Parameters.AddWithValue("@mid", finalId);
                                cmd.Parameters.AddWithValue("@o", ordre++);
                                cmd.Parameters.AddWithValue("@aid", string.IsNullOrEmpty((string)l["ARTICLE_ID"]) ? (object)DBNull.Value : l["ARTICLE_ID"]);
                                cmd.Parameters.AddWithValue("@des", l["DESIGNATION"]);
                                cmd.Parameters.AddWithValue("@ref", string.IsNullOrEmpty((string)l["REFERENCE_LIGNE"]) ? (object)DBNull.Value : l["REFERENCE_LIGNE"]);
                                cmd.Parameters.AddWithValue("@exid", string.IsNullOrEmpty((string)l["EXERCICE_ID"]) ? (object)DBNull.Value : l["EXERCICE_ID"]);
                                cmd.Parameters.AddWithValue("@desc", string.IsNullOrEmpty((string)l["DESCRIPTION"]) ? (object)DBNull.Value : l["DESCRIPTION"]);
                                cmd.Parameters.AddWithValue("@taxe", l["TAXE"]);
                                cmd.Parameters.AddWithValue("@lh", l["MONTANT_LOC_HT"]);
                                cmd.Parameters.AddWithValue("@lt", l["MONTANT_LOC_TVA"]);
                                cmd.Parameters.AddWithValue("@ltt", l["MONTANT_LOC_TTC"]);
                                cmd.Parameters.AddWithValue("@rh", l["MONTANT_RAP_HT"]);
                                cmd.Parameters.AddWithValue("@rt", l["MONTANT_RAP_TVA"]);
                                cmd.Parameters.AddWithValue("@rtt", l["MONTANT_RAP_TTC"]);
                                cmd.Parameters.AddWithValue("@p1",  l["PLAN1"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p2",  l["PLAN2"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p3",  l["PLAN3"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p4",  l["PLAN4"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p5",  l["PLAN5"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p6",  l["PLAN6"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p7",  l["PLAN7"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p8",  l["PLAN8"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p9",  l["PLAN9"]  ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@p10", l["PLAN10"] ?? (object)DBNull.Value);
                                cmd.Parameters.AddWithValue("@src", string.IsNullOrEmpty((string)l["SOURCE_FINANCEMENT"]) ? (object)DBNull.Value : l["SOURCE_FINANCEMENT"]);
                                cmd.Parameters.AddWithValue("@obs", string.IsNullOrEmpty((string)l["OBSERVATIONS"]) ? (object)DBNull.Value : l["OBSERVATIONS"]);
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

            ctx.Response.Write(serializer.Serialize(new
            {
                success = true,
                id = finalId,
                message = isEdit ? "Marché modifié." : "Marché créé."
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

    private void AddHeaderParams(SqlCommand cmd, Guid siteGuid, bool hasSite,
        string numero, string description, decimal coursDevise,
        string typeMarche, string modePassation, string statut,
        string dateLancement, string dateAttribution, string dateSignature,
        string dateDebut, string dateFin,
        Guid fourGuid, bool hasFour, string fournisseurNom,
        decimal tlh, decimal tlt, decimal ltt,
        decimal tdh, decimal tdt, decimal dtt, int userId)
    {
        cmd.Parameters.AddWithValue("@site", hasSite ? (object)siteGuid : DBNull.Value);
        cmd.Parameters.AddWithValue("@n", numero);
        cmd.Parameters.AddWithValue("@desc", string.IsNullOrEmpty(description) ? (object)DBNull.Value : description);
        cmd.Parameters.AddWithValue("@cours", coursDevise);
        cmd.Parameters.AddWithValue("@tm", typeMarche);
        cmd.Parameters.AddWithValue("@mp", modePassation);
        cmd.Parameters.AddWithValue("@st", statut);
        cmd.Parameters.AddWithValue("@dl", string.IsNullOrEmpty(dateLancement) ? (object)DBNull.Value : DateTime.Parse(dateLancement));
        cmd.Parameters.AddWithValue("@da", string.IsNullOrEmpty(dateAttribution) ? (object)DBNull.Value : DateTime.Parse(dateAttribution));
        cmd.Parameters.AddWithValue("@ds", string.IsNullOrEmpty(dateSignature) ? (object)DBNull.Value : DateTime.Parse(dateSignature));
        cmd.Parameters.AddWithValue("@dd", string.IsNullOrEmpty(dateDebut) ? (object)DBNull.Value : DateTime.Parse(dateDebut));
        cmd.Parameters.AddWithValue("@df", string.IsNullOrEmpty(dateFin) ? (object)DBNull.Value : DateTime.Parse(dateFin));
        cmd.Parameters.AddWithValue("@fourId", hasFour ? (object)fourGuid : DBNull.Value);
        cmd.Parameters.AddWithValue("@fourNom", string.IsNullOrEmpty(fournisseurNom) ? (object)DBNull.Value : fournisseurNom);
        cmd.Parameters.AddWithValue("@tlh", tlh); cmd.Parameters.AddWithValue("@tlt", tlt); cmd.Parameters.AddWithValue("@ltt", ltt);
        cmd.Parameters.AddWithValue("@tdh", tdh); cmd.Parameters.AddWithValue("@tdt", tdt); cmd.Parameters.AddWithValue("@dtt", dtt);
        cmd.Parameters.AddWithValue("@u", userId);
    }

    private string GetString(Dictionary<string, object> data, string key)
    { return data.ContainsKey(key) && data[key] != null ? data[key].ToString() : null; }
    private decimal GetDecimal(Dictionary<string, object> data, string key, decimal def)
    {
        decimal v;
        if (data.ContainsKey(key) && data[key] != null &&
            decimal.TryParse(data[key].ToString(), System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture, out v)) return v;
        return def;
    }
    private List<Dictionary<string, object>> GetObjectList(Dictionary<string, object> data, string key)
    {
        var result = new List<Dictionary<string, object>>();
        if (!data.ContainsKey(key) || data[key] == null) return result;
        var arr = data[key] as IList;
        if (arr == null) return result;
        foreach (var item in arr)
        {
            var dict = item as Dictionary<string, object>;
            if (dict != null) result.Add(dict);
        }
        return result;
    }

    public bool IsReusable { get { return false; } }
}
