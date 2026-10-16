<%@ Page Language="C#" AutoEventWireup="true" CodeFile="exercices.cs" Inherits="exercices" UICulture="Auto"
  Culture="Auto" %>
  <!DOCTYPE html>
  <html lang="<%= LocalizationHelper.CurrentCultureCode %>">

  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <script src="../../_assets/js/theme-init.js?v=<%=AuthHelper.Version %>"></script>
    <title>
      <%= LocalizationHelper.GetString("exercices.title") %> — <%= LocalizationHelper.GetString("app.name") %>
    </title>
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
  </head>

  <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <script>document.body.classList.toggle("dark-mode", document.documentElement.classList.contains("dark-mode"));</script>
    <form id="exerciceFormPage" runat="server">
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
                      <h1><i class="fas fa-calendar-alt" style="color:#007bff;"></i>
                        <span data-i18n="exercices.title"></span>
                      </h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb" style="float:right;">
                        <li class="breadcrumb-item"><a href="../generale/generale.aspx" data-i18n="menu.generale">Générale</a></li>
                        <li class="breadcrumb-item active" data-i18n="menu.exercices">Exercices</li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <section class="content" id="section-exercices">
                <div class="row exercices-stats" id="exercicesStats">
                  <div class="col-lg-3 col-6">
                    <div class="stat-card stat-card-total">
                      <div class="stat-icon"><i class="fas fa-calendar-alt"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statTotal">0</span>
                        <span class="stat-label" data-i18n="exercices.stat.total"></span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-3 col-6">
                    <div class="stat-card stat-card-normal">
                      <div class="stat-icon"><i class="fas fa-lock-open"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statOuverts">0</span>
                        <span class="stat-label" data-i18n="exercices.stat.ouverts"></span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-3 col-6">
                    <div class="stat-card stat-card-inactive">
                      <div class="stat-icon"><i class="fas fa-lock"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statClotures">0</span>
                        <span class="stat-label" data-i18n="exercices.stat.clotures"></span>
                      </div>
                    </div>
                  </div>
                  <div class="col-lg-3 col-6">
                    <div class="stat-card stat-card-inactive">
                      <div class="stat-icon"><i class="fas fa-archive"></i></div>
                      <div class="stat-body">
                        <span class="stat-value" id="statArchives">0</span>
                        <span class="stat-label" data-i18n="exercices.stat.archives"></span>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="dash-card">
                  <div class="dash-card-head">
                    <span class="dash-card-title">
                      <i class="fas fa-calendar-alt"></i>
                      <span data-i18n="exercices.list_title"></span>
                    </span>
                    <div class="action-buttons">
                      <a href="../../generale/generale.aspx" class="btn btn-secondary btn-sm">
                        <i class="fas fa-arrow-left"></i> <span data-i18n="button.back"></span>
                      </a>
                      <button class="btn btn-success btn-sm" onclick="openAddExerciceModal(event)" type="button">
                        <i class="fas fa-plus"></i> <span data-i18n="exercices.btn.add"></span>
                      </button>
                      <button class="btn btn-primary btn-sm" onclick="exportExercicesPDF()" type="button">
                        <i class="fas fa-file-pdf"></i> <span data-i18n="exercices.btn.pdf"></span>
                      </button>
                      <button class="btn btn-outline-success btn-sm" onclick="exportExercicesToExcelOnly()"
                        type="button">
                        <i class="fas fa-file-excel"></i> <span data-i18n="exercices.btn.excel"></span>
                      </button>
                    </div>
                  </div>

                  <div class="dash-card-toolbar">
                    <div class="toolbar-search">
                      <i class="fas fa-search"></i>
                      <input type="text" id="search-filter" class="form-control"
                        data-i18n-attr="placeholder:exercices.search_placeholder" autocomplete="off" />
                    </div>
                    <select id="status-filter" class="form-control toolbar-select">
                      <option value="" data-i18n="exercices.filter.all_status"></option>
                      <option value="OUVERT" data-i18n="exercices.status.ouvert"></option>
                      <option value="CLOTURE" data-i18n="exercices.status.cloture"></option>
                      <option value="ARCHIVE" data-i18n="exercices.status.archive"></option>
                    </select>
                    <select id="active-filter" class="form-control toolbar-select">
                      <option value="" data-i18n="exercices.filter.all_active"></option>
                      <option value="1" data-i18n="exercices.filter.active"></option>
                      <option value="0" data-i18n="exercices.filter.inactive"></option>
                    </select>
                    <select id="rows-per-page-top" class="form-control toolbar-select">
                      <option value="10" data-i18n="exercices.rows_per_page.10"></option>
                      <option value="25" data-i18n="exercices.rows_per_page.25"></option>
                      <option value="50" data-i18n="exercices.rows_per_page.50"></option>
                      <option value="100" data-i18n="exercices.rows_per_page.100"></option>
                      <option value="all" data-i18n="exercices.rows_per_page.all"></option>
                    </select>
                    <button class="btn btn-light btn-sm" id="btnResetFilters" onclick="resetFilters()" type="button"
                      data-i18n-attr="title:exercices.reset_filters">
                      <i class="fas fa-undo"></i>
                    </button>
                    <span class="toolbar-counter" id="resultsCounter" data-i18n="exercices.counter.zero"></span>
                  </div>

                  <div class="dash-card-body">
                    <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                      <table class="dash-table"
                        style="table-layout:fixed; width:1180px; min-width:100%; border-collapse:collapse;">
                        <thead>
                          <tr style="background-color:#f8f9fa;">
                            <th onclick="sortData('CODE')" style="cursor:pointer; width:110px; text-align:left;">
                              <span data-i18n="exercices.table.code"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('LIBELLE')" style="cursor:pointer; width:220px; text-align:left;">
                              <span data-i18n="exercices.table.libelle"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('DATE_DEBUT')"
                              style="cursor:pointer; width:130px; text-align:center;">
                              <span data-i18n="exercices.table.date_debut"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('DATE_FIN')" style="cursor:pointer; width:130px; text-align:center;">
                              <span data-i18n="exercices.table.date_fin"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th style="width:110px; text-align:center;" data-i18n="exercices.table.duree"></th>
                            <th onclick="sortData('STATUT')" style="cursor:pointer; width:130px; text-align:center;">
                              <span data-i18n="exercices.table.statut"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th onclick="sortData('ACTIVE')" style="cursor:pointer; width:100px; text-align:left;">
                              <span data-i18n="exercices.table.active"></span> <i class="fas fa-sort ml-1"></i>
                            </th>
                            <th style="width:190px; text-align:right;" data-i18n="exercices.table.actions"></th>
                          </tr>
                        </thead>
                        <tbody id="exercicesTableBody">
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

      <!-- MODALE AJOUT / MODIFICATION EXERCICE -->
      <div id="exerciceModal" class="modal">
        <input type="hidden" id="editingId" value="" />
        <div class="modal-content modal-exercice" style="max-width:640px;">
          <div class="modal-header">
            <h3 id="modalTitle">
              <i class="fas fa-calendar-alt"></i>
              <span data-i18n="exercices.modal.add_title"></span>
            </h3>
            <span class="close" onclick="closeExerciceModal()">&times;</span>
          </div>
          <div class="modal-body">

            <div class="form-group">
              <label>
                <span data-i18n="exercices.modal.code_label"></span>
                <span class="text-danger">*</span>
                <small class="text-muted" data-i18n="exercices.modal.code_hint"></small>
              </label>
              <input type="text" id="exerciceCode" class="form-control" maxlength="20" required
                style="text-transform:uppercase;" data-i18n-attr="placeholder:exercices.modal.code_placeholder" />
              <small class="field-error" id="err-exerciceCode"></small>
            </div>

            <div class="form-group">
              <label>
                <span data-i18n="exercices.modal.libelle_label"></span>
                <span class="text-danger">*</span>
              </label>
              <input type="text" id="exerciceLibelle" class="form-control" maxlength="100" required
                data-i18n-attr="placeholder:exercices.modal.libelle_placeholder" />
              <small class="field-error" id="err-exerciceLibelle"></small>
            </div>

            <div class="form-row" style="display:flex;gap:15px;">
              <div class="form-group" style="flex:1;">
                <label>
                  <span data-i18n="exercices.modal.date_debut_label"></span>
                  <span class="text-danger">*</span>
                </label>
                <input type="date" id="exerciceDateDebut" class="form-control" required />
                <small class="field-error" id="err-exerciceDateDebut"></small>
              </div>
              <div class="form-group" style="flex:1;">
                <label>
                  <span data-i18n="exercices.modal.date_fin_label"></span>
                  <span class="text-danger">*</span>
                </label>
                <input type="date" id="exerciceDateFin" class="form-control" required />
                <small class="field-error" id="err-exerciceDateFin"></small>
              </div>
            </div>

            <div class="form-group">
              <label>
                <span data-i18n="exercices.modal.statut_label"></span>
                <span class="text-danger">*</span>
              </label>
              <select id="exerciceStatut" class="form-control">
                <option value="OUVERT" data-i18n="exercices.status.ouvert"></option>
                <option value="CLOTURE" data-i18n="exercices.status.cloture"></option>
                <option value="ARCHIVE" data-i18n="exercices.status.archive"></option>
              </select>
              <small class="text-muted" data-i18n="exercices.modal.statut_hint"></small>
            </div>

            <div class="form-group">
              <label>
                <span data-i18n="exercices.modal.active_label"></span>
                <span class="text-danger">*</span>
              </label>
              <select id="exerciceActive" class="form-control">
                <option value="1" data-i18n="button.yes"></option>
                <option value="0" data-i18n="button.no"></option>
              </select>
            </div>

          </div>
          <div class="modal-footer">
            <button class="btn btn-primary" id="btnSaveExercice" onclick="saveExercice(event)" type="button">
              <i class="fas fa-save"></i> <span data-i18n="button.save"></span>
            </button>
            <button class="btn btn-danger" onclick="closeExerciceModal()" type="button">
              <i class="fas fa-times"></i> <span data-i18n="button.cancel"></span>
            </button>
          </div>
        </div>
      </div>

      <div id="spinnerOverlays" aria-hidden="true" style="display:none;visibility:hidden;">
        <div class="spinner"></div>
      </div>

      <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/jspdf.umd.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/jspdf.plugin.autotable.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/xlsx.full.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/vfs_fonts.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/csrf.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
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
