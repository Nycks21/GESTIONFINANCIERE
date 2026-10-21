<%@ Page Language="C#" AutoEventWireup="true" CodeFile="liste-ecritures.cs" Inherits="liste_ecritures" UICulture="Auto" Culture="Auto" %>
<!DOCTYPE html>
<html lang="<%= LocalizationHelper.CurrentCultureCode %>">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title><%= LocalizationHelper.GetString("liste_ecritures.title") %> — <%= LocalizationHelper.GetString("app.name") %></title>
  <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="css/liste-ecritures.css?v=<%=AuthHelper.Version %>" />
</head>

<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
<form id="listeEcrituresFormPage" runat="server">
  <div class="wrapper">
    <%= AuthHelper.RenderTopBarHTML() %>
    <aside class="main-sidebar" id="sidebar">
      <div class="sidebar"><%= AuthHelperFinance.RenderMenuHTML() %></div>
    </aside>
    <%= AuthHelper.RenderControlSidebarHTML() %>

    <div class="content-wrapper" id="contentWrapper">
      <div class="content-header">
        <div class="container-fluid">
          <div class="row">
            <div class="col-lg-6">
              <h1 class="page-title">
                <i class="fas fa-book-open"></i>
                <span data-i18n="liste_ecritures.title"></span>
              </h1>
            </div>
            <div class="col-lg-6">
              <ol class="breadcrumb">
                <li class="breadcrumb-item" data-i18n="menu.finance"></li>
                <li class="breadcrumb-item" data-i18n="menu.grand_livre"></li>
                <li class="breadcrumb-item active" data-i18n="liste_ecritures.title"></li>
              </ol>
            </div>
          </div>
        </div>
      </div>

      <section class="content liste-content">
        <div id="listeEcrituresApp" v-cloak>

          <!-- ═══════════════════════════════════════════════════
               FILTRES (au-dessus du tableau)
               ═══════════════════════════════════════════════════ -->
          <div class="liste-filter-panel">
            <div class="liste-filter-grid">

              <div class="lf-field">
                <label data-i18n="liste_ecritures.filter.exercice"></label>
                <select v-model="vm.exerciceId" @change="onFilterChange" class="form-control">
                  <option value="">{{ t('liste_ecritures.filter.all_exercices') }}</option>
                  <option v-for="ex in exercices" :key="ex.ID" :value="ex.ID">
                    {{ ex.CODE }} — {{ ex.LIBELLE }}
                  </option>
                </select>
              </div>

              <div class="lf-field">
                <label data-i18n="liste_ecritures.filter.journal"></label>
                <select v-model="vm.journalId" @change="onFilterChange" class="form-control">
                  <option value="">{{ t('liste_ecritures.filter.all_journaux') }}</option>
                  <option v-for="j in journaux" :key="j.ID" :value="j.ID">{{ j.CODE }} — {{ j.LIBELLE }}</option>
                </select>
              </div>

              <div class="lf-field">
                <label data-i18n="liste_ecritures.filter.date_comptable_du"></label>
                <input type="date" v-model="vm.dateDebut" @change="onFilterChange" class="form-control" />
              </div>

              <div class="lf-field">
                <label data-i18n="liste_ecritures.filter.date_comptable_au"></label>
                <input type="date" v-model="vm.dateFin" @change="onFilterChange" class="form-control" />
              </div>

              <div class="lf-field">
                <label data-i18n="liste_ecritures.filter.date_piece_du"></label>
                <input type="date" v-model="vm.datePieceDebut" @change="onFilterChange" class="form-control" />
              </div>

              <div class="lf-field">
                <label data-i18n="liste_ecritures.filter.date_piece_au"></label>
                <input type="date" v-model="vm.datePieceFin" @change="onFilterChange" class="form-control" />
              </div>

              <div class="lf-field">
                <label data-i18n="liste_ecritures.filter.numero_piece"></label>
                <input type="text" v-model="vm.numeroPiece" @input="onFilterChange" class="form-control" placeholder="ECR-..." />
              </div>

              <div class="lf-field">
                <label data-i18n="liste_ecritures.filter.compte"></label>
                <input type="text" v-model="vm.compte" @input="onFilterChange" class="form-control" placeholder="401100" />
              </div>

              <div class="lf-field">
                <label data-i18n="liste_ecritures.filter.tiers"></label>
                <input type="text" v-model="vm.tiers" @input="onFilterChange" class="form-control" placeholder="AUX..." />
              </div>

              <div class="lf-field">
                <label data-i18n="liste_ecritures.filter.marche"></label>
                <select v-model="vm.marcheId" @change="onFilterChange" class="form-control">
                  <option value="">{{ t('liste_ecritures.filter.all_marches') }}</option>
                  <option v-for="m in marches" :key="m.ID" :value="m.ID">{{ m.CODE }}</option>
                </select>
              </div>

              <div class="lf-field">
                <label data-i18n="liste_ecritures.filter.statut"></label>
                <select v-model="vm.statut" @change="onFilterChange" class="form-control">
                  <option value="">{{ t('liste_ecritures.filter.all_status') }}</option>
                  <option value="BROUILLON">{{ t('saisie.statut.BROUILLON') }}</option>
                  <option value="A_VALIDER">{{ t('saisie.statut.A_VALIDER') }}</option>
                  <option value="VALIDEE">{{ t('saisie.statut.VALIDEE') }}</option>
                  <option value="COMPTABILISEE">{{ t('saisie.statut.COMPTABILISEE') }}</option>
                </select>
              </div>

              <div class="lf-field lf-search">
                <label data-i18n="liste_ecritures.filter.search"></label>
                <input type="text" v-model="vm.search" @input="onSearchInput"
                       class="form-control" :placeholder="t('liste_ecritures.filter.search_placeholder')" />
              </div>
            </div>

            <div class="liste-filter-actions">
              <button type="button" class="btn btn-light" @click="resetFilters">
                <i class="fas fa-undo"></i> {{ t('liste_ecritures.btn.reset') }}
              </button>
              <span class="toolbar-counter">{{ counterText }}</span>
              <button type="button" class="btn btn-success" @click="navigateToNew">
                <i class="fas fa-plus"></i> {{ t('liste_ecritures.btn.new') }}
              </button>
            </div>
          </div>

          <!-- ═══════════════════════════════════════════════════
               TABLEAU
               ═══════════════════════════════════════════════════ -->
          <div class="list-grid">
            <table class="grid-table" id="ecrituresTable">
              <thead>
                <tr>
                  <th style="width:36px;"></th>
                  <th style="width:150px;">{{ t('saisie.col.piece_number') }}</th>
                  <th style="width:110px;">{{ t('saisie.col.date_piece') }}</th>
                  <th style="width:110px;">{{ t('saisie.col.date') }}</th>
                  <th style="width:90px;">{{ t('saisie.col.journal') }}</th>
                  <th>{{ t('saisie.col.libelle') }}</th>
                  <th style="width:120px;text-align:right;">{{ t('saisie.col.debit') }}</th>
                  <th style="width:120px;text-align:right;">{{ t('saisie.col.credit') }}</th>
                  <th style="width:120px;text-align:right;">{{ t('saisie.col.debit_rap') }}</th>
                  <th style="width:120px;text-align:right;">{{ t('saisie.col.credit_rap') }}</th>
                  <th style="width:120px;text-align:center;">{{ t('saisie.col.statut') }}</th>
                  <th style="width:130px;text-align:right;">{{ t('saisie.col.actions') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-if="vm.loading"><td colspan="12" class="table-loading">
                  <i class="fas fa-spinner fa-spin"></i> {{ t('saisie.msg.loading') }}
                </td></tr>
                <tr v-else-if="vm.error"><td colspan="12" class="table-empty">
                  <i class="fas fa-exclamation-triangle"></i> <span>{{ vm.error }}</span>
                </td></tr>
                <tr v-else-if="!vm.ecritures.length"><td colspan="12" class="table-empty">
                  <i class="fas fa-inbox"></i> <span>{{ t('saisie.msg.no_data') }}</span>
                </td></tr>

                <template v-else v-for="e in vm.ecritures" :key="e.ID">
                  <tr class="ecr-main-row">
                    <td style="text-align:center;">
                      <button type="button" class="btn-toggle-ecr" @click.stop="toggleLines(e.ID)">
                        <i class="fas" :class="vm.expanded[e.ID] ? 'fa-chevron-down' : 'fa-chevron-right'"></i>
                      </button>
                    </td>
                    <td><span class="badge-code">{{ e.REFERENCE || '' }}</span></td>
                    <td>{{ e.DATE_PIECE || '—' }}</td>
                    <td>{{ e.DATE_COMPTABLE }}</td>
                    <td><span class="badge-journal">{{ e.JOURNAL_CODE || '?' }}</span></td>
                    <td>{{ e.LIBELLE }}</td>
                    <td class="cell-montant debit">{{ fmt(e.TOTAL_DEBIT) }}</td>
                    <td class="cell-montant credit">{{ fmt(e.TOTAL_CREDIT) }}</td>
                    <td class="cell-montant debit">{{ fmt(e.TOTAL_DEBIT_RAP) }}</td>
                    <td class="cell-montant credit">{{ fmt(e.TOTAL_CREDIT_RAP) }}</td>
                    <td style="text-align:center;">
                      <span class="badge-statut" :class="statusClass(e.STATUT)">{{ statusLabel(e.STATUT) }}</span>
                    </td>
                    <td style="text-align:right;">
                      <button type="button" class="btn btn-sm btn-primary" @click="editEcr(e.ID)">
                        <i class="fas fa-edit"></i>
                      </button>
                      <button type="button" class="btn btn-sm btn-danger" @click="delEcr(e.ID)">
                        <i class="fas fa-trash"></i>
                      </button>
                    </td>
                  </tr>

                  <tr v-if="vm.expanded[e.ID] && vm.linesCache[e.ID]" class="ecr-sub-row">
                    <td colspan="12" style="padding:0;background:#f8f9fa;border-bottom:2px solid #dee2e6;">
                      <div style="padding:10px 20px 14px;">
                        <table style="width:100%;font-size:12px;border-collapse:collapse;">
                          <thead>
                            <tr style="background:#e9ecef;color:#495057;font-size:11px;text-transform:uppercase;">
                              <th style="width:36px;">#</th>
                              <th style="width:90px;">{{ t('saisie.col.auxiliaire') }}</th>
                              <th v-for="p in activePlans" :key="p.key" style="width:90px;">{{ p.label }}</th>
                              <th>{{ t('saisie.col.libelle') }}</th>
                              <th style="width:110px;text-align:right;">{{ t('saisie.col.debit') }}</th>
                              <th style="width:110px;text-align:right;">{{ t('saisie.col.credit') }}</th>
                            </tr>
                          </thead>
                          <tbody>
                            <tr v-for="(l, i) in vm.linesCache[e.ID]" :key="l.ID || i"
                                style="border-bottom:1px solid #e9ecef;">
                              <td style="text-align:center;color:#94A3B8;">{{ i + 1 }}</td>
                              <td>{{ l.AUXILIAIRE || '' }}</td>
                              <td v-for="p in activePlans" :key="p.key">
                                <span class="cell-badge">{{ resolveCode(p.ordre, l['PLAN' + p.ordre]) || '' }}</span>
                              </td>
                              <td>{{ l.LIBELLE }}</td>
                              <td class="cell-montant debit">
                                <span v-if="parseFloat(l.DEBIT || 0) > 0">{{ fmt(l.DEBIT) }}</span>
                              </td>
                              <td class="cell-montant credit">
                                <span v-if="parseFloat(l.CREDIT || 0) > 0">{{ fmt(l.CREDIT) }}</span>
                              </td>
                            </tr>
                          </tbody>
                        </table>
                      </div>
                    </td>
                  </tr>
                </template>
              </tbody>
            </table>
          </div>

          <!-- Pagination -->
          <div class="pagination-wrapper" v-if="pagination.length">
            <div style="margin:12px 0;display:flex;justify-content:center;gap:5px;flex-wrap:wrap;">
              <button v-for="(p, idx) in pagination" :key="idx" type="button"
                      @click="goToPage(p.page)" :disabled="p.disabled" :style="paginationStyle(p)">
                {{ p.text }}
              </button>
            </div>
          </div>

        </div>
      </section>
    </div>
  </div>

  <div id="spinnerOverlay"><div class="spinner"></div></div>

  <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/csrf.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
  <script src="../../_assets/js/vue.global.prod.js?v=<%=AuthHelper.Version %>"></script>

  <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>

  <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/i18n-refresh.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/liste-ecritures-vue.js?v=<%=AuthHelper.Version %>"></script>
</form>
</body>
</html>
