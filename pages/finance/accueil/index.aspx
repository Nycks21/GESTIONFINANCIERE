﻿<%@ Page Language="C#" AutoEventWireup="true" CodeFile="index.cs" Inherits="index" UICulture="Auto" Culture="Auto" %>
<!DOCTYPE html>
<html lang="<%= LocalizationHelper.CurrentCultureCode %>">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="../../_assets/js/theme-init.js?v=<%= AuthHelper.Version %>"></script>
    <title><%= LocalizationHelper.GetString("finance.dashboard.title") %> — Gestion Financière</title>

    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%= AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%= AuthHelper.Version %>">
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%= AuthHelper.Version %>">
    <link rel="stylesheet" href="css/dashboard.css?v=<%= AuthHelper.Version %>">
</head>

<body class="hold-transition fin-body" data-version="<%= AuthHelper.Version %>">
<script>document.body.classList.toggle("dark-mode", document.documentElement.classList.contains("dark-mode"));</script>
<form id="form1" runat="server">
    <asp:HiddenField ID="hfUserRole" runat="server" />
    <div class="wrapper">

        <%= AuthHelper.RenderTopBarHTML() %>

        <aside class="main-sidebar" id="sidebar">
            <div class="sidebar">
                <%= AuthHelperFinance.RenderMenuHTML() %>
            </div>
        </aside>

        <%= AuthHelper.RenderControlSidebarHTML() %>

        <div class="content-wrapper" id="contentWrapper">
            <div class="fin-container">

                <!-- ═══════════════════════════════════════════════
                     HERO — Greeting personnalisé
                     ═══════════════════════════════════════════════ -->
                <section class="fin-hero">
                    <div class="fin-hero-glow"></div>
                    <div class="fin-hero-glow fin-hero-glow-2"></div>

                    <div class="fin-hero-content">
                        <div class="fin-hero-eyebrow">
                            <span class="fin-hero-dot"></span>
                            <span data-i18n="finance.hero.eyebrow">Tableau de bord comptable</span>
                        </div>
                        <h1 class="fin-hero-title">
                            <span data-i18n="finance.hero.greeting">Bonjour</span>,
                            <span class="fin-hero-username"><%= AuthHelper.GetUserName() %></span>
                            <span class="fin-hero-wave">👋</span>
                        </h1>
                        <p class="fin-hero-sub" data-i18n="finance.hero.subtitle">
                            Voici un aperçu en temps réel de votre situation financière.
                        </p>
                        <div class="fin-hero-meta">
                            <div class="fin-hero-meta-item">
                                <i class="far fa-calendar-alt"></i>
                                <span id="finHeroDate">—</span>
                            </div>
                            <div class="fin-hero-meta-item">
                                <i class="far fa-clock"></i>
                                <span id="finHeroTime">—</span>
                            </div>
                        </div>
                    </div>

                    <div class="fin-hero-actions">
                        <a href="../ecritures/saisie/saisie.aspx" class="fin-hero-btn fin-hero-btn-primary">
                            <i class="fas fa-plus"></i>
                            <span data-i18n="finance.hero.new_ecriture">Nouvelle écriture</span>
                        </a>
                        <a href="../rapports/balance/balance.aspx" class="fin-hero-btn fin-hero-btn-ghost">
                            <i class="fas fa-chart-bar"></i>
                            <span data-i18n="finance.hero.view_reports">Voir les rapports</span>
                        </a>
                    </div>
                </section>

                <!-- ═══════════════════════════════════════════════
                     KPI BENTO — 4 tuiles indicateurs
                     ═══════════════════════════════════════════════ -->
                <section class="fin-bento-kpi">

                    <article class="fin-tile fin-tile-emerald" data-tile="solde">
                        <div class="fin-tile-glow"></div>
                        <header class="fin-tile-head">
                            <span class="fin-tile-label" data-i18n="finance.kpi.solde">Solde trésorerie</span>
                            <span class="fin-tile-icon"><i class="fas fa-wallet"></i></span>
                        </header>
                        <div class="fin-tile-value" id="finKpiSolde">—</div>
                        <footer class="fin-tile-foot">
                            <span class="fin-tile-trend" id="finTrendSolde">—</span>
                            <span class="fin-tile-period" data-i18n="finance.kpi.vs_last_month">vs mois dernier</span>
                        </footer>
                    </article>

                    <article class="fin-tile fin-tile-blue" data-tile="ecritures">
                        <div class="fin-tile-glow"></div>
                        <header class="fin-tile-head">
                            <span class="fin-tile-label" data-i18n="finance.kpi.ecritures_mois">Écritures du mois</span>
                            <span class="fin-tile-icon"><i class="fas fa-file-invoice"></i></span>
                        </header>
                        <div class="fin-tile-value" id="finKpiEcritures">—</div>
                        <footer class="fin-tile-foot">
                            <span class="fin-tile-trend" id="finTrendEcritures">—</span>
                            <span class="fin-tile-period" data-i18n="finance.kpi.vs_last_month">vs mois dernier</span>
                        </footer>
                    </article>

                    <article class="fin-tile fin-tile-violet" data-tile="debits">
                        <div class="fin-tile-glow"></div>
                        <header class="fin-tile-head">
                            <span class="fin-tile-label" data-i18n="finance.kpi.debits_mois">Débits du mois</span>
                            <span class="fin-tile-icon"><i class="fas fa-arrow-trend-down"></i></span>
                        </header>
                        <div class="fin-tile-value" id="finKpiDebits">—</div>
                        <footer class="fin-tile-foot">
                            <span class="fin-tile-trend" id="finTrendDebits">—</span>
                            <span class="fin-tile-period" data-i18n="finance.kpi.vs_last_month">vs mois dernier</span>
                        </footer>
                    </article>

                    <article class="fin-tile fin-tile-amber" data-tile="credits">
                        <div class="fin-tile-glow"></div>
                        <header class="fin-tile-head">
                            <span class="fin-tile-label" data-i18n="finance.kpi.credits_mois">Crédits du mois</span>
                            <span class="fin-tile-icon"><i class="fas fa-arrow-trend-up"></i></span>
                        </header>
                        <div class="fin-tile-value" id="finKpiCredits">—</div>
                        <footer class="fin-tile-foot">
                            <span class="fin-tile-trend" id="finTrendCredits">—</span>
                            <span class="fin-tile-period" data-i18n="finance.kpi.vs_last_month">vs mois dernier</span>
                        </footer>
                    </article>

                </section>

                <!-- ═══════════════════════════════════════════════
                     GRAPHIQUES — bento 2 colonnes
                     ═══════════════════════════════════════════════ -->
                <section class="fin-bento-charts">

                    <article class="fin-panel fin-panel-wide">
                        <header class="fin-panel-head">
                            <div class="fin-panel-title">
                                <span class="fin-panel-dot" style="background:#10b981"></span>
                                <h3 data-i18n="finance.dashboard.chart_evolution">Évolution des opérations</h3>
                            </div>
                            <div class="fin-panel-legend">
                                <span class="fin-leg"><span class="fin-leg-dot" style="background:#10b981"></span> <span data-i18n="finance.chart.debits">Débits</span></span>
                                <span class="fin-leg"><span class="fin-leg-dot" style="background:#8b5cf6"></span> <span data-i18n="finance.chart.credits">Crédits</span></span>
                            </div>
                        </header>
                        <div class="fin-panel-body">
                            <div class="fin-chart-wrap">
                                <canvas id="chartEvolution"></canvas>
                            </div>
                        </div>
                    </article>

                    <article class="fin-panel">
                        <header class="fin-panel-head">
                            <div class="fin-panel-title">
                                <span class="fin-panel-dot" style="background:#8b5cf6"></span>
                                <h3 data-i18n="finance.dashboard.chart_repartition">Répartition des dépenses</h3>
                            </div>
                        </header>
                        <div class="fin-panel-body">
                            <div class="fin-donut-wrap">
                                <div class="fin-donut-canvas">
                                    <canvas id="chartRepartition"></canvas>
                                    <div class="fin-donut-center">
                                        <span class="fin-donut-label" data-i18n="finance.dashboard.total">Total</span>
                                        <span class="fin-donut-value" id="donutTotal">—</span>
                                    </div>
                                </div>
                                <ul class="fin-donut-legend" id="donutLegend"></ul>
                            </div>
                        </div>
                    </article>

                </section>

                <!-- ═══════════════════════════════════════════════
                     ACTIVITÉS RÉCENTES
                     ═══════════════════════════════════════════════ -->
                <section class="fin-panel fin-panel-full">
                    <header class="fin-panel-head">
                        <div class="fin-panel-title">
                            <span class="fin-panel-dot" style="background:#3b82f6"></span>
                            <h3 data-i18n="finance.dashboard.dernieres_ecritures">Dernières écritures</h3>
                        </div>
                        <a href="../ecritures/consultation/consultation.aspx" class="fin-panel-link">
                            <span data-i18n="finance.dashboard.voir_tout">Voir tout</span>
                            <i class="fas fa-arrow-right"></i>
                        </a>
                    </header>
                    <div class="fin-activity-list" id="activityList">
                        <div class="fin-loading">
                            <div class="fin-loading-dot"></div>
                            <div class="fin-loading-dot"></div>
                            <div class="fin-loading-dot"></div>
                        </div>
                    </div>
                </section>

            </div>
        </div>
    </div>

    <div id="spinnerOverlay" class="fin-spinner-overlay">
        <div class="fin-spinner">
            <span></span><span></span><span></span>
        </div>
    </div>

    <script src="../../_assets/js/chart.umd.min.js?v=<%= AuthHelper.Version %>"></script>
    <script src="../../_assets/js/i18n.js?v=<%= AuthHelper.Version %>"></script>
    <script src="../../_assets/js/csrf.js?v=<%= AuthHelper.Version %>"></script>
    <script src="../../_assets/js/global.js?v=<%= AuthHelper.Version %>"></script>
    <script src="../../_assets/js/sweetalert2.all.min.js?v=<%= AuthHelper.Version %>"></script>
    <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>
    <script src="js/config.js?v=<%= AuthHelper.Version %>"></script>
    <script src="js/state.js?v=<%= AuthHelper.Version %>"></script>
    <script src="js/utils.js?v=<%= AuthHelper.Version %>"></script>
    <script src="js/ui.js?v=<%= AuthHelper.Version %>"></script>
    <script src="js/charts.js?v=<%= AuthHelper.Version %>"></script>
    <script src="js/init.js?v=<%= AuthHelper.Version %>"></script>
    <script src="js/loaders.js?v=<%= AuthHelper.Version %>"></script>
</form>
</body>
</html>
