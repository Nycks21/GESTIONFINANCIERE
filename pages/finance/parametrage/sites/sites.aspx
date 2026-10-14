<%@ Page Language="C#" AutoEventWireup="true" CodeFile="sites.cs" Inherits="sites" UICulture="Auto" Culture="Auto" %>
  <!DOCTYPE html>
  <html lang="<%= LocalizationHelper.CurrentCultureCode %>">

  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <script src="../../../_assets/js/theme-init.js?v=<%=AuthHelper.Version %>"></script>
    <title>
      <%= LocalizationHelper.GetString("sites.title") %> — <%= LocalizationHelper.GetString("app.name") %>
    </title>
    <link rel="stylesheet" href="../../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
  </head>

  <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <script>document.body.classList.toggle("dark-mode", document.documentElement.classList.contains("dark-mode"));</script>
    <form id="siteFormPage" runat="server">
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
                      <h1>
                        <i class="fas fa-map-marker-alt" style="color:#007bff;"></i>
                        <span data-i18n="sites.title"></span>
                      </h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb" style="float:right;">
                        <li class="breadcrumb-item" data-i18n="menu.finance">Finance</li>
                        <li class="breadcrumb-item active" data-i18n="menu.sites">Sites</li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <section class="content" id="section-sites">

                <!-- CARTES DE SYNTHÈSE -->
                <div class="row sites-stats" id="sitesStats">
                  <div class="col-lg-4 col-6">
                    <div class="stat-card stat-card-total">
                      <div class="stat-icon"><i class="fas fa-map-marker-alt"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statTotal">0</span>
                        <span class="stat-label" data-i18n="sites.stat.total"></span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-4 col-6">
                    <div class="stat-card stat-card-normal">
                      <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statActives">0</span>
                        <span class="stat-label" data-i18n="sites.stat.active"></span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-4 col-6">
                    <div class="stat-card stat-card-inactive">
                      <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statInactives">0</span>
                        <span class="stat-label" data-i18n="sites.stat.inactive"></span>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="dash-card">
                  <div class="dash-card-head">
                    <span class="dash-card-title">
                      <i class="fas fa-map-marker-alt"></i>
                      <span data-i18n="sites.list_title"></span>
                    </span>
                    <div class="action-buttons">
                      <a href="../../generale/generale.aspx" class="btn btn-secondary btn-sm">
                        <i class="fas fa-arrow-left"></i> <span data-i18n="button.back"></span>
                      </a>
                      <button class="btn btn-success btn-sm" onclick="openAddSiteModal(event)" type="button">
                        <i class="fas fa-plus"></i> <span data-i18n="sites.btn.add"></span>
                      </button>
                      <button class="btn btn-primary btn-sm" onclick="exportSitesPDF()" type="button">
                        <i class="fas fa-file-pdf"></i> <span data-i18n="sites.btn.pdf"></span>
                      </button>
                      <button class="btn btn-outline-success btn-sm" onclick="exportSitesToExcelOnly()" type="button">
                        <i class="fas fa-file-excel"></i> <span data-i18n="sites.btn.excel"></span>
                      </button>
                    </div>
                  </div>

                  <!-- BARRE DE FILTRES -->
                  <div class="dash-card-toolbar">
                    <div class="toolbar-search">
                      <i class="fas fa-search"></i>
                      <input type="text" id="search-filter" class="form-control"
                        data-i18n-attr="placeholder:sites.search_placeholder" autocomplete="off" />
                    </div>
                    <select id="status-filter" class="form-control toolbar-select">
                      <option value="" data-i18n="sites.filter.all_status"></option>
                      <option value="1" data-i18n="sites.filter.active"></option>
                      <option value="0" data-i18n="sites.filter.inactive"></option>
                    </select>
                    <select id="rows-per-page-top" class="form-control toolbar-select">
                      <option value="10" data-i18n="sites.rows_per_page.10"></option>
                      <option value="25" data-i18n="sites.rows_per_page.25"></option>
                      <option value="50" data-i18n="sites.rows_per_page.50"></option>
                      <option value="100" data-i18n="sites.rows_per_page.100"></option>
                      <option value="all" data-i18n="sites.rows_per_page.all"></option>
                    </select>
                    <button class="btn btn-light btn-sm" id="btnResetFilters" onclick="resetFilters()" type="button"
                      data-i18n-attr="title:sites.reset_filters">
                      <i class="fas fa-undo"></i>
                    </button>
                    <span class="toolbar-counter" id="resultsCounter" data-i18n="sites.counter.zero"></span>
                  </div>

                  <div class="dash-card-body">
                    <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                      <table class="dash-table"
                        style="table-layout:fixed; width:1020px; min-width:100%; border-collapse:collapse;">
                        <thead>
                          <tr style="background-color:#f8f9fa;">
                            <th onclick="sortData('CODE')" style="cursor:pointer; width:140px; text-align:left;">
                              <span data-i18n="sites.table.code"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('NOM')" style="cursor:pointer; width:250px; text-align:left;">
                              <span data-i18n="sites.table.nom"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th style="width:300px; text-align:left;" data-i18n="sites.table.description"></th>
                            <th onclick="sortData('EN_COURS')" style="cursor:pointer; width:100px; text-align:center;">
                              <span data-i18n="sites.table.etat"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('ACTIVE')" style="cursor:pointer; width:100px; text-align:left;">
                              <span data-i18n="sites.table.statut"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th style="width:130px; text-align:right;" data-i18n="sites.table.actions"></th>
                          </tr>
                        </thead>
                        <tbody id="sitesTableBody">
                          <tr>
                            <td colspan="6" style="text-align:center;padding:40px;">
                              <i class="fas fa-spinner fa-spin" style="font-size:24px;color:#ccc;"></i>
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                    <div class="pagination-wrapper" id="paginationWrapper"></div>
                  </div>

                </div>
              </section>
            </div>
      </div>

      <!-- MODALE AJOUT / MODIFICATION SITE -->
      <div id="siteModal" class="modal">
        <input type="hidden" id="editingId" value="" />
        <div class="modal-content modal-site" style="max-width:620px;">
          <div class="modal-header">
            <h3 id="modalTitle">
              <i class="fas fa-map-marker-alt"></i>
              <span data-i18n="sites.modal.add_title"></span>
            </h3>
            <span class="close" onclick="closeSiteModal()">&times;</span>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>
                <span data-i18n="sites.modal.code_label"></span>
                <small class="text-muted" data-i18n="sites.modal.code_hint"></small>
              </label>
              <input type="text" id="siteCode" class="form-control"
                data-i18n-attr="placeholder:sites.modal.code_auto_placeholder" readonly />
              <small class="field-error" id="err-siteCode"></small>
            </div>
            <div class="form-group">
              <label>
                <span data-i18n="sites.modal.nom_label"></span>
                <span class="text-danger">*</span>
              </label>
              <input type="text" id="siteNom" class="form-control" maxlength="200"
                data-i18n-attr="placeholder:sites.modal.nom_placeholder" required />
              <small class="field-error" id="err-siteNom"></small>
            </div>
            <div class="form-group">
              <label data-i18n="sites.modal.description_label"></label>
              <textarea id="siteDescription" class="form-control" rows="3" maxlength="500"
                data-i18n-attr="placeholder:sites.modal.description_placeholder"></textarea>
              <small class="field-error" id="err-siteDescription"></small>
            </div>
            <div class="form-group">
              <label>
                <span data-i18n="sites.modal.actif_label"></span>
                <span class="text-danger">*</span>
              </label>
              <select id="siteActif" class="form-control">
                <option value="1" data-i18n="button.yes"></option>
                <option value="0" data-i18n="button.no"></option>
              </select>
            </div>
            <div class="form-group">
              <label style="display:flex;align-items:center;gap:10px;cursor:pointer;">
                <input type="checkbox" id="siteEnCours"
                  style="width:18px;height:18px;accent-color:#10b981;cursor:pointer;" />
                <span style="font-weight:600;">
                  <i class="fas fa-circle-check" style="color:#10b981;"></i>
                  <span data-i18n="sites.modal.en_cours_label"></span>
                </span>
              </label>
              <small class="text-muted" style="display:block;margin-top:4px;margin-left:28px;"
                data-i18n="sites.modal.en_cours_hint"></small>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn btn-primary" id="btnSaveSite" onclick="saveSite(event)" type="button">
              <i class="fas fa-save"></i> <span data-i18n="button.save"></span>
            </button>
            <button class="btn btn-danger" onclick="closeSiteModal()" type="button">
              <i class="fas fa-times"></i> <span data-i18n="button.cancel"></span>
            </button>
          </div>
        </div>
      </div>

      <div id="spinnerOverlays" aria-hidden="true" style="display:none;visibility:hidden;">
        <div class="spinner"></div>
      </div>

      <script src="../../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../../_assets/js/jspdf.umd.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../../_assets/js/jspdf.plugin.autotable.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../../_assets/js/xlsx.full.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../../_assets/js/vfs_fonts.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../../_assets/js/csrf.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
      <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>
      <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/export.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
      <div id="toastContainer"></div>
    </form>
  </body>

  </html>
