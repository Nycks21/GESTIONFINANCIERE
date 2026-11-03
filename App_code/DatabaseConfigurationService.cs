using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Net.Mail;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Configuration;

public sealed class DatabaseSetupResult
{
    public bool Success { get; private set; }
    public string Message { get; private set; }

    public DatabaseSetupResult(bool success, string message)
    {
        Success = success;
        Message = message;
    }
}

public static class DatabaseConfigurationService
{
    private static readonly Regex DatabaseNamePattern =
        new Regex(@"^[A-Za-z0-9_]{1,128}$", RegexOptions.CultureInvariant);

    public static string BuildConnectionString(string server, string instance, string database,
        bool integratedSecurity, string username, string password, bool encrypt,
        bool trustServerCertificate)
    {
        server = (server ?? String.Empty).Trim();
        instance = (instance ?? String.Empty).Trim();
        database = (database ?? String.Empty).Trim();

        if (server.Length == 0 || server.Length > 128 || server.IndexOf(';') >= 0 ||
            server.IndexOf('=') >= 0 || server.IndexOf('\r') >= 0 || server.IndexOf('\n') >= 0)
            throw new ArgumentException("Le nom du serveur SQL est invalide.");
        if (instance.Length > 128 || instance.IndexOfAny(new[] { '\\', '/', ';', '=' }) >= 0)
            throw new ArgumentException("Le nom de l'instance SQL est invalide.");
        if (!DatabaseNamePattern.IsMatch(database))
            throw new ArgumentException("Le nom de la base doit contenir uniquement des lettres, chiffres ou tirets bas.");
        if (!integratedSecurity && (String.IsNullOrWhiteSpace(username) || String.IsNullOrEmpty(password)))
            throw new ArgumentException("Le nom d'utilisateur et le mot de passe SQL sont requis.");
        if (username != null && username.Length > 128)
            throw new ArgumentException("Le nom d'utilisateur SQL est trop long.");
        if (password != null && password.Length > 128)
            throw new ArgumentException("Le mot de passe SQL est trop long.");

        SqlConnectionStringBuilder builder = new SqlConnectionStringBuilder();
        builder.DataSource = instance.Length == 0 ? server : server + "\\" + instance;
        builder.InitialCatalog = database;
        builder.IntegratedSecurity = integratedSecurity;
        builder.PersistSecurityInfo = false;
        builder.ConnectTimeout = 5;
        builder.Encrypt = encrypt;
        builder.TrustServerCertificate = trustServerCertificate;
        builder.ApplicationName = "GESTION FINANCIERE";
        if (!integratedSecurity)
        {
            builder.UserID = username.Trim();
            builder.Password = password;
        }
        return builder.ConnectionString;
    }

    public static DatabaseSetupResult TestConnection(string connectionString, bool requireCompatibleSchema)
    {
        try
        {
            SqlConnectionStringBuilder builder = new SqlConnectionStringBuilder(connectionString);
            builder.ConnectTimeout = 5;
            using (SqlConnection connection = new SqlConnection(builder.ConnectionString))
            {
                connection.Open();
                if (requireCompatibleSchema && !DatabaseConnectionHelper.HasRequiredSchema(connection))
                    return new DatabaseSetupResult(false,
                        "La connexion fonctionne, mais cette base ne contient pas le schéma requis par GESTION FINANCIERE. Aucune donnée n'a été modifiée. Faites valider une migration contrôlée par un administrateur avant de réessayer.");
            }
            return new DatabaseSetupResult(true, "La connexion SQL Server a été vérifiée avec succès.");
        }
        catch (ArgumentException)
        {
            return new DatabaseSetupResult(false, "Les paramètres de connexion sont incomplets ou invalides.");
        }
        catch (InvalidOperationException)
        {
            return new DatabaseSetupResult(false, "Les paramètres de connexion sont incomplets ou invalides.");
        }
        catch (SqlException exception)
        {
            return new DatabaseSetupResult(false, GetSafeConnectionMessage(exception));
        }
    }

