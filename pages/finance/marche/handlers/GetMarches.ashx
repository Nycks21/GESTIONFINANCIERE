<%@ WebHandler Language="C#" Class="GetMarches" %>
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.SessionState;

public class GetMarches : IHttpHandler, IRequiresSessionState
{
    public void ProcessRequest(HttpContext ctx)
    {
        ctx.Response.ContentType = "application/json";
        ctx.Response.Charset = "utf-8";
        ctx.Response.Cache.SetNoStore();

        if (!AuthHelper.RequireApiPermission(ctx, "marche"))
        { ctx.Response.StatusCode = 403; ctx.Response.Write("{\"success\":false,\"message\":\"Accès non autorisé\"}"); return; }

        try
        {
            int page = 1, pageSize = 20;
            int.TryParse(ctx.Request.QueryString["page"], out page);
            int.TryParse(ctx.Request.QueryString["pageSize"], out pageSize);
            if (page < 1) page = 1;
            if (pageSize <= 0 || pageSize > 200) pageSize = 20;

            string search     = (ctx.Request.QueryString["search"] ?? "").Trim();
            string statut     = (ctx.Request.QueryString["statut"] ?? "").Trim();
            string typeMarche = (ctx.Request.QueryString["typeMarche"] ?? "").Trim();

            string connStr = AuthHelper.ConnectionString;
            var marches = new List<Dictionary<string, object>>();
            int total = 0;

            using (SqlConnection conn = new SqlConnection(connStr))
            {
                conn.Open();

                string whereClause = " WHERE m.DELETION_AT IS NULL ";
                var parameters = new List<SqlParameter>();

                if (!string.IsNullOrEmpty(search))
                {
                    whereClause += " AND (m.NUMERO LIKE @search OR m.DESCRIPTION LIKE @search) ";
                    parameters.Add(new SqlParameter("@search", "%" + search + "%"));
                }
                if (!string.IsNullOrEmpty(statut))
                {
                    whereClause += " AND m.STATUT = @statut ";
                    parameters.Add(new SqlParameter("@statut", statut));
                }
                if (!string.IsNullOrEmpty(typeMarche))
                {
                    whereClause += " AND m.TYPE_MARCHE = @typeMarche ";
                    parameters.Add(new SqlParameter("@typeMarche", typeMarche));
                }

                // COUNT
                using (SqlCommand cmd = new SqlCommand("SELECT COUNT(*) FROM FMARCHE m " + whereClause, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());
                    object scalar = cmd.ExecuteScalar();
                    total = (scalar == null || scalar == DBNull.Value) ? 0 : Convert.ToInt32(scalar);
                }

                // SELECT
                string sql = @"
                    SELECT
                        m.ID, m.NUMERO, m.DESCRIPTION, m.COURS_DEVISE,
                        m.TYPE_MARCHE, m.MODE_PASSATION, m.STATUT,
                        m.DATE_LANCEMENT, m.DATE_SIGNATURE, m.DATE_DEBUT, m.DATE_FIN,
                        m.MONTANT_LOC_HT, m.MONTANT_LOC_TVA, m.MONTANT_LOC_TTC,
                        m.MONTANT_DEV_HT, m.MONTANT_DEV_TVA, m.MONTANT_DEV_TTC,
                        m.FOURNISSEUR_ID, m.FOURNISSEUR_NOM,
                        s.CODE AS SITE_CODE, s.NOM AS SITE_NOM
                    FROM FMARCHE m
                    LEFT JOIN FSITE s ON s.ID = m.SITE_ID
                    " + whereClause + @"
                    ORDER BY m.DATE_SIGNATURE DESC, m.CREATED_AT DESC
                    OFFSET @offset ROWS FETCH NEXT @pageSize ROWS ONLY";

                using (SqlCommand cmd = new SqlCommand(sql, conn))
                {
                    cmd.Parameters.AddRange(parameters.ToArray());
                    cmd.Parameters.AddWithValue("@offset", (page - 1) * pageSize);
                    cmd.Parameters.AddWithValue("@pageSize", pageSize);

                    using (SqlDataReader r = cmd.ExecuteReader())
                    {
                        while (r.Read())
                        {
                            var d = new Dictionary<string, object>();
                            d["ID"]              = r["ID"].ToString();
                            d["NUMERO"]          = r["NUMERO"].ToString();
                            d["DESCRIPTION"]     = r["DESCRIPTION"] == DBNull.Value ? "" : r["DESCRIPTION"].ToString();
                            d["COURS_DEVISE"]    = r["COURS_DEVISE"] == DBNull.Value ? 0m : Convert.ToDecimal(r["COURS_DEVISE"]);
                            d["TYPE_MARCHE"]     = r["TYPE_MARCHE"].ToString();
                            d["MODE_PASSATION"]  = r["MODE_PASSATION"].ToString();
                            d["STATUT"]          = r["STATUT"].ToString();
                            d["DATE_LANCEMENT"]  = r["DATE_LANCEMENT"]  == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_LANCEMENT"]).ToString("yyyy-MM-dd");
                            d["DATE_SIGNATURE"]  = r["DATE_SIGNATURE"]  == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_SIGNATURE"]).ToString("yyyy-MM-dd");
                            d["DATE_DEBUT"]      = r["DATE_DEBUT"]      == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_DEBUT"]).ToString("yyyy-MM-dd");
                            d["DATE_FIN"]        = r["DATE_FIN"]        == DBNull.Value ? "" : Convert.ToDateTime(r["DATE_FIN"]).ToString("yyyy-MM-dd");
                            d["MONTANT_LOC_HT"]  = Convert.ToDecimal(r["MONTANT_LOC_HT"]);
                            d["MONTANT_LOC_TVA"] = Convert.ToDecimal(r["MONTANT_LOC_TVA"]);
                            d["MONTANT_LOC_TTC"] = Convert.ToDecimal(r["MONTANT_LOC_TTC"]);
                            d["MONTANT_DEV_HT"]  = Convert.ToDecimal(r["MONTANT_DEV_HT"]);
                            d["MONTANT_DEV_TVA"] = Convert.ToDecimal(r["MONTANT_DEV_TVA"]);
                            d["MONTANT_DEV_TTC"] = Convert.ToDecimal(r["MONTANT_DEV_TTC"]);
                            d["FOURNISSEUR_ID"]  = r["FOURNISSEUR_ID"]  == DBNull.Value ? null : r["FOURNISSEUR_ID"].ToString();
                            d["FOURNISSEUR_NOM"] = r["FOURNISSEUR_NOM"] == DBNull.Value ? "" : r["FOURNISSEUR_NOM"].ToString();
                            d["SITE_CODE"]       = r["SITE_CODE"]       == DBNull.Value ? "" : r["SITE_CODE"].ToString();
                            d["SITE_NOM"]        = r["SITE_NOM"]        == DBNull.Value ? "" : r["SITE_NOM"].ToString();
                            marches.Add(d);
                        }
                    }
                }
            }

            int totalPages = (int)Math.Ceiling((double)total / pageSize);
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            {
                success = true, marches = marches,
                total = total, totalPages = totalPages,
                page = page, pageSize = pageSize
            }));
        }
        catch (Exception ex)
        {
            ctx.Response.StatusCode = 500;
            ctx.Response.Write(new JavaScriptSerializer().Serialize(new
            { success = false, message = ex.Message }));
        }
    }

    public bool IsReusable { get { return false; } }
}
