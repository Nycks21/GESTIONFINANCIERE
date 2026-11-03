<%@ Page Language="C#" AutoEventWireup="true" CodeFile="grand-livre.cs" Inherits="grand_livre" UICulture="Auto" Culture="Auto" %>
<!DOCTYPE html>
<html lang="<%= LocalizationHelper.CurrentCultureCode %>">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Grand Livre Général — <%= LocalizationHelper.GetString("app.name") %></title>
  <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
  <link rel="stylesheet" href="css/gl.css?v=<%=AuthHelper.Version %>" />
</head>

<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
<form id="grandLivreFormPage" runat="server">
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
                <i class="fas fa-book"></i>
                <span>Grand Livre Général</span>
              </h1>
            </div>
            <div class="col-lg-6">
              <ol class="breadcrumb">
                <li class="breadcrumb-item" data-i18n="menu.finance">Finance</li>
                <li class="breadcrumb-item" data-i18n="menu.grand_livre">Grand Livre</li>
                <li class="breadcrumb-item active">Général</li>
              </ol>
            </div>
          </div>
        </div>
      </div>

      <section class="content liste-content">
        <div id="grandLivreApp" v-cloak>

          <!-- TOOLBAR -->
          <div class="toolbar-modern">
            <button type="button" class="btn btn-primary btn-filter" @click="openFilterModal"
                    aria-haspopup="dialog" aria-controls="filterModal">
              <i class="fas fa-filter"></i> {{ t('correction.open_filters') }}
            </button>
            <button type="button" class="btn btn-light btn-refresh" @click="loadData" :disabled="!vm.hasAppliedFilters || vm.loading" :title="t('correction.refresh')">
              <i class="fas fa-sync-alt" :class="{'fa-spin': vm.loading}"></i>
            </button>
            <span class="toolbar-counter" v-if="vm.hasAppliedFilters">{{ t('correction.count', { n: vm.total }) }}</span>
            <span class="toolbar-counter" v-else>{{ t('correction.waiting_filters') }}</span>
          </div>

          <div class="active-filters" v-if="vm.hasAppliedFilters && activeFilters.length">
            <span class="active-filters-label">{{ t('correction.active_filters') }}</span>
            <button v-for="filter in activeFilters" :key="filter.key" type="button"
                    class="filter-chip" @click="removeFilter(filter.key)" :title="t('correction.remove_filter')">
              {{ filter.label }} : {{ filter.value }} <i class="fas fa-times" aria-hidden="true"></i>
            </button>
            <button type="button" class="btn-clear-filters" @click="clearAppliedFilters">
              {{ t('correction.clear_all') }}
            </button>
          </div>

          <!-- TABLEAU -->
          <div class="list-grid">
            <table class="grid-table">
              <thead>
                <tr>
                  <th style="width:36px;"></th>
                  <th style="width:140px;">{{ t('saisie.col.piece_number') }}</th>
                  <th style="width:115px;">{{ t('saisie.col.date') }}</th>
                  <th style="width:100px;">{{ t('saisie.col.journal') }}</th>
                  <th>{{ t('saisie.col.libelle') }}</th>
                  <th style="width:120px;text-align:right;">{{ t('saisie.col.debit') }}</th>
                  <th style="width:120px;text-align:right;">{{ t('saisie.col.credit') }}</th>
                  <th style="width:120px;text-align:right;">{{ t('saisie.col.debit_rap') }}</th>
                  <th style="width:120px;text-align:right;">{{ t('saisie.col.credit_rap') }}</th>
                  <th style="width:120px;text-align:center;">{{ t('saisie.col.statut') }}</th>
                  <th style="width:100px;text-align:center;">Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr v-if="vm.loading"><td colspan="11" class="table-loading"><i class="fas fa-spinner fa-spin"></i> {{ t('correction.loading') }}</td></tr>
                <tr v-else-if="vm.error"><td colspan="11" class="table-empty table-error"><i class="fas fa-exclamation-circle"></i> {{ vm.error }}</td></tr>

                <tr v-else-if="!vm.hasAppliedFilters">
                  <td colspan="11" class="table-empty">
                    <i class="fas fa-filter empty-state-icon"></i>
                    <strong>{{ t('correction.initial_title') }}</strong>
                    <span>{{ t('correction.initial_hint') }}</span>
                  </td>
                </tr>
                <tr v-else-if="!vm.ecritures.length">
                  <td colspan="11" class="table-empty">
                    <i class="fas fa-inbox empty-state-icon"></i>
                    <strong>{{ t('correction.no_results') }}</strong>
                    <span>{{ t('correction.no_results_hint') }}</span>
                  </td>
                </tr>

                <template v-else v-for="e in vm.ecritures" :key="e.ID">
                  <tr class="ecr-main-row">
                    <td style="text-align:center;">
                      <button type="button" class="btn-toggle-ecr" @click.stop="toggleLines(e.ID)">
                        <i class="fas" :class="vm.expanded[e.ID] ? 'fa-chevron-down' : 'fa-chevron-right'"></i>
                      </button>
                    </td>
                    <td><span class="badge-code">{{ e.REFERENCE || '—' }}</span></td>
                    <td>{{ formatDate(e.DATE_COMPTABLE) }}</td>
                    <td><span class="badge-journal">{{ e.JOURNAL_CODE }}</span></td>
                    <td class="text-truncate" style="max-width:300px;" :title="e.LIBELLE">{{ e.LIBELLE }}</td>
                    <td class="cell-montant debit">{{ fmt(e.TOTAL_DEBIT) }}</td>
                    <td class="cell-montant credit">{{ fmt(e.TOTAL_CREDIT) }}</td>
                    <td class="cell-montant debit">{{ fmt(e.TOTAL_DEBIT_RAP) }}</td>
                    <td class="cell-montant credit">{{ fmt(e.TOTAL_CREDIT_RAP) }}</td>
                    <td style="text-align:center;">
                      <span class="badge-statut" :class="statusClass(e.STATUT)">{{ statusLabel(e.STATUT) }}</span>
                    </td>
                    <td style="text-align:center;">
                      <button type="button" class="btn btn-sm btn-info" @click="viewEcriture(e.ID)" title="Voir les détails">
                        <i class="fas fa-eye"></i>
                      </button>
                    </td>
                  </tr>

                  <!-- DÉTAIL DES LIGNES -->
                  <tr v-if="vm.expanded[e.ID] && vm.linesCache[e.ID]" class="ecr-sub-row">
                    <td colspan="11" style="padding:0;background:#f8fafc;">
                      <div style="padding:12px 20px;">
                        <table class="sub-grid-table">
                          <thead>
                            <tr>
                              <th style="width:30px;">#</th>
                              <th style="width:80px;">Aux.</th>
                              <th v-for="p in activePlans" :key="p.key" style="width:80px;">{{ p.label }}</th>
                              <th>Libellé</th>
                              <th style="width:100px;text-align:right;">Débit</th>
                              <th style="width:100px;text-align:right;">Crédit</th>
                              <th style="width:100px;text-align:right;">Débit RAP</th>
                              <th style="width:100px;text-align:right;">Crédit RAP</th>
                            </tr>
                          </thead>
                          <tbody>
                            <tr v-for="(l, i) in vm.linesCache[e.ID]" :key="i">
                              <td style="text-align:center;color:#94A3B8;">{{ i + 1 }}</td>
                              <td>{{ l.AUXILIAIRE || '—' }}</td>
                              <td v-for="p in activePlans" :key="p.key">
                                <span class="cell-badge">{{ resolveCode(p.ordre, l['PLAN' + p.ordre]) || '—' }}</span>
                              </td>
                              <td>{{ l.LIBELLE }}</td>
                              <td class="cell-montant debit">{{ l.DEBIT > 0 ? fmt(l.DEBIT) : '' }}</td>
                              <td class="cell-montant credit">{{ l.CREDIT > 0 ? fmt(l.CREDIT) : '' }}</td>
                              <td class="cell-montant debit">{{ (l.SENS === 'D' && l.MONTANT_DEVISE > 0) ? fmt(l.MONTANT_DEVISE) : '' }}</td>
                              <td class="cell-montant credit">{{ (l.SENS === 'C' && l.MONTANT_DEVISE > 0) ? fmt(l.MONTANT_DEVISE) : '' }}</td>
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

          <div class="pagination-bar" v-if="vm.hasAppliedFilters && vm.total > 0">
            <label class="page-size-control">
              {{ t('correction.rows_per_page') }}
              <select v-model.number="vm.pageSize" @change="changePageSize" class="form-control">
                <option :value="10">10</option>
                <option :value="25">25</option>
                <option :value="50">50</option>
                <option :value="100">100</option>
              </select>
            </label>
            <span class="pagination-summary">{{ t('correction.page', { page: vm.page, total: vm.totalPages }) }}</span>
            <div class="pagination-actions">
              <button type="button" class="btn btn-light" @click="goToPage(vm.page - 1)" :disabled="vm.page <= 1 || vm.loading" :aria-label="t('correction.previous')">
                <i class="fas fa-chevron-left"></i>
              </button>
              <button type="button" class="btn btn-light" @click="goToPage(vm.page + 1)" :disabled="vm.page >= vm.totalPages || vm.loading" :aria-label="t('correction.next')">
                <i class="fas fa-chevron-right"></i>
              </button>
            </div>
          </div>

          <!-- MODALE DE FILTRAGE -->
          <div id="filterModal" class="modal" v-show="vm.showFilterModal"
               role="dialog" aria-modal="true" aria-labelledby="filterModalTitle"
               @click.self="closeFilterModal" @keydown.esc="closeFilterModal">
            <div class="modal-content modal-filter">
              <div class="modal-header">
                <div>
                  <h3 id="filterModalTitle"><i class="fas fa-sliders-h"></i> {{ t('correction.filter_title') }}</h3>
                  <p>{{ t('correction.filter_hint') }}</p>
                </div>
                <button type="button" class="close" @click="closeFilterModal" :aria-label="t('correction.close')">&times;</button>
              </div>
              <div class="modal-body">
                <div class="filter-grid">
                  <div class="form-group">
                    <label for="glSite">{{ t('correction.site') }}</label>
                    <select id="glSite" v-model="filters.siteId" class="form-control">
                      <option value="">{{ t('correction.all_sites') }}</option>
                      <option v-for="s in lookup.sites" :key="s.ID" :value="s.ID">{{ s.CODE }} — {{ s.NOM }}</option>
                    </select>
                  </div>
                  <div class="form-group">
                    <label for="glJournal">{{ t('correction.journal') }}</label>
                    <select id="glJournal" v-model="filters.journalId" class="form-control">
                      <option value="">{{ t('correction.all_journals') }}</option>
                      <option v-for="j in lookup.journaux" :key="j.ID" :value="j.ID">{{ j.CODE }} — {{ j.LIBELLE }}</option>
                    </select>
                  </div>
                  <div class="form-group">
                    <label for="glCompte">Compte comptable</label>
                    <input id="glCompte" type="text" v-model.trim="filters.compte" class="form-control" placeholder="Ex: 401100" />
                  </div>
                  <div class="form-group">
                    <label for="glStatus">{{ t('correction.status') }}</label>
                    <select id="glStatus" v-model="filters.statut" class="form-control">
                      <option value="">{{ t('correction.all_statuses') }}</option>
                      <option value="BROUILLON">{{ t('saisie.statut.BROUILLON') }}</option>
                      <option value="A_VALIDER">{{ t('saisie.statut.A_VALIDER') }}</option>
                      <option value="VALIDEE">{{ t('saisie.statut.VALIDEE') }}</option>
                      <option value="COMPTABILISEE">{{ t('saisie.statut.COMPTABILISEE') }}</option>
                    </select>
                  </div>
                  <div class="form-group form-group-wide">
                    <label>Référence (N° pièce)</label>
                    <div class="range-group">
                      <input type="text" v-model.trim="filters.referenceDebut" class="form-control" placeholder="De..." />
                      <span class="range-label">{{ t('correction.to') }}</span>
                      <input type="text" v-model.trim="filters.referenceFin" class="form-control" placeholder="À..." />
                    </div>
                  </div>
                  <div class="form-group form-group-wide">
                    <label>{{ t('correction.date') }}</label>
                    <div class="range-group">
                      <input type="date" v-model="filters.dateDebut" class="form-control" />
                      <span class="range-label">{{ t('correction.to') }}</span>
                      <input type="date" v-model="filters.dateFin" class="form-control" />
                    </div>
                  </div>
                  <div class="form-group form-group-wide">
                    <label>{{ t('correction.amount') }}</label>
                    <div class="range-group">
                      <input type="number" min="0" step="0.01" v-model.number="filters.montantMin" class="form-control" placeholder="Min" />
                      <span class="range-label">{{ t('correction.to') }}</span>
                      <input type="number" min="0" step="0.01" v-model.number="filters.montantMax" class="form-control" placeholder="Max" />
                    </div>
                  </div>
                  <div class="form-group form-group-wide">
                    <label for="glMarket">{{ t('correction.market') }}</label>
                    <select id="glMarket" v-model="filters.marcheId" class="form-control">
                      <option value="">{{ t('correction.all_markets') }}</option>
                      <option v-for="m in lookup.marches" :key="m.ID" :value="m.ID">{{ m.NUMERO }} — {{ m.DESCRIPTION }}</option>
                    </select>
                  </div>
                </div>
                <p class="filter-error" v-if="vm.filterError" role="alert">{{ vm.filterError }}</p>
              </div>
              <div class="modal-footer">
                <button type="button" class="btn btn-light" @click="resetFilters"><i class="fas fa-undo"></i> Réinitialiser</button>
                <button type="button" class="btn btn-primary" @click="applyFilters" :disabled="vm.loading">
                  <i class="fas fa-search"></i> Appliquer les filtres
                </button>
              </div>
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
  <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/plan-config.js?v=<%=AuthHelper.Version %>"></script>
  <script src="js/grand-livre-vue.js?v=<%=AuthHelper.Version %>"></script>
</form>
</body>
</html>
