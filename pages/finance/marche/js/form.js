// form.js — Logique du formulaire de ligne (i18n + compteur)
'use strict';

// ============================================================
// NOUVELLE LIGNE
// ============================================================
function newLigne() {
    clearFormLigne();
    AppState.selectedLigneIndex = -1;
    renderGrid();

    var active = getActivePlanFields();
    if (active.length) {
        var el = document.getElementById(active[0].selectId);
        if (el) el.focus();
    } else {
        var el2 = document.getElementById('flLibelle');
        if (el2) el2.focus();
    }
}

// ============================================================
// VIDER LE FORMULAIRE
// ============================================================
function clearFormLigne() {
    getActivePlanFields().forEach(function (plan) {
        _setVal(plan.selectId, '');
    });

    ['flAux','flSub','flMode','flLibelle','flEcheance'].forEach(function (id) {
        _setVal(id, '');
    });
    _setVal('flMontantLocal', '0');
    _setVal('flMontantRep', '0');

    var rd = document.querySelector('input[name="flSens"][value="D"]');
    if (rd) rd.checked = true;

    // Le champ auxiliaire repasse en mode grisé
    if (typeof refreshAuxiliaireField === 'function') {
        refreshAuxiliaireField({ preserveValue: false });
    }

    AppState.lastLigneSnapshot = null;

    if (typeof _refreshLinesCounter === 'function') _refreshLinesCounter();
}

function clearCurrentLigne() { clearFormLigne(); }

// ============================================================
// UNDO
// ============================================================
function undoLigne() {
    if (AppState.lastLigneSnapshot) {
        var snap = AppState.lastLigneSnapshot;
        Object.keys(snap).forEach(function (k) {
            if (k === 'sens') {
                var r = document.querySelector('input[name="flSens"][value="' + snap[k] + '"]');
                if (r) r.checked = true;
            } else {
                _setVal(k, snap[k]);
            }
        });

        if (typeof refreshAuxiliaireField === 'function') {
            refreshAuxiliaireField({ preserveValue: true });
        }
    } else {
        clearFormLigne();
    }
}

// ============================================================
// SNAPSHOT
// ============================================================
function takeSnapshot() {
    var snap = {};
    getActivePlanFields().forEach(function (plan) {
        snap[plan.selectId] = _getVal(plan.selectId);
    });
    ['flAux','flSub','flMode','flLibelle','flMontantLocal','flMontantRep','flEcheance']
        .forEach(function (id) { snap[id] = _getVal(id); });
    snap.sens = (document.querySelector('input[name="flSens"]:checked') || {}).value || 'D';
    AppState.lastLigneSnapshot = snap;
}

// ============================================================
// ÉDITER LIGNE COURANTE
// ============================================================
function editCurrentLigne() {
    if (AppState.selectedLigneIndex < 0) {
        showErrorToast(_t('saisie.msg.no_line_selected'));
        return;
    }
    takeSnapshot();
    loadLigneIntoForm(AppState.selectedLigneIndex);
}

// ============================================================
// VALIDER LA LIGNE
// ============================================================
function validateLigne() {
    var primaire = getPrimaryPlanField();

    if (primaire) {
        var compteId = _getVal(primaire.selectId);
        if (!compteId) {
            showErrorToast(
                (_t('saisie.msg.account_required') || 'Le compte « {label} » est obligatoire.')
                    .replace('{label}', primaire.label)
            );
            return;
        }
    }

    var mntLocal = parseMoneyFR(_getVal('flMontantLocal'));
    if (isNaN(mntLocal) || mntLocal <= 0) {
        showErrorToast(_t('saisie.msg.amount_required'));
        return;
    }

    var sens = (document.querySelector('input[name="flSens"]:checked') || {}).value || 'D';
    var mntRep = parseMoneyFR(_getVal('flMontantRep'));

    var auxSel = document.getElementById('flAux');
    var auxiliaire = (auxSel && !auxSel.disabled) ? (auxSel.value || '').trim() : '';

    var ligne = {
        auxiliaire:   auxiliaire,
        compteIdSUB:  _getVal('flSub')  || null,
        mode:         _getVal('flMode') || '',
        libelle:      (_getVal('flLibelle') || '').trim(),
        montantRep:   mntRep || 0,
        sens:         sens,
        debit:        sens === 'D' ? mntLocal : 0,
        credit:       sens === 'C' ? mntLocal : 0,
        echeance:     _getVal('flEcheance') || ''
    };

    getActivePlanFields().forEach(function (plan) {
        var val = _getVal(plan.selectId) || null;
        ligne['compteId' + plan.key] = val;
        ligne['code' + plan.key]     = val
            ? findCodeCompteByKey(plan.key, val)
            : '';
    });

    if (AppState.selectedLigneIndex >= 0) {
        AppState.lignes[AppState.selectedLigneIndex] = ligne;
    } else {
        AppState.lignes.push(ligne);
    }

    AppState.selectedLigneIndex = -1;
    renderGrid();
    computeTotaux();
    clearFormLigne();
}

// ============================================================
// SUPPRIMER / DUPLIQUER
// ============================================================
function deleteCurrentLigne() {
    if (AppState.selectedLigneIndex < 0) {
        showErrorToast(_t('saisie.msg.no_line_selected'));
        return;
    }
    AppState.lignes.splice(AppState.selectedLigneIndex, 1);
    AppState.selectedLigneIndex = -1;
    renderGrid();
    computeTotaux();
    clearFormLigne();
}

function duplicateLigne() {
    if (AppState.selectedLigneIndex < 0) {
        showErrorToast(_t('saisie.msg.no_line_selected'));
        return;
    }
    var orig = AppState.lignes[AppState.selectedLigneIndex];
    var copy = JSON.parse(JSON.stringify(orig));
    AppState.lignes.splice(AppState.selectedLigneIndex + 1, 0, copy);
    AppState.selectedLigneIndex = AppState.selectedLigneIndex + 1;
    renderGrid();
    computeTotaux();
    if (typeof _refreshLinesCounter === 'function') _refreshLinesCounter();
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.newLigne             = newLigne;
window.clearCurrentLigne    = clearCurrentLigne;
window.undoLigne            = undoLigne;
window.editCurrentLigne     = editCurrentLigne;
window.validateLigne        = validateLigne;
window.deleteCurrentLigne   = deleteCurrentLigne;
window.duplicateLigne       = duplicateLigne;
window.clearFormLigne       = clearFormLigne;
