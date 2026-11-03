using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Web.Script.Serialization;

public partial class EcrituresOD : System.Web.UI.Page
{
    protected void Page_Load(object sender, EventArgs e)
    {
        Response.ContentType = "application/json";
        try
        {
            string action = Request.QueryString["action"] ?? "";
            if (action == "listUnpaid")
            {
                var rows = ListUnpaid(
                    Request.QueryString["compteId"],
                    Request.QueryString["auxiliaireId"]);
                Response.Write(new JavaScriptSerializer().Serialize(
                    new { success = true, rows = rows }));
            }
            else
            {
                Response.Write(new JavaScriptSerializer().Serialize(
                    new { success = false, message = "action inconnue" }));
            }
        }
        catch (Exception ex)
        {
            Response.Write(new JavaScriptSerializer().Serialize(
                new { success = false, message = ex.Message }));
        }
    }

    private List<Dictionary<string, object>> ListUnpaid(string compteId, string auxiliaireId)
    {
        var rows = new List<Dictionary<string, object>>();
        if (string.IsNullOrEmpty(compteId) || string.IsNullOrEmpty(auxiliaireId))
            return rows;

        // ⚠️ À ADAPTER à votre schéma réel (noms de tables/colonnes)
        // Hypothèse : ECRITURES, ECRITURES_LIGNES, JOURNAUX, LETTRAGE
        string sql = @"
SELECT
    l.ID            AS LIGNE_ID,
    l.ECRITURE_ID   AS ECRITURE_ID,
    e.DATE_PIECE    AS DATE_PIECE,
    e.NUMERO        AS NUMERO,
    e.REFERENCE     AS REFERENCE,
    j.CODE          AS JOURNAL_CODE,
    c.CODE          AS COMPTE_CODE,
    l.AUXILIAIRE    AS AUXILIAIRE,
    l.LIBELLE       AS LIBELLE,
    ISNULL(l.DEBIT,0)  AS DEBIT,
    ISNULL(l.CREDIT,0) AS CREDIT,
    CASE WHEN ISNULL(l.DEBIT,0) > 0 THEN 'D' ELSE 'C' END AS SENS,
    CASE WHEN ISNULL(l.DEBIT,0) > 0 THEN l.DEBIT ELSE l.CREDIT END AS MONTANT_INIT,
    ISNULL((SELECT SUM(LT.MONTANT) FROM LETTRAGE LT WHERE LT.LIGNE_ID = l.ID),0) AS REGLE,
    (CASE WHEN ISNULL(l.DEBIT,0) > 0 THEN l.DEBIT ELSE l.CREDIT END)
      - ISNULL((SELECT SUM(LT.MONTANT) FROM LETTRAGE LT WHERE LT.LIGNE_ID = l.ID),0)
      AS SOLDE_RESTANT
FROM ECRITURES_LIGNES l
INNER JOIN ECRITURES e ON e.ID = l.ECRITURE_ID
INNER JOIN JOURNAUX  j ON j.ID = e.JOURNAL_ID
INNER JOIN COMPTES   c ON c.ID = l.PLAN1
WHERE j.CATEGORIE_JOURNAL = 1         -- ⭐ journaux OD uniquement
  AND l.PLAN1 = @compteId
  AND l.AUXILIAIRE = @auxiliaireId
  AND (CASE WHEN ISNULL(l.DEBIT,0) > 0 THEN l.DEBIT ELSE l.CREDIT END)
      > ISNULL((SELECT SUM(LT.MONTANT) FROM LETTRAGE LT WHERE LT.LIGNE_ID = l.ID),0)
ORDER BY e.DATE_PIECE DESC, e.NUMERO DESC";

        using (var cn = new SqlConnection(System.Configuration.ConfigurationManager
                    .ConnectionStrings["DefaultConnection"].ConnectionString))
        using (var cmd = new SqlCommand(sql, cn))
        {
            cmd.Parameters.AddWithValue("@compteId", compteId);
            cmd.Parameters.AddWithValue("@auxiliaireId", auxiliaireId);
            cn.Open();
            using (var rd = cmd.ExecuteReader())
            {
                while (rd.Read())
                {
                    var d = new Dictionary<string, object>();
                    for (int i = 0; i < rd.FieldCount; i++)
                        d[rd.GetName(i)] = rd.IsDBNull(i) ? null : rd.GetValue(i);
                    rows.Add(d);
                }
            }
        }
        return rows;
    }
}
