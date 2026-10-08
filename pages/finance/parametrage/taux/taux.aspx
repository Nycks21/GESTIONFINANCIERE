<%@ Page Language="C#" AutoEventWireup="true" CodeFile="taux.cs" Inherits="taux" UICulture="Auto" Culture="Auto" %>
<!DOCTYPE html>
<html lang="<%= LocalizationHelper.CurrentCultureCode %>">

<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <script src="../../../_assets/js/theme-init.js?v=<%=AuthHelper.Version %>"></script>
    <title><%= LocalizationHelper.GetString("taux.title") %> — <%= LocalizationHelper.GetString("app.name") %></title>
    <link rel="stylesheet" href="../../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
</head>

<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
<script>document.body.classList.toggle("dark-mode", document.documentElement.classList.contains("dark-mode"));</script>
<form id="tauxFormPage" runat="server">
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
                                <i class="fas fa-exchange-alt" style="color:#007bff;"></i>
                                <span data-i18n="taux.title"></span>
                            </h1>
                        </div>
                        <div class="col-lg-6">
                            <ol class="breadcrumb" style="float:right;">
                                <li class="breadcrumb-item" data-i18n="menu.finance">Finance</li>
                                <li class="breadcrumb-item active" data-i18n="menu.taux">Taux de change</li>
                            </ol>
                        </div>
                    </div>
                </div>
            </div>

            <section class="content" id="section-taux">

                <!-- CARTES DE SYNTHÈSE -->
                <div class="row taux-stats" id="tauxStats">
                    <div class="col-lg-4 col-6">
                        <div class="stat-card stat-card-total">
                            <div class="stat-icon"><i class="fas fa-exchange-alt"></i></div>
                            <div class="stat-body">
                                <span class="stat-value" id="statTotal">0</span>
                                <span class="stat-label" data-i18n="taux.stat.total"></span>
                            </div>
                        </div>
                    </div>
                    <div class="col-lg-4 col-6">
                        <div class="stat-card stat-card-normal">
                            <div class="stat-icon"><i class="fas fa-check-circle"></i></div>
                            <div class="stat-body">
                                <span class="stat-value" id="statActives">0</span>
                                <span class="stat-label" data-i18n="taux.stat.active"></span>
                            </div>
                        </div>
                    </div>
                    <div class="col-lg-4 col-6">
                        <div class="stat-card stat-card-inactive">
                            <div class="stat-icon"><i class="fas fa-times-circle"></i></div>
                            <div class="stat-body">
                                <span class="stat-value" id="statInactives">0</span>
                                <span class="stat-label" data-i18n="taux.stat.inactive"></span>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="dash-card">
                    <div class="dash-card-head">
                        <span class="dash-card-title">
                            <i class="fas fa-exchange-alt"></i>
                            <span data-i18n="taux.list_title"></span>
                        </span>
                        <div class="action-buttons">
                            <button class="btn btn-success btn-sm" onclick="openAddTauxModal(event)" type="button">
                                <i class="fas fa-plus"></i> <span data-i18n="taux.btn.add"></span>
                            </button>
                            <button class="btn btn-primary btn-sm" onclick="exportTauxPDF()" type="button">
                                <i class="fas fa-file-pdf"></i> <span data-i18n="taux.btn.pdf"></span>
                            </button>
                            <button class="btn btn-outline-success btn-sm" onclick="exportTauxToExcelOnly()" type="button">
                                <i class="fas fa-file-excel"></i> <span data-i18n="taux.btn.excel"></span>
                            </button>
                        </div>
                    </div>

                    <!-- BARRE DE FILTRES -->
                    <div class="dash-card-toolbar">
                        <div class="toolbar-search">
                            <i class="fas fa-search"></i>
                            <input type="text" id="search-filter" class="form-control"
                                   data-i18n-attr="placeholder:taux.search_placeholder" autocomplete="off" />
                        </div>
                        <select id="source-filter" class="form-control toolbar-select">
                            <option value="" data-i18n="taux.filter.all_source"></option>
                        </select>
                        <select id="target-filter" class="form-control toolbar-select">
                            <option value="" data-i18n="taux.filter.all_target"></option>
                        </select>
                        <select id="status-filter" class="form-control toolbar-select">
                            <option value="" data-i18n="taux.filter.all_status"></option>
                            <option value="1" data-i18n="taux.filter.active"></option>
                            <option value="0" data-i18n="taux.filter.inactive"></option>
                        </select>
                        <select id="rows-per-page-top" class="form-control toolbar-select">
                            <option value="10" data-i18n="taux.rows_per_page.10"></option>
                            <option value="25" data-i18n="taux.rows_per_page.25"></option>
                            <option value="50" data-i18n="taux.rows_per_page.50"></option>
                            <option value="100" data-i18n="taux.rows_per_page.100"></option>
                            <option value="all" data-i18n="taux.rows_per_page.all"></option>
                        </select>
                        <button class="btn btn-light btn-sm" id="btnResetFilters" onclick="resetFilters()" type="button"
                                data-i18n-attr="title:taux.reset_filters">
                            <i class="fas fa-undo"></i>
                        </button>
                        <span class="toolbar-counter" id="resultsCounter" data-i18n="taux.counter.zero"></span>
                    </div>

                    <div class="dash-card-body">
                        <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                            <table class="dash-table"
                                   style="table-layout:fixed; width:1120px; min-width:100%; border-collapse:collapse;">
                                <thead>
                                    <tr style="background-color:#f8f9fa;">
                                        <th onclick="sortData('SOURCE_CODE')" style="cursor:pointer; width:130px; text-align:left;">
                                            <span data-i18n="taux.table.source"></span> <i class="fas fa-sort ml-1"></i>
                                        </th>
                                        <th style="width:60px; text-align:center;">
                                            <i class="fas fa-arrow-right" style="color:#007bff;"></i>
                                        </th>
                                        <th onclick="sortData('CIBLE_CODE')" style="cursor:pointer; width:130px; text-align:left;">
                                            <span data-i18n="taux.table.cible"></span> <i class="fas fa-sort ml-1"></i>
                                        </th>
                                        <th onclick="sortData('TAUX')" style="cursor:pointer; width:150px; text-align:right;">
                                            <span data-i18n="taux.table.taux"></span> <i class="fas fa-sort ml-1"></i>
                                        </th>
                                        <th onclick="sortData('DATE_EFFET')" style="cursor:pointer; width:120px; text-align:center;">
                                            <span data-i18n="taux.table.date_effet"></span> <i class="fas fa-sort ml-1"></i>
                                        </th>
                                        <th style="width:200px; text-align:left;" data-i18n="taux.table.source_info"></th>
                                        <th onclick="sortData('ACTIVE')" style="cursor:pointer; width:110px; text-align:left;">
                                            <span data-i18n="taux.table.statut"></span> <i class="fas fa-sort ml-1"></i>
                                        </th>
                                        <th style="width:130px; text-align:right;" data-i18n="taux.table.actions"></th>
                                    </tr>
                                </thead>
                                <tbody id="tauxTableBody">
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

    <!-- MODALE AJOUT / MODIFICATION TAUX -->
    <div id="tauxModal" class="modal">
        <input type="hidden" id="editingId" value="" />
        <div class="modal-content modal-taux" style="max-width:680px;">
            <div class="modal-header">
                <h3 id="modalTitle">
                    <i class="fas fa-exchange-alt"></i>
                    <span data-i18n="taux.modal.add_title"></span>
                </h3>
                <span class="close" onclick="closeTauxModal()">&times;</span>
            </div>
            <div class="modal-body">

                <div class="form-group">
                    <label>
                        <span data-i18n="taux.modal.source_label"></span>
                        <span class="text-danger">*</span>
                    </label>
                    <select id="tauxSourceId" class="form-control" required></select>
                    <small class="field-error" id="err-tauxSourceId"></small>
                </div>

                <div class="form-group" style="text-align:center;">
                    <button type="button" class="btn btn-light btn-sm" onclick="swapCurrencies(event)" title="Inverser">
                        <i class="fas fa-arrows-alt-v"></i>
                    </button>
                </div>

                <div class="form-group">
                    <label>
                        <span data-i18n="taux.modal.cible_label"></span>
                        <span class="text-danger">*</span>
                    </label>
                    <select id="tauxCibleId" class="form-control" required></select>
                    <small class="field-error" id="err-tauxCibleId"></small>
                </div>

                <div class="form-group">
                    <label>
                        <span data-i18n="taux.modal.taux_label"></span>
                        <span class="text-danger">*</span>
                    </label>
                    <input type="number" id="tauxValeur" class="form-control" step="0.00000001" min="0.00000001"
                           data-i18n-attr="placeholder:taux.modal.taux_placeholder" required />
                    <small class="field-error" id="err-tauxValeur"></small>
                </div>

                <div class="form-group">
                    <label>
                        <span data-i18n="taux.modal.date_label"></span>
                        <span class="text-danger">*</span>
                    </label>
                    <input type="date" id="tauxDateEffet" class="form-control" required />
                    <small class="field-error" id="err-tauxDateEffet"></small>
                </div>

                <div class="form-group">
                    <label data-i18n="taux.modal.source_info_label"></label>
                    <input type="text" id="tauxSourceInfo" class="form-control" maxlength="100"
                           data-i18n-attr="placeholder:taux.modal.source_info_placeholder" />
                    <small class="field-error" id="err-tauxSourceInfo"></small>
                </div>

                <div class="form-group">
                    <label>
                        <span data-i18n="taux.modal.actif_label"></span>
                        <span class="text-danger">*</span>
                    </label>
                    <select id="tauxActif" class="form-control">
                        <option value="1" data-i18n="button.yes"></option>
                        <option value="0" data-i18n="button.no"></option>
                    </select>
                </div>

            </div>
            <div class="modal-footer">
                <button class="btn btn-primary" id="btnSaveTaux" onclick="saveTaux(event)" type="button">
                    <i class="fas fa-save"></i> <span data-i18n="button.save"></span>
                </button>
                <button class="btn btn-danger" onclick="closeTauxModal()" type="button">
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
