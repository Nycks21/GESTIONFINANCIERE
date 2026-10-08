﻿<%@ Page Language="C#" AutoEventWireup="true" CodeFile="index.cs" Inherits="index" UICulture="Auto" Culture="Auto" %>
<!DOCTYPE html>
<html lang="<%= LocalizationHelper.CurrentCultureCode %>">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <script src="../_assets/js/theme-init.js?v=<%=AuthHelper.Version %>"></script>
  <title><%= LocalizationHelper.GetString("dashboard.welcome_title") %> — Gestion Financière</title>

  <link rel="stylesheet" href="../_assets/css/all.min.css?v=<%=AuthHelper.Version %>">
  <link rel="stylesheet" href="../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>">
  <link rel="stylesheet" href="../_assets/css/global.css?v=<%=AuthHelper.Version %>">
  <link rel="stylesheet" href="css/dashboard.css?v=<%=AuthHelper.Version %>">
</head>

<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
<script>document.body.classList.toggle("dark-mode", document.documentElement.classList.contains("dark-mode"));</script>
<form id="form1" runat="server">
  <asp:HiddenField ID="hfUserRole" runat="server" />
  <div class="wrapper">

    <%= AuthHelper.RenderTopBarHTML() %>

    <aside class="main-sidebar" id="sidebar">
      <div class="sidebar">
        <%= AuthHelperDashboard.RenderMenuHTML() %>
      </div>
    </aside>

    <%= AuthHelper.RenderControlSidebarHTML() %>

    <div class="content-wrapper" id="contentWrapper">
      <div class="content-header">
        <div class="container-fluid">
          <div class="row">
            <div class="col-lg-6">
              <h1>
                <i class="fas fa-home"></i>
                <span data-i18n="dashboard.title"></span>
              </h1>
            </div>
            <div class="col-lg-6">
              <ol class="breadcrumb" style="float:right;">
                <li class="breadcrumb-item" data-i18n="menu.accueil"></li>
                <li class="breadcrumb-item active" data-i18n="dashboard.title"></li>
              </ol>
            </div>
          </div>
        </div>
      </div>

      <section class="content">
        <div class="container-fluid">

          <!-- ═══ ZONE 0 : BANDEAU DE BIENVENUE ═══ -->
          <div class="fin-welcome">
            <div class="fin-welcome-left">
              <div class="fin-welcome-icon"><i class="fas fa-wallet"></i></div>
              <div class="fin-welcome-text">
                <div class="fin-welcome-eyebrow" data-i18n="dashboard.welcome_eyebrow"></div>
                <h2 class="fin-welcome-title" data-i18n="dashboard.welcome_title"></h2>
                <div class="fin-welcome-sub" data-i18n="dashboard.welcome_sub"></div>
              </div>
            </div>
            <div class="fin-welcome-right">
              <div class="fin-welcome-date">
                <i class="far fa-calendar-alt"></i>
                <span id="finWelcomeDate">—</span>
              </div>
              <div class="fin-welcome-time" id="finWelcomeTime">—</div>
            </div>
          </div>

          <!-- ═══ ZONE 1 : NOS APPLICATIONS ═══ -->
          <div class="fin-section-title">
            <i class="fas fa-th-large"></i>
            <span data-i18n="dashboard.our_apps"></span>
          </div>

          <div class="fin-apps">

            <% if (AuthHelper.HasPermission("stock")) { %>
            <a href="../stock/accueil/index.aspx" class="fin-app-card stock">
              <div class="fin-app-icon"><i class="fas fa-boxes"></i></div>
              <div class="fin-app-body">
                <div class="fin-app-title" data-i18n="dashboard.app_stock_title"></div>
                <div class="fin-app-desc" data-i18n="dashboard.app_stock_desc"></div>
                <div class="fin-app-cta">
                  <span data-i18n="dashboard.access"></span>
                  <i class="fas fa-arrow-right"></i>
                </div>
              </div>
              <div class="fin-app-deco"><i class="fas fa-warehouse"></i></div>
            </a>
            <% } %>

            <% if (AuthHelper.HasPermission("finance_ecritures") || AuthHelper.HasPermission("comptabilite")) { %>
            <a href="../finance/accueil/index.aspx" class="fin-app-card compta">
              <div class="fin-app-icon"><i class="fas fa-calculator"></i></div>
              <div class="fin-app-body">
                <div class="fin-app-title" data-i18n="dashboard.app_compta_title"></div>
                <div class="fin-app-desc" data-i18n="dashboard.app_compta_desc"></div>
                <div class="fin-app-cta">
                  <span data-i18n="dashboard.access"></span>
                  <i class="fas fa-arrow-right"></i>
                </div>
              </div>
              <div class="fin-app-deco"><i class="fas fa-file-invoice-dollar"></i></div>
            </a>
            <% } %>

          </div>

          <!-- ═══ ZONE 2 : VUE D'ENSEMBLE ═══ -->
          <div class="fin-section-title">
            <i class="fas fa-chart-bar"></i>
            <span data-i18n="dashboard.overview"></span>
          </div>

          <div class="fin-kpi-row">

            <div class="fin-kpi">
              <div class="fin-kpi-icon icon-emerald"><i class="fas fa-wallet"></i></div>
              <div class="fin-kpi-body">
                <div class="fin-kpi-label" data-i18n="dashboard.kpi_solde"></div>
                <div class="fin-kpi-value" id="finKpiSolde">—</div>
                <div class="fin-kpi-sub">
                  <span class="fin-kpi-trend" id="finTrendSolde">—</span>
                  <span class="fin-kpi-period" data-i18n="dashboard.vs_last_month"></span>
                </div>
              </div>
            </div>

            <div class="fin-kpi">
              <div class="fin-kpi-icon icon-blue"><i class="fas fa-exchange-alt"></i></div>
              <div class="fin-kpi-body">
                <div class="fin-kpi-label" data-i18n="dashboard.kpi_ecritures"></div>
                <div class="fin-kpi-value" id="finKpiEcritures">—</div>
                <div class="fin-kpi-sub">
                  <span class="fin-kpi-trend" id="finTrendEcritures">—</span>
                  <span class="fin-kpi-period" data-i18n="dashboard.vs_last_month"></span>
                </div>
              </div>
            </div>

            <div class="fin-kpi">
              <div class="fin-kpi-icon icon-violet"><i class="fas fa-file-invoice-dollar"></i></div>
              <div class="fin-kpi-body">
                <div class="fin-kpi-label" data-i18n="dashboard.kpi_entrees"></div>
                <div class="fin-kpi-value" id="finKpiEntrees">—</div>
                <div class="fin-kpi-sub">
                  <span class="fin-kpi-trend" id="finTrendEntrees">—</span>
                  <span class="fin-kpi-period" data-i18n="dashboard.vs_last_month"></span>
                </div>
              </div>
            </div>

            <div class="fin-kpi">
              <div class="fin-kpi-icon icon-amber"><i class="fas fa-arrow-up"></i></div>
              <div class="fin-kpi-body">
                <div class="fin-kpi-label" data-i18n="dashboard.kpi_sorties"></div>
                <div class="fin-kpi-value" id="finKpiSorties">—</div>
                <div class="fin-kpi-sub">
                  <span class="fin-kpi-trend" id="finTrendSorties">—</span>
                  <span class="fin-kpi-period" data-i18n="dashboard.vs_last_month"></span>
                </div>
              </div>
            </div>

          </div>

          <!-- ═══ ZONE 3 : GRAPHIQUES + ACTIVITÉS ═══ -->
          <div class="fin-row-3">

            <div class="dash-card">
              <div class="dash-card-head">
                <span class="dash-card-title">
                  <i class="fas fa-chart-line" style="color:#10b981"></i>
                  <span data-i18n="dashboard.chart_evolution"></span>
                </span>
              </div>
              <div class="dash-card-body">
                <div style="position:relative;height:260px;">
                  <canvas id="chartEvolution"></canvas>
                </div>
              </div>
            </div>

            <div class="dash-card">
              <div class="dash-card-head">
                <span class="dash-card-title">
                  <i class="fas fa-chart-pie" style="color:#8b5cf6"></i>
                  <span data-i18n="dashboard.chart_repartition"></span>
                </span>
              </div>
              <div class="dash-card-body">
                <div class="donut-wrap">
                  <div class="donut-canvas">
                    <canvas id="chartRepartition"></canvas>
                    <div class="donut-center">
                      <div class="donut-center-label" data-i18n="dashboard.total"></div>
                      <div class="donut-center-value" id="donutTotal">—</div>
                    </div>
                  </div>
                  <div class="donut-legend" id="donutLegend"></div>
                </div>
              </div>
            </div>

            <div class="dash-card">
              <div class="dash-card-head">
                <span class="dash-card-title">
                  <i class="fas fa-clock" style="color:#3b82f6"></i>
                  <span data-i18n="dashboard.recent_activity"></span>
                </span>
                <a href="../finance/ecritures/consultation/consultation.aspx" class="dash-link">
                  <span data-i18n="dashboard.see_all"></span>
                  <i class="fas fa-arrow-right"></i>
                </a>
              </div>
              <div class="activity-list" id="activityList">
                <div class="loading-mini" data-i18n="message.loading"></div>
              </div>
            </div>

          </div>

        </div>
      </section>
    </div>
  </div>

  <div id="spinnerOverlay"
       style="display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.35);z-index:9998;align-items:center;justify-content:center;">
    <div class="ldr" aria-label="Chargement">
      <span></span><span></span><span></span><span></span><span></span>
    </div>
  </div>

  <script src="../_assets/js/chart.umd.min.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../_assets/js/csrf.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../_assets/js/sweetalert2.all.min.js?v=<%=AuthHelper.Version %>"></script>
  <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>
  <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/charts.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
</form>
</body>
</html>
