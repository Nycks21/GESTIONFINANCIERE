<%@ Page Language="C#" AutoEventWireup="true" CodeFile="balance-auxiliaire.cs" Inherits="balanceAuxi" UICulture="Auto"
  Culture="Auto" %>
  <!DOCTYPE html>
  <html lang="<%= LocalizationHelper.CurrentCultureCode %>">

  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>
      <%= LocalizationHelper.GetString("balance.title") %> — <%= LocalizationHelper.GetString("app.name") %>
    </title>
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%= AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%= AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%= AuthHelper.Version %>" />
    <link rel="stylesheet" href="../saisie/css/style.css?v=<%= AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/balance.css?v=<%= AuthHelper.Version %>" />
  </head>

  <body class="hold-transition" data-version="<%= AuthHelper.Version %>">
    <form id="balanceFormPage" runat="server">
      <div class="wrapper">
        <%= AuthHelper.RenderTopBarHTML() %>
          <aside class="main-sidebar" id="sidebar">
            <div class="sidebar">
              <%= AuthHelperFinance.RenderMenuHTML() %>
            </div>
          </aside>
          <%= AuthHelper.RenderControlSidebarHTML() %>

            <div class="content-wrapper" id="contentWrapper">
              <div class="content-header">
                <div class="container-fluid">
                  <div class="row">
                    <div class="col-lg-6">
                      <h1 class="page-title">
                        <i class="fas fa-balance-scale"></i>
                        <span data-i18n="balance.auxi.title">Balance Auxiliaire</span>
                      </h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb">
                        <li class="breadcrumb-item" data-i18n="menu.finance">Finance</li>
                        <li class="breadcrumb-item" data-i18n="menu.saisie">Saisie</li>
                        <li class="breadcrumb-item active" data-i18n="balance.auxi.title">Balance Auxiliaire</li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <section class="content balance-content">
                <!-- ═══════════════════════════════════════════════════
                         FILTRES
                         ═══════════════════════════════════════════════════ -->
                <div class="balance-filter-panel" id="filterPanel">
                  <!-- En-tête du panneau -->
                  <div class="balance-filter-header">
                    <div class="balance-filter-title">
                      <i class="fas fa-sliders-h"></i>
                      <span data-i18n="balance.filters.title">Filtres</span>
                    </div>
                    <button type="button" class="btn-toggle-filter" id="btnToggleFilter"
                      title="Replier/Déplier les filtres">
                      <i class="fas fa-chevron-up"></i>
                    </button>
                  </div>

                  <!-- Contenu des filtres -->
                  <div class="balance-filter-content" id="filterContent">
                    <!-- Section Période & Contexte -->
                    <div class="balance-filter-box">
                      <span class="options-label">Période & Contexte</span>
                      <div class="balance-field-group">
                        <div class="balance-field">
                          <label data-i18n="balance.col.site">Site</label>
                          <select id="balSite" class="form-control"></select>
                        </div>
                        <div class="balance-field">
                          <label data-i18n="balance.col.exercice">Exercice</label>
                          <select id="balExercice" class="form-control"></select>
                        </div>
                        <div class="balance-field">
                          <label data-i18n="balance.col.date_debut">Du</label>
                          <div class="input-with-icon">
                            <input type="date" id="balDateDebut" class="form-control" />
                          </div>
                        </div>
                        <div class="balance-field">
                          <label data-i18n="balance.col.date_fin">Au</label>
                          <div class="input-with-icon">
                            <input type="date" id="balDateFin" class="form-control" />
                          </div>
                        </div>
                      </div>
                    </div>

                    <!-- Section Comptes & Auxiliaires -->
                    <div class="balance-filter-box">
                      <span class="options-label">Comptes & Auxiliaires</span>
                      <div class="balance-field-group">
                        <div class="balance-field">
                          <label data-i18n="auxiliaire.comp">Compte (4xxxxx)</label>
                          <select id="balCompteAux" class="form-control">
                            <option value="">— Tous les comptes —</option>
                          </select>
                        </div>
                        <div class="balance-field">
                          <label data-i18n="auxiliaire.du">Du</label>
                          <select id="balAuxiliaireDu" class="form-control">
                            <option value="">— Tous les auxiliaires —</option>
                          </select>
                        </div>
                        <div class="balance-field">
                          <label data-i18n="auxiliaire.au">au</label>
                          <select id="balAuxiliaireAu" class="form-control">
                            <option value="">— Tous les auxiliaires —</option>
                          </select>
                        </div>
                      </div>
                    </div>

                    <!-- Options et Statuts -->
                    <div class="balance-filter-box">
                      <div class="balance-status-group">
                        <span class="options-label">Statuts :</span>
                        <div class="status-pills">
                          <label class="status-pill">
                            <input type="checkbox" class="bal-statut" value="VALIDEE" checked>
                            <span class="pill-text" data-i18n="saisie.statut.VALIDEE">Validée</span>
                          </label>
                          <label class="status-pill">
                            <input type="checkbox" class="bal-statut" value="BROUILLON">
                            <span class="pill-text" data-i18n="saisie.statut.BROUILLON">Brouillon</span>
                          </label>
                          <label class="status-pill">
                            <input type="checkbox" class="bal-statut" value="A_VALIDER">
                            <span class="pill-text" data-i18n="saisie.statut.A_VALIDER">À valider</span>
                          </label>
                        </div>
                      </div>
                    </div>

                    <!-- Barre d'actions -->
                    <div class="balance-actions">
                      <div class="actions-left">
                        <button type="button" id="btnLoadBalance" class="btn btn-primary btn-modern">
                          <i class="fas fa-search"></i>
                          <span data-i18n="balance.btn.load">Charger</span>
                        </button>
                        <button type="button" id="btnExportBalance" class="btn btn-success btn-modern">
                          <i class="fas fa-file-csv"></i>
                          <span data-i18n="balance.btn.export">Export CSV</span>
                        </button>
                      </div>
                      <div class="actions-right">
                        <button type="button" id="btnPrintBalance" class="btn btn-light btn-icon" title="Imprimer">
                          <i class="fas fa-print"></i>
                        </button>
                        <button type="button" id="btnResetBalance" class="btn btn-light btn-icon" title="Réinitialiser">
                          <i class="fas fa-undo"></i>
                        </button>
                        <span id="balanceCounter" class="balance-counter badge-counter"></span>
                      </div>
                    </div>
                  </div> <!-- End balance-filter-content -->

                  <!-- Résumé des filtres actifs -->
                  <div class="active-filters-summary" id="activeFiltersSummary" style="display: none;">
                    <!-- Les badges générés en JS apparaîtront ici -->
                  </div>
                </div> <!-- End balance-filter-panel -->

                <!-- ═══════════════════════════════════════════════════
                         TABLEAU DES RÉSULTATS
                         ═══════════════════════════════════════════════════ -->
                <div class="balance-table-wrapper" id="balanceResults">
                  <table class="balance-table" id="balanceTable">
                    <thead>
                      <tr class="balance-head-group">
                        <th rowspan="2" style="width:150px;" data-i18n="balance.col.code">Compte / Auxiliaire</th>
                        <th rowspan="2" data-i18n="balance.col.libelle">Libellé</th>
                        <th colspan="2" class="text-center" data-i18n="balance.section.solde_init">Solde Initial</th>
                        <th colspan="2" class="text-center" data-i18n="balance.section.mouvements">Mouvements</th>
                        <th colspan="2" class="text-center" data-i18n="balance.section.solde_final">Solde Final</th>
                      </tr>
                      <tr>
                        <th style="width:130px;text-align:right;" data-i18n="balance.col.debit">Débit</th>
                        <th style="width:130px;text-align:right;" data-i18n="balance.col.credit">Crédit</th>
                        <th style="width:130px;text-align:right;" data-i18n="balance.col.debit">Débit</th>
                        <th style="width:130px;text-align:right;" data-i18n="balance.col.credit">Crédit</th>
                        <th style="width:130px;text-align:right;" data-i18n="balance.col.debit">Débit</th>
                        <th style="width:130px;text-align:right;" data-i18n="balance.col.credit">Crédit</th>
                      </tr>
                    </thead>
                    <tbody id="balanceBody">
                      <tr>
                        <td colspan="8" class="table-empty">
                          <i class="fas fa-balance-scale"></i>
                          <span data-i18n="balance.msg.empty">Aucune donnée</span>
                        </td>
                      </tr>
                    </tbody>
                    <tfoot id="balanceFooter"></tfoot>
                  </table>
                </div>

              </section>
            </div>
      </div>

      <div id="spinnerOverlay" aria-hidden="true">
        <div class="spinner"></div>
      </div>

      <!-- Librairies -->
      <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/csrf.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>

      <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>

      <!-- Scripts applicatifs -->
      <script src="../saisie/js/config.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../saisie/js/utils.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../saisie/js/ui.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/balance-auxiliaire.js?v=<%=AuthHelper.Version %>"></script>

      <div id="toastContainer"></div>
    </form>
  </body>

  </html>
