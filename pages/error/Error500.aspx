<%@ Page Language="C#" AutoEventWireup="true" CodeFile="Error500.aspx.cs" Inherits="Error500" %>

<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Erreur serveur (500)</title>

    <link rel="stylesheet" href="../_assets/css/adminlte.min.css" />
    <link rel="stylesheet" href="../_assets/css/fontawesome.min.css" />
    <link rel="stylesheet" href="../_assets/css/error500.css" />
</head>
<body class="ep-body">
    <form id="form1" runat="server" class="ep-form">

        <!-- ================= En-tête ================= -->
        <header class="ep-header">
            <asp:HyperLink ID="lnkBrand" runat="server" NavigateUrl="~/auth/Login.aspx" CssClass="ep-brand">
                <svg class="ep-brand-mark" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                    <path d="M24 4 42 13.5v21L24 44 6 34.5v-21z" fill="#2563eb"/>
                    <path d="M24 4 42 13.5 24 23 6 13.5z" fill="#60a5fa"/>
                    <path d="M24 23v21L6 34.5v-21z" fill="#1d4ed8"/>
                </svg>
                <span>MonApp<span class="ep-brand-accent">Ecole</span></span>
            </asp:HyperLink>

            <asp:HyperLink ID="lnkHome" runat="server" NavigateUrl="~/auth/Login.aspx" CssClass="ep-home-link">
                <i class="fas fa-home" aria-hidden="true"></i>
                <span>Retour à l'accueil</span>
            </asp:HyperLink>
        </header>

        <!-- ================= Contenu ================= -->
        <main class="ep-main">

            <!-- Illustration -->
            <div class="ep-illustration">
                <svg class="ep-svg" viewBox="0 0 520 430" xmlns="http://www.w3.org/2000/svg"
                     role="img" aria-labelledby="epSvgTitle">
                    <title id="epSvgTitle">Illustration d'une erreur interne du serveur</title>
                    <defs>
                        <linearGradient id="epBlobGrad" x1="0" y1="0" x2="1" y2="1">
                            <stop offset="0%" stop-color="#eaf1fd" />
                            <stop offset="100%" stop-color="#d7e5fa" />
                        </linearGradient>
                        <linearGradient id="epRackGrad" x1="0" y1="0" x2="0" y2="1">
                            <stop offset="0%" stop-color="#33455f" />
                            <stop offset="100%" stop-color="#22304a" />
                        </linearGradient>
                        <linearGradient id="epRobotGrad" x1="0" y1="0" x2="0" y2="1">
                            <stop offset="0%" stop-color="#ffffff" />
                            <stop offset="100%" stop-color="#e8eefb" />
                        </linearGradient>
                    </defs>

                    <!-- Halo de fond -->
                    <ellipse cx="252" cy="232" rx="222" ry="182" fill="url(#epBlobGrad)" />

                    <!-- Nuages -->
                    <g fill="#ffffff" opacity="0.9">
                        <ellipse cx="176" cy="104" rx="40" ry="18" />
                        <ellipse cx="212" cy="112" rx="26" ry="12" />
                        <rect x="268" y="98" width="46" height="10" rx="5" />
                        <rect x="298" y="76" width="32" height="10" rx="5" />
                    </g>

                    <!-- Ombre au sol -->
                    <ellipse cx="255" cy="352" rx="190" ry="16" fill="#c6d8f3" opacity="0.5" />

                    <!-- Plante -->
                    <g>
                        <path d="M92 300 C 92 262 72 254 58 246 C 84 244 92 268 92 300 Z" fill="#2fa27a" />
                        <path d="M92 300 C 92 258 112 250 128 240 C 106 240 92 264 92 300 Z" fill="#3bb98f" />
                        <path d="M92 300 V 250" stroke="#1f7d5c" stroke-width="3" stroke-linecap="round" />
                        <path d="M70 300 h44 l-5 34 a9 9 0 0 1 -9 8 h-16 a9 9 0 0 1 -9 -8 z"
                              fill="#ffffff" stroke="#cfdcf2" stroke-width="3" stroke-linejoin="round" />
                    </g>

                    <!-- Baies serveurs -->
                    <g>
                        <rect x="118" y="128" width="150" height="50" rx="10" fill="url(#epRackGrad)" />
                        <rect x="118" y="186" width="150" height="50" rx="10" fill="url(#epRackGrad)" />
                        <rect x="118" y="244" width="150" height="50" rx="10" fill="url(#epRackGrad)" />

                        <g fill="#5c86d6">
                            <circle cx="140" cy="153" r="5" /><circle cx="158" cy="153" r="5" /><circle cx="176" cy="153" r="5" />
                            <circle cx="140" cy="211" r="5" /><circle cx="158" cy="211" r="5" /><circle cx="176" cy="211" r="5" />
                            <circle cx="140" cy="269" r="5" /><circle cx="158" cy="269" r="5" /><circle cx="176" cy="269" r="5" />
                        </g>
                        <g fill="#8ea6c9">
                            <circle cx="222" cy="153" r="5" /><circle cx="242" cy="153" r="5" />
                            <circle cx="222" cy="211" r="5" /><circle cx="242" cy="211" r="5" />
                            <circle cx="222" cy="269" r="5" /><circle cx="242" cy="269" r="5" />
                        </g>
                    </g>

                    <!-- Pastille d'erreur -->
                    <g>
                        <circle cx="193" cy="211" r="40" fill="#e5484d" />
                        <path d="M178 196 L208 226 M208 196 L178 226"
                              stroke="#ffffff" stroke-width="9" stroke-linecap="round" />
                    </g>

                    <!-- Robot -->
                    <g class="ep-svg-robot">
                        <path d="M348 232 V 212" stroke="#b9cbe6" stroke-width="5" stroke-linecap="round" />
                        <circle cx="348" cy="206" r="8" fill="#2563eb" />

                        <rect x="310" y="228" width="76" height="68" rx="26"
                              fill="url(#epRobotGrad)" stroke="#d3e0f4" stroke-width="3" />
                        <circle cx="306" cy="262" r="7" fill="#cfe0f7" />
                        <circle cx="390" cy="262" r="7" fill="#cfe0f7" />

                        <rect x="322" y="246" width="52" height="34" rx="15" fill="#22304a" />
                        <path d="M333 262 l11 7" stroke="#9dc0f0" stroke-width="4" stroke-linecap="round" />
                        <path d="M363 262 l-11 7" stroke="#9dc0f0" stroke-width="4" stroke-linecap="round" />

                        <rect x="318" y="298" width="60" height="50" rx="22"
                              fill="url(#epRobotGrad)" stroke="#d3e0f4" stroke-width="3" />
                        <rect x="296" y="306" width="20" height="14" rx="7"
                              fill="#e8eefb" stroke="#d3e0f4" stroke-width="3" />
                        <rect x="380" y="306" width="20" height="14" rx="7"
                              fill="#e8eefb" stroke="#d3e0f4" stroke-width="3" />

                        <path d="M326 350 h52 l9 -26 h-52 z"
                              fill="#dfe8f7" stroke="#c3d3ec" stroke-width="3" stroke-linejoin="round" />
                    </g>

                    <!-- Détails flottants -->
                    <g fill="#c3d3ec">
                        <circle cx="432" cy="130" r="5" />
                        <circle cx="462" cy="168" r="4" />
                        <circle cx="446" cy="200" r="3" />
                    </g>
                </svg>
            </div>

            <!-- Message -->
            <div class="ep-content">
                <h1 class="ep-code">500</h1>
                <h2 class="ep-title">Erreur interne du serveur</h2>

                <p class="ep-text">
                    Désolé, une erreur inattendue s'est produite lors du traitement de votre demande.
                    Veuillez réessayer dans quelques instants.
                </p>

                <div class="ep-help">
                    <i class="far fa-lightbulb ep-help-icon" aria-hidden="true"></i>
                    <div>
                        <p class="ep-help-title">Que pouvez-vous faire ?</p>
                        <ul class="ep-help-list">
                            <li>Réessayer dans quelques instants</li>
                            <li>Vérifier votre connexion internet</li>
                            <li>Si le problème persiste, contacter l'administrateur</li>
                        </ul>
                    </div>
                </div>

                <div class="ep-actions">
                    <button type="button" class="ep-btn ep-btn-primary" onclick="epRetry();">
                        <i class="fas fa-redo" aria-hidden="true"></i>
                        Réessayer
                    </button>

                    <asp:Button ID="btnRetourLogin" runat="server"
                                Text="Retour à l'accueil"
                                CssClass="ep-btn ep-btn-outline"
                                OnClick="btnRetourLogin_Click" />
                </div>

                <p class="ep-support">
                    Le problème persiste ?
                    <a href="mailto:support@monappecole.com">Contacter l'administrateur</a>
                </p>
            </div>
        </main>

        <!-- ================= Pied de page ================= -->
        <footer class="ep-footer">
            Nous nous excusons pour la gêne occasionnée.
        </footer>
    </form>

    <script src="../_assets/js/jquery.min.js"></script>
    <script src="../_assets/js/bootstrap.bundle.min.js"></script>
    <script>
        // Relance l'opération précédente : retour arrière si possible, sinon rechargement.
        function epRetry() {
            if (window.history.length > 1) {
                window.history.back();
                return;
            }
            window.location.reload();
        }
    </script>
</body>
</html>