    public static DatabaseSetupResult TestServer(string connectionString, string databaseName)
    {
        try
        {
            SqlConnectionStringBuilder builder = new SqlConnectionStringBuilder(connectionString);
            builder.InitialCatalog = "master";
            using (SqlConnection connection = new SqlConnection(builder.ConnectionString))
            {
                connection.Open();
                using (SqlCommand command = new SqlCommand(
                    "SELECT DB_ID(@databaseName), CASE WHEN IS_SRVROLEMEMBER('sysadmin') = 1 OR HAS_PERMS_BY_NAME(NULL, NULL, 'CREATE ANY DATABASE') = 1 THEN 1 ELSE 0 END;",
                    connection))
                {
                    command.Parameters.Add("@databaseName", SqlDbType.NVarChar, 128).Value = databaseName;
                    using (SqlDataReader reader = command.ExecuteReader())
                    {
                        reader.Read();
                        if (reader.GetValue(0) != DBNull.Value)
                            return new DatabaseSetupResult(false,
                                "Cette base existe déjà. Elle ne sera jamais écrasée. Choisissez « Connexion à une base existante ».");
                        if (Convert.ToInt32(reader.GetValue(1)) != 1)
                            return new DatabaseSetupResult(false,
                                "Le serveur répond, mais le compte ne dispose pas de la permission de création. Demandez à un administrateur SQL Server de créer la base ou d'accorder temporairement cette permission.");
                    }
                }
            }
            return new DatabaseSetupResult(true,
                "Le serveur est accessible, la base n'existe pas et le compte dispose de la permission de création.");
        }
        catch (ArgumentException)
        {
            return new DatabaseSetupResult(false, "Les paramètres de connexion sont incomplets ou invalides.");
        }
        catch (SqlException exception)
        {
            return new DatabaseSetupResult(false, GetSafeConnectionMessage(exception));
        }
    }

    public static DatabaseSetupResult CreateAndInitialize(string connectionString, string databaseName,
        string adminUsername, string adminName, string adminEmail, string adminPassword)
    {
        if (!DatabaseNamePattern.IsMatch(databaseName ?? String.Empty))
            return new DatabaseSetupResult(false, "Le nom de la base de données est invalide.");
        if (String.IsNullOrWhiteSpace(adminUsername) || adminUsername.Length > 100 ||
            String.IsNullOrWhiteSpace(adminName) || adminName.Length > 100 ||
            String.IsNullOrWhiteSpace(adminEmail) || adminEmail.Length > 100 ||
            String.IsNullOrEmpty(adminPassword) || adminPassword.Length < 12 || adminPassword.Length > 128)
            return new DatabaseSetupResult(false, "Renseignez un compte administrateur valide et un mot de passe d'au moins 12 caractères.");
        try
        {
            MailAddress email = new MailAddress(adminEmail.Trim());
            if (!String.Equals(email.Address, adminEmail.Trim(), StringComparison.OrdinalIgnoreCase))
                return new DatabaseSetupResult(false, "L'adresse courriel de l'administrateur est invalide.");
        }
        catch (FormatException)
        {
            return new DatabaseSetupResult(false, "L'adresse courriel de l'administrateur est invalide.");
        }

        SqlConnectionStringBuilder databaseBuilder;
        try
        {
            databaseBuilder = new SqlConnectionStringBuilder(connectionString);
        }
        catch (ArgumentException)
        {
            return new DatabaseSetupResult(false, "Les paramètres de connexion sont incomplets ou invalides.");
        }

        databaseBuilder.InitialCatalog = "master";
        string masterConnectionString = databaseBuilder.ConnectionString;
        try
        {
            using (SqlConnection master = new SqlConnection(masterConnectionString))
            {
                master.Open();
                using (SqlCommand check = new SqlCommand("SELECT DB_ID(@databaseName);", master))
                {
                    check.Parameters.Add("@databaseName", SqlDbType.NVarChar, 128).Value = databaseName;
                    object existingDatabase = check.ExecuteScalar();
                    if (existingDatabase != DBNull.Value && existingDatabase != null)
                        return new DatabaseSetupResult(false,
                            "Cette base existe déjà. Elle n'a pas été modifiée. Utilisez l'option de connexion à une base existante.");
                }

                using (SqlCommand create = new SqlCommand(
                    "CREATE DATABASE " + QuoteIdentifier(databaseName) + ";", master))
                {
                    create.CommandTimeout = 60;
                    create.ExecuteNonQuery();
                }
            }

            databaseBuilder.InitialCatalog = databaseName;
            string newDatabaseConnectionString = databaseBuilder.ConnectionString;
            InitializeFromOfficialSchema(newDatabaseConnectionString);
            CreateInitialAdministrator(newDatabaseConnectionString, adminUsername, adminName,
                adminEmail, adminPassword);

            DatabaseSetupResult schemaResult = TestConnection(newDatabaseConnectionString, true);
            if (!schemaResult.Success)
                return new DatabaseSetupResult(false,
                    "La base a été créée, mais la vérification du schéma a échoué. La configuration n'a pas été enregistrée.");

            SaveConnectionStrings(newDatabaseConnectionString);
            return new DatabaseSetupResult(true,
                "La nouvelle base a été initialisée et la configuration enregistrée.");
        }
        catch (SqlException exception)
        {
            return new DatabaseSetupResult(false, GetSafeConnectionMessage(exception));
        }
        catch (IOException)
        {
            return new DatabaseSetupResult(false,
                "La base a été créée, mais le script officiel d'initialisation est introuvable ou illisible. La configuration n'a pas été enregistrée.");
        }
        catch (UnauthorizedAccessException)
        {
            return new DatabaseSetupResult(false,
                "La base a été créée, mais IIS ne peut pas lire le script officiel d'initialisation. La configuration n'a pas été enregistrée.");
        }
        catch (InvalidDataException)
        {
            return new DatabaseSetupResult(false,
                "Le script officiel ne peut pas être adapté de manière sûre. La configuration n'a pas été enregistrée.");
        }
        catch (ConfigurationErrorsException)
        {
            return new DatabaseSetupResult(false,
                "La base a été initialisée, mais la configuration IIS n'a pas pu être enregistrée. Vérifiez les droits d'écriture restreints sur web.config.");
        }
    }

