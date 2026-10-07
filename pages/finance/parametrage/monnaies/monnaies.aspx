<%@ Page Language="C#" AutoEventWireup="true" CodeFile="monnaies.aspx.cs" Inherits="monnaies" UICulture="Auto" Culture="Auto" %>
<!DOCTYPE html>
<html lang="<%= LocalizationHelper.CurrentCultureCode %>">

<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title><%= LocalizationHelper.GetString("monnaies.title") %> — <%= LocalizationHelper.GetString("app.name") %></title>
  <link rel="stylesheet" href="../../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
</head>

<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
  <form id="monnaieForm" runat="server">
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
                  <i class="fas fa-coins" style="color:#f39c12;"></i>
                  <span data-i18n="monnaies.title"></span>
                </h1>
              </div>
              <div class="col-lg-6">
                <ol class="breadcrumb" style="float:right;">
                  <li class="breadcrumb-item" data-i18n="menu.finance"></li>
                  <li class="breadcrumb-item" data-i18n="menu.parametrage"></li>
                  <li class="breadcrumb-item active" data-i18n="menu.monnaies"></li>
                </ol>
              </div>
            </div>
          </div>
        </div>

        <section class="content" id="section-monnaies">

          <!-- CARTES DE SYNTHÈSE -->
          <div class="row monnaies-stats" id="monnaiesStats">
            <div class="col-lg-3 col-6">
              <div class="stat-card stat-card-total">
                <div class="stat-icon"><i class="fas fa-coins"></i></div>
                <div class="stat-body">
                  <span class="stat-value" id="statTotal">0</span>
                  <span class="stat-label" data-i18n="monnaies.stat.total"></span>
                </div>
              </div>
            </div>
            <div class="col-lg-3 col-6">
              <div class="stat-card stat-card-normal">
                <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
                <div class="stat-body">
                  <span class="stat-value" id="statActives">0</span>
                  <span class="stat-label" data-i18n="monnaies.stat.active"></span>
                </div>
              </div>
            </div>
            <div class="col-lg-3 col-6">
              <div class="stat-card stat-card-inactive">
                <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
                <div class="stat-body">
                  <span class="stat-value" id="statInactives">0</span>
                  <span class="stat-label" data-i18n="monnaies.stat.inactive"></span>
                </div>
              </div>
            </div>
            <div class="col-lg-3 col-6">
              <div class="stat-card stat-card-info">
                <div class="stat-icon"><i class="fas fa-star"></i></div>
                <div class="stat-body">
                  <span class="stat-value" id="statReference">0</span>
                  <span class="stat-label" data-i18n="monnaies.stat.reference"></span>
                </div>
              </div>
            </div>
          </div>

          <div class="dash-card">
            <div class="dash-card-head">
              <span class="dash-card-title">
                <i class="fas fa-coins"></i>
                <span data-i18n="monnaies.list_title"></span>
              </span>
              <div class="action-buttons">
                <button class="btn btn-success btn-sm" onclick="openAddMonnaieModal(event)" type="button">
                  <i class="fas fa-plus"></i> <span data-i18n="monnaies.btn.add"></span>
                </button>
                <button class="btn btn-primary btn-sm" onclick="exportMonnaiesPDF()" type="button">
                  <i class="fas fa-file-pdf"></i> <span data-i18n="monnaies.btn.pdf"></span>
                </button>
                <button class="btn btn-outline-success btn-sm" onclick="exportMonnaiesToExcelOnly()" type="button">
                  <i class="fas fa-file-excel"></i> <span data-i18n="monnaies.btn.excel"></span>
                </button>
              </div>
            </div>

            <!-- BARRE DE FILTRES -->
            <div class="dash-card-toolbar">
              <div class="toolbar-search">
                <i class="fas fa-search"></i>
                <input type="text" id="search-filter" class="form-control"
                  data-i18n-attr="placeholder:monnaies.search_placeholder" autocomplete="off" />
              </div>
              <select id="status-filter" class="form-control toolbar-select">
                <option value="" data-i18n="monnaies.filter.all_status"></option>
                <option value="1" data-i18n="monnaies.filter.active"></option>
                <option value="0" data-i18n="monnaies.filter.inactive"></option>
              </select>
              <select id="rows-per-page-top" class="form-control toolbar-select">
                <option value="10" data-i18n="monnaies.rows_per_page.10"></option>
                <option value="25" data-i18n="monnaies.rows_per_page.25"></option>
                <option value="50" data-i18n="monnaies.rows_per_page.50"></option>
                <option value="100" data-i18n="monnaies.rows_per_page.100"></option>
                <option value="all" data-i18n="monnaies.rows_per_page.all"></option>
              </select>
              <button class="btn btn-light btn-sm" id="btnResetFilters" onclick="resetFilters()" type="button"
                data-i18n-attr="title:monnaies.reset_filters">
                <i class="fas fa-undo"></i>
              </button>
              <span class="toolbar-counter" id="resultsCounter" data-i18n="monnaies.counter.zero"></span>
            </div>

            <div class="dash-card-body">
              <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                <table class="dash-table"
                  style="table-layout:fixed; width:100%; min-width:900px; border-collapse:collapse;">
                  <thead>
                    <tr style="background-color:#f8f9fa; text-align:left;">
                      <th onclick="sortData('CODE')" style="cursor:pointer; width:100px;">
                        <span data-i18n="monnaies.table.code"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th onclick="sortData('NOM')" style="cursor:pointer; width:200px;">
                        <span data-i18n="monnaies.table.nom"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th style="width:80px;">
                        <span data-i18n="monnaies.table.symbole"></span>
                      </th>
                      <th style="width:80px; text-align:center;">
                        <span data-i18n="monnaies.table.decimales"></span>
                      </th>
                      <th style="width:130px; text-align:right;">
                        <span data-i18n="monnaies.table.taux"></span>
                      </th>
                      <th style="width:100px; text-align:center;">
                        <span data-i18n="monnaies.table.reference"></span>
                      </th>
                      <th onclick="sortData('ACTIVE')" style="cursor:pointer; width:100px;">
                        <span data-i18n="monnaies.table.statut"></span> <i class="fas fa-sort ml-1"></i>
                      </th>
                      <th style="width:130px;">
                        <span data-i18n="monnaies.table.actions"></span>
                      </th>
                    </tr>
                  </thead>
                  <tbody id="monnaiesTableBody">
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

    <!-- MODALE AJOUT / MODIFICATION MONNAIE -->
    <div id="monnaieModal" class="modal">
      <input type="hidden" id="editingId" value="" />
      <div class="modal-content modal-monnaie" style="max-width:650px;">
        <div class="modal-header">
          <h3 id="modalTitle">
            <i class="fas fa-coins"></i>
            <span data-i18n="monnaies.modal.add_title"></span>
          </h3>
          <span class="close" onclick="closeMonnaieModal()">&times;</span>
        </div>
        <div class="modal-body">
          <div class="form-row">
            <div class="form-group col-6">
              <label>
                <span data-i18n="monnaies.modal.code_label"></span>
                <span class="text-danger">*</span>
              </label>
              <input type="text" id="monnaieCode" class="form-control" maxlength="10"
                style="text-transform:uppercase;"
                data-i18n-attr="placeholder:monnaies.modal.code_placeholder" required />
              <small class="field-hint" data-i18n="monnaies.modal.code_hint"></small>
              <small class="field-error" id="err-monnaieCode"></small>
            </div>
            <div class="form-group col-6">
              <label>
                <span data-i18n="monnaies.modal.symbole_label"></span>
              </label>
              <input type="text" id="monnaieSymbole" class="form-control" maxlength="10"
                data-i18n-attr="placeholder:monnaies.modal.symbole_placeholder" />
              <small class="field-error" id="err-monnaieSymbole"></small>
            </div>
          </div>

          <div class="form-group">
            <label>
              <span data-i18n="monnaies.modal.nom_label"></span>
              <span class="text-danger">*</span>
            </label>
            <input type="text" id="monnaieNom" class="form-control"
              data-i18n-attr="placeholder:monnaies.modal.nom_placeholder" required />
            <small class="field-error" id="err-monnaieNom"></small>
          </div>

          <div class="form-row">
            <div class="form-group col-4">
              <label>
                <span data-i18n="monnaies.modal.decimales_label"></span>
                <span class="text-danger">*</span>
              </label>
              <input type="number" id="monnaieDecimales" class="form-control" min="0" max="6" value="2" required />
              <small class="field-error" id="err-monnaieDecimales"></small>
            </div>
            <div class="form-group col-4">
              <label>
                <span data-i18n="monnaies.modal.taux_label"></span>
              </label>
              <input type="number" id="monnaieTaux" class="form-control" step="0.00000001" min="0"
                placeholder="1.00000000" />
              <small class="field-hint" data-i18n="monnaies.modal.taux_hint"></small>
              <small class="field-error" id="err-monnaieTaux"></small>
            </div>
            <div class="form-group col-4">
              <label>
                <span data-i18n="monnaies.modal.reference_label"></span>
              </label>
              <select id="monnaieReference" class="form-control">
                <option value="0" data-i18n="button.no"></option>
                <option value="1" data-i18n="button.yes"></option>
              </select>
              <small class="field-hint" data-i18n="monnaies.modal.reference_hint"></small>
            </div>
          </div>

          <div class="form-group">
            <label>
              <span data-i18n="monnaies.modal.actif_label"></span>
              <span class="text-danger">*</span>
            </label>
            <select id="monnaieActif" class="form-control">
              <option value="1" data-i18n="button.yes"></option>
              <option value="0" data-i18n="button.no"></option>
            </select>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn btn-primary" id="btnSaveMonnaie" onclick="saveMonnaie(event)" type="button">
            <i class="fas fa-save"></i> <span data-i18n="button.save"></span>
          </button>
          <button class="btn btn-danger" onclick="closeMonnaieModal()" type="button">
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
