<%@ Page Language="C#" AutoEventWireup="true" CodeFile="marche.cs" Inherits="marche" UICulture="Auto" Culture="Auto" %>
  <!DOCTYPE html>
  <html lang="<%= LocalizationHelper.CurrentCultureCode %>">

  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>
      <%= LocalizationHelper.GetString("marche.title") %> — <%= LocalizationHelper.GetString("app.name") %>
    </title>
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
  </head>

  <body class="hold-transition" data-version="<%=AuthHelper.Version %>">
    <form id="marcheFormPage" runat="server">
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
                        <i class="fas fa-file-contract"></i>
                        <span data-i18n="marche.title"></span>
                      </h1>
                    </div>
                    <div class="col-lg-6">
                      <ol class="breadcrumb">
                        <li class="breadcrumb-item" data-i18n="menu.finance">Finance</li>
                        <li class="breadcrumb-item active" data-i18n="marche.title">Contrats</li>
                      </ol>
                    </div>
                  </div>
                </div>
              </div>

              <section class="content saisie-content">

                <!-- TOOLBAR -->
                <div class="saisie-toolbar">
                  <button type="button" class="st-btn" onclick="focusSearch()">
                    <i class="fas fa-search"></i>
                    <span data-i18n="marche.toolbar.search"></span>
                  </button>
                  <button type="button" class="st-btn" onclick="printMarche()">
                    <i class="fas fa-print"></i>
                    <span data-i18n="marche.toolbar.print"></span>
                  </button>
                  <button type="button" class="st-btn" onclick="openAvenants()">
                    <i class="fas fa-file-signature"></i>
                    <span data-i18n="marche.toolbar.avenants"></span>
                  </button>
                  <button type="button" class="st-btn" onclick="openReception()">
                    <i class="fas fa-clipboard-check"></i>
                    <span data-i18n="marche.toolbar.reception"></span>
                  </button>

                  <div class="toolbar-spacer"></div>
                  <button type="button" class="st-btn st-btn-toggle" id="btnToggleCompact"
                    onclick="toggleCompactMode()">
                    <i class="fas fa-compress"></i>
                    <span data-i18n="marche.toolbar.compact"></span>
                  </button>
                </div>

                <!-- TABS -->
                <div class="saisie-tabs">
                  <button type="button" class="saisie-tab active" data-tab="list" onclick="switchTab('list')">
                    <i class="fas fa-list"></i>
                    <span data-i18n="marche.tab.list"></span>
                  </button>
                  <button type="button" class="saisie-tab" data-tab="edit" onclick="switchTab('edit')">
                    <i class="fas fa-pen-to-square"></i>
                    <span data-i18n="marche.tab.edit"></span>
                  </button>
                  <span id="dirtyIndicator" class="dirty-indicator" style="display:none;">
                    <i class="fas fa-circle"></i>
                    <span data-i18n="marche.msg.unsaved"></span>
                  </span>
                </div>

                <!-- ═══════════════════════════════════════════════════
                     ONGLET 1 — LISTE (Vue.js)
                     ═══════════════════════════════════════════════════ -->
                <div id="tab-list" class="saisie-tab-panel active">
                  <div id="marcheListApp" v-cloak>

                    <!-- Filtres -->
                    <div class="list-toolbar">
                      <div class="toolbar-search">
                        <i class="fas fa-search"></i>
                        <input type="text" id="search-filter" class="form-control" v-model="vm.search"
                          @input="onSearchInput" :placeholder="t('marche.search_placeholder')" />
                      </div>
                      <select class="form-control toolbar-select" v-model="vm.statut" @change="onFilterChange">
                        <option value="">{{ t('marche.filter.all_status') }}</option>
                        <option value="ATTRIBUE">{{ t('marche.statut.ATTRIBUE') }}</option>
                        <option value="EN_EXECUTION">{{ t('marche.statut.EN_EXECUTION') }}</option>
                        <option value="TERMINE">{{ t('marche.statut.TERMINE') }}</option>
                        <option value="ANNULE">{{ t('marche.statut.ANNULE') }}</option>
                        <option value="RESILIE">{{ t('marche.statut.RESILIE') }}</option>
                      </select>
                      <select class="form-control toolbar-select" v-model="vm.typeMarche" @change="onFilterChange">
                        <option value="">{{ t('marche.filter.all_types') }}</option>
                        <option value="FOURNITURES">{{ t('marche.type.FOURNITURES') }}</option>
                        <option value="TRAVAUX">{{ t('marche.type.TRAVAUX') }}</option>
                        <option value="SERVICES">{{ t('marche.type.SERVICES') }}</option>
                        <option value="PRESTATIONS_INTELLECTUELLES">{{ t('marche.type.PRESTATIONS_INTELLECTUELLES') }}
                        </option>
                        <option value="AUTRE">{{ t('marche.type.AUTRE') }}</option>
                      </select>
                      <button class="btn btn-light btn-sm" @click="resetFilters" type="button">
                        <i class="fas fa-undo"></i>
                      </button>
                      <span class="toolbar-counter">{{ counterText }}</span>
                      <button class="btn btn-success btn-sm" @click="newMarche" type="button">
                        <i class="fas fa-plus"></i> {{ t('marche.btn.add') }}
                      </button>
                    </div>

                    <!-- Tableau -->
                    <div class="list-grid">
                      <table class="grid-table" id="marchesTable">
                        <thead>
                          <tr>
                            <th style="width:36px;"></th>
                            <th style="width:150px;">{{ t('marche.col.numero') }}</th>
                            <th style="width:110px;">{{ t('marche.col.date_signature') }}</th>
                            <th style="width:110px;">{{ t('marche.col.date_debut') }}</th>
                            <th style="width:110px;">{{ t('marche.col.date_fin') }}</th>
                            <th>{{ t('marche.col.fournisseur') }}</th>
                            <th style="width:130px;">{{ t('marche.col.type') }}</th>
                            <th style="width:120px; text-align:right;">{{ t('marche.col.montant_loc_ttc') }}</th>
                            <th style="width:120px; text-align:right;">{{ t('marche.col.montant_dev_ttc') }}</th>
                            <th style="width:120px; text-align:center;">{{ t('marche.col.statut') }}</th>
                            <th style="width:130px; text-align:right;">{{ t('marche.col.actions') }}</th>
                          </tr>
                        </thead>
                        <tbody id="marchesBody">

                          <tr v-if="vm.loading">
                            <td colspan="11" class="table-loading">
                              <i class="fas fa-spinner fa-spin"></i>
                              {{ t('marche.msg.loading') }}
                            </td>
                          </tr>
                          <tr v-else-if="vm.error">
                            <td colspan="11" class="table-empty">
                              <i class="fas fa-exclamation-triangle"></i>
                              <span>{{ vm.error }}</span>
                            </td>
                          </tr>
                          <tr v-else-if="!vm.marches.length">
                            <td colspan="11" class="table-empty">
                              <i class="fas fa-inbox"></i>
                              <span>{{ t('marche.msg.no_data') }}</span>
                            </td>
                          </tr>

                          <template v-else v-for="m in vm.marches" :key="m.ID">
                            <tr class="ecr-main-row" :data-id="m.ID">
                              <td style="text-align:center;">
                                <button type="button" class="btn-toggle-ecr" @click.stop="toggleLines(m.ID)"
                                  style="background:none;border:none;cursor:pointer;color:#007bff;padding:4px 8px;">
                                  <i class="fas"
                                    :class="vm.expanded[m.ID] ? 'fa-chevron-down' : 'fa-chevron-right'"></i>
                                </button>
                              </td>
                              <td><span class="badge-code">{{ m.NUMERO }}</span></td>
                              <td>{{ m.DATE_SIGNATURE || '—' }}</td>
                              <td>{{ m.DATE_DEBUT || '—' }}</td>
                              <td>{{ m.DATE_FIN || '—' }}</td>
                              <td>{{ m.FOURNISSEUR_NOM || '—' }}</td>
                              <td><span class="badge-journal">{{ typeLabel(m.TYPE_MARCHE) }}</span></td>
                              <td style="text-align:right;font-family:monospace;color:#B91C1C;">
                                {{ fmt(m.MONTANT_LOC_TTC) }}
                              </td>
                              <td style="text-align:right;font-family:monospace;color:#047857;">
                                {{ fmt(m.MONTANT_DEV_TTC) }}
                              </td>
                              <td style="text-align:center;">
                                <span class="badge-statut" :class="statusClass(m.STATUT)">
                                  {{ statusLabel(m.STATUT) }}
                                </span>
                              </td>
                              <td style="text-align:right;">
                                <button type="button" class="btn btn-sm btn-primary" @click="editMarche(m.ID)">
                                  <i class="fas fa-edit"></i>
                                </button>
                                <button type="button" class="btn btn-sm btn-danger" @click="delMarche(m.ID)">
                                  <i class="fas fa-trash"></i>
                                </button>
                              </td>
                            </tr>

                            <!-- Sous-ligne : lignes du marché -->
                            <tr v-if="vm.expanded[m.ID] && vm.linesCache[m.ID]" class="ecr-sub-row">
                              <td colspan="11" style="padding:0;background:#f8f9fa;border-bottom:2px solid #dee2e6;">
                                <div style="padding:10px 20px 14px;">
                                  <table style="width:100%;font-size:12px;border-collapse:collapse;">
                                    <thead>
                                      <tr
                                        style="background:#e9ecef;color:#495057;font-size:11px;text-transform:uppercase;">
                                        <th style="width:36px;">#</th>
                                        <th>{{ t('marche.col.designation') }}</th>
                                        <th style="width:110px;text-align:right;">{{ t('marche.col.montant_loc_ht') }}
                                        </th>
                                        <th style="width:110px;text-align:right;">{{ t('marche.col.montant_loc_tva') }}
                                        </th>
                                        <th style="width:110px;text-align:right;">{{ t('marche.col.montant_loc_ttc') }}
                                        </th>
                                        <th style="width:80px;text-align:right;">{{ t('marche.col.taxe') }}</th>
                                      </tr>
                                    </thead>
                                    <tbody>
                                      <tr v-for="(l, i) in vm.linesCache[m.ID]" :key="l.ID || i"
                                        style="border-bottom:1px solid #e9ecef;">
                                        <td style="text-align:center;color:#94A3B8;">{{ i + 1 }}</td>
                                        <td>{{ l.DESIGNATION }}</td>
                                        <td style="text-align:right;font-family:monospace;color:#B91C1C;">
                                          {{ fmt(l.MONTANT_LOC_HT) }}
                                        </td>
                                        <td style="text-align:right;font-family:monospace;color:#6B7280;">
                                          {{ fmt(l.MONTANT_LOC_TVA) }}
                                        </td>
                                        <td style="text-align:right;font-family:monospace;color:#047857;">
                                          {{ fmt(l.MONTANT_LOC_TTC) }}
                                        </td>
                                        <td style="text-align:right;font-family:monospace;color:#6B7280;">
                                          {{ l.TAXE }} %
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
                    <div class="pagination-wrapper" id="paginationWrapper">
                      <div v-if="pagination.length"
                        style="margin:12px 0;display:flex;justify-content:center;gap:5px;flex-wrap:wrap;">
                        <button v-for="(p, idx) in pagination" :key="idx" type="button" @click="goToPage(p.page)"
                          :disabled="p.disabled" :style="paginationStyle(p)">
                          {{ p.text }}
                        </button>
                      </div>
                    </div>

                  </div>
                </div>

                <!-- ═══════════════════════════════════════════════════
                     ONGLET 2 — SAISIE / CORRECTION
                     ═══════════════════════════════════════════════════ -->
                <div id="tab-edit" class="saisie-tab-panel">
                  <input type="hidden" id="editingId" value="" />
                  <input type="hidden" id="marNumero" value="" />
                  <input type="hidden" id="marLibelle" value="" />

                  <!-- BLOC 1 : ENTÊTE -->
                  <div class="ecr-block ecr-header">
                    <div class="ecr-block-title">
                      <i class="fas fa-info-circle"></i>
                      <span data-i18n="marche.section.header"></span>
                    </div>

                    <div class="eh-sections">
                      <section class="eh-section">
                        <h3 class="eh-section-title">
                          <i class="fas fa-building"></i>
                          <span data-i18n="marche.section.identification"></span>
                        </h3>
                        <div class="eh-section-fields">
                          <div class="eh-field">
                            <label data-i18n="marche.col.numero"></label>
                            <input type="text" id="marNumeroInput" class="form-control" maxlength="50" />
                          </div>
                          <div class="eh-field">
                            <label data-i18n="marche.col.site"></label>
                            <select id="marSite" class="form-control"></select>
                          </div>


                        </div>
                      </section>

                      <section class="eh-section">
                        <h3 class="eh-section-title">
                          <i class="fas fa-calendar-alt"></i>
                          <span data-i18n="marche.section.rens"></span>
                        </h3>
                        <div class="eh-section-fields">
                          <div class="row">
                            <div class="col-md-6">
                              <div class="eh-field">
                                <label data-i18n="marche.col.fournisseur"></label>
                                <select id="marFournisseur" class="form-control"></select>
                              </div>
                            </div>

                            <div class="col-md-6">
                              <div class="eh-field">
                                <label data-i18n="marche.col.auxi"></label>
                                <select id="marAuxi" class="form-control" disabled
                                  data-i18n-attr="title:marche.hint.aux_filtered" onchange="markDirty()"></select>
                                <!--<small id="marAuxHint" class="field-hint" data-i18n="marche.hint.aux_initial"></small>-->
                              </div>
                            </div>
                          </div>
                          <div class="row">
                            <div class="col-md-6">
                              <div class="eh-field">
                                <label data-i18n="marche.col.type"></label>
                                <select id="marType" class="form-control">
                                  <option value="FRT">Fournitures</option>
                                  <option value="TRX">Travaux</option>
                                  <option value="SRV">Services</option>
                                  <option value="PIS">Prestations intellectuelles</option>
                                  <option value="ATR">Autre</option>
                                </select>
                              </div>
                            </div>

                            <div class="col-md-6">
                              <div class="eh-field">
                                <label data-i18n="marche.col.mode_passation"></label>
                                <select id="marMode" class="form-control">
                                  <option value="AON">Appel d'offres national</option>
                                  <option value="AOI">Appel d'offres international</option>
                                  <option value="CST">Consultation</option>
                                  <option value="GAG">Gré à gré</option>
                                  <option value="EDT">Entente directe</option>
                                  <option value="ATR">Autre</option>
                                </select>
                              </div>
                            </div>
                          </div>
                        </div>
                      </section>

                      <section class="eh-section">
                        <h3 class="eh-section-title">
                          <i class="fas fa-coins"></i>
                          <span data-i18n="marche.section.dates"></span>
                        </h3>
                        <div class="eh-section-fields">
                          <div class="row">
                            <div class="col-md-6">
                              <div class="eh-field">
                                <label data-i18n="marche.col.date_lancement"></label>
                                <input type="date" id="marDateLancement" class="form-control" />
                              </div>
                            </div>
                            <!--<div class="eh-field">
                                <label data-i18n="marche.col.date_attribution"></label>
                                <input type="date" id="marDateAttribution" class="form-control" />
                              </div>-->
                            <div class="col-md-6">
                              <div class="eh-field">
                                <label data-i18n="marche.col.date_signature"></label>
                                <input type="date" id="marDateSignature" class="form-control" />
                              </div>
                            </div>
                          </div>
                          <div class="row">
                            <div class="col-md-6">
                              <div class="eh-field">
                                <label data-i18n="marche.col.date_debut"></label>
                                <input type="date" id="marDateDebut" class="form-control" />
                              </div>
                            </div>
                            <div class="col-md-6">
                              <div class="eh-field">
                                <label data-i18n="marche.col.date_fin"></label>
                                <input type="date" id="marDateFin" class="form-control" />
                              </div>
                            </div>
                          </div>
                        </div>
                      </section>

                      <section class="eh-section">
                        <h3 class="eh-section-title">
                          <i class="fas fa-clipboard-list"></i>
                          <span data-i18n="marche.section.reference_status"></span>
                        </h3>

                        <div class="eh-section-fields">
                          <div class="eh-field">
                            <label data-i18n="marche.col.cours_devise"></label>
                            <input type="text" id="marCoursDevise" class="form-control money-input" data-money-field="1"
                              value="0" autocomplete="off" />
                          </div>
                          <div class="eh-field">
                            <label data-i18n="marche.col.statut"></label>
                            <select id="marStatut" class="form-control">
                              <option value="1">Attribué</option>
                              <option value="2">Terminé</option>
                              <option value="3">Annulé</option>
                              <option value="4">Résilié</option>
                            </select>
                          </div>
                        </div>
                      </section>
                    </div>

                    <div class="eh-field" style="margin-top:12px;">
                      <label data-i18n="marche.col.description"></label>
                      <input type="text" id="marDescription" class="form-control" rows="2" maxlength="2000" />
                    </div>
                  </div>

                  <!-- BLOC 2 : LIGNE + TOTAUX -->
                  <div class="ecr-bottom">
                    <div class="ecr-block eb-form">
                      <div class="ecr-block-title">
                        <i class="fas fa-edit"></i>
                        <span data-i18n="marche.section.line"></span>
                      </div>

                      <div class="eb-form-row">
                        <!--<div class="eb-field eb-w-2">
                          <label data-i18n="marche.col.article"></label>
                          <select id="mlArticle" class="form-control"></select>
                        </div>-->
                        <div class="eb-field eb-w-full">
                          <label data-i18n="marche.col.designation"></label>
                          <input type="text" id="mlDesignation" class="form-control" maxlength="500" />
                        </div>
                      </div>

                      <div class="eb-form-row" id="dynPlanFieldsRow"></div>

                      <div class="eb-form-row">
                        <div class="eb-field">
                          <label data-i18n="marche.col.taxe"></label>
                          <input type="text" id="mlTaxe" class="form-control money-input" data-money-field="1" value="0"
                            autocomplete="off" />
                        </div>
                        <div class="eb-field">
                          <label data-i18n="marche.col.montant_loc_ht"></label>
                          <input type="text" id="mlMontantLocHT" class="form-control money-input" data-money-field="1"
                            value="0" autocomplete="off" />
                        </div>
                        <div class="eb-field">
                          <label data-i18n="marche.col.montant_rap_ht"></label>
                          <input type="text" id="mlMontantRapHT" class="form-control money-input" data-money-field="1"
                            value="0" autocomplete="off" />
                        </div>
                      </div>
                    </div>

                    <div class="ecr-block eb-totaux">
                      <div class="ecr-block-title">
                        <i class="fas fa-calculator"></i>
                        <span data-i18n="marche.section.totals"></span>
                      </div>

                      <table class="totaux-table">
                        <thead>
                          <tr>
                            <th></th>
                            <th data-i18n="marche.col.montant_loc_ht"></th>
                            <th data-i18n="marche.col.montant_loc_tva"></th>
                            <th data-i18n="marche.col.montant_loc_ttc"></th>
                          </tr>
                        </thead>
                        <tbody>
                          <tr>
                            <td class="tt-label" data-i18n="marche.totaux.total"></td>
                            <td class="tt-val" id="ttLocHT">0,00</td>
                            <td class="tt-val" id="ttLocTVA">0,00</td>
                            <td class="tt-val" id="ttLocTTC">0,00</td>
                          </tr>
                          <tr>
                            <td class="tt-label" data-i18n="marche.totaux.rap"></td>
                            <td class="tt-val" id="ttRapHT">0,00</td>
                            <td class="tt-val" id="ttRapTVA">0,00</td>
                            <td class="tt-val" id="ttRapTTC">0,00</td>
                          </tr>
                        </tbody>
                      </table>

                      <div class="ligne-actions">
                        <button type="button" class="la-btn la-validate" onclick="validateLigne()">
                          <i class="fas fa-check"></i>
                        </button>
                        <button type="button" class="la-btn la-add" onclick="newLigne()">
                          <i class="fas fa-plus"></i>
                        </button>
                        <button type="button" class="la-btn la-edit" onclick="editCurrentLigne()">
                          <i class="fas fa-pen"></i>
                        </button>
                        <button type="button" class="la-btn la-dup" onclick="duplicateLigne()">
                          <i class="fas fa-clone"></i>
                        </button>
                        <button type="button" class="la-btn la-del" onclick="deleteCurrentLigne()">
                          <i class="fas fa-trash"></i>
                        </button>
                        <button type="button" id="btnSaveMarche" class="la-btn la-save" onclick="saveMarche(event)"
                          disabled>
                          <i class="fas fa-save"></i>
                        </button>
                      </div>

                      <div class="ligne-actions2">
                        <button type="button" class="la-btn la-erase" onclick="clearCurrentLigne()">
                          <i class="fas fa-eraser"></i>
                        </button>
                        <button type="button" class="la-btn la-undo" onclick="undoLigne()">
                          <i class="fas fa-undo"></i>
                        </button>
                        <button type="button" class="la-btn la-del-ecriture" onclick="deleteCurrentMarche()">
                          <i class="fas fa-trash-alt"></i>
                          <span data-i18n="marche.action.delete_marche"></span>
                        </button>
                      </div>
                    </div>
                  </div>

                  <!-- BLOC 3 : GRILLE -->
                  <div class="ecr-block">
                    <div class="ecr-block-title">
                      <i class="fas fa-table"></i>
                      <span data-i18n="marche.section.lines"></span>
                      <span class="ecr-block-counter" id="marLinesCounter"></span>
                    </div>
                    <div class="ecr-grid-wrapper">
                      <table class="grid-table ecr-grid" id="marGrid">
                        <thead>
                          <tr id="marGridHeadRow"></tr>
                        </thead>
                        <tbody id="marLignesBody">
                          <tr>
                            <td colspan="15" class="table-empty">
                              <i class="fas fa-inbox"></i>
                              <span data-i18n="marche.msg.no_lignes"></span>
                            </td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
                <!-- /tab-edit -->

              </section>
            </div>
      </div>

      <div id="spinnerOverlays" aria-hidden="true">
        <div class="spinner"></div>
      </div>

      <!-- Librairies -->
      <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/csrf.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>
      <script src="../../_assets/js/vue.global.prod.js?v=<%=AuthHelper.Version %>"></script>

      <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>

      <!-- Scripts applicatifs -->
      <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/money-input.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/plan-config.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/i18n-refresh.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/marche-vue.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/ui.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/loaders.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/grid.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/totaux.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/form.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/validation.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/crud.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/keyboard.js?v=<%=AuthHelper.Version %>"></script>
      <script src="js/init.js?v=<%=AuthHelper.Version %>"></script>

      <div id="toastContainer"></div>
    </form>
  </body>

  </html>
