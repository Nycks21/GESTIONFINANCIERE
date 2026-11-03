<%@ Page Language="C#" AutoEventWireup="true" CodeFile="delletrage.cs" Inherits="delletrage" UICulture="Auto"
  Culture="Auto" %>
  <!DOCTYPE html>
  <html lang="<%= LocalizationHelper.CurrentCultureCode %>">

  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Délettrage — <%= LocalizationHelper.GetString("app.name") %>
    </title>
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/lettrage.css?v=<%=AuthHelper.Version %>" />
  </head>

  <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="delletrageFormPage" runat="server">
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
                      <h1 class="page-title">
                        <i class="fas fa-unlink"></i>
                        <span>Délettrage des comptes</span>
                      </h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb">
                        <li class="breadcrumb-item" data-i18n="menu.finance">Finance</li>
                        <li class="breadcrumb-item" data-i18n="menu.grand_livre">Grand Livre</li>
                        <li class="breadcrumb-item active">Délettrage</li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <section class="content liste-content">
                <div id="delletrageApp" v-cloak>

                  <!-- TOOLBAR -->
                  <div class="toolbar-modern">
                    <button type="button" class="btn btn-primary btn-filter" @click="openFilterModal">
                      <i class="fas fa-filter"></i> Choisir le compte
                    </button>
                    <button type="button" class="btn btn-light btn-refresh" @click="loadData"
                      :disabled="!vm.hasAppliedFilters || vm.loading">
                      <i class="fas fa-sync-alt" :class="{'fa-spin': vm.loading}"></i>
                    </button>
                    <div v-if="vm.hasAppliedFilters" class="toolbar-account-info">
                      <span class="badge-code">{{ vm.currentAccountCode }}</span>
                      <span class="account-name">{{ vm.currentAccountName }}</span>
                    </div>
                    <span class="toolbar-counter" v-if="vm.hasAppliedFilters">{{ vm.total }} ligne(s) lettrée(s)</span>
                  </div>

                  <!-- TABLEAU -->
                  <div class="list-grid">
                    <table class="grid-table">
                      <thead>
                        <tr>
                          <th style="width:40px;text-align:center;">
                            <input type="checkbox" @change="toggleAll($event)" :checked="isAllSelected"
                              :disabled="!vm.lines.length" />
                          </th>
                          <th style="width:110px;">Date</th>
                          <th style="width:140px;">N° Pièce</th>
                          <th style="width:80px;">Journal</th>
                          <th>Libellé</th>
                          <th style="width:120px;text-align:right;">Débit</th>
                          <th style="width:120px;text-align:right;">Crédit</th>
                          <th style="width:120px;text-align:center;">Code Lettrage</th>
                        </tr>
                      </thead>
                      <tbody>
                        <tr v-if="vm.loading">
                          <td colspan="8" class="table-loading"><i class="fas fa-spinner fa-spin"></i> Chargement...
                          </td>
                        </tr>

                        <tr v-else-if="!vm.hasAppliedFilters">
                          <td colspan="8" class="table-empty">
                            <i class="fas fa-mouse-pointer empty-state-icon"></i>
                            <strong>Veuillez sélectionner un compte de tiers.</strong>
                            <span>Le délettrage permet de rompre le rapprochement des factures et règlements.</span>
                          </td>
                        </tr>
                        <tr v-else-if="!vm.lines.length">
                          <td colspan="8" class="table-empty">
                            <i class="fas fa-info-circle empty-state-icon" style="color:#3B82F6;"></i>
                            <strong>Aucune ligne lettrée.</strong>
                            <span>Ce compte n'a pas de lettrage à annuler.</span>
                          </td>
                        </tr>

                        <tr v-else v-for="l in vm.lines" :key="l.ID"
                          :class="{'row-selected': vm.selectedLines.includes(l.ID)}">
                          <td style="text-align:center;">
                            <input type="checkbox" :value="l.ID" v-model="vm.selectedLines"
                              @change="computeSelection" />
                          </td>
                          <td>{{ formatDate(l.DATE_COMPTABLE) }}</td>
                          <td>
                            <span class="badge-code"
                              :title="l.NUMERO ? 'N° écriture : ' + l.NUMERO : 'N° écriture indisponible'">
                              {{ l.REFERENCE || l.NUMERO || '—' }}
                            </span>
                          </td>
                          <td><span class="badge-journal">{{ l.JOURNAL_CODE }}</span></td>
                          <td class="text-truncate" style="max-width:300px;">{{ l.LIBELLE }}</td>
                          <td class="cell-montant debit">{{ l.DEBIT > 0 ? fmt(l.DEBIT) : '' }}</td>
                          <td class="cell-montant credit">{{ l.CREDIT > 0 ? fmt(l.CREDIT) : '' }}</td>
                          <td style="text-align:center;">
                            <span class="badge" style="background:#FEF3C7;color:#B45309;font-weight:700;">{{
                              l.LETTRAGE_CODE }}</span>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </div>

                  <!-- BARRE D'ACTION FLOTTANTE POUR LE DÉLETTRAGE -->
                  <transition name="slide-up">
                    <div class="lettrage-action-bar" v-if="vm.selectedLines.length > 0">
                      <div class="lettrage-info">
                        <div class="lettrage-stat">
                          <span class="stat-label">Lignes sélectionnées</span>
                          <span class="stat-value" style="color:var(--s-primary);">{{ vm.selectedLines.length }}</span>
                        </div>
                      </div>
                      <div class="lettrage-actions">
                        <button type="button" class="btn btn-outline" @click="clearSelection">Annuler</button>
                        <button type="button" class="btn" style="background:#DC2626;color:white;"
                          @click="performDelletrage">
                          <i class="fas fa-unlink"></i> Délettrer la sélection
                        </button>
                      </div>
                    </div>
                  </transition>

                  <div class="pagination-bar" v-if="vm.hasAppliedFilters && vm.total > 0">
                    <span class="pagination-summary">Page {{ vm.page }} / {{ vm.totalPages }}</span>
                    <div class="pagination-actions">
                      <button type="button" class="btn btn-light" @click="goToPage(vm.page - 1)"
                        :disabled="vm.page <= 1 || vm.loading">
                        <i class="fas fa-chevron-left"></i>
                      </button>
                      <button type="button" class="btn btn-light" @click="goToPage(vm.page + 1)"
                        :disabled="vm.page >= vm.totalPages || vm.loading">
                        <i class="fas fa-chevron-right"></i>
                      </button>
                    </div>
                  </div>

                  <!-- MODALE DE FILTRAGE -->
                  <div id="filterModal" class="modal" v-show="vm.showFilterModal" role="dialog" aria-modal="true"
                    @click.self="closeFilterModal" @keydown.esc="closeFilterModal">
                    <div class="modal-content modal-filter" style="max-width:700px;">
                      <div class="modal-header">
                        <h3><i class="fas fa-unlink"></i> Choix du compte à délettrer</h3>
                        <button type="button" class="close" @click="closeFilterModal">&times;</button>
                      </div>
                      <div class="modal-body">
                        <div class="filter-grid">

                          <!-- ⭐ Compte comptable -->
                          <div class="form-group">
                            <label>Compte comptable (Tiers)</label>
                            <select v-model="filters.compteId" class="form-control" @change="onCompteChange">
                              <option value="">Sélectionnez un compte...</option>
                              <option v-for="c in lookup.comptes" :key="c.ID" :value="c.ID">
                                {{ c.CODE }} — {{ c.LIBELLE }}
                              </option>
                            </select>
                          </div>

                          <!-- ⭐ Auxiliaire (filtré par compte) -->
                          <div class="form-group">
                            <label>Auxiliaire (Tiers)</label>
                            <select v-model="filters.auxiliaire" class="form-control"
                              :disabled="!filters.compteId || filteredAuxiliaires.length === 0">
                              <option value="">Tous les auxiliaires</option>
                              <option v-for="t in filteredAuxiliaires" :key="t.ID" :value="t.CODE">
                                {{ t.CODE }} — {{ t.NOM }}
                              </option>
                            </select>
                            <small v-if="filters.compteId && filteredAuxiliaires.length === 0"
                              style="color:#6c757d; font-style:italic;">
                              Aucun auxiliaire rattaché à ce compte.
                            </small>
                          </div>

                          <!-- ⭐ Dates comptables -->
                          <div class="form-group form-group-wide">
                            <label>Date comptable</label>
                            <div class="range-group">
                              <input type="date" v-model="filters.dateDebut" class="form-control" placeholder="Du" />
                              <span class="range-label">au</span>
                              <input type="date" v-model="filters.dateFin" class="form-control" placeholder="Au" />
                            </div>
                          </div>

                        </div>
                      </div>
                      <div class="modal-footer">
                        <button type="button" class="btn btn-light" @click="resetFilterModal">
                          <i class="fas fa-undo"></i> Réinitialiser
                        </button>
                        <button type="button" class="btn btn-primary" @click="applyFilters"
                          :disabled="!filters.compteId">
                          <i class="fas fa-search"></i> Afficher les lignes lettrées
                        </button>
                      </div>
                    </div>
                  </div>

                </div>
              </section>
            </div>
      </div>

      <div id="spinnerOverlay">
        <div class="spinner"></div>
      </div>

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
      <script src="js/delletrage-vue.js?v=<%=AuthHelper.Version %>"></script>
    </form>
  </body>

  </html>
