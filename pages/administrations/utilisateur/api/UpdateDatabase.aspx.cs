using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Text;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.UI;

public partial class UpdateDatabase : Page
{
    // ═══════════════════════════════════════════════════════════════
    // LISTE DES MIGRATIONS
    // ─────────────────────────────────────────────────────────────
    // Conventions :
    //   • VERSION unique et séquentielle (001, 002, ..., 006, 007, ...)
    //   • IDEMPOTENTE : IF NOT EXISTS partout
    //   • Ne supprime JAMAIS de données (pas de DROP / DELETE / TRUNCATE)
    //   • Immuable une fois appliquée en production
    //   • Utilise EXEC('...') si ALTER + UPDATE dans le même batch
    //
    // ⚠️  Les migrations 002 à 005 reflètent des modifications déjà
    //     présentes dans BDDSQLCONSO.sql (base neuve).
    //     Elles sont conservées pour migrer d'anciennes bases.
    //
    // 📌  Les futures migrations commencent à 006.
    // ═══════════════════════════════════════════════════════════════
    private static readonly List<Migration> Migrations = new List<Migration>
    {
        // ───────────────────────────────────────────────────────────
        // 001 — Table de suivi des migrations (INDISPENSABLE)
        // ───────────────────────────────────────────────────────────
        new Migration("001", "Table de suivi _SCHEMA_MIGRATIONS", @"
            IF OBJECT_ID('dbo._SCHEMA_MIGRATIONS', 'U') IS NULL
            CREATE TABLE dbo._SCHEMA_MIGRATIONS (
                ID           INT IDENTITY(1,1) PRIMARY KEY,
                VERSION      VARCHAR(20)   NOT NULL UNIQUE,
                DESCRIPTION  NVARCHAR(500) NULL,
                APPLIED_AT   DATETIME      NOT NULL DEFAULT GETDATE(),
                APPLIED_BY   INT           NULL
            );
        "),

        // ───────────────────────────────────────────────────────────
        // 002 — FECRITURE : ref. facture + date facture
        //       (déjà dans BDDSQLCONSO.sql — skip sur base neuve)
        // ───────────────────────────────────────────────────────────
        new Migration("002", "FECRITURE : REFERENCE_FACTURE + DATE_FACTURE", @"
            IF NOT EXISTS (SELECT 1 FROM sys.columns
                            WHERE object_id = OBJECT_ID('dbo.FECRITURE')
                              AND name = 'REFERENCE_FACTURE')
                ALTER TABLE dbo.FECRITURE ADD REFERENCE_FACTURE VARCHAR(100) NULL;

            IF NOT EXISTS (SELECT 1 FROM sys.columns
                            WHERE object_id = OBJECT_ID('dbo.FECRITURE')
                              AND name = 'DATE_FACTURE')
                ALTER TABLE dbo.FECRITURE ADD DATE_FACTURE DATE NULL;
        "),

        // ───────────────────────────────────────────────────────────
        // 003 — FMARCHE : colonne AUXILIAIRE
        //       (déjà dans BDDSQLCONSO.sql — skip sur base neuve)
        // ───────────────────────────────────────────────────────────
        new Migration("003", "FMARCHE : colonne AUXILIAIRE", @"
            IF OBJECT_ID('dbo.FMARCHE', 'U') IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM sys.columns
                                WHERE object_id = OBJECT_ID('dbo.FMARCHE')
                                  AND name = 'AUXILIAIRE')
                ALTER TABLE dbo.FMARCHE ADD AUXILIAIRE NVARCHAR(50) NULL;

            IF OBJECT_ID('dbo.FMARCHE', 'U') IS NOT NULL
               AND NOT EXISTS (SELECT 1 FROM sys.indexes
                                WHERE name = 'IX_FMARCHE_AUXILIAIRE'
                                  AND object_id = OBJECT_ID('dbo.FMARCHE'))
                CREATE INDEX IX_FMARCHE_AUXILIAIRE
                    ON dbo.FMARCHE(AUXILIAIRE)
                    WHERE AUXILIAIRE IS NOT NULL AND DELETION_AT IS NULL;
        "),

        // ───────────────────────────────────────────────────────────
        // 004 — FMARCHE : STATUT VARCHAR → TINYINT (1-4)
        //       (déjà dans BDDSQLCONSO.sql — skip sur base neuve)
        //       ⭐ FIX : EXEC('...') pour éviter l'erreur de compilation
        //       « Nom de colonne non valide : 'STATUT_CODE' »
        // ───────────────────────────────────────────────────────────
        new Migration("004", "FMARCHE : STATUT en TINYINT (1-4)", @"
            IF OBJECT_ID('dbo.FMARCHE', 'U') IS NOT NULL
               AND EXISTS (SELECT 1 FROM sys.columns c
                            JOIN sys.types t ON t.user_type_id = c.user_type_id
                           WHERE c.object_id = OBJECT_ID('dbo.FMARCHE')
                             AND c.name = 'STATUT'
                             AND t.name = 'varchar')
            BEGIN
                -- 1. Supprimer l'ancienne contrainte CHECK
                IF EXISTS (SELECT 1 FROM sys.check_constraints
                            WHERE name = 'CK_FMARCHE_STATUT'
                              AND parent_object_id = OBJECT_ID('dbo.FMARCHE'))
                    EXEC('ALTER TABLE dbo.FMARCHE DROP CONSTRAINT CK_FMARCHE_STATUT');

                -- 2. Supprimer STATUT_CODE s'il existe (run partiel précédent)
                IF EXISTS (SELECT 1 FROM sys.columns
                            WHERE object_id = OBJECT_ID('dbo.FMARCHE')
                              AND name = 'STATUT_CODE')
                    EXEC('ALTER TABLE dbo.FMARCHE DROP COLUMN STATUT_CODE');

                -- 3. Créer la nouvelle colonne
                EXEC('ALTER TABLE dbo.FMARCHE ADD STATUT_CODE TINYINT NULL');

                -- 4. Copier les valeurs (⭐ EXEC = nouveau contexte de compilation)
                EXEC('
                    UPDATE dbo.FMARCHE
                       SET STATUT_CODE =
                           CASE STATUT
                               WHEN ''ATTRIBUE''     THEN 1
                               WHEN ''EN_EXECUTION'' THEN 1
                               WHEN ''TERMINE''      THEN 2
                               WHEN ''ANNULE''       THEN 3
                               WHEN ''RESILIE''      THEN 4
                               ELSE 1
                           END
                ');

                -- 5. Supprimer l'ancienne colonne
                EXEC('ALTER TABLE dbo.FMARCHE DROP COLUMN STATUT');

                -- 6. Renommer STATUT_CODE → STATUT
                EXEC sp_rename 'dbo.FMARCHE.STATUT_CODE', 'STATUT', 'COLUMN';

                -- 7. Rendre NOT NULL
                EXEC('ALTER TABLE dbo.FMARCHE ALTER COLUMN STATUT TINYINT NOT NULL');

                -- 8. Ajouter la valeur par défaut
                EXEC('ALTER TABLE dbo.FMARCHE ADD CONSTRAINT DF_FMARCHE_STATUT DEFAULT (1) FOR STATUT');

                -- 9. Ajouter la nouvelle contrainte CHECK
                EXEC('ALTER TABLE dbo.FMARCHE ADD CONSTRAINT CK_FMARCHE_STATUT
                        CHECK (STATUT IN (1, 2, 3, 4))');
            END
        "),

        // ───────────────────────────────────────────────────────────
        // 005 — FMARCHE : TYPE_MARCHE + MODE_PASSATION en VARCHAR(5)
        //       (déjà dans BDDSQLCONSO.sql — skip sur base neuve)
        //       ⭐ FIX : EXEC('...') pour éviter l'erreur de compilation
        // ───────────────────────────────────────────────────────────
        new Migration("005", "FMARCHE : codes courts TYPE_MARCHE + MODE_PASSATION", @"
            -- TYPE_MARCHE
            IF OBJECT_ID('dbo.FMARCHE', 'U') IS NOT NULL
               AND EXISTS (SELECT 1 FROM sys.columns c
                            JOIN sys.types t ON t.user_type_id = c.user_type_id
                           WHERE c.object_id = OBJECT_ID('dbo.FMARCHE')
                             AND c.name = 'TYPE_MARCHE'
                             AND t.name = 'varchar'
                             AND c.max_length > 5)
            BEGIN
                IF EXISTS (SELECT 1 FROM sys.check_constraints
                            WHERE name = 'CK_FMARCHE_TYPE'
                              AND parent_object_id = OBJECT_ID('dbo.FMARCHE'))
                    EXEC('ALTER TABLE dbo.FMARCHE DROP CONSTRAINT CK_FMARCHE_TYPE');

                EXEC('ALTER TABLE dbo.FMARCHE ALTER COLUMN TYPE_MARCHE VARCHAR(5) NOT NULL');

                EXEC('
                    UPDATE dbo.FMARCHE
                       SET TYPE_MARCHE =
                           CASE TYPE_MARCHE
                               WHEN ''FOURNITURES''                 THEN ''FRT''
                               WHEN ''TRAVAUX''                     THEN ''TRX''
                               WHEN ''SERVICES''                    THEN ''SRV''
                               WHEN ''PRESTATIONS_INTELLECTUELLES'' THEN ''PIS''
                               ELSE ''ATR''
                           END
                ');

                EXEC('ALTER TABLE dbo.FMARCHE ADD CONSTRAINT CK_FMARCHE_TYPE
                        CHECK (TYPE_MARCHE IN (''FRT'',''TRX'',''SRV'',''PIS'',''ATR''))');
            END

            -- MODE_PASSATION
            IF OBJECT_ID('dbo.FMARCHE', 'U') IS NOT NULL
               AND EXISTS (SELECT 1 FROM sys.columns c
                            JOIN sys.types t ON t.user_type_id = c.user_type_id
                           WHERE c.object_id = OBJECT_ID('dbo.FMARCHE')
                             AND c.name = 'MODE_PASSATION'
                             AND t.name = 'varchar'
                             AND c.max_length > 5)
            BEGIN
                IF EXISTS (SELECT 1 FROM sys.check_constraints
                            WHERE name = 'CK_FMARCHE_MODE'
                              AND parent_object_id = OBJECT_ID('dbo.FMARCHE'))
                    EXEC('ALTER TABLE dbo.FMARCHE DROP CONSTRAINT CK_FMARCHE_MODE');

                EXEC('ALTER TABLE dbo.FMARCHE ALTER COLUMN MODE_PASSATION VARCHAR(5) NOT NULL');

                EXEC('
                    UPDATE dbo.FMARCHE
                       SET MODE_PASSATION =
                           CASE MODE_PASSATION
                               WHEN ''APPEL_OFFRES_NATIONAL''      THEN ''AON''
                               WHEN ''APPEL_OFFRES_INTERNATIONAL'' THEN ''AOI''
                               WHEN ''CONSULTATION''               THEN ''CST''
                               WHEN ''GRE_A_GRE''                  THEN ''GAG''
                               WHEN ''ENTENTE_DIRECTE''            THEN ''EDT''
                               ELSE ''ATR''
                           END
                ');

                EXEC('ALTER TABLE dbo.FMARCHE ADD CONSTRAINT CK_FMARCHE_MODE
                        CHECK (MODE_PASSATION IN (''AON'',''AOI'',''CST'',''GAG'',''EDT'',''ATR''))');
            END
        "        ),
        new Migration("006", "FMARCHE : fournisseur rattaché à PLAN1", @"
            IF OBJECT_ID('dbo.FMARCHE', 'U') IS NOT NULL
            BEGIN
                IF OBJECT_ID('dbo.PLAN1', 'U') IS NULL
                   OR OBJECT_ID('dbo.SFOURNISSEUR', 'U') IS NULL
                    THROW 51000, 'Migration fournisseur impossible : PLAN1 ou SFOURNISSEUR est absent.', 1;

                IF EXISTS (
                    SELECT 1
                    FROM sys.columns c
                    INNER JOIN sys.types t ON t.user_type_id = c.user_type_id
                    WHERE c.object_id = OBJECT_ID('dbo.FMARCHE')
                      AND c.name = 'FOURNISSEUR_NOM'
                      AND t.name = 'nvarchar'
                      AND c.max_length < 500
                )
                    ALTER TABLE dbo.FMARCHE ALTER COLUMN FOURNISSEUR_NOM NVARCHAR(250) NULL;

                IF EXISTS (
                    SELECT 1
                    FROM dbo.FMARCHE m
                    WHERE m.FOURNISSEUR_ID IS NOT NULL
                      AND NOT EXISTS (
                          SELECT 1
                          FROM dbo.PLAN1 p
                          WHERE p.ID = m.FOURNISSEUR_ID
                            AND p.CODE LIKE '4%'
                            AND p.ACTIVE = 1
                            AND p.DELETION_AT IS NULL
                      )
                      AND NOT EXISTS (
                          SELECT 1
                          FROM dbo.SFOURNISSEUR s
                          INNER JOIN dbo.PLAN1 p ON p.ID = s.PLAN_ELEMENT_ID
                          WHERE s.ID = m.FOURNISSEUR_ID
                            AND p.CODE LIKE '4%'
                            AND p.ACTIVE = 1
                            AND p.DELETION_AT IS NULL
                      )
                )
                    THROW 51001, 'Migration fournisseur annulée : au moins un marché référence un fournisseur sans compte PLAN1 admissible. Aucune donnée n’a été modifiée.', 1;

                IF EXISTS (
                    SELECT 1
                    FROM sys.foreign_keys fk
                    WHERE fk.name = 'FK_FMARCHE_FOURNISSEUR'
                      AND fk.parent_object_id = OBJECT_ID('dbo.FMARCHE')
                      AND fk.referenced_object_id <> OBJECT_ID('dbo.PLAN1')
                )
                    ALTER TABLE dbo.FMARCHE DROP CONSTRAINT FK_FMARCHE_FOURNISSEUR;

                UPDATE m
                   SET FOURNISSEUR_ID = s.PLAN_ELEMENT_ID
                FROM dbo.FMARCHE m
                INNER JOIN dbo.SFOURNISSEUR s ON s.ID = m.FOURNISSEUR_ID
                INNER JOIN dbo.PLAN1 p ON p.ID = s.PLAN_ELEMENT_ID
                WHERE p.CODE LIKE '4%'
                  AND p.ACTIVE = 1
                  AND p.DELETION_AT IS NULL
                  AND NOT EXISTS (
                      SELECT 1
                      FROM dbo.PLAN1 currentAccount
                      WHERE currentAccount.ID = m.FOURNISSEUR_ID
                        AND currentAccount.CODE LIKE '4%'
                        AND currentAccount.ACTIVE = 1
                        AND currentAccount.DELETION_AT IS NULL
                  );

                UPDATE m
                   SET FOURNISSEUR_NOM = p.LIBELLE
                FROM dbo.FMARCHE m
                INNER JOIN dbo.PLAN1 p ON p.ID = m.FOURNISSEUR_ID
                WHERE (m.FOURNISSEUR_NOM IS NULL OR LTRIM(RTRIM(m.FOURNISSEUR_NOM)) = '')
                  AND p.CODE LIKE '4%'
                  AND p.ACTIVE = 1
                  AND p.DELETION_AT IS NULL;

                IF NOT EXISTS (
                    SELECT 1
                    FROM sys.foreign_keys fk
                    INNER JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
                    WHERE fk.name = 'FK_FMARCHE_FOURNISSEUR'
                      AND fk.parent_object_id = OBJECT_ID('dbo.FMARCHE')
                      AND fk.referenced_object_id = OBJECT_ID('dbo.PLAN1')
                      AND COL_NAME(fkc.parent_object_id, fkc.parent_column_id) = 'FOURNISSEUR_ID'
                      AND COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) = 'ID'
                )
                BEGIN
                    IF EXISTS (
                        SELECT 1
                        FROM sys.foreign_keys
                        WHERE name = 'FK_FMARCHE_FOURNISSEUR'
                          AND parent_object_id = OBJECT_ID('dbo.FMARCHE')
                    )
                        ALTER TABLE dbo.FMARCHE DROP CONSTRAINT FK_FMARCHE_FOURNISSEUR;

                    ALTER TABLE dbo.FMARCHE
                        ADD CONSTRAINT FK_FMARCHE_FOURNISSEUR
                        FOREIGN KEY (FOURNISSEUR_ID) REFERENCES dbo.PLAN1(ID);
                END
            END
        ")

        // ═══════════════════════════════════════════════════════════
        // 📌 FUTURES MIGRATIONS — Ajouter à partir de 007
        // ═══════════════════════════════════════════════════════════
        // Modèle à copier-coller :
        //
        // new Migration("007", "Description courte de la modif", @"
        //     IF NOT EXISTS (SELECT 1 FROM sys.columns
        //                     WHERE object_id = OBJECT_ID('dbo.MA_TABLE')
        //                       AND name = 'MA_COLONNE')
        //         ALTER TABLE dbo.MA_TABLE ADD MA_COLONNE VARCHAR(50) NULL;
        // "),
        //
        // new Migration("008", "Description autre modif", @"..."),
        //
        // ═══════════════════════════════════════════════════════════
    };

    // ═══════════════════════════════════════════════════════════════
    // TRAITEMENT DE LA REQUÊTE
    // ═══════════════════════════════════════════════════════════════
    protected void Page_Load(object sender, EventArgs e)
    {
        Response.ContentType = "application/json";
        Response.Charset = "utf-8";
        Response.Cache.SetNoStore();

        // ─── Sécurité : SuperAdmin uniquement ───
        if (!AuthHelper.IsSuperAdmin())
        {
            Response.StatusCode = 403;
            Response.Write("{\"success\":false,\"message\":\"Accès réservé au SuperAdmin.\"}");
            return;
        }

        try
        {
            int userId = AuthHelper.GetUserId(Context);
            string connStr = AuthHelper.ConnectionString;

            var applied = new List<Dictionary<string, object>>();
            var skipped = new List<Dictionary<string, object>>();
            var errors  = new List<Dictionary<string, object>>();

            using (var conn = new SqlConnection(connStr))
            {
                conn.Open();

                // 1) S'assure que la table de suivi existe
                EnsureMigrationsTable(conn);

                // 2) Récupère les versions déjà appliquées
                var already = GetAppliedVersions(conn);

                // 3) Applique chaque migration non exécutée
                foreach (var mig in Migrations)
                {
                    if (already.Contains(mig.Version))
                    {
                        skipped.Add(new Dictionary<string, object> {
                            { "version",     mig.Version },
                            { "description", mig.Description }
                        });
                        continue;
                    }

                    try
                    {
                        using (var tx = conn.BeginTransaction())
                        {
                            try
                            {
                                ExecuteSql(conn, tx, mig.Sql);

                                using (var cmd = new SqlCommand(@"
                                    INSERT INTO dbo._SCHEMA_MIGRATIONS
                                        (VERSION, DESCRIPTION, APPLIED_BY)
                                    VALUES (@v, @d, @u)", conn, tx))
                                {
                                    cmd.Parameters.AddWithValue("@v", mig.Version);
                                    cmd.Parameters.AddWithValue("@d", mig.Description);
                                    cmd.Parameters.AddWithValue("@u", userId);
                                    cmd.ExecuteNonQuery();
                                }

                                tx.Commit();

                                applied.Add(new Dictionary<string, object> {
                                    { "version",     mig.Version },
                                    { "description", mig.Description }
                                });
                            }
                            catch
                            {
                                try { tx.Rollback(); } catch { }
                                throw;
                            }
                        }
                    }
                    catch (Exception exMig)
                    {
                        errors.Add(new Dictionary<string, object> {
                            { "version",     mig.Version },
                            { "description", mig.Description },
                            { "error",       exMig.Message }
                        });
                        break;   // On arrête dès qu'une migration échoue
                    }
                }
            }

            var serializer = new JavaScriptSerializer();
            Response.Write(serializer.Serialize(new
            {
                success = errors.Count == 0,
                applied = applied,
                skipped = skipped,
                errors  = errors,
                message = errors.Count == 0
                    ? (applied.Count + " migration(s) appliquée(s), " + skipped.Count + " déjà à jour.")
                    : "Erreur lors de l'application des migrations."
            }));
        }
        catch (Exception ex)
        {
            Response.StatusCode = 500;
            Response.Write(new JavaScriptSerializer().Serialize(new
            { success = false, message = ex.Message }));
        }
    }

    // ─── Création de la table de suivi si absente ───
    private void EnsureMigrationsTable(SqlConnection conn)
    {
        using (var cmd = new SqlCommand(@"
            IF OBJECT_ID('dbo._SCHEMA_MIGRATIONS', 'U') IS NULL
            CREATE TABLE dbo._SCHEMA_MIGRATIONS (
                ID           INT IDENTITY(1,1) PRIMARY KEY,
                VERSION      VARCHAR(20)   NOT NULL UNIQUE,
                DESCRIPTION  NVARCHAR(500) NULL,
                APPLIED_AT   DATETIME      NOT NULL DEFAULT GETDATE(),
                APPLIED_BY   INT           NULL
            );", conn))
        {
            cmd.ExecuteNonQuery();
        }
    }

    // ─── Récupère les versions déjà appliquées ───
    private HashSet<string> GetAppliedVersions(SqlConnection conn)
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        using (var cmd = new SqlCommand("SELECT VERSION FROM dbo._SCHEMA_MIGRATIONS", conn))
        using (var r = cmd.ExecuteReader())
        {
            while (r.Read()) set.Add(r["VERSION"].ToString());
        }
        return set;
    }

    // ─── Exécute un script SQL multi-requêtes (séparateur GO) ───
    private void ExecuteSql(SqlConnection conn, SqlTransaction tx, string sql)
    {
        foreach (var batch in SplitOnGo(sql))
        {
            var trimmed = batch.Trim();
            if (string.IsNullOrEmpty(trimmed)) continue;

            using (var cmd = new SqlCommand(trimmed, conn, tx))
            {
                cmd.CommandTimeout = 120;
                cmd.ExecuteNonQuery();
            }
        }
    }

    private List<string> SplitOnGo(string sql)
    {
        var result = new List<string>();
        var lines = sql.Replace("\r\n", "\n").Split('\n');
        var current = new StringBuilder();

        foreach (var line in lines)
        {
            if (line.Trim().Equals("GO", StringComparison.OrdinalIgnoreCase))
            {
                result.Add(current.ToString());
                current.Clear();
            }
            else
            {
                current.AppendLine(line);
            }
        }
        if (current.Length > 0) result.Add(current.ToString());
        return result;
    }

    // ─── Classe interne ───
    private class Migration
    {
        public string Version     { get; private set; }
        public string Description { get; private set; }
        public string Sql         { get; private set; }

        public Migration(string version, string description, string sql)
        {
            Version     = version;
            Description = description;
            Sql         = sql;
        }
    }
}
