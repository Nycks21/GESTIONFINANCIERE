// form.js — MARCHE (formulaire ligne)
// ⭐ CORRECTION MONTANTS : parseMontant + getMoneyNumericValue + setMoneyValue
'use strict';

function newLigne() {
    clearFormLigne();
    AppState.selectedLigneIndex = -1;
    renderGrid();

    var el = document.getElementById('mlDesignation');
    if (el) el.focus();
}

function clearFormLigne() {
    getActivePlanFields().forEach(function (plan) {
        _setVal(plan.selectId, '');
    });

    ['mlArticle','mlDesignation','mlReference','mlDescription'].forEach(function (id) {
        _setVal(id, '');
    });
    _setVal('mlTaxe', '0');

    // ⭐ setMoneyValue au lieu de _setVal
    if (typeof setMoneyValue === 'function') {
        setMoneyValue('mlMontantLocHT', 0);
        setMoneyValue('mlMontantRapHT', 0);
    } else {
        _setVal('mlMontantLocHT', '0');
        _setVal('mlMontantRapHT', '0');
    }

    AppState.lastLigneSnapshot = null;
    if (typeof _refreshLinesCounter === 'function') _refreshLinesCounter();
}

function clearCurrentLigne() { clearFormLigne(); }

function undoLigne() {
    if (AppState.lastLigneSnapshot) {
        var snap = AppState.lastLigneSnapshot;
        Object.keys(snap).forEach(function (k) {
            if (k === 'mlMontantLocHT' || k === 'mlMontantRapHT') {
                if (typeof setMoneyValue === 'function') setMoneyValue(k, snap[k]);
                else _setVal(k, snap[k]);
            } else {
                _setVal(k, snap[k]);
            }
        });
    } else {
        clearFormLigne();
    }
}

function takeSnapshot() {
    var snap = {};
    getActivePlanFields().forEach(function (plan) {
        snap[plan.selectId] = _getVal(plan.selectId);
    });
    ['mlArticle','mlDesignation','mlReference','mlDescription',
     'mlTaxe','mlMontantLocHT','mlMontantRapHT'].forEach(function (id) {
        snap[id] = _getVal(id);
    });
    AppState.lastLigneSnapshot = snap;
}

function editCurrentLigne() {
    if (AppState.selectedLigneIndex < 0) {
        showErrorToast(_t('marche.msg.no_line_selected') || 'Aucune ligne sélectionnée.');
        return;
    }
    takeSnapshot();
    loadLigneIntoForm(AppState.selectedLigneIndex);
}

// ⭐⭐⭐ CORRECTION MAJEURE : lecture montant robuste ⭐⭐⭐
function _readFormMontant(inputId) {
    // Priorité 1 : valeur canonique (money-input.js)
    if (typeof getMoneyNumericValue === 'function') {
        var v = getMoneyNumericValue(inputId);
        if (v !== 0) return v;
    }
    // Priorité 2 : parse robuste du visible
    if (typeof parseMontant === 'function') {
        return parseMontant(_getVal(inputId));
    }
    // Fallback (ne devrait pas arriver)
    return parseFloat(_getVal(inputId)) || 0;
}

function validateLigne() {
    var designation = (_getVal('mlDesignation') || '').trim();
    if (!designation) {
        showErrorToast(_t('marche.msg.designation_required') || 'La désignation est obligatoire.');
        return;
    }

    var taxe = parseFloat(_getVal('mlTaxe') || 0) || 0;
    if (taxe < 0 || taxe > 100) {
        showErrorToast(_t('marche.msg.taxe_invalid') || 'Taxe invalide (0-100).');
        return;
    }

    // ⭐ Lecture robuste des montants
    var locHT = _readFormMontant('mlMontantLocHT');
    var rapHT = _readFormMontant('mlMontantRapHT');

    // Log de vérification (visible F12)
    console.log('[validateLigne] mlMontantLocHT visible="' + _getVal('mlMontantLocHT') +
                '" → locHT=' + locHT);
    console.log('[validateLigne] mlMontantRapHT visible="' + _getVal('mlMontantRapHT') +
                '" → rapHT=' + rapHT);

    if (locHT < 0 || rapHT < 0) {
        showErrorToast(_t('marche.msg.amount_invalid') || 'Montant invalide.');
        return;
    }

    var locTVA = Math.round(locHT * taxe) / 100;
    var locTTC = locHT + locTVA;
    var rapTVA = Math.round(rapHT * taxe) / 100;
    var rapTTC = rapHT + rapTVA;

    var ligne = {
        id:               AppState.selectedLigneIndex >= 0
                            ? (AppState.lignes[AppState.selectedLigneIndex].id || null)
                            : null,
        articleId:        _getVal('mlArticle') || null,
        designation:      designation,
        referenceLigne:   (_getVal('mlReference') || '').trim(),
        description:      (_getVal('mlDescription') || '').trim(),
        taxe:             taxe,
        montantLocHT:     locHT,
        montantLocTVA:    locTVA,
        montantLocTTC:    locTTC,
        montantRapHT:     rapHT,
        montantRapTVA:    rapTVA,
        montantRapTTC:    rapTTC
    };

    getActivePlanFields().forEach(function (plan) {
        var val = _getVal(plan.selectId) || null;
        ligne['compteId' + plan.key] = val;
        ligne['code' + plan.key]     = val ? findCodeCompteByKey(plan.key, val) : '';
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

    if (typeof markDirty === 'function') markDirty();
}

function deleteCurrentLigne() {
    if (AppState.selectedLigneIndex < 0) {
        showErrorToast(_t('marche.msg.no_line_selected') || 'Aucune ligne sélectionnée.');
        return;
    }
    AppState.lignes.splice(AppState.selectedLigneIndex, 1);
    AppState.selectedLigneIndex = -1;
    renderGrid();
    computeTotaux();
    clearFormLigne();

    if (typeof markDirty === 'function') markDirty();
}

function duplicateLigne() {
    if (AppState.selectedLigneIndex < 0) {
        showErrorToast(_t('marche.msg.no_line_selected') || 'Aucune ligne sélectionnée.');
        return;
    }
    var orig = AppState.lignes[AppState.selectedLigneIndex];
    var copy = JSON.parse(JSON.stringify(orig));
    copy.id = null;
    AppState.lignes.splice(AppState.selectedLigneIndex + 1, 0, copy);
    AppState.selectedLigneIndex = AppState.selectedLigneIndex + 1;
    renderGrid();
    computeTotaux();

    if (typeof markDirty === 'function') markDirty();
    if (typeof _refreshLinesCounter === 'function') _refreshLinesCounter();
}

window.newLigne             = newLigne;
window.clearCurrentLigne    = clearCurrentLigne;
window.undoLigne            = undoLigne;
window.editCurrentLigne     = editCurrentLigne;
window.validateLigne        = validateLigne;
window.deleteCurrentLigne   = deleteCurrentLigne;
window.duplicateLigne       = duplicateLigne;
window.clearFormLigne       = clearFormLigne;
window._readFormMontant     = _readFormMontant;   // ⭐ utilitaire
