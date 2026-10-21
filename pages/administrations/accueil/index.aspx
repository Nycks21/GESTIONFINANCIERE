<%@ Page Language="C#" AutoEventWireup="true" CodeFile="index.cs" Inherits="administrations_accueil" UICulture="Auto" Culture="Auto" %>
<!DOCTYPE html>
<html lang="<%= LocalizationHelper.CurrentCultureCode %>">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title><%= LocalizationHelper.GetString("admin.accueil.title") %> — <%= LocalizationHelper.GetString("app.name") %></title>
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%= AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%= AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%= AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%= AuthHelper.Version %>" />
</head>
<body class="hold-transition" data-version="<%= AuthHelper.Version %>">
<form id="adminAccueilPage" runat="server">
    <div class="wrapper">
        <%= AuthHelper.RenderTopBarHTML() %>
        <aside class="main-sidebar" id="sidebar">
            <div class="sidebar"><%= AuthHelperDashboard.RenderMenuHTML() %></div>
        </aside>
        <%= AuthHelper.RenderControlSidebarHTML() %>

        <div class="content-wrapper" id="contentWrapper">
            <div class="content-header">
                <div class="container-fluid">
                    <div class="row">
                        <div class="col-lg-8">
                            <h1 class="page-title">
                                <i class="fas fa-user-shield"></i>
                                <span data-i18n="admin.accueil.title"></span>
                            </h1>
                            <p class="page-subtitle" data-i18n="admin.accueil.subtitle"></p>
                        </div>
                        <div class="col-lg-4">
                            <ol class="breadcrumb">
                                <li class="breadcrumb-item" data-i18n="menu.accueil">Accueil</li>
                                <li class="breadcrumb-item active" data-i18n="admin.accueil.title">Administration</li>
                            </ol>
                        </div>
                    </div>
                </div>
            </div>

            <section class="content admin-accueil-content">

                <!-- ═══════════════ Section présentation ═══════════════ -->
                <div class="admin-hero">
                    <div class="admin-hero-icon">
                        <i class="fas fa-user-cog"></i>
                    </div>
                    <div class="admin-hero-text">
                        <h2 data-i18n="admin.accueil.hero_title"></h2>
                        <p  data-i18n="admin.accueil.hero_text"></p>
                    </div>
                </div>

                <!-- ═══════════════ Grille des cartes ═══════════════ -->
                <div class="admin-cards-grid">
                    <% foreach (var card in AdminCards) { %>
                        <a href="<%= ResolveUrl(card.Url) %>"
                           class="admin-card"
                           data-card-code="<%= HttpUtility.HtmlAttributeEncode(card.Code) %>">
                            <div class="admin-card-icon">
                                <i class="<%= card.Icon %>"></i>
                            </div>
                            <div class="admin-card-body">
                                <h3 class="admin-card-title" data-i18n="<%= HttpUtility.HtmlAttributeEncode(card.TextKey) %>"></h3>
                                <p  class="admin-card-desc"  data-i18n="<%= HttpUtility.HtmlAttributeEncode(card.DescKey) %>"></p>
                            </div>
                            <div class="admin-card-arrow">
                                <i class="fas fa-arrow-right"></i>
                            </div>
                        </a>
                    <% } %>
                </div>

                <!-- ═══════════════ Message si aucune carte ═══════════════ -->
                <% if (AdminCards.Count == 0) { %>
                    <div class="admin-empty">
                        <i class="fas fa-lock"></i>
                        <p data-i18n="admin.accueil.no_access"></p>
                    </div>
                <% } %>

            </section>
        </div>
    </div>

    <div id="spinnerOverlay" aria-hidden="true"><div class="spinner"></div></div>

    <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%= AuthHelper.Version %>"></script>
    <script src="../../_assets/js/i18n.js?v=<%= AuthHelper.Version %>"></script>
    <script src="../../_assets/js/global.js?v=<%= AuthHelper.Version %>"></script>

    <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>
    <div id="toastContainer"></div>
</form>
</body>
</html>
