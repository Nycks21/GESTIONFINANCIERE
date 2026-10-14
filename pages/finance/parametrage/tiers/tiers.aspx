<%@ Page Language="C#" AutoEventWireup="true" CodeFile="tiers.cs" Inherits="tiers" UICulture="Auto" Culture="Auto" %>
  <!DOCTYPE html>
  <html lang="<%= LocalizationHelper.CurrentCultureCode %>">

  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>
      <%= LocalizationHelper.GetString("tiers.title") %> — <%= LocalizationHelper.GetString("app.name") %>
    </title>
    <link rel="stylesheet" href="../../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
  </head>

  <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="tiersFormPage" runat="server">
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
                      <h1><i class="fas fa-users" style="color:#007bff;"></i>
                        <span data-i18n="tiers.title"></span>
                      </h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb" style="float:right;">
                        <li class="breadcrumb-item" data-i18n="menu.finance">Finance</li>
                        <li class="breadcrumb-item"><a href="../generale/generale.aspx"
                            data-i18n="menu.generale">Générale</a></li>
                        <li class="breadcrumb-item active" data-i18n="tiers.title">Tiers</li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <section class="content">
                <!-- STATS -->
                <div class="row tiers-stats">
                  <div class="col-lg-4 col-6">
                    <div class="stat-card stat-card-total">
                      <div class="stat-icon"><i class="fas fa-users"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statTotal">0</span>
                        <span class="stat-label" data-i18n="tiers.stat.total"></span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-4 col-6">
                    <div class="stat-card stat-card-normal">
                      <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statActives">0</span>
                        <span class="stat-label" data-i18n="tiers.stat.active"></span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-4 col-6">
                    <div class="stat-card stat-card-inactive">
                      <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statInactives">0</span>
                        <span class="stat-label" data-i18n="tiers.stat.inactive"></span>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="dash-card">
                  <div class="dash-card-head">
                    <span class="dash-card-title">
                      <i class="fas fa-users"></i>
                      <span data-i18n="tiers.list_title"></span>
                    </span>
                    <div class="action-buttons">
                      <button class="btn btn-success btn-sm" onclick="openAddTiersModal(event)" type="button">
                        <i class="fas fa-plus"></i> <span data-i18n="tiers.btn.add"></span>
                      </button>
                      <button class="btn btn-primary btn-sm" onclick="exportTiersPDF()" type="button">
                        <i class="fas fa-file-pdf"></i> <span data-i18n="tiers.btn.pdf"></span>
                      </button>
                      <button class="btn btn-outline-success btn-sm" onclick="exportTiersToExcelOnly()" type="button">
                        <i class="fas fa-file-excel"></i> <span data-i18n="tiers.btn.excel"></span>
                      </button>
                    </div>
                  </div>

                  <!-- FILTRES -->
                  <div class="dash-card-toolbar">
                    <div class="toolbar-search">
                      <i class="fas fa-search"></i>
                      <input type="text" id="search-filter" class="form-control"
                        data-i18n-attr="placeholder:tiers.search_placeholder" autocomplete="off" />
                    </div>
                    <select id="type-filter" class="form-control toolbar-select">
                      <option value="" data-i18n="tiers.filter.all_types"></option>
                      <option value="FOURNISSEUR" data-i18n="tiers.type.fournisseur"></option>
                      <option value="CLIENT" data-i18n="tiers.type.client"></option>
                      <option value="AGENT" data-i18n="tiers.type.agent"></option>
                      <option value="PARTENAIRE" data-i18n="tiers.type.partenaire"></option>
                      <option value="AUTRE" data-i18n="tiers.type.autre"></option>
                    </select>
                    <select id="compte-filter" class="form-control toolbar-select">
                      <option value="" data-i18n="tiers.filter.all_comptes"></option>
                      <option value="1">PLAN1</option>
                      <option value="2">PLAN2</option>
                      <option value="3">PLAN3</option>
                      <option value="4">PLAN4</option>
                      <option value="5">PLAN5</option>
                      <option value="6">PLAN6</option>
                      <option value="7">PLAN7</option>
                      <option value="8">PLAN8</option>
                      <option value="9">PLAN9</option>
                      <option value="10">PLAN10</option>
                    </select>
                    <select id="status-filter" class="form-control toolbar-select">
                      <option value="" data-i18n="tiers.filter.all_status"></option>
                      <option value="1" data-i18n="tiers.filter.active"></option>
                      <option value="0" data-i18n="tiers.filter.inactive"></option>
                    </select>
                    <select id="rows-per-page-top" class="form-control toolbar-select">
                      <option value="10" data-i18n="tiers.rows_per_page.10"></option>
                      <option value="25" data-i18n="tiers.rows_per_page.25"></option>
                      <option value="50" data-i18n="tiers.rows_per_page.50"></option>
                      <option value="100" data-i18n="tiers.rows_per_page.100"></option>
                      <option value="all" data-i18n="tiers.rows_per_page.all"></option>
                    </select>
                    <button class="btn btn-light btn-sm" onclick="resetFilters()" type="button">
                      <i class="fas fa-undo"></i>
                    </button>
                    <span class="toolbar-counter" id="resultsCounter"></span>
                  </div>

                  <div class="dash-card-body">
                    <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                      <table class="dash-table"
                        style="table-layout:fixed; width:1180px; min-width:100%; border-collapse:collapse;">
                        <thead>
                          <tr style="background-color:#f8f9fa;">
                            <th onclick="sortData('CODE')" style="cursor:pointer; width:120px; text-align:left;">
                              <span data-i18n="tiers.col.code"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('NOM')" style="cursor:pointer; width:240px; text-align:left;">
                              <span data-i18n="tiers.col.nom"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('TYPE_TIERS')" style="cursor:pointer; width:140px; text-align:left;">
                              <span data-i18n="tiers.col.type"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th style="width:220px; text-align:left;" data-i18n="tiers.col.compte_collectif"></th>
                            <th style="width:160px; text-align:left;" data-i18n="tiers.col.email"></th>
                            <th style="width:130px; text-align:left;" data-i18n="tiers.col.telephone"></th>
                            <th onclick="sortData('ACTIVE')" style="cursor:pointer; width:100px; text-align:center;">
                              <span data-i18n="tiers.col.active"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th style="width:180px; text-align:right;" data-i18n="tiers.col.actions"></th>
                          </tr>
                        </thead>
                        <tbody id="tiersTableBody">
                          <tr>
                            <td colspan="8" style="text-align:center;padding:40px;">
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

      <!-- MODALE AJOUT / ÉDITION -->
      <div id="tiersModal" class="modal">
        <input type="hidden" id="editingId" value="" />
        <div class="modal-content" style="max-width:640px;">
          <div class="modal-header">
            <h3 id="modalTitle">
              <i class="fas fa-plus"></i>
              <span data-i18n="tiers.modal.add_title"></span>
            </h3>
            <span class="close" onclick="closeTiersModal()">&times;</span>
          </div>
          <div class="modal-body">

            <div class="form-row" style="display:flex;gap:15px;">
              <div class="form-group" style="flex:0 0 160px;">
                <label>
                  <span data-i18n="tiers.col.code"></span>
                  <span class="text-danger">*</span>
                </label>
                <input type="text" id="tiersCode" class="form-control" maxlength="50" required
                  style="text-transform:uppercase; font-family:monospace;"
                  data-i18n-attr="placeholder:tiers.modal.code_placeholder" />
                <small class="field-error" id="err-tiersCode"></small>
              </div>
              <div class="form-group" style="flex:1;">
                <label>
                  <span data-i18n="tiers.col.nom"></span>
                  <span class="text-danger">*</span>
                </label>
                <input type="text" id="tiersNom" class="form-control" maxlength="250" required
                  data-i18n-attr="placeholder:tiers.modal.nom_placeholder" />
                <small class="field-error" id="err-tiersNom"></small>
              </div>
            </div>

            <div class="form-group">
              <label>
                <span data-i18n="tiers.col.type"></span>
                <span class="text-danger">*</span>
              </label>
              <select id="tiersType" class="form-control" required>
                <option value="">— <span data-i18n="tiers.modal.type_select"></span> —</option>
                <option value="FOURNISSEUR" data-i18n="tiers.type.fournisseur"></option>
                <option value="CLIENT" data-i18n="tiers.type.client"></option>
                <option value="AGENT" data-i18n="tiers.type.agent"></option>
                <option value="PARTENAIRE" data-i18n="tiers.type.partenaire"></option>
                <option value="AUTRE" data-i18n="tiers.type.autre"></option>
              </select>
              <small class="field-error" id="err-tiersType"></small>
            </div>

            <div class="form-group">
              <label>
                <span data-i18n="tiers.col.compte_collectif"></span>
                <span class="text-danger">*</span>
              </label>
              <select id="tiersCompte" class="form-control" required></select>
              <small class="text-muted" data-i18n="tiers.modal.compte_hint"></small>
              <small class="field-error" id="err-tiersCompte"></small>
            </div>

            <div class="form-row" style="display:flex;gap:15px;">
              <div class="form-group" style="flex:1;">
                <label data-i18n="tiers.col.email"></label>
                <input type="email" id="tiersEmail" class="form-control" maxlength="150"
                  data-i18n-attr="placeholder:tiers.modal.email_placeholder" />
              </div>
              <div class="form-group" style="flex:1;">
                <label data-i18n="tiers.col.telephone"></label>
                <input type="text" id="tiersTelephone" class="form-control" maxlength="50"
                  data-i18n-attr="placeholder:tiers.modal.telephone_placeholder" />
              </div>
            </div>

            <div class="form-group">
              <label data-i18n="tiers.col.adresse"></label>
              <textarea id="tiersAdresse" class="form-control" rows="2" maxlength="500"></textarea>
            </div>

            <div class="form-group" style="display:flex; align-items:center; gap:10px;">
              <input type="checkbox" id="tiersActive" style="width:18px;height:18px;cursor:pointer;" checked />
              <label for="tiersActive" style="margin:0; cursor:pointer;">
                <span data-i18n="tiers.modal.active_label"></span>
              </label>
            </div>

          </div>
          <div class="modal-footer">
            <button class="btn btn-primary" onclick="saveTiers(event)" type="button">
              <i class="fas fa-save"></i> <span data-i18n="button.save"></span>
            </button>
            <button class="btn btn-secondary" onclick="closeTiersModal()" type="button">
              <i class="fas fa-times"></i> <span data-i18n="button.cancel"></span>
            </button>
          </div>
        </div>
      </div>

      <div id="spinnerOverlay" aria-hidden="true" style="display:none;visibility:hidden;">
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
