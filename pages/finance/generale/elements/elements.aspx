<%@ Page Language="C#" AutoEventWireup="true" CodeFile="elements.cs" Inherits="elements" UICulture="Auto" Culture="Auto"
  %>
  <!DOCTYPE html>
  <html lang="<%= LocalizationHelper.CurrentCultureCode %>">

  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>
      <%= LocalizationHelper.GetString("elements.title") %> — <%= LocalizationHelper.GetString("app.name") %>
    </title>
    <link rel="stylesheet" href="../../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../css/style.css?v=<%=AuthHelper.Version %>" />
  </head>

  <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="elementsFormPage" runat="server">
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
                        <i class="fas fa-sitemap" style="color:#007bff;"></i>
                        <span data-i18n="elements.title"></span>
                        <small style="color:#6c757d; font-size:14px; font-weight:400;">
                          — <span id="planNameHeader">…</span>
                        </small>
                      </h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb" style="float:right;">
                        <li class="breadcrumb-item" data-i18n="menu.finance">Finance</li>
                        <li class="breadcrumb-item"><a href="../generale.aspx" data-i18n="menu.generale">Générale</a>
                        </li>
                        <li class="breadcrumb-item active" data-i18n="elements.title">Éléments</li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <section class="content">
                <!-- Fiche plan -->
                <div class="plan-info-card" id="planInfoCard">
                  <div class="plan-info-icon"><i class="fas fa-book"></i></div>
                  <div class="plan-info-body">
                    <div class="plan-info-title" id="planInfoTitle">…</div>
                    <div class="plan-info-meta">
                      <span><i class="fas fa-code"></i> <span id="planInfoCode">—</span></span>
                      <span><i class="fas fa-layer-group"></i> <span data-i18n="elements.plan.niveau"></span>
                        <strong id="planInfoNiveau">—</strong></span>
                      <span><i class="fas fa-tag"></i> <span id="planInfoType">—</span></span>
                    </div>
                  </div>
                  <a href="../generale.aspx" class="btn btn-secondary btn-sm">
                    <i class="fas fa-arrow-left"></i> <span data-i18n="button.back"></span>
                  </a>
                </div>

                <!-- Onglets niveaux -->
                <div class="dash-card">
                  <div class="dash-card-head">
                    <span class="dash-card-title">
                      <i class="fas fa-sitemap"></i>
                      <span data-i18n="elements.list_title"></span>
                    </span>
                    <div class="action-buttons">
                      <button class="btn btn-success btn-sm" onclick="openAddElementModal(event)" type="button">
                        <i class="fas fa-plus"></i> <span data-i18n="elements.btn.add"></span>
                      </button>
                    </div>
                  </div>

                  <!-- Barre onglets par niveau -->
                  <div class="level-tabs" id="levelTabs"></div>

                  <!-- Barre d'outils -->
                  <div class="dash-card-toolbar">
                    <div class="toolbar-search">
                      <i class="fas fa-search"></i>
                      <input type="text" id="search-filter" class="form-control"
                        data-i18n-attr="placeholder:elements.search_placeholder" autocomplete="off" />
                    </div>
                    <select id="active-filter" class="form-control toolbar-select">
                      <option value="" data-i18n="elements.filter.all_active"></option>
                      <option value="1" data-i18n="elements.filter.active"></option>
                      <option value="0" data-i18n="elements.filter.inactive"></option>
                    </select>
                    <button class="btn btn-light btn-sm" onclick="resetFilters()" type="button"
                      data-i18n-attr="title:elements.reset_filters">
                      <i class="fas fa-undo"></i>
                    </button>
                    <span class="toolbar-counter" id="resultsCounter"></span>
                  </div>

                  <div class="dash-card-body">
                    <div style="overflow-x:auto; border:1px solid #dee2e6; border-radius:8px;">
                      <table class="dash-table tree-table">
                        <thead>
                          <tr style="background-color:#f8f9fa;">
                            <th style="width:280px; text-align:left;" data-i18n="elements.col.code"></th>
                            <th style="width:280px; text-align:left;" data-i18n="elements.col.libelle"></th>
                            <th style="width:90px;  text-align:center;" data-i18n="elements.col.niveau"></th>
                            <th style="width:130px; text-align:left;" data-i18n="elements.col.type"></th>
                            <th style="width:100px; text-align:center;" data-i18n="elements.col.active"></th>
                            <th style="width:140px; text-align:right;" data-i18n="elements.col.actions"></th>
                          </tr>
                        </thead>
                        <tbody id="elementsTableBody">
                          <tr>
                            <td colspan="6" style="text-align:center;padding:40px;">
                              <i class="fas fa-spinner fa-spin" style="font-size:24px;color:#ccc;"></i>
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              </section>
            </div>
      </div>

      <!-- MODALE AJOUT / ÉDITION ÉLÉMENT -->
      <div id="elementModal" class="modal">
        <input type="hidden" id="elementId" value="" />
        <div class="modal-content" style="max-width:600px;">
          <div class="modal-header">
            <h3 id="elementModalTitle">
              <i class="fas fa-plus"></i>
              <span data-i18n="elements.modal.add_title"></span>
            </h3>
            <span class="close" onclick="closeElementModal()">&times;</span>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>
                <span data-i18n="elements.col.code"></span>
                <span class="text-danger">*</span>
              </label>
              <input type="text" id="elementCode" class="form-control" maxlength="50"
                style="text-transform:uppercase; font-family:monospace;"
                data-i18n-attr="placeholder:elements.modal.code_placeholder" />
              <small class="text-muted" id="codeHint" style="display:none;"></small>
              <small class="field-error" id="err-elementCode"></small>
            </div>

            <div class="form-group">
              <label>
                <span data-i18n="elements.col.libelle"></span>
                <span class="text-danger">*</span>
              </label>
              <input type="text" id="elementLibelle" class="form-control" maxlength="250"
                data-i18n-attr="placeholder:elements.modal.libelle_placeholder" />
              <small class="field-error" id="err-elementLibelle"></small>
            </div>

            <div class="form-group">
              <label data-i18n="elements.modal.parent_label"></label>
              <select id="elementParent" class="form-control"></select>
              <small class="text-muted" data-i18n="elements.modal.parent_hint"></small>
            </div>

            <div class="form-group">
              <label>
                <span data-i18n="elements.col.niveau"></span>
              </label>
              <input type="text" id="elementNiveau" class="form-control" readonly />
            </div>

            <!-- Case Auxiliaire — visible uniquement pour les comptes de dernier niveau -->
            <div class="form-group" id="grpAuxiliaire" style="display:none;">
              <label style="display:flex; align-items:center; gap:10px; cursor:pointer;">
                <input type="checkbox" id="elementAuxiliaire"
                  style="width:18px;height:18px;accent-color:#2563EB;cursor:pointer;" />
                <span style="font-weight:600;">
                  <i class="fas fa-users" style="color:#2563EB;"></i>
                  <span data-i18n="elements.modal.auxiliaire_label"></span>
                </span>
              </label>
              <small class="text-muted" style="display:block;margin-top:4px;margin-left:28px;"
                data-i18n="elements.modal.auxiliaire_hint"></small>
              <small class="field-error" id="err-elementAuxiliaire"></small>
            </div>

            <div class="form-group" style="display:flex; align-items:center; gap:10px;">
              <input type="checkbox" id="elementActive" style="width:18px;height:18px;cursor:pointer;" checked />
              <label for="elementActive" style="margin:0; cursor:pointer;">
                <span data-i18n="elements.modal.active_label"></span>
              </label>
            </div>

          </div>
          <div class="modal-footer">
            <button class="btn btn-primary" onclick="saveElement(event)" type="button">
              <i class="fas fa-save"></i> <span data-i18n="button.save"></span>
            </button>
            <button class="btn btn-secondary" onclick="closeElementModal()" type="button">
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
      <script src="../../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../../_assets/js/csrf.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
      <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>
      <script src="../js/config.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../js/utils.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../js/ui.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../js/crud.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/tree.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
      <div id="toastContainer"></div>
    </form>
  </body>

  </html>
