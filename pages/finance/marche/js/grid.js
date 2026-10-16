// grid.js — MARCHE (grille des lignes)
'use strict';
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// ============================================================
// GÉNÉRATION DU FORMULAIRE (champs plans dynamiques)
// ============================================================
function renderFormPlanFields() {
    var container = document.getElementById('dynPlanFieldsRow');
    if (!container) return;

    var active = getActivePlanFields();
    if (!active.length) { container.innerHTML = ''; return; }

    var html = '';
    active.forEach(function (plan) {
        var widthClass = plan.isPrimary ? 'eb-w-2' : 'eb-w-1';
        html += '<div class="eb-field ' + widthClass + '" '
              +     'id="' + plan.wrapperId + '" '
              +     'data-plan-key="' + plan.key + '" '
              +     'data-plan-order="' + plan.ordre + '" '
              +     'data-plan-type="' + plan.typeCode + '">'
              +   '<label>' + escapeHtml(plan.label) + '</label>'
              +   '<select id="' + plan.selectId + '" class="form-control"></select>'
              + '</div>';
    });
    container.innerHTML = html;
}

// ============================================================
// EN-TÊTE DE GRILLE (dynamique)
// ============================================================
function renderGridHead() {
    var row = document.getElementById('marGridHeadRow');
    if (!row) return;

    var active = getActivePlanFields();
    var html = '<th style="width:40px;">#</th>';

    active.forEach(function (plan) {
        html += '<th style="width:110px;">' + escapeHtml(plan.label) + '</th>';
    });

    html += '<th style="min-width:200px;">' + _t('marche.col.designation') + '</th>';
    html += '<th style="width:120px;">' + _t('marche.col.reference_ligne') + '</th>';
    html += '<th style="width:90px; text-align:right;">' + _t('marche.col.taxe') + '</th>';
    html += '<th style="width:130px; text-align:right;">' + _t('marche.col.montant_loc_ht') + '</th>';
    html += '<th style="width:130px; text-align:right;">' + _t('marche.col.montant_loc_tva') + '</th>';
    html += '<th style="width:130px; text-align:right;">' + _t('marche.col.montant_loc_ttc') + '</th>';
    html += '<th style="width:130px; text-align:right;">' + _t('marche.col.montant_rap_ht') + '</th>';
    html += '<th style="width:130px; text-align:right;">' + _t('marche.col.montant_rap_tva') + '</th>';
    html += '<th style="width:130px; text-align:right;">' + _t('marche.col.montant_rap_ttc') + '</th>';

    row.innerHTML = html;
}

// ============================================================
// RENDU CORPS DE GRILLE
// ============================================================
function renderGrid() {
    var tb = document.getElementById('marLignesBody');
    if (!tb) return;

    var active = getActivePlanFields();
    var totalCols = 1 + active.length + 9;

    if (!AppState.lignes.length) {
        tb.innerHTML = '<tr><td colspan="' + totalCols + '" class="table-empty">'
            + '<i class="fas fa-inbox"></i>'
            + '<span>' + _t('marche.msg.no_lignes') + '</span></td></tr>';
        return;
    }

    var html = '';
    AppState.lignes.forEach(function (l, idx) {
        var sel = (idx === AppState.selectedLigneIndex) ? ' selected' : '';
        html += '<tr class="ecr-ligne' + sel + '" data-index="' + idx + '" '
              + 'onclick="selectLigne(' + idx + ')">';

        html += '<td><span class="cell-num">' + (idx + 1) + '</span></td>';

        active.forEach(function (plan) {
            html += _cellPlan(l['code' + plan.key] || '');
        });

        html += '<td>' + escapeHtml(l.designation || '') + '</td>';
        html += '<td>' + escapeHtml(l.referenceLigne || '') + '</td>';
        html += '<td style="text-align:right;font-family:monospace;">' + (l.taxe || 0) + ' %</td>';
        html += '<td class="cell-montant">' + formatMontant(l.montantLocHT || 0) + '</td>';
        html += '<td class="cell-montant">' + formatMontant(l.montantLocTVA || 0) + '</td>';
        html += '<td class="cell-montant">' + formatMontant(l.montantLocTTC || 0) + '</td>';
        html += '<td class="cell-montant">' + formatMontant(l.montantRapHT || 0) + '</td>';
        html += '<td class="cell-montant">' + formatMontant(l.montantRapTVA || 0) + '</td>';
        html += '<td class="cell-montant">' + formatMontant(l.montantRapTTC || 0) + '</td>';
        html += '</tr>';
    });
    tb.innerHTML = html;

    if (typeof _refreshLinesCounter === 'function') _refreshLinesCounter();
}

function _cellPlan(code) {
    var safe = escapeHtml(code || '');
    return '<td><span class="cell-badge" title="' + safe + '">'
         + (safe || '—') + '</span></td>';
}

// ============================================================
// SÉLECTION LIGNE
// ============================================================
function selectLigne(idx) {
    AppState.selectedLigneIndex = idx;
    renderGrid();
    loadLigneIntoForm(idx);
}

function loadLigneIntoForm(idx) {
    var l = AppState.lignes[idx];
    if (!l) return;

    getActivePlanFields().forEach(function (plan) {
        _setVal(plan.selectId, l['compteId' + plan.key] || '');
    });

    _setVal('mlArticle',     l.articleId || '');
    _setVal('mlDesignation', l.designation || '');
    _setVal('mlReference',   l.referenceLigne || '');
    _setVal('mlTaxe',         l.taxe || 0);
    _setVal('mlMontantLocHT', l.montantLocHT || 0);
    _setVal('mlMontantRapHT', l.montantRapHT || 0);
    _setVal('mlDescription',  l.description || '');
}

// ============================================================
// PEUPLEMENT DES SELECTS DE COMPTES
// ============================================================
function populatePlanSelectsForm() {
    var active = getActivePlanFields();
    active.forEach(function (plan) {
        var sel = document.getElementById(plan.selectId);
        if (!sel) return;
        sel.innerHTML = '<option value="">—</option>';
        var comptes = AppState.comptesParPlan[plan.ordre] || [];
        comptes.forEach(function (c) {
            var o = document.createElement('option');
            o.value = c.ID;
            o.textContent = c.CODE + ' — ' + c.LIBELLE;
            o.setAttribute('data-code', c.CODE);
            sel.appendChild(o);
        });
    });
}

function findCodeCompteByKey(key, compteId) {
    if (!compteId) return '';
    var plan = getPlanFieldByKey(key);
    if (!plan) return '';
    var arr = AppState.comptesParPlan[plan.ordre] || [];
    var c = arr.find(function (x) { return x.ID === compteId; });
    return c ? c.CODE : '';
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.renderFormPlanFields      = renderFormPlanFields;
window.renderGridHead            = renderGridHead;
window.renderGrid                = renderGrid;
window.selectLigne               = selectLigne;
window.loadLigneIntoForm         = loadLigneIntoForm;
window.populatePlanSelectsForm   = populatePlanSelectsForm;
window.findCodeCompteByKey       = findCodeCompteByKey;
