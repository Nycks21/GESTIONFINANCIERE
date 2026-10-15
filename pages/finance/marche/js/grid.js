// grid.js — Rendu grille + plans dynamiques + auxiliaire filtré + i18n
'use strict';
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// ============================================================
// GESTION DU CHAMP AUXILIAIRE (avec filtrage des tiers)
// ============================================================
function refreshAuxiliaireField(options) {
    options = options || {};
    var preserveValue = options.preserveValue === true;

    var auxSel = document.getElementById('flAux');
    if (!auxSel) return;

    var primaire = getPrimaryPlanField();

    // Cas 1 : pas de plan comptable actif
    if (!primaire) {
        _disableAuxField(auxSel, _t('saisie.hint.aux_no_primary') ||
            'Aucun plan comptable actif.', preserveValue);
        return;
    }

    // Cas 2 : pas de compte sélectionné
    var compteId = _getVal(primaire.selectId);
    if (!compteId) {
        _disableAuxField(auxSel,
            (_t('saisie.hint.aux_initial') ||
             'Sélectionnez d\'abord un compte {label}.')
                .replace('{label}', primaire.label),
            preserveValue);
        return;
    }

    // Cas 3 : cherche le compte
    var comptes = AppState.comptesParPlan[primaire.ordre] || [];
    var compte = null;
    for (var i = 0; i < comptes.length; i++) {
        if (comptes[i].ID === compteId) { compte = comptes[i]; break; }
    }

    if (!compte) {
        _disableAuxField(auxSel, _t('saisie.hint.aux_not_found') ||
            'Compte introuvable.', preserveValue);
        return;
    }

    // Cas 4 : compte sans autorisation auxiliaire
    if (!compte.EST_AUXILIAIRE) {
        _disableAuxField(auxSel,
            (_t('saisie.hint.aux_no_auth') ||
             'Le compte {code} n\'autorise pas d\'auxiliaire.')
                .replace('{code}', compte.CODE),
            preserveValue);
        return;
    }

    // ⭐ Cas 5 : compte autorisé → REPEUPLE avec filtre par compte
    populateAuxiliaireOptions(compte.ID, preserveValue);
    _enableAuxField(auxSel);

    // Hint informatif
    var count = parseInt(auxSel.getAttribute('data-count') || '0', 10);
    var isFiltered = auxSel.getAttribute('data-filtered') === '1';
    var hint = document.getElementById('flAuxHint');
    if (hint) {
        if (isFiltered) {
            hint.textContent = (_t('saisie.hint.aux_filtered') ||
                '{n} tiers liés au compte {code}')
                .replace('{n}', count)
                .replace('{code}', compte.CODE);
            hint.style.color = '#047857';
        } else {
            hint.textContent = (_t('saisie.hint.aux_all') ||
                'Aucun tiers spécifique lié — {n} tiers disponibles.')
                .replace('{n}', count);
            hint.style.color = '#6c757d';
        }
        hint.style.display = 'block';
    }
}

function _disableAuxField(sel, reason, preserveValue) {
    sel.disabled = true;
    sel.style.backgroundColor = '#e9ecef';
    sel.style.cursor = 'not-allowed';

    if (typeof populateAuxiliaireOptions === 'function') {
        populateAuxiliaireOptions(null, preserveValue);
    }
    if (!preserveValue) sel.value = '';

    var hint = document.getElementById('flAuxHint');
    if (hint) {
        hint.textContent = reason || '';
        hint.style.color = '#6c757d';
        hint.style.display = reason ? 'block' : 'none';
    }
}

function _enableAuxField(sel) {
    sel.disabled = false;
    sel.style.backgroundColor = '';
    sel.style.cursor = '';
}

// ============================================================
// GÉNÉRATION DU FORMULAIRE (champs plans dynamiques)
// ============================================================
function renderFormPlanFields() {
    var container = document.getElementById('dynPlanFieldsRow');
    if (!container) return;

    var active = getActivePlanFields();

    if (!active.length) {
        container.innerHTML = '<div class="eb-field eb-w-full" '
            + 'style="color:#B91C1C;font-style:italic;text-align:center;padding:12px;">'
            + _t('saisie.msg.no_plans')
            + '</div>';
        return;
    }

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
    console.log('[grid] Formulaire plans généré :',
        active.map(function (p) { return p.label; }).join(', '));
}

