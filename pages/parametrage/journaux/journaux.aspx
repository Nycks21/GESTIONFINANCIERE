<%@ Page Language="C#" AutoEventWireup="true" CodeFile="journaux.cs" Inherits="journaux" UICulture="Auto" Culture="Auto" %>
<!DOCTYPE html>
<html lang="<%= LocalizationHelper.CurrentCultureCode %>">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title><%= LocalizationHelper.GetString("journaux.title") %> — <%= LocalizationHelper.GetString("app.name") %></title>
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
</head>
<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
<form id="journalFormPage" runat="server">
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
                                <i class="fas fa-book-open" style="color:#007bff;"></i>
                                <span data-i18n="journaux.title"></span>
                            </h1>
                        </div>
                        <div class="col-lg-6">
                            <ol class="breadcrumb" style="float:right;">
                                <li class="breadcrumb-item"><a href="../generale/generale.aspx" data-i18n="menu.generale">Générale</a></li>
                                <li class="breadcrumb-item active" data-i18n="journaux.title">Journaux</li>
                            </ol>
                        </div>
                    </div>
                </div>
            </div>

            <section class="content" id="section-journaux">

                <!-- STATS -->
                <div class="row journaux-stats">
                    <div class="col-lg-4 col-6">
                        <div class="stat-card stat-card-total">
                            <div class="stat-icon"><i class="fas fa-book-open"></i></div>
                            <div class="stat-body">
                                <span class="stat-value" id="statTotal">0</span>
                                <span class="stat-label" data-i18n="journaux.stat.total"></span>
                            </div>
                        </div>
                    </div>
                    <div class="col-lg-4 col-6">
                        <div class="stat-card stat-card-normal">
                            <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
                            <div class="stat-body">
                                <span class="stat-value" id="statActives">0</span>
                                <span class="stat-label" data-i18n="journaux.stat.active"></span>
                            </div>
                        </div>
                    </div>
                    <div class="col-lg-4 col-6">
                        <div class="stat-card stat-card-inactive">
                            <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
                            <div class="stat-body">
                                <span class="stat-value" id="statInactives">0</span>
                                <span class="stat-label" data-i18n="journaux.stat.inactive"></span>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="dash-card">
                    <div class="dash-card-head">
                        <span class="dash-card-title">
                            <i class="fas fa-book-open"></i>
                            <span data-i18n="journaux.list_title"></span>
                        </span>
                        <div class="action-buttons">
                            <a href="../../generale/generale.aspx" class="btn btn-secondary btn-sm">
                                <i class="fas fa-arrow-left"></i> <span data-i18n="button.back"></span>
                            </a>
                            <button class="btn btn-success btn-sm" onclick="openAddJournalModal(event)" type="button">
                                <i class="fas fa-plus"></i> <span data-i18n="journaux.btn.add"></span>
                            </button>
                            <button class="btn btn-primary btn-sm" onclick="exportJournauxPDF()" type="button">
                                <i class="fas fa-file-pdf"></i> <span data-i18n="journaux.btn.pdf"></span>
                            </button>
                            <button class="btn btn-outline-success btn-sm" onclick="exportJournauxToExcelOnly()" type="button">
                                <i class="fas fa-file-excel"></i> <span data-i18n="journaux.btn.excel"></span>
                            </button>
                        </div>
                    </div>

                    <!-- FILTRES -->
                    <div class="dash-card-toolbar">
                        <div class="toolbar-search">
                            <i class="fas fa-search"></i>
                            <input type="text" id="search-filter" class="form-control"
                                   data-i18n-attr="placeholder:journaux.search_placeholder" autocomplete="off" />
                        </div>
                        <select id="type-filter" class="form-control toolbar-select">
                            <option value="" data-i18n="journaux.filter.all_types"></option>
                            <option value="ACHATS" data-i18n="journaux.type.achats"></option>
                            <option value="VENTES" data-i18n="journaux.type.ventes"></option>
                            <option value="BANQUE" data-i18n="journaux.type.banque"></option>
                            <option value="CAISSE" data-i18n="journaux.type.caisse"></option>
                            <option value="OPERATIONS_DIVERSES" data-i18n="journaux.type.operations_diverses"></option>
                            <option value="GENERAL" data-i18n="journaux.type.general"></option>
                        </select>

                        <!-- 🆕 Filtre catégorie -->
                        <select id="categorie-filter" class="form-control toolbar-select">
                            <option value="" data-i18n="journaux.filter.all_categories"></option>
                            <option value="1" data-i18n="journaux.categorie.od"></option>
                            <option value="2" data-i18n="journaux.categorie.tresorerie"></option>
                        </select>

                        <select id="site-filter" class="form-control toolbar-select">
                            <option value="" data-i18n="journaux.filter.all_sites"></option>
                        </select>
                        <select id="status-filter" class="form-control toolbar-select">
                            <option value="" data-i18n="journaux.filter.all_status"></option>
                            <option value="1" data-i18n="journaux.filter.active"></option>
                            <option value="0" data-i18n="journaux.filter.inactive"></option>
                        </select>
                        <select id="rows-per-page-top" class="form-control toolbar-select">
                            <option value="10" data-i18n="journaux.rows_per_page.10"></option>
                            <option value="25" data-i18n="journaux.rows_per_page.25"></option>
                            <option value="50" data-i18n="journaux.rows_per_page.50"></option>
                            <option value="100" data-i18n="journaux.rows_per_page.100"></option>
                            <option value="all" data-i18n="journaux.rows_per_page.all"></option>
                        </select>
                        <button class="btn btn-light btn-sm" id="btnResetFilters" onclick="resetFilters()" type="button"
                                data-i18n-attr="title:journaux.reset_filters">
                            <i class="fas fa-undo"></i>
                        </button>
                        <span class="toolbar-counter" id="resultsCounter" data-i18n="journaux.counter.zero"></span>
                    </div>

                    <div class="dash-card-body">
                        <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                            <table class="dash-table" style="table-layout:fixed; width:1340px; min-width:100%; border-collapse:collapse;">
                                <thead>
                                    <tr style="background-color:#f8f9fa;">
                                        <th onclick="sortData('CODE')" style="cursor:pointer; width:110px; text-align:left;">
                                            <span data-i18n="journaux.col.code"></span> <i class="fas fa-sort ml-1"></i>
                                        </th>
                                        <th onclick="sortData('LIBELLE')" style="cursor:pointer; width:220px; text-align:left;">
                                            <span data-i18n="journaux.col.libelle"></span> <i class="fas fa-sort ml-1"></i>
                                        </th>
                                        <th onclick="sortData('TYPE_JOURNAL')" style="cursor:pointer; width:160px; text-align:left;">
                                            <span data-i18n="journaux.col.type"></span> <i class="fas fa-sort ml-1"></i>
                                        </th>
                                        <!-- 🆕 Colonne catégorie -->
                                        <th onclick="sortData('CATEGORIE_JOURNAL')" style="cursor:pointer; width:140px; text-align:center;">
                                            <span data-i18n="journaux.col.categorie"></span> <i class="fas fa-sort ml-1"></i>
                                        </th>
                                        <th style="width:140px; text-align:left;" data-i18n="journaux.col.sites"></th>
                                        <th style="width:110px; text-align:center;" data-i18n="journaux.col.monnaie"></th>
                                        <th style="width:130px; text-align:left;" data-i18n="journaux.col.prefixe"></th>
                                        <th onclick="sortData('ACTIVE')" style="cursor:pointer; width:100px; text-align:center;">
                                            <span data-i18n="journaux.col.active"></span> <i class="fas fa-sort ml-1"></i>
                                        </th>
                                        <th style="width:180px; text-align:right;" data-i18n="journaux.col.actions"></th>
                                    </tr>
                                </thead>
                                <tbody id="journauxTableBody">
                                    <tr><td colspan="9" style="text-align:center;padding:40px;">
                                        <i class="fas fa-spinner fa-spin" style="font-size:24px;color:#ccc;"></i>
                                    </td></tr>
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
    <div id="journalModal" class="modal">
        <input type="hidden" id="editingId" value="" />
        <div class="modal-content" style="max-width:640px;">
            <div class="modal-header">
                <h3 id="modalTitle">
                    <i class="fas fa-plus"></i>
                    <span data-i18n="journaux.modal.add_title"></span>
                </h3>
                <span class="close" onclick="closeJournalModal()">&times;</span>
            </div>
            <div class="modal-body">

                <div class="form-row" style="display:flex;gap:15px;">
                    <div class="form-group" style="flex:0 0 140px;">
                        <label>
                            <span data-i18n="journaux.col.code"></span>
                            <span class="text-danger">*</span>
                        </label>
                        <input type="text" id="journalCode" class="form-control" maxlength="20" required
                               style="text-transform:uppercase; font-family:monospace;"
                               data-i18n-attr="placeholder:journaux.modal.code_placeholder" />
                        <small class="field-error" id="err-journalCode"></small>
                    </div>
                    <div class="form-group" style="flex:1;">
                        <label>
                            <span data-i18n="journaux.col.libelle"></span>
                            <span class="text-danger">*</span>
                        </label>
                        <input type="text" id="journalLibelle" class="form-control" maxlength="150" required
                               data-i18n-attr="placeholder:journaux.modal.libelle_placeholder" />
                        <small class="field-error" id="err-journalLibelle"></small>
                    </div>
                </div>

                <div class="form-group">
                    <label>
                        <span data-i18n="journaux.col.type"></span>
                        <span class="text-danger">*</span>
                    </label>
                    <select id="journalType" class="form-control" required>
                        <option value="">— <span data-i18n="journaux.modal.type_select"></span> —</option>
                        <option value="ACHATS" data-i18n="journaux.type.achats"></option>
                        <option value="VENTES" data-i18n="journaux.type.ventes"></option>
                        <option value="BANQUE" data-i18n="journaux.type.banque"></option>
                        <option value="CAISSE" data-i18n="journaux.type.caisse"></option>
                        <option value="OPERATIONS_DIVERSES" data-i18n="journaux.type.operations_diverses"></option>
                        <option value="GENERAL" data-i18n="journaux.type.general"></option>
                    </select>
                    <small class="field-error" id="err-journalType"></small>
                </div>

                <!-- 🆕 Catégorie : OD vs Trésorerie -->
                <div class="form-group">
                    <label>
                        <span data-i18n="journaux.categorie.label"></span>
                        <span class="text-danger">*</span>
                    </label>
                    <div class="categorie-radio-group">
                        <label class="categorie-radio">
                            <input type="radio" name="categorieJournal" value="1" checked />
                            <span class="categorie-radio-content">
                                <i class="fas fa-file-alt"></i>
                                <span class="categorie-radio-title" data-i18n="journaux.categorie.od"></span>
                                <span class="categorie-radio-hint" data-i18n="journaux.categorie.od_hint"></span>
                            </span>
                        </label>
                        <label class="categorie-radio">
                            <input type="radio" name="categorieJournal" value="2" />
                            <span class="categorie-radio-content">
                                <i class="fas fa-coins"></i>
                                <span class="categorie-radio-title" data-i18n="journaux.categorie.tresorerie"></span>
                                <span class="categorie-radio-hint" data-i18n="journaux.categorie.tresorerie_hint"></span>
                            </span>
                        </label>
                    </div>
                    <small class="field-error" id="err-journalCategorie"></small>
                </div>

                <div class="form-group">
                    <label>
                        <span data-i18n="journaux.col.sites"></span>
                        <span class="text-danger">*</span>
                    </label>

                    <div class="multiselect-sites" id="sitesMultiselect">
                        <div class="multiselect-header">
                            <span class="multiselect-title">
                                <i class="fas fa-map-marker-alt"></i>
                                <span data-i18n="journaux.modal.sites_selected"></span>
                                <span class="multiselect-count" id="sitesCount">0</span>
                            </span>
                            <div class="multiselect-actions">
                                <button type="button" class="multiselect-action" onclick="selectAllSites(true)"
                                        data-i18n="journaux.modal.select_all"></button>
                                <span class="multiselect-sep">·</span>
                                <button type="button" class="multiselect-action" onclick="selectAllSites(false)"
                                        data-i18n="journaux.modal.clear_all"></button>
                            </div>
                        </div>
                        <div class="multiselect-search">
                            <i class="fas fa-search"></i>
                            <input type="text" id="sitesSearch" class="form-control"
                                   data-i18n-attr="placeholder:journaux.modal.search_site" autocomplete="off" />
                        </div>
                        <div class="multiselect-list" id="sitesList"></div>
                    </div>

                    <small class="field-error" id="err-journalSites"></small>
                    <small class="text-muted" data-i18n="journaux.modal.sites_hint"></small>
                </div>

                <div class="form-group">
                    <label data-i18n="journaux.col.monnaie"></label>
                    <select id="journalMonnaie" class="form-control">
                        <option value="">— <span data-i18n="journaux.modal.none"></span> —</option>
                    </select>
                    <small class="text-muted" data-i18n="journaux.modal.monnaie_hint"></small>
                </div>

                <!-- Compte comptable — visible uniquement si Trésorerie -->
                <div class="form-group" id="grpCompteBanque" style="display:none;">
                    <label>
                        <span data-i18n="journaux.modal.compte_banque"></span>
                        <span class="text-danger">*</span>
                    </label>
                    <select id="journalCompteBanque" class="form-control"></select>
                    <small class="field-error" id="err-journalCompteBanque"></small>
                </div>

                <div class="form-group">
                    <label data-i18n="journaux.modal.prefixe"></label>
                    <input type="text" id="journalPrefixe" class="form-control" maxlength="20"
                           style="text-transform:uppercase; font-family:monospace;"
                           data-i18n-attr="placeholder:journaux.modal.prefixe_placeholder" />
                    <small class="text-muted" data-i18n="journaux.modal.prefixe_hint"></small>
                </div>

                <div class="form-group" style="display:flex; align-items:center; gap:10px;">
                    <input type="checkbox" id="journalActive" style="width:18px;height:18px;cursor:pointer;" checked />
                    <label for="journalActive" style="margin:0; cursor:pointer;">
                        <span data-i18n="journaux.modal.active_label"></span>
                    </label>
                </div>

            </div>
            <div class="modal-footer">
                <button class="btn btn-primary" onclick="saveJournal(event)" type="button">
                    <i class="fas fa-save"></i> <span data-i18n="button.save"></span>
                </button>
                <button class="btn btn-secondary" onclick="closeJournalModal()" type="button">
                    <i class="fas fa-times"></i> <span data-i18n="button.cancel"></span>
                </button>
            </div>
        </div>
    </div>

    <div id="spinnerOverlay" aria-hidden="true" style="display:none;visibility:hidden;">
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
