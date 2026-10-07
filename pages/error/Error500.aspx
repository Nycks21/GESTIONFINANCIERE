<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Error500.aspx.cs" Inherits="Error500" %>

<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8" />
    <title>Erreur Serveur</title>
    <link rel="stylesheet" href="../_assets/css/adminlte.min.css" />
    <link rel="stylesheet" href="../_assets/css/fontawesome.min.css" />
</head>
<body class="hold-transition layout-top-nav">
    <div class="wrapper">
        <!-- Content Wrapper -->
        <div class="content-wrapper">
            <div class="content-header text-center mt-5">
                <h1 class="text-danger">Erreur 500</h1>
                <p>Une erreur inattendue est survenue. Veuillez réessayer plus tard ou contacter l’administrateur.</p>
            </div>

            <!-- Formulaire pour les boutons -->
            <form id="form1" runat="server" class="text-center mt-4">
                <asp:Button ID="btnRetourLogin" runat="server" Text="Retour à l'accueil" CssClass="btn btn-primary" OnClick="btnRetourLogin_Click" />
            </form>
        </div>
    </div>

    <script src="../_assets/js/jquery.min.js"></script>
    <script src="../_assets/js/bootstrap.bundle.min.js"></script>
</body>
</html>