// ============================================================
// EN-TÊTE DE GRILLE (dynamique)
// ============================================================
function renderGridHead() {
    var row = document.getElementById('ecrGridHeadRow');
    if (!row) return;

    var active = getActivePlanFields();
    var hasPrimary = active.some(function (p) { return p.isPrimary; });

    var html = '<th style="width:40px;" data-i18n="saisie.col.line_number">#</th>';

    active.forEach(function (plan) {
        var w = plan.isPrimary ? 110 : 100;
        html += '<th style="width:' + w + 'px;">' + escapeHtml(plan.label) + '</th>';
        if (plan.isPrimary) {
            html += '<th style="width:90px;" data-i18n="saisie.col.auxiliaire">'
                  + _t('saisie.col.auxiliaire') + '</th>';
        }
    });

    if (!hasPrimary) {
        html += '<th style="width:90px;" data-i18n="saisie.col.auxiliaire">'
              + _t('saisie.col.auxiliaire') + '</th>';
    }

    html += '<th style="width:100px;" data-i18n="saisie.col.subvention">'
          + _t('saisie.col.subvention') + '</th>';
    html += '<th data-i18n="saisie.col.libelle">'
          + _t('saisie.col.libelle') + '</th>';
    html += '<th style="width:110px; text-align:right;" data-i18n="saisie.col.debit">'
          + _t('saisie.col.debit') + '</th>';
    html += '<th style="width:110px; text-align:right;" data-i18n="saisie.col.credit">'
          + _t('saisie.col.credit') + '</th>';
    html += '<th style="width:110px; text-align:right;" data-i18n="saisie.col.debit_rep">'
          + _t('saisie.col.debit_rep') + '</th>';
    html += '<th style="width:110px; text-align:right;" data-i18n="saisie.col.credit_rep">'
          + _t('saisie.col.credit_rep') + '</th>';
    html += '<th style="width:110px;" data-i18n="saisie.col.echeance">'
          + _t('saisie.col.echeance') + '</th>';

    row.innerHTML = html;
}

// ============================================================
// RENDU CORPS DE GRILLE
// ============================================================
function renderGrid() {
    var tb = document.getElementById('ecrLignesBody');
    if (!tb) return;

    var active = getActivePlanFields();
    var hasPrimary = active.some(function (p) { return p.isPrimary; });
    var totalCols = 1 + active.length + 1 + 7;

    if (!AppState.lignes.length) {
        tb.innerHTML = '<tr><td colspan="' + totalCols + '" class="table-empty">'
            + '<i class="fas fa-inbox"></i>'
            + '<span>' + _t('saisie.msg.no_lignes') + '</span></td></tr>';
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
            if (plan.isPrimary) {
                html += '<td>' + escapeHtml(l.auxiliaire || '') + '</td>';
            }
        });

        if (!hasPrimary) {
            html += '<td>' + escapeHtml(l.auxiliaire || '') + '</td>';
        }

        html += _cellPlan(l.codeSUB || '');
        html += '<td title="' + escapeHtml(l.libelle || '') + '">' + escapeHtml(l.libelle || '') + '</td>';
        html += '<td class="cell-montant debit">'  + (l.debit  > 0 ? formatMontant(l.debit)  : '') + '</td>';
        html += '<td class="cell-montant credit">' + (l.credit > 0 ? formatMontant(l.credit) : '') + '</td>';
        html += '<td class="cell-montant debit">'  + (l.montantRep > 0 && l.sens === 'D' ? formatMontant(l.montantRep) : '') + '</td>';
        html += '<td class="cell-montant credit">' + (l.montantRep > 0 && l.sens === 'C' ? formatMontant(l.montantRep) : '') + '</td>';
        html += '<td>' + escapeHtml(l.echeance || '') + '</td>';
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

    // 1) Remplit les selects de plans
    getActivePlanFields().forEach(function (plan) {
        _setVal(plan.selectId, l['compteId' + plan.key] || '');
    });

    // 2) Champs fixes
    _setVal('flSub',      l.compteIdSUB  || '');
    _setVal('flMode',     l.mode         || '');
    _setVal('flLibelle',  l.libelle      || '');
    _setVal('flMontantLocal', l.debit > 0 ? l.debit : l.credit);
    _setVal('flMontantRep',   l.montantRep || 0);
    _setVal('flEcheance', l.echeance     || '');

    // 3) Sens
    var sensRadios = document.querySelectorAll('input[name="flSens"]');
    sensRadios.forEach(function (r) {
        r.checked = (r.value === (l.sens || 'D'));
    });

    // 4) Refresh auxiliaire AVANT de set la valeur
    refreshAuxiliaireField({ preserveValue: true });

    // 5) Restaure la valeur auxiliaire
    var auxSel = document.getElementById('flAux');
    if (auxSel && l.auxiliaire) {
        auxSel.value = l.auxiliaire;
        if (auxSel.value !== l.auxiliaire) {
            var opt = document.createElement('option');
            opt.value = l.auxiliaire;
            opt.textContent = l.auxiliaire + ' (' + _t('saisie.hint.out_of_filter') + ')';
            auxSel.appendChild(opt);
            auxSel.value = l.auxiliaire;
        }
    }
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
            o.setAttribute('data-aux', c.EST_AUXILIAIRE ? '1' : '0');
            sel.appendChild(o);
        });
    });

    console.log('[grid] Selects de comptes peuplés :', active.length);
}

// ============================================================
// HELPERS
// ============================================================
function findCodeCompteByKey(key, compteId) {
    if (!compteId) return '';
    var plan = getPlanFieldByKey(key);
    if (!plan) return '';
    var arr = AppState.comptesParPlan[plan.ordre] || [];
    var c = arr.find(function (x) { return x.ID === compteId; });
    return c ? c.CODE : '';
}

function findCodeCompte(planOrder, compteId) {
    if (!planOrder || !compteId) return '';
    var arr = AppState.comptesParPlan[planOrder] || [];
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
window.refreshAuxiliaireField    = refreshAuxiliaireField;
window.findCodeCompte            = findCodeCompte;
window.findCodeCompteByKey       = findCodeCompteByKey;
