<%@ Page Language="C#" AutoEventWireup="true" CodeFile="saisie.cs" Inherits="saisie" UICulture="Auto" Culture="Auto" %>
<!DOCTYPE html>
<html lang="<%= LocalizationHelper.CurrentCultureCode %>">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title><%= LocalizationHelper.GetString("saisie.title") %>  <%= LocalizationHelper.GetString("app.name") %></title>
    <link rel="stylesheet" href="../../_assets/css/all.min.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/fontawesome.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="../../_assets/css/global.css?v=<%=AuthHelper.Version %>" />
    <link rel="stylesheet" href="css/style.css?v=<%=AuthHelper.Version %>" />
</head>

<body class="hold-transition" data-version="<%=AuthHelper.Version %>">
<form id="saisieFormPage" runat="server">
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
                                <i class="fas fa-pen-fancy"></i>
                                <span data-i18n="saisie.title"></span>
                            </h1>
                        </div>
                        <div class="col-lg-6">
                            <ol class="breadcrumb">
                                <li class="breadcrumb-item" data-i18n="menu.finance">Finance</li>
                                <li class="breadcrumb-item active" data-i18n="saisie.title">Saisie</li>
                            </ol>
                        </div>
                    </div>
                </div>
            </div>

            <section class="content saisie-content">

                <!-- TOOLBAR -->
                <div class="saisie-toolbar">
                    <button type="button" class="st-btn" onclick="focusSearch()"
                            data-i18n-attr="title:saisie.toolbar.search_hint">
                        <i class="fas fa-search"></i>
                        <span data-i18n="saisie.toolbar.search"></span>
                    </button>
                    <button type="button" class="st-btn" onclick="printEcriture()"
                            data-i18n-attr="title:saisie.toolbar.print_hint">
                        <i class="fas fa-print"></i>
                        <span data-i18n="saisie.toolbar.print"></span>
                    </button>
                    <button type="button" class="st-btn" onclick="openVentilations()"
                            data-i18n-attr="title:saisie.toolbar.ventilations_hint">
                        <i class="fas fa-project-diagram"></i>
                        <span data-i18n="saisie.toolbar.ventilations"></span>
                    </button>
                    <button type="button" class="st-btn" onclick="openFichesImputation()"
                            data-i18n-attr="title:saisie.toolbar.fiches_hint">
                        <i class="fas fa-book"></i>
                        <span data-i18n="saisie.toolbar.fiches"></span>
                    </button>

                    <div class="toolbar-spacer"></div>
                    <button type="button" class="st-btn st-btn-toggle" id="btnToggleCompact"
                            onclick="toggleCompactMode()"
                            data-i18n-attr="title:saisie.toolbar.compact_hint">
                        <i class="fas fa-compress"></i>
                        <span data-i18n="saisie.toolbar.compact"></span>
                    </button>
                </div>

                <!-- TABS -->
                <div class="saisie-tabs">
                    <button type="button" class="saisie-tab active" data-tab="list" onclick="switchTab('list')">
                        <i class="fas fa-list"></i>
                        <span data-i18n="saisie.tab.list"></span>
                    </button>
                    <button type="button" class="saisie-tab" data-tab="edit" onclick="switchTab('edit')">
                        <i class="fas fa-pen-to-square"></i>
                        <span data-i18n="saisie.tab.edit"></span>
                    </button>
                    <span id="dirtyIndicator" class="dirty-indicator" style="display:none;">
                        <i class="fas fa-circle"></i>
                        <span data-i18n="saisie.msg.unsaved"></span>
                    </span>
                </div>

                <!-- ═══════════════════════════════════════════════════
                     ONGLET 1  LISTE (Vue.js)
                     ═══════════════════════════════════════════════════ -->
                <div id="tab-list" class="saisie-tab-panel active">
                    <div id="saisieListApp" v-cloak>

                        <!-- Toolbar filtres -->
                        <div class="list-toolbar">
                            <div class="toolbar-search">
                                <i class="fas fa-search"></i>
                                <input type="text" id="search-filter" class="form-control"
                                       v-model="vm.search" @input="onSearchInput"
                                       :placeholder="t('saisie.search_placeholder')" />
                            </div>
                            <select id="journal-filter" class="form-control toolbar-select"
                                    v-model="vm.journalId" @change="onFilterChange"
                                    :title="t('saisie.filter.journal_hint')">
                                <option value="">{{ t('saisie.filter.all_journals') }}</option>
                                <option v-for="j in journaux" :key="j.ID" :value="j.ID">{{ j.CODE }}</option>
                            </select>
                            <select id="statut-filter" class="form-control toolbar-select"
                                    v-model="vm.statut" @change="onFilterChange"
                                    :title="t('saisie.filter.status_hint')">
                                <option value="">{{ t('saisie.filter.all_status') }}</option>
                                <option value="BROUILLON">{{ t('saisie.statut.BROUILLON') }}</option>
                                <option value="VALIDEE">{{ t('saisie.statut.VALIDEE') }}</option>
                                <option value="COMPTABILISEE">{{ t('saisie.statut.COMPTABILISEE') }}</option>
                            </select>
                            <button class="btn btn-light btn-sm" @click="resetFilters" type="button"
                                    :title="t('saisie.filter.reset_hint')">
                                <i class="fas fa-undo"></i>
                            </button>
                            <span class="toolbar-counter" id="resultsCounter">{{ counterText }}</span>
                            <button class="btn btn-success btn-sm" @click="newEcr" type="button">
                                <i class="fas fa-plus"></i> {{ t('saisie.btn.add') }}
                            </button>
                        </div>

                        <!-- Tableau -->
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
                                        <th style="width:120px; text-align:right;">{{ t('saisie.col.debit') }}</th>
                                        <th style="width:120px; text-align:right;">{{ t('saisie.col.credit') }}</th>
                                        <th style="width:120px; text-align:right;">{{ t('saisie.col.debit_rap') }}</th>
                                        <th style="width:120px; text-align:right;">{{ t('saisie.col.credit_rap') }}</th>
                                        <th style="width:120px; text-align:center;">{{ t('saisie.col.statut') }}</th>
                                        <th style="width:130px; text-align:right;">{{ t('saisie.col.actions') }}</th>
                                    </tr>
                                </thead>
                                <tbody id="ecrituresBody">

                                    <!-- Loading -->
                                    <tr v-if="vm.loading">
                                        <td colspan="12" class="table-loading">
                                            <i class="fas fa-spinner fa-spin"></i>
                                            {{ t('saisie.msg.loading') }}
                                        </td>
                                    </tr>

                                    <!-- Error -->
                                    <tr v-else-if="vm.error">
                                        <td colspan="12" class="table-empty">
                                            <i class="fas fa-exclamation-triangle"></i>
                                            <span>{{ vm.error }}</span>
                                        </td>
                                    </tr>

                                    <!-- Empty -->
                                    <tr v-else-if="!vm.ecritures.length">
                                        <td colspan="12" class="table-empty">
                                            <i class="fas fa-inbox"></i>
                                            <span>{{ t('saisie.msg.no_data') }}</span>
                                        </td>
                                    </tr>

                                    <!-- Rows -->
                                    <template v-else v-for="e in vm.ecritures" :key="e.ID">
                                        <tr class="ecr-main-row" :data-id="e.ID">
                                            <td style="text-align:center;">
                                                <button type="button" class="btn-toggle-ecr"
                                                        @click.stop="toggleLines(e.ID)"
                                                        :title="t('saisie.action.toggle_lines')"
                                                        style="background:none;border:none;cursor:pointer;color:#007bff;padding:4px 8px;">
                                                    <i class="fas"
                                                       :class="vm.expanded[e.ID] ? 'fa-chevron-down' : 'fa-chevron-right'"></i>
                                                </button>
                                            </td>
                                            <td><span class="badge-code">{{ e.REFERENCE || '' }}</span></td>
                                            <td>
                                                <span v-if="e.DATE_PIECE">{{ e.DATE_PIECE }}</span>
                                                <span v-else class="cell-empty">&mdash;</span>
                                            </td>
                                            <td>{{ e.DATE_COMPTABLE }}</td>
                                            <td><span class="badge-journal">{{ e.JOURNAL_CODE || '?' }}</span></td>
                                            <td>{{ e.LIBELLE }}</td>
                                            <td style="text-align:right;font-family:monospace;color:#B91C1C;">
                                                {{ fmt(e.TOTAL_DEBIT) }}</td>
                                            <td style="text-align:right;font-family:monospace;color:#047857;">
                                                {{ fmt(e.TOTAL_CREDIT) }}</td>
                                            <td style="text-align:right;font-family:monospace;color:#B91C1C;">
                                                <span v-if="parseFloat(e.TOTAL_DEBIT_RAP || 0) > 0">
                                                    {{ fmt(e.TOTAL_DEBIT_RAP) }}
                                                </span>
                                                <span v-else class="cell-empty">0,00</span>
                                            </td>
                                            <td style="text-align:right;font-family:monospace;color:#047857;">
                                                <span v-if="parseFloat(e.TOTAL_CREDIT_RAP || 0) > 0">
                                                    {{ fmt(e.TOTAL_CREDIT_RAP) }}
                                                </span>
                                                <span v-else class="cell-empty">0,00</span>
                                            </td>
                                            <td style="text-align:center;">
                                                <span class="badge-statut" :class="statusClass(e.STATUT)">
                                                    {{ statusLabel(e.STATUT) }}
                                                </span>
                                            </td>
                                            <td style="text-align:right;">
                                                <button type="button" class="btn btn-sm btn-primary"
                                                        @click="editEcr(e.ID)"
                                                        :title="t('button.edit')">
                                                    <i class="fas fa-edit"></i>
                                                </button>
                                                <button type="button" class="btn btn-sm btn-danger"
                                                        @click="delEcr(e.ID)"
                                                        :title="t('button.delete')">
                                                    <i class="fas fa-trash"></i>
                                                </button>
                                            </td>
                                        </tr>

                                        <!-- Sous-ligne -->
                                        <tr v-if="vm.expanded[e.ID] && vm.linesCache[e.ID]" class="ecr-sub-row">
                                            <td colspan="12" style="padding:0;background:#f8f9fa;border-bottom:2px solid #dee2e6;">
                                                <div style="padding:10px 20px 14px;">
                                                    <table style="width:100%;font-size:12px;border-collapse:collapse;">
                                                        <thead>
                                                            <tr style="background:#e9ecef;color:#495057;font-size:11px;text-transform:uppercase;letter-spacing:.5px;">
                                                                <th style="width:36px;">#</th>
                                                                <th style="width:90px;">{{ t('saisie.col.auxiliaire') }}</th>
                                                                <th v-for="p in activePlans" :key="p.key" style="width:90px;">
                                                                    {{ p.label }}
                                                                </th>
                                                                <th>{{ t('saisie.col.libelle') }}</th>
                                                                <th style="width:110px;text-align:right;">{{ t('saisie.col.debit') }}</th>
                                                                <th style="width:110px;text-align:right;">{{ t('saisie.col.credit') }}</th>
                                                                <th style="width:110px;text-align:right;">{{ t('saisie.col.debit_rap') }}</th>
                                                                <th style="width:110px;text-align:right;">{{ t('saisie.col.credit_rap') }}</th>
                                                            </tr>
                                                        </thead>
                                                        <tbody>
                                                            <tr v-for="(l, i) in vm.linesCache[e.ID]" :key="l.ID || i"
                                                                style="border-bottom:1px solid #e9ecef;">
                                                                <td style="text-align:center;color:#94A3B8;">{{ i + 1 }}</td>
                                                                <td>{{ l.AUXILIAIRE || '' }}</td>
                                                                <td v-for="p in activePlans" :key="p.key">
                                                                    <span class="cell-badge"
                                                                          :title="resolveCode(p.ordre, l['PLAN' + p.ordre])">
                                                                        {{ resolveCode(p.ordre, l['PLAN' + p.ordre]) || '' }}
                                                                    </span>
                                                                </td>
                                                                <td>{{ l.LIBELLE }}</td>
                                                                <td style="text-align:right;font-family:monospace;color:#B91C1C;">
                                                                    <span v-if="parseFloat(l.DEBIT || 0) > 0">{{ fmt(l.DEBIT) }}</span>
                                                                </td>
                                                                <td style="text-align:right;font-family:monospace;color:#047857;">
                                                                    <span v-if="parseFloat(l.CREDIT || 0) > 0">{{ fmt(l.CREDIT) }}</span>
                                                                </td>
                                                                <td style="text-align:right;font-family:monospace;color:#B91C1C;">
                                                                    <span v-if="l.SENS === 'D' && parseFloat(l.MONTANT_DEVISE || 0) > 0">
                                                                        {{ fmt(l.MONTANT_DEVISE) }}
                                                                    </span>
                                                                </td>
                                                                <td style="text-align:right;font-family:monospace;color:#047857;">
                                                                    <span v-if="l.SENS === 'C' && parseFloat(l.MONTANT_DEVISE || 0) > 0">
                                                                        {{ fmt(l.MONTANT_DEVISE) }}
                                                                    </span>
                                                                </td>
                                                            </tr>
                                                        </tbody>
                                                    </table>
                                                    <div style="margin-top:8px;font-size:11px;color:#6c757d;">
                                                        {{ vm.linesCache[e.ID].length }} {{ t('saisie.lines_count_unit') }}
                                                        {{ t('saisie.col.debit') }} :
                                                        <strong style="color:#B91C1C;">{{ fmt(sumDebit(vm.linesCache[e.ID])) }}</strong>
                                                         {{ t('saisie.col.credit') }} :
                                                        <strong style="color:#047857;">{{ fmt(sumCredit(vm.linesCache[e.ID])) }}</strong>
                                                    </div>
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
                                <button v-for="(p, idx) in pagination" :key="idx"
                                        type="button"
                                        @click="goToPage(p.page)"
                                        :disabled="p.disabled"
                                        :style="paginationStyle(p)">
                                    {{ p.text }}
                                </button>
                            </div>
                        </div>

                    </div>
                </div>

                <!-- ═══════════════════════════════════════════════════
                     ONGLET 2  SAISIE / CORRECTION (Vanilla JS)
                     ═══════════════════════════════════════════════════ -->
                <div id="tab-edit" class="saisie-tab-panel">
                    <input type="hidden" id="editingId" value="" />
                    <input type="hidden" id="ecrNumero" value="" />
                    <input type="hidden" id="ecrPeriode" value="" />
                    <input type="hidden" id="ecrLibelle" value="" />

                    <!-- BLOC 1 : ENTÊTE -->
                    <div class="ecr-block ecr-header">
                        <div class="ecr-block-title">
                            <i class="fas fa-info-circle"></i>
                            <span data-i18n="saisie.section.header"></span>
                        </div>

                        <div class="eh-grid eh-grid-5">
                            <div class="eh-field">
                                <label data-i18n="saisie.col.centre"></label>
                                <select id="ecrSite" class="form-control"></select>
                            </div>
                            <div class="eh-field">
                                <label data-i18n="saisie.col.journal"></label>
                                <select id="ecrJournal" class="form-control"></select>
                            </div>
                            <div class="eh-field">
                                <label data-i18n="saisie.col.exercice"></label>
                                <select id="ecrExercice" class="form-control"></select>
                            </div>
                            <div class="eh-field">
                                <label data-i18n="saisie.col.devise"></label>
                                <select id="ecrDevise" class="form-control"></select>
                            </div>
                            <div class="eh-field">
                                <label data-i18n="saisie.col.cours"></label>
                                <input type="number" id="ecrCours" class="form-control"
                                       step="0.00000001" min="0" value="1" />
                            </div>
                        </div>

                        <div class="eh-grid eh-grid-4">
                            <div class="eh-field">
                                <label data-i18n="saisie.col.date"></label>
                                <input type="date" id="ecrDate" class="form-control" />
                            </div>
                            <div class="eh-field">
                                <label data-i18n="saisie.col.date_piece"></label>
                                <input type="date" id="ecrDatePiece" class="form-control" />
                            </div>
                            <div class="eh-field">
                                <label data-i18n="saisie.col.reference"></label>
                                <input type="text" id="ecrReference" class="form-control" maxlength="100" />
                            </div>
                            <div class="eh-field">
                                <label data-i18n="saisie.col.statut"></label>
                                <select id="ecrStatut" class="form-control">
                                    <option value="BROUILLON" data-i18n="saisie.statut.BROUILLON"></option>
                                    <option value="A_VALIDER" data-i18n="saisie.statut.A_VALIDER"></option>
                                    <option value="VALIDEE" data-i18n="saisie.statut.VALIDEE"></option>
                                </select>
                            </div>
                        </div>
                    </div>

                    <!-- BLOC 2 : LIGNE + TOTAUX -->
                    <div class="ecr-bottom">
                        <div class="ecr-block eb-form">
                            <div class="ecr-block-title">
                                <i class="fas fa-edit"></i>
                                <span data-i18n="saisie.section.line"></span>
                            </div>

                            <div class="eb-form-row" id="dynPlanFieldsRow"></div>

                            <div class="eb-form-row eb-form-row-2">
                                <div class="eb-field">
                                    <label data-i18n="saisie.col.auxiliaire"></label>
                                    <select id="flAux" class="form-control" disabled
                                            style="background-color:#e9ecef;cursor:not-allowed;">
                                        <option value=""></option>
                                    </select>
                                    <small id="flAuxHint" class="field-hint" data-i18n="saisie.hint.aux_initial"></small>
                                </div>
                                <div class="eb-field eb-field-wide">
                                    <label data-i18n="saisie.col.libelle"></label>
                                    <input type="text" id="flLibelle" class="form-control" maxlength="500" />
                                </div>
                            </div>

                            <div class="eb-form-row eb-form-row-4">
                                <div class="eb-field">
                                    <label data-i18n="saisie.col.montant_local"></label>
                                    <input type="text" id="flMontantLocal" class="form-control money-input"
                                           data-money-field="1" value="0" autocomplete="off" />
                                </div>
                                <div class="eb-field">
                                    <label data-i18n="saisie.col.montant_rep"></label>
                                    <input type="text" id="flMontantRep" class="form-control money-input"
                                           data-money-field="1" value="0" autocomplete="off" />
                                </div>
                                <div class="eb-field eb-sens">
                                    <label data-i18n="saisie.col.sens"></label>
                                    <div class="sens-radios">
                                        <label><input type="radio" name="flSens" value="D" checked />
                                            <span data-i18n="saisie.sens.debit"></span></label>
                                        <label><input type="radio" name="flSens" value="C" />
                                            <span data-i18n="saisie.sens.credit"></span></label>
                                    </div>
                                </div>
                                <div class="eb-field">
                                    <label data-i18n="saisie.col.echeance"></label>
                                    <input type="date" id="flEcheance" class="form-control" />
                                </div>
                            </div>
                        </div>

                        <div class="ecr-block eb-totaux">
                            <div class="ecr-block-title">
                                <i class="fas fa-calculator"></i>
                                <span data-i18n="saisie.section.totals"></span>
                            </div>

                            <table class="totaux-table">
                                <thead>
                                    <tr>
                                        <th></th>
                                        <th data-i18n="saisie.col.debit"></th>
                                        <th data-i18n="saisie.col.credit"></th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr>
                                        <td class="tt-label" data-i18n="saisie.totaux.local"></td>
                                        <td class="tt-val" id="ttDebitLocal">0,00</td>
                                        <td class="tt-val" id="ttCreditLocal">0,00</td>
                                    </tr>
                                    <tr>
                                        <td class="tt-label" data-i18n="saisie.totaux.solde"></td>
                                        <td class="tt-val" colspan="2" id="ttSolde">0,00</td>
                                    </tr>
                                    <tr>
                                        <td class="tt-label" data-i18n="saisie.totaux.rap"></td>
                                        <td class="tt-val" id="ttDebitRep">0,00</td>
                                        <td class="tt-val" id="ttCreditRep">0,00</td>
                                    </tr>
                                </tbody>
                            </table>

                            <div class="ligne-actions">
                                <button type="button" class="la-btn la-validate" onclick="validateLigne()"
                                        data-i18n-attr="title:saisie.action.validate_line">
                                    <i class="fas fa-check"></i>
                                </button>
                                <button type="button" class="la-btn la-add" onclick="newLigne()"
                                        data-i18n-attr="title:saisie.action.new_line">
                                    <i class="fas fa-plus"></i>
                                </button>
                                <button type="button" class="la-btn la-edit" onclick="editCurrentLigne()"
                                        data-i18n-attr="title:saisie.action.edit_line">
                                    <i class="fas fa-pen"></i>
                                </button>
                                <button type="button" class="la-btn la-dup" onclick="duplicateLigne()"
                                        data-i18n-attr="title:saisie.action.dup_line">
                                    <i class="fas fa-clone"></i>
                                </button>
                                <button type="button" class="la-btn la-del" onclick="deleteCurrentLigne()"
                                        data-i18n-attr="title:saisie.action.delete_line">
                                    <i class="fas fa-trash"></i>
                                </button>
                                <button type="button" id="btnSaveEcriture" class="la-btn la-save"
                                        onclick="saveEcriture(event)"
                                        data-i18n-attr="title:saisie.action.save_ecriture" disabled>
                                    <i class="fas fa-save"></i>
                                </button>
                            </div>

                            <div class="ligne-actions2">
                                <button type="button" class="la-btn la-erase" onclick="clearCurrentLigne()"
                                        data-i18n-attr="title:saisie.action.clear_line">
                                    <i class="fas fa-eraser"></i>
                                </button>
                                <button type="button" class="la-btn la-undo" onclick="undoLigne()"
                                        data-i18n-attr="title:saisie.action.undo">
                                    <i class="fas fa-undo"></i>
                                </button>
                                <button type="button" class="la-btn la-del-ecriture" onclick="deleteCurrentEcriture()">
                                    <i class="fas fa-trash-alt"></i>
                                    <span data-i18n="saisie.action.delete_ecriture"></span>
                                </button>
                            </div>
                        </div>
                    </div>

                    <!-- BLOC 3 : GRILLE -->
                    <div class="ecr-block">
                        <div class="ecr-block-title">
                            <i class="fas fa-table"></i>
                            <span data-i18n="saisie.section.lines"></span>
                            <span class="ecr-block-counter" id="ecrLinesCounter"></span>
                        </div>
                        <div class="ecr-grid-wrapper">
                            <table class="grid-table ecr-grid" id="ecrGrid">
                                <thead><tr id="ecrGridHeadRow"></tr></thead>
                                <tbody id="ecrLignesBody">
                                    <tr>
                                        <td colspan="15" class="table-empty">
                                            <i class="fas fa-inbox"></i>
                                            <span data-i18n="saisie.msg.no_lignes"></span>
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

    <div id="spinnerOverlay" aria-hidden="true"><div class="spinner"></div></div>

    <!-- Librairies tierces -->
    <script src="../../_assets/js/jquery-3.6.0.min.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../../_assets/js/sweetalert2@11.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../../_assets/js/i18n.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../../_assets/js/csrf.js?v=<%=AuthHelper.Version %>"></script>
    <script src="../../_assets/js/global.js?v=<%=AuthHelper.Version %>"></script>

    <!-- ⭐ Vue 3 CDN -->
    <script src="../../_assets/js/vue.global.prod.js?v=<%=AuthHelper.Version %>"></script>

    <script>window.BASE_PATH = '<%= ResolveUrl("~/") %>';</script>

    <!-- Scripts applicatifs -->
    <script src="js/config.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/state.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/money-input.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/utils.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/plan-config.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/i18n-refresh.js?v=<%=AuthHelper.Version %>"></script>
    <script src="js/saisie-vue.js?v=<%=AuthHelper.Version %>"></script>  <!-- ⭐ NOUVEAU -->
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