    public static DatabaseSetupResult SaveExistingConnection(string connectionString)
    {
        DatabaseSetupResult test = TestConnection(connectionString, true);
        if (!test.Success)
            return test;

        try
        {
            SaveConnectionStrings(connectionString);
            return new DatabaseSetupResult(true, "La connexion existante a été enregistrée.");
        }
        catch (ConfigurationErrorsException)
        {
            return new DatabaseSetupResult(false,
                "La connexion est valide, mais IIS n'a pas pu enregistrer la configuration. Vérifiez les droits d'écriture restreints sur web.config.");
        }
    }

    private static void InitializeFromOfficialSchema(string connectionString)
    {
        string scriptPath = HttpContext.Current.Server.MapPath("~/update/BDDSQLCONSO.sql");
        string script = File.ReadAllText(scriptPath);
        Regex defaultAdminInsert = new Regex(
            @"(?ims)^[ \t]*INSERT[ \t]+INTO[ \t]+(?:dbo\.)?\[?USERS\]?\b.*?;[ \t]*(?:\r?\n|$)",
            RegexOptions.CultureInvariant);
        if (defaultAdminInsert.Matches(script).Count != 1)
            throw new InvalidDataException("Le script ne contient pas exactement l'insertion administrateur attendue.");
        script = defaultAdminInsert.Replace(script, String.Empty, 1);
        string[] batches = Regex.Split(script, @"(?im)^\s*GO\s*(?:--.*)?$");

        using (SqlConnection connection = new SqlConnection(connectionString))
        {
            connection.Open();
            foreach (string rawBatch in batches)
            {
                string batch = rawBatch.Trim();
                if (batch.Length == 0 ||
                    Regex.IsMatch(batch, @"(?im)^\s*USE\s+", RegexOptions.CultureInvariant) ||
                    Regex.IsMatch(batch, @"\b(DROP|ALTER|CREATE)\s+DATABASE\b", RegexOptions.IgnoreCase))
                    continue;
                if (Regex.IsMatch(batch, @"\b(DROP|TRUNCATE)\s+TABLE\b|\bDELETE\s+FROM\b",
                    RegexOptions.IgnoreCase))
                    throw new InvalidDataException("Le script contient une opération destructive sur des données.");

                using (SqlCommand command = new SqlCommand(batch, connection))
                {
                    command.CommandTimeout = 120;
                    command.ExecuteNonQuery();
                }
            }
        }
    }

