<%@ Page Language="C#" AutoEventWireup="true" CodeFile="generale.cs" Inherits="generale" UICulture="Auto" Culture="Auto" %>
<!DOCTYPE html>
<html lang="<%= LocalizationHelper.CurrentCultureCode %>">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title><%= LocalizationHelper.GetString("generale.title") %> — <%= LocalizationHelper.GetString("app.name") %></title>
    <link rel="stylesheet" href="../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
</head>
<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
<form id="generaleFormPage" runat="server">
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
                                <i class="fas fa-sliders-h" style="color:#007bff;"></i>
                                <span data-i18n="generale.title"></span>
                            </h1>
                            <p style="color:#6c757d; margin-top:4px; font-size:13px;"
                               data-i18n="generale.subtitle"></p>
                        </div>
                        <div class="col-lg-6">
                            <ol class="breadcrumb" style="float:right;">
                                <li class="breadcrumb-item"><a href="generale.aspx"
                            data-i18n="menu.generale">Générale</a></li>
                            </ol>
                        </div>
                    </div>
                </div>
            </div>

            <section class="content" id="section-generale">
                <!-- Les sections sont injectées dynamiquement par ui.js → renderHub() -->
                <div id="hubContainer"></div>
            </section>
        </div>
    </div>

    <!-- ═══════════════════════════════════════════════════════
         MODALE — PLANS COMPTABLES
         ═══════════════════════════════════════════════════════ -->
    <div id="plansModal" class="modal">
        <div class="modal-content modal-plans" style="max-width:1100px;">
            <div class="modal-header">
                <h3>
                    <i class="fas fa-book"></i>
                    <span data-i18n="generale.plans.title"></span>
                </h3>
                <span class="close" onclick="closePlansModal()">&times;</span>
            </div>
            <div class="modal-body">

                <div class="plans-info-banner">
                    <i class="fas fa-info-circle"></i>
                    <span data-i18n="generale.plans.info_max"></span>
                </div>

                <div style="overflow-x:auto; width:100%; border:1px solid #dee2e6; border-radius:8px;">
                    <table class="dash-table" style="table-layout:fixed; width:1040px; min-width:100%; border-collapse:collapse;">
                        <thead>
                            <tr style="background-color:#f8f9fa;">
                                <th style="width:60px;  text-align:center;" data-i18n="generale.plans.col.ordre"></th>
                                <th style="width:100px; text-align:left;"   data-i18n="generale.plans.col.code"></th>
                                <th style="width:150px; text-align:left;"   data-i18n="generale.plans.col.nom"></th>
                                <th style="width:90px;  text-align:center;" data-i18n="generale.plans.col.niveau"></th>
                                <th style="width:150px; text-align:left;"   data-i18n="generale.plans.col.type"></th>
                                <th style="width:90px; text-align:center;" data-i18n="generale.plans.col.principal"></th>
                                <th style="width:90px;  text-align:center;" data-i18n="generale.plans.col.active"></th>
                                <th style="width:200px; text-align:right;"  data-i18n="generale.plans.col.actions"></th>
                            </tr>
                        </thead>
                        <tbody id="plansTableBody">
                            <tr><td colspan="8" style="text-align:center;padding:40px;">
                                <i class="fas fa-spinner fa-spin" style="font-size:24px;color:#ccc;"></i>
                            </td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
            <div class="modal-footer">
                <button class="btn btn-danger" onclick="closePlansModal()" type="button">
                    <i class="fas fa-times"></i> <span data-i18n="button.close"></span>
                </button>
            </div>
        </div>
    </div>

    <!-- ═══════════════════════════════════════════════════════
         MODALE — ÉDITION D'UN PLAN
         ═══════════════════════════════════════════════════════ -->
    <div id="planEditModal" class="modal">
        <input type="hidden" id="editPlanId" value="" />
        <div class="modal-content" style="max-width:560px;">
            <div class="modal-header">
                <h3>
                    <i class="fas fa-edit"></i>
                    <span data-i18n="generale.plans.edit.title"></span>
                </h3>
                <span class="close" onclick="closePlanEditModal()">&times;</span>
            </div>
            <div class="modal-body">

                <div class="form-group">
                    <label data-i18n="generale.plans.col.ordre"></label>
                    <input type="text" id="planOrdre" class="form-control" readonly />
                </div>

                <div class="form-group">
                    <label data-i18n="generale.plans.col.code"></label>
                    <input type="text" id="planCode" class="form-control" maxlength="50"
                           style="text-transform:uppercase;"
                           data-i18n-attr="placeholder:generale.plans.edit.code_placeholder" />
                    <small class="field-error" id="err-planCode"></small>
                </div>

                <div class="form-group">
                    <label data-i18n="generale.plans.col.nom"></label>
                    <input type="text" id="planNom" class="form-control" maxlength="200"
                           data-i18n-attr="placeholder:generale.plans.edit.nom_placeholder" />
                    <small class="field-error" id="err-planNom"></small>
                </div>

                <div class="form-group">
                    <label data-i18n="generale.plans.edit.description"></label>
                    <textarea id="planDescription" class="form-control" rows="2" maxlength="500"></textarea>
                </div>

                <div class="form-group">
                    <label>
                        <span data-i18n="generale.plans.col.niveau"></span>
                        <span class="text-danger">*</span>
                    </label>
                    <input type="number" id="planNiveau" class="form-control" min="1" max="10" required />
                    <small class="text-muted" data-i18n="generale.plans.edit.niveau_hint"></small>
                    <small class="field-error" id="err-planNiveau"></small>
                </div>

                <div class="form-group">
                    <label data-i18n="generale.plans.col.type"></label>
                    <select id="planType" class="form-control"></select>
                </div>

                <div class="form-group" style="display:flex; align-items:center; gap:10px;">
                    <input type="checkbox" id="planPrincipal" style="width:18px;height:18px;cursor:pointer;" />
                    <label for="planPrincipal" style="margin:0; cursor:pointer;">
                        <span data-i18n="generale.plans.edit.principal_label"></span>
                    </label>
                </div>

            </div>
            <div class="modal-footer">
                <button class="btn btn-primary" id="btnSavePlan" onclick="savePlan(event)" type="button">
                    <i class="fas fa-save"></i> <span data-i18n="button.save"></span>
                </button>
                <button class="btn btn-secondary" onclick="closePlanEditModal()" type="button">
                    <i class="fas fa-times"></i> <span data-i18n="button.cancel"></span>
                </button>
            </div>
        </div>
    </div>

    <!-- ✅ Spinner — ID SINGULIER pour matcher global.js / ui.js -->
    <div id="spinnerOverlay" aria-hidden="true" style="display:none;visibility:hidden;">
        <div class="spinner"></div>
    </div>

    <script src="../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../_assets/js/csrf.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
    <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>
    <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>
    <div id="toastContainer"></div>
</form>
</body>
</html>