    private static void CreateInitialAdministrator(string connectionString, string username,
        string name, string email, string password)
    {
        string passwordHash = PasswordHelper.HashPassword(password);
        using (SqlConnection connection = new SqlConnection(connectionString))
        {
            connection.Open();
            using (SqlCommand command = new SqlCommand(@"
IF NOT EXISTS (SELECT 1 FROM USERROLE WHERE ROLEID = 0)
    INSERT INTO USERROLE (ROLEID, ROLENAME) VALUES (0, 'SuperAdmin');
INSERT INTO USERS (USERNAME, NOM, EMAIL, PWD, ROLEID, ACTIVE)
VALUES (@username, @name, @email, @passwordHash, 0, 1);", connection))
            {
                command.Parameters.Add("@username", SqlDbType.NVarChar, 100).Value = username.Trim();
                command.Parameters.Add("@name", SqlDbType.NVarChar, 100).Value = name.Trim();
                command.Parameters.Add("@email", SqlDbType.NVarChar, 100).Value = email.Trim();
                command.Parameters.Add("@passwordHash", SqlDbType.NVarChar, 255).Value = passwordHash;
                command.ExecuteNonQuery();
            }
        }
    }

    private static void SaveConnectionStrings(string connectionString)
    {
        try
        {
            Configuration configuration = WebConfigurationManager.OpenWebConfiguration("~/");
            ConnectionStringsSection section =
                configuration.GetSection("connectionStrings") as ConnectionStringsSection;
            if (section == null)
                throw new ConfigurationErrorsException("Section connectionStrings absente.");

            bool wasProtected = section.SectionInformation.IsProtected;
            if (wasProtected)
                section.SectionInformation.UnprotectSection();

            ConnectionStringSettings main = section.ConnectionStrings["MaConnexion"];
            if (main == null)
                throw new ConfigurationErrorsException("Chaîne MaConnexion absente.");
            main.ConnectionString = connectionString;

            section.SectionInformation.ProtectSection("DataProtectionConfigurationProvider");
            section.SectionInformation.ForceSave = true;
            configuration.Save(ConfigurationSaveMode.Modified);
            ConfigurationManager.RefreshSection("connectionStrings");
            DatabaseConnectionHelper.InvalidateHealthCache();
        }
        catch (UnauthorizedAccessException exception)
        {
            throw new ConfigurationErrorsException("IIS ne peut pas écrire la configuration protégée.", exception);
        }
        catch (IOException exception)
        {
            throw new ConfigurationErrorsException("IIS ne peut pas écrire la configuration protégée.", exception);
        }
    }

    private static string QuoteIdentifier(string identifier)
    {
        return "[" + identifier.Replace("]", "]]") + "]";
    }

    private static string GetSafeConnectionMessage(SqlException exception)
    {
        foreach (SqlError error in exception.Errors)
        {
            switch (error.Number)
            {
                case 2:
                case 53:
                case 10060:
                case 10061:
                case 11001:
                    return "Le serveur SQL Server est introuvable ou ne répond pas. Vérifiez le serveur, l'instance et le réseau.";
                case -2:
                    return "Le délai d'attente de 5 secondes est dépassé. Vérifiez le serveur et l'instance SQL Server, ainsi que l'activation de TCP/IP et de SQL Server Browser pour une instance nommée.";
                case 18456:
                    return "L'authentification SQL Server a échoué. Vérifiez le mode d'authentification et les identifiants.";
                case 4060:
                    return "La base de données demandée est introuvable ou inaccessible pour ce compte.";
                case 1801:
                    return "Cette base existe déjà ou a été créée par une opération simultanée. Elle n'a pas été écrasée.";
                case 262:
                case 229:
                    return "Le compte SQL Server ne dispose pas des permissions requises.";
            }
        }
        return "Une erreur SQL Server empêche l'opération. Vérifiez les paramètres et les permissions du compte.";
    }
}
