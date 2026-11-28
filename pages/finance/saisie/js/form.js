// form.js — Logique du formulaire de ligne (i18n + compteur + verrouillage)
// ⭐ Verrouillage progressif des champs "Détail de la ligne" pour les journaux TRESO.
// ⭐ Déverrouillage conditionnel par préfixe de compte PLAN1 (trésorerie) :
//    - compte 2/3/6 → tous les champs SAUF auxiliaire
//    - compte 4     → SEUL le champ auxiliaire (+ modale OD déclencheur)
//    - compte 5xxx  → auto-bank TRESO (compte imposé + verrouillé)
// ⭐ Modale OD déclenchée sur compte 4 + aux (une seule fois par écriture).
'use strict';

// ============================================================
// VERROUILLAGE INITIAL DES CHAMPS DETAIL
// ============================================================
window._detailLocked = false;
window._lineEditLocked = false;

function _hasDetailHeaderPrerequisites() {
    return ['ecrSite', 'ecrJournal', 'ecrDate', 'ecrDatePiece'].every(function (id) {
        var field = document.getElementById(id);
        return !!(field && String(field.value || '').trim());
    });
}

function _lockAllDetailFields() {
    ['flSub', 'flMode', 'flLibelle', 'flMontantLocal', 'flMontantRep', 'flEcheance']
        .forEach(function (id) {
            var el = document.getElementById(id);
            if (el) { el.disabled = true; el.style.backgroundColor = '#e9ecef'; el.style.cursor = 'not-allowed'; }
        });
    document.querySelectorAll('input[name="flSens"]').forEach(function (r) { r.disabled = true; });
    if (typeof getActivePlanFields === 'function') {
        getActivePlanFields().forEach(function (plan) {
            var el = document.getElementById(plan.selectId);
            if (el) { el.disabled = true; el.style.backgroundColor = '#e9ecef'; el.style.cursor = 'not-allowed'; }
        });
    }
    var aux = document.getElementById('flAux');
    if (aux) { aux.disabled = true; aux.style.backgroundColor = '#e9ecef'; aux.style.cursor = 'not-allowed'; }
}

function _unlockAllDetailFields() {
    if (!_hasDetailHeaderPrerequisites()) {
        window._detailLocked = true;
        _lockAllDetailFields();
        return;
    }

    ['flSub', 'flMode', 'flLibelle', 'flMontantLocal', 'flMontantRep', 'flEcheance']
        .forEach(function (id) {
            var el = document.getElementById(id);
            if (el) { el.disabled = false; el.style.backgroundColor = ''; el.style.cursor = ''; }
        });
    document.querySelectorAll('input[name="flSens"]').forEach(function (r) { r.disabled = false; });
    if (typeof getActivePlanFields === 'function') {
        getActivePlanFields().forEach(function (plan) {
            var el = document.getElementById(plan.selectId);
            if (el) { el.disabled = false; el.style.backgroundColor = ''; el.style.cursor = ''; }
        });
    }
    if (typeof _applyPlanRestrictionToDom === 'function') {
        _applyPlanRestrictionToDom();
    }
    if (typeof _applyJournalPlan1Lock === 'function') {
        _applyJournalPlan1Lock();
    }
    if (_isOdManualEntryUnlockActive()) {
        _lockTreasuryAnalyticFields();
    }
}

function _lockOnlyCompte() {
    if (!_hasDetailHeaderPrerequisites()) {
        window._detailLocked = true;
        _lockAllDetailFields();
        return;
    }
    _lockAllDetailFields();
    var primaire = getPrimaryPlanField();
    if (!primaire) return;
    var compteSel = document.getElementById(primaire.selectId);
    if (compteSel) { compteSel.disabled = false; compteSel.style.backgroundColor = ''; compteSel.style.cursor = ''; }
}

function _lockOnlyAuxiliaire() {
    if (!_hasDetailHeaderPrerequisites()) {
        window._detailLocked = true;
        _lockAllDetailFields();
        return;
    }
    _lockAllDetailFields();
    var aux = document.getElementById('flAux');
    if (aux) { aux.disabled = false; aux.style.backgroundColor = ''; aux.style.cursor = ''; }
    var primaire = getPrimaryPlanField();
    if (primaire) {
        var compteSel = document.getElementById(primaire.selectId);
        if (compteSel) { compteSel.disabled = false; compteSel.style.backgroundColor = ''; compteSel.style.cursor = ''; }
    }
}

function _lockTreasuryAnalyticFields() {
    if (typeof getActivePlanFields !== 'function') return;
    getActivePlanFields().forEach(function (plan) {
        if (Number(plan.ordre) <= 1) return;
        var el = document.getElementById(plan.selectId);
        if (!el) return;
        el.disabled = true;
        el.classList.add('is-disabled');
        el.style.backgroundColor = '#e9ecef';
        el.style.cursor = 'not-allowed';
        el.setAttribute('title', 'Les imputations analytiques restent désactivées sur ce journal de trésorerie.');
    });
}

function _unlockTreasuryManualLineAfterOdCancel() {
    if (!_hasDetailHeaderPrerequisites()
        || window._lineEditLocked
        || AppState.selectedLigneIndex >= 0
        || typeof _isTreasuryJournal !== 'function'
        || !_isTreasuryJournal()) {
        return false;
    }

    var primaire = getPrimaryPlanField();
    if (!primaire) return false;
    var compteId = _getVal(primaire.selectId);
    var compte = compteId ? _findCompteByPlanAndId(primaire.ordre, compteId) : null;
    if (!compte || String(compte.CODE || '').charAt(0) !== '4') return false;

    window._odManualEntryUnlockedFor = {
        compteId: String(compteId),
        journalId: String(_getVal('ecrJournal') || '')
    };
    window._detailLocked = false;
    _unlockAllDetailFields();
    return true;
}

function _isOdManualEntryUnlockActive() {
    var manualUnlock = window._odManualEntryUnlockedFor;
    if (!manualUnlock) return false;

    var primaire = getPrimaryPlanField();
    var compteId = primaire ? String(_getVal(primaire.selectId) || '') : '';
    var compte = primaire && compteId
        ? _findCompteByPlanAndId(primaire.ordre, compteId)
        : null;
    var active = !!(
        compte
        && String(compte.CODE || '').charAt(0) === '4'
        && manualUnlock.compteId === compteId
        && manualUnlock.journalId === String(_getVal('ecrJournal') || '')
        && typeof _isTreasuryJournal === 'function'
        && _isTreasuryJournal()
        && AppState.selectedLigneIndex < 0
    );
    if (!active) window._odManualEntryUnlockedFor = null;
    return active;
}

function setDetailLock(locked) {
    if (!_hasDetailHeaderPrerequisites()) {
        window._detailLocked = true;
        _lockAllDetailFields();
        return;
    }

    if (window._lineEditLocked) {
        window._detailLocked = true;
        if (typeof _applyJournalPlan1Lock === 'function') {
            _applyJournalPlan1Lock();
        }
        _lockAllDetailFields();
        return;
    }

    window._detailLocked = !!locked;
    if (locked) {
        _lockAllDetailFields();
    } else {
        window._inUnlockProcess = true;
        try {
            window._detailLocked = false;
            _unlockAllDetailFields();
            if (typeof refreshAuxiliaireField === 'function') {
                try { refreshAuxiliaireField({ preserveValue: true }); } catch (e) { }
            }
            if (typeof refreshPlanRestrictionUI === 'function') {
                try { refreshPlanRestrictionUI(); } catch (e) { }
            }
        } finally {
            window._inUnlockProcess = false;
        }
    }
}

function setLineEditLocked(locked) {
    window._lineEditLocked = !!locked;
    if (window._lineEditLocked) {
        setDetailLock(true);
    } else {
        setDetailLock(false);
    }
    _syncLineEditActions();
}

function _syncLineEditActions() {
    var validateButton = document.getElementById('btnValidateLigne');
    if (validateButton) {
        validateButton.disabled = !!(AppState.editingId && window._lineEditLocked);
    }
}

// ============================================================
// ⭐ PATCH A.3 — Auto-bank TRESO
//    Si la dernière ligne est une charge (6xxx / 2xxx / 3xxx),
//    la nouvelle ligne est la contrepartie banque : compte imposé,
//    montant équilibrant auto-calculé, sens auto-sélectionné.
//    Cas 2 (dernière = 4xxx) → pas d'auto-bank → saisie multiple 4xxx.
// ============================================================
function _maybeAutoBankForTreasury() {
    if (!_hasDetailHeaderPrerequisites()) {
        window._detailLocked = true;
        _lockAllDetailFields();
        return false;
    }
    if (typeof _isTreasuryJournal !== 'function' || !_isTreasuryJournal()) return false;
    if (!AppState.lignes || AppState.lignes.length === 0) return false;

    var bankId = (typeof _getJournalCompteBanqueId === 'function') ? _getJournalCompteBanqueId() : null;
    if (!bankId) return false;

    var primaire = getPrimaryPlanField();
    if (!primaire) return false;

    // Dernière ligne = charge ?
    var lastLine = AppState.lignes[AppState.lignes.length - 1];
    var lastCompteId = lastLine['compteId' + primaire.key];
    var lastCompte = (typeof _findCompteByPlanAndId === 'function' && lastCompteId)
        ? _findCompteByPlanAndId(primaire.ordre, lastCompteId)
        : null;
    var lastPrefix = lastCompte ? String(lastCompte.CODE || '').charAt(0) : '';

    if (lastPrefix !== '6' && lastPrefix !== '2' && lastPrefix !== '3') {
        return false; // Cas 2 : pas d'auto-bank (saisie 4xxx multiple)
    }

    var p1Sel = document.getElementById(primaire.selectId);
    if (!p1Sel) return false;

    // 1. Sélection + verrouillage du compte banque
    if (String(p1Sel.value) !== String(bankId)) p1Sel.value = bankId;
    _lockOnlyCompte();
    p1Sel.disabled = true;
    p1Sel.style.backgroundColor = '#e2e8f0';
    p1Sel.style.cursor = 'not-allowed';
    p1Sel.setAttribute('title', _t('saisie.hint.plan1_forced_treso',
        'Compte trésorerie imposé par le journal (non modifiable).'));

    // 2. Déverrouiller les champs de détail
    ['flLibelle', 'flMontantLocal', 'flMontantRep', 'flEcheance'].forEach(function (id) {
        var el = document.getElementById(id);
        if (el) { el.disabled = false; el.style.backgroundColor = ''; el.style.cursor = ''; }
    });
    document.querySelectorAll('input[name="flSens"]').forEach(function (r) { r.disabled = false; });

    // 3. Auto-fill montant équilibrant (seulement si champ vide)
    var mntInput = document.getElementById('flMontantLocal');
    var needFill = mntInput && (!mntInput.value || mntInput.value === '0' || mntInput.value === '0,00');
    if (needFill) {
        var sumD = 0, sumC = 0;
        AppState.lignes.forEach(function (l) { sumD += (l.debit || 0); sumC += (l.credit || 0); });
        var diff = sumD - sumC;
        if (Math.abs(diff) > 0.01) {
            var sensToUse = diff > 0 ? 'C' : 'D';
            var amount = Math.abs(diff);
            if (typeof window.setMoneyValue === 'function') {
                window.setMoneyValue('flMontantLocal', amount);
            } else {
                mntInput.value = amount.toFixed(2).replace('.', ',');
            }
            var sensRadio = document.querySelector('input[name="flSens"][value="' + sensToUse + '"]');
            if (sensRadio) sensRadio.checked = true;
        }
    }

    window._detailLocked = false;
    console.log('[form] Auto-bank TRESO → compte ' + (typeof _getJournalCompteBanqueCode === 'function' ? _getJournalCompteBanqueCode() : '?') + ' imposé');
    return true;
}

// ============================================================
// Déverrouillage conditionnel par préfixe de compte PLAN1
// ============================================================
function _applyLockByComptePrefix() {
    if (!_hasDetailHeaderPrerequisites()) {
        window._detailLocked = true;
        _lockAllDetailFields();
        return true;
    }

    // ⭐ PATCH A.1 : seulement si l'utilisateur ÉDITE une ligne existante
    if (AppState.selectedLigneIndex >= 0) {
        return false;
    }

    var primaire = getPrimaryPlanField();
    if (!primaire) return false;

    var compteId = _getVal(primaire.selectId);
    if (!compteId) return false;

    var compte = (typeof _findCompteByPlanAndId === 'function')
        ? _findCompteByPlanAndId(primaire.ordre, compteId)
        : null;
    if (!compte) return false;

    var code = String(compte.CODE || '');
    var prefix = code.charAt(0);
    var treasury = typeof _isTreasuryJournal === 'function' && _isTreasuryJournal();
    var manualUnlockActive = _isOdManualEntryUnlockActive();

    // Cas 1 : compte 2 / 3 / 6 → tous les champs SAUF auxiliaire
    if (prefix === '2' || prefix === '3' || prefix === '6') {
        _unlockAllDetailFields();
        var aux = document.getElementById('flAux');
        if (aux) { aux.disabled = true; aux.style.backgroundColor = '#e9ecef'; aux.style.cursor = 'not-allowed'; }
        window._detailLocked = false;
        console.log('[form] Compte ' + prefix + 'xxx (' + code + ') → champs ouverts SAUF auxiliaire');
        return true;
    }

    // Le verrou du compte 4 ne concerne que les journaux de trésorerie :
    // un journal OD doit pouvoir enregistrer librement le sens et les montants.
    if (prefix === '4') {
        if (!treasury) {
            return false;
        }
        if (manualUnlockActive) {
            _unlockAllDetailFields();
            window._detailLocked = false;
            return true;
        }
        _lockOnlyAuxiliaire();
        if (!compte.EST_AUXILIAIRE) {
            var aux4 = document.getElementById('flAux');
            if (aux4) { aux4.disabled = true; aux4.style.backgroundColor = '#e9ecef'; aux4.style.cursor = 'not-allowed'; }
        }
        window._detailLocked = true;
        console.log('[form] Compte 4xxx (' + code + ') → SEUL le champ auxiliaire ouvert');
        return true;
    }

    return false;
}

// ============================================================
// Applique l'état de verrouillage selon le contexte
// ============================================================
function applyDetailLockByContext() {
    if (!_hasDetailHeaderPrerequisites()) {
        window._detailLocked = true;
        _lockAllDetailFields();
        return;
    }

    if (window._lineEditLocked) {
        setDetailLock(true);
        return;
    }

    var journal = _getVal('ecrJournal');
    if (!journal) { setDetailLock(true); _applyJournalPlan1Lock(); return; }

    if (_isOdManualEntryUnlockActive()) {
        _applyLockByComptePrefix();
        _applyJournalPlan1Lock();
        return;
    }

    // ⭐ PATCH A.2 : auto-bank AVANT le check "lines > 0"
    if (_maybeAutoBankForTreasury()) { _applyJournalPlan1Lock(); return; }

    if (AppState.lignes && AppState.lignes.length > 0) {
        setDetailLock(false);
        _applyJournalPlan1Lock();
        return;
    }

    if (_applyLockByComptePrefix()) { _applyJournalPlan1Lock(); return; }

    if (typeof _isTreasuryJournal !== 'function' || !_isTreasuryJournal()) {
        setDetailLock(false);
        _applyJournalPlan1Lock();
        return;
    }

    var ref = _getVal('ecrReference');
    if (ref && ref.trim()) {
        window._detailLocked = true;
        _lockOnlyCompte();
    } else {
        setDetailLock(true);
    }
    _applyJournalPlan1Lock();
}

// Wrapper pour respecter le verrou après refreshPlanRestrictionUI
(function () {
    var _orig = window.refreshPlanRestrictionUI;
    if (typeof _orig !== 'function') return;

    window.refreshPlanRestrictionUI = function () {
        _orig.apply(this, arguments);
        if (!_hasDetailHeaderPrerequisites()) {
            window._detailLocked = true;
            _lockAllDetailFields();
            return;
        }
        if (window._inUnlockProcess) {
            _applyJournalPlan1Lock();
            if (_isOdManualEntryUnlockActive()) {
                _lockTreasuryAnalyticFields();
            }
            return;
        }

        if (window._lineEditLocked) {
            window._detailLocked = true;
            _applyJournalPlan1Lock();
            _lockAllDetailFields();
            return;
        }

        if (_isOdManualEntryUnlockActive()) {
            _applyLockByComptePrefix();
            _applyJournalPlan1Lock();
            return;
        }

        if (AppState.lignes && AppState.lignes.length > 0) {
            setDetailLock(false);
            _applyJournalPlan1Lock();
            return;
        }

        if (_applyLockByComptePrefix()) { _applyJournalPlan1Lock(); return; }

        if (!window._detailLocked) { _applyJournalPlan1Lock(); return; }

        var treasury = typeof _isTreasuryJournal === 'function' && _isTreasuryJournal();
        if (!treasury) { _applyJournalPlan1Lock(); return; }

        var ref = _getVal('ecrReference');
        if (ref && ref.trim()) { _lockOnlyCompte(); }
        else { _lockAllDetailFields(); }
        _applyJournalPlan1Lock();
    };
})();

// ============================================================
// ACTIONS STANDARD DU FORMULAIRE
// ============================================================
function newLigne() {
    AppState.selectedLigneIndex = -1;
    if (AppState.editingId) setLineEditLocked(false);
    clearFormLigne();
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

function clearFormLigne() {
    window._odManualEntryUnlockedFor = null;
    getActivePlanFields().forEach(function (plan) { _setVal(plan.selectId, ''); });
    ['flAux', 'flSub', 'flMode', 'flLibelle', 'flEcheance'].forEach(function (id) { _setVal(id, ''); });
    _setVal('flMontantLocal', '0');
    _setVal('flMontantRep', '0');

    var rd = document.querySelector('input[name="flSens"][value="D"]');
    if (rd) rd.checked = true;

    if (typeof _applyJournalPlan1Lock === 'function') {
        _applyJournalPlan1Lock();
    }
    if (typeof refreshAuxiliaireField === 'function') refreshAuxiliaireField({ preserveValue: false });

    AppState.lastLigneSnapshot = null;

    if (typeof refreshPlanRestrictionUI === 'function') refreshPlanRestrictionUI();
    if (typeof _refreshLinesCounter === 'function') _refreshLinesCounter();

    applyDetailLockByContext();
}

function clearCurrentLigne() {
    AppState.selectedLigneIndex = -1;
    if (AppState.editingId) setLineEditLocked(true);
    clearFormLigne();
    renderGrid();
}

function undoLigne() {
    if (AppState.editingId && AppState.selectedLigneIndex >= 0) {
        var selectedIndex = AppState.selectedLigneIndex;
        loadLigneIntoForm(selectedIndex);
        setLineEditLocked(true);
        AppState.lastLigneSnapshot = null;
        return;
    }

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
        if (typeof refreshAuxiliaireField === 'function') refreshAuxiliaireField({ preserveValue: true });
        if (typeof refreshPlanRestrictionUI === 'function') refreshPlanRestrictionUI();
    } else {
        clearFormLigne();
        if (AppState.editingId) setLineEditLocked(true);
    }
}

function takeSnapshot() {
    var snap = {};
    getActivePlanFields().forEach(function (plan) { snap[plan.selectId] = _getVal(plan.selectId); });
    ['flAux', 'flSub', 'flMode', 'flLibelle', 'flMontantLocal', 'flMontantRep', 'flEcheance']
        .forEach(function (id) { snap[id] = _getVal(id); });
    snap.sens = (document.querySelector('input[name="flSens"]:checked') || {}).value || 'D';
    AppState.lastLigneSnapshot = snap;
}

function editCurrentLigne() {
    if (AppState.selectedLigneIndex < 0) { showErrorToast(_t('saisie.msg.no_line_selected')); return; }
    takeSnapshot();
    loadLigneIntoForm(AppState.selectedLigneIndex);
    if (AppState.editingId) setLineEditLocked(false);
}

function validateLigne() {
    if (AppState.editingId && AppState.selectedLigneIndex >= 0
        && window._lineEditLocked) {
        return;
    }

    var primaire = getPrimaryPlanField();
    if (primaire) {
        var compteId = _getVal(primaire.selectId);
        if (!compteId) {
            showErrorToast((_t('saisie.msg.account_required') || 'Le compte « {label} » est obligatoire.')
                .replace('{label}', primaire.label));
            return;
        }
    }

    var mntLocal = parseMoneyFR(_getVal('flMontantLocal'));
    if (isNaN(mntLocal) || mntLocal <= 0) { showErrorToast(_t('saisie.msg.amount_required')); return; }

    var sens = (document.querySelector('input[name="flSens"]:checked') || {}).value || 'D';
    var mntRep = parseMoneyFR(_getVal('flMontantRep'));
    if (isNaN(mntRep) || mntRep < 0) { showErrorToast(_t('saisie.msg.amount_invalid')); return; }

    var auxSel = document.getElementById('flAux');
    var auxiliaire = (auxSel && !auxSel.disabled) ? (auxSel.value || '').trim() : '';
    var selectedAux = auxSel && auxSel.selectedIndex >= 0
        ? auxSel.options[auxSel.selectedIndex]
        : null;

    var ligne = {
        auxiliaire:   auxiliaire,
        tiersId:      selectedAux ? selectedAux.getAttribute('data-tiers-id') : null,
        compteIdSUB:  _getVal('flSub') || null,
        sourceFinancement: _getVal('flSub') || '',
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
        ligne['code' + plan.key] = val ? findCodeCompteByKey(plan.key, val) : '';
    });

    var editingExistingLine = AppState.selectedLigneIndex >= 0;
    if (editingExistingLine) {
        AppState.lignes[AppState.selectedLigneIndex] = ligne;
    } else {
        AppState.lignes.push(ligne);
    }

    if (AppState.editingId && editingExistingLine) {
        var savedIndex = AppState.selectedLigneIndex;
        renderGrid();
        computeTotaux();
        loadLigneIntoForm(savedIndex);
        setLineEditLocked(true);
        if (typeof markDirty === 'function') markDirty();
        return;
    }

    AppState.selectedLigneIndex = -1;
    renderGrid();
    computeTotaux();
    clearFormLigne();
    if (AppState.editingId) setLineEditLocked(true);
    if (typeof markDirty === 'function') markDirty();
}

function deleteCurrentLigne() {
    if (AppState.selectedLigneIndex < 0) { showErrorToast(_t('saisie.msg.no_line_selected')); return; }
    AppState.lignes.splice(AppState.selectedLigneIndex, 1);
    AppState.selectedLigneIndex = -1;
    if (AppState.editingId) setLineEditLocked(true);
    renderGrid();
    computeTotaux();
    clearFormLigne();
    if (typeof markDirty === 'function') markDirty();
}

function duplicateLigne() {
    if (AppState.selectedLigneIndex < 0) { showErrorToast(_t('saisie.msg.no_line_selected')); return; }
    var orig = AppState.lignes[AppState.selectedLigneIndex];
    var copy = JSON.parse(JSON.stringify(orig));
    AppState.lignes.splice(AppState.selectedLigneIndex + 1, 0, copy);
    AppState.selectedLigneIndex = AppState.selectedLigneIndex + 1;
    if (AppState.editingId) setLineEditLocked(true);
    renderGrid();
    computeTotaux();
    if (typeof _refreshLinesCounter === 'function') _refreshLinesCounter();
    if (typeof markDirty === 'function') markDirty();
}

// ============================================================
// Déverrouillage après saisie de la Référence (TRESO uniquement)
// ============================================================
function _bindTreasuryUnlockOnReferenceBlur() {
    var refInput = document.getElementById('ecrReference');
    if (!refInput || refInput._treasuryBound) return;
    refInput._treasuryBound = true;

    refInput.addEventListener('blur', function () {
        if (typeof _isTreasuryJournal !== 'function' || !_isTreasuryJournal()) return;
        if (!refInput.value.trim()) return;
        if (AppState.lignes.length > 0) return;

        window._detailLocked = true;
        _lockOnlyCompte();

        var primaire = getPrimaryPlanField();
        if (primaire) {
            var compteSel = document.getElementById(primaire.selectId);
            if (compteSel) compteSel.focus();
        }
        console.log('[form] Déverrouillage trésorerie : focus Compte');
    });
}

// ============================================================
// Anti-réentrance modale OD
// ============================================================
var _odModalOpening = false;

// ============================================================
// LIAISON déclencheur modale OD sur Auxiliaire
// ============================================================
function _bindTreasuryOdModalTrigger() {
    var primaire = getPrimaryPlanField();
    if (!primaire) return;
    var auxSel = document.getElementById('flAux');
    if (!auxSel) return;
    if (!auxSel._treasuryBound) {
        auxSel._treasuryBound = true;
        auxSel.addEventListener('change', _maybeOpenOdModal);
    }
}

function _bindComptePrefixUnlock() {
    var primaire = getPrimaryPlanField();
    if (!primaire) return;
    var compteSel = document.getElementById(primaire.selectId);
    if (!compteSel || compteSel._prefixBound) return;
    compteSel._prefixBound = true;
    compteSel.addEventListener('change', function () {
        Promise.resolve().then(function () { _applyLockByComptePrefix(); });
    });
}

// ============================================================
// ⭐ PATCH B.1 — Ouvre la modale OD (une seule fois par écriture)
// ============================================================
async function _maybeOpenOdModal() {
    if (_odModalOpening) { console.log('[form] Modale OD : déjà en cours → skip'); return; }

    if (typeof _isTreasuryJournal !== 'function' || !_isTreasuryJournal()) {
        console.log('[form] Modale OD : journal non-TRESO → skip');
        return;
    }
    if (AppState.selectedLigneIndex >= 0) {
        console.log('[form] Modale OD : édition d\'une ligne → skip');
        return;
    }

    // ⭐ PATCH B.1 : ne pas rouvrir si une reprise a déjà eu lieu
    var hasReprise = false;
    if (AppState.lettrageSources && AppState.lettrageSources.length) {
        hasReprise = AppState.lettrageSources.some(function (s) {
            return typeof s.newLineRef === 'number'
                && s.newLineRef >= 0
                && s.newLineRef < (AppState.lignes || []).length;
        });
    }
    if (hasReprise) {
        console.log('[form] Modale OD : reprise déjà faite → mode manuel (utilisez window.reopenOdModal() pour forcer)');
        return;
    }

    var primaire = getPrimaryPlanField();
    if (!primaire) return;
    var compteId = _getVal(primaire.selectId);
    if (!compteId) { console.log('[form] Modale OD : aucun compte sélectionné → skip'); return; }
    var compte = _findCompteByPlanAndId(primaire.ordre, compteId);
    if (!compte) { console.log('[form] Modale OD : compte introuvable → skip'); return; }
    if (String(compte.CODE).charAt(0) !== '4') {
        console.log('[form] Modale OD : compte non-4xxx (' + compte.CODE + ') → skip');
        return;
    }

    var auxSel = document.getElementById('flAux');
    if (!auxSel || auxSel.disabled) { console.log('[form] Modale OD : aux désactivé → skip'); return; }
    if (!auxSel.value) { console.log('[form] Modale OD : aucun aux sélectionné → skip'); return; }

    var auxId = auxSel.value;
    var auxLabel = '';
    if (auxSel.selectedIndex >= 0 && auxSel.options[auxSel.selectedIndex]) {
        auxLabel = auxSel.options[auxSel.selectedIndex].textContent || '';
    }
    var sens = (document.querySelector('input[name="flSens"]:checked') || {}).value || 'D';

    var filter = {
        compteId: compte.ID,
        compteCode: String(compte.CODE || ''),
        auxiliaireId: auxId,
        auxiliaireLabel: auxLabel,
        sens: sens,
        // ⭐ PATCH B.1 : PAS de contrepartie auto (Cas 2 — ligne 5xxx séparée)
        generateCounterpart: false
    };

    console.log('%c[form] Ouverture modale OD — filtre compte+aux',
        'color:#0a7;font-weight:bold', filter);

    if (typeof openOdModal !== 'function') {
        console.warn('[form] openOdModal non disponible — modale impossible');
        return;
    }

    _odModalOpening = true;
    try {
        await openOdModal(filter);
    } catch (e) {
        console.error('[form] Erreur ouverture modale OD :', e);
    } finally {
        _odModalOpening = false;
    }

    _prefillOdModalSearch(auxLabel);
}

function _prefillOdModalSearch(auxLabel) {
    if (!auxLabel) return;
    var auxCode = String(auxLabel).split(/\s+—\s+/)[0].trim();
    if (!auxCode) return;
    setTimeout(function () {
        var input = document.getElementById('odSearchInput');
        if (!input) return;
        if (input.value) return;
        input.value = auxCode;
        input.dispatchEvent(new Event('input', { bubbles: true }));
        console.log('[form] Modale OD : recherche pré-remplie avec "' + auxCode + '"');
    }, 250);
}

// ============================================================
// ⭐ PATCH A.4 — Helper : ajouter une contrepartie banque manuellement
//    (Cas 2 : après plusieurs lignes 4xxx, l'utilisateur doit
//     équilibrer avec la banque — appel via window.addBankLineManually())
// ============================================================
function _addBankLineManually() {
    if (!_hasDetailHeaderPrerequisites()) {
        window._detailLocked = true;
        _lockAllDetailFields();
        return false;
    }

    var primaire = getPrimaryPlanField();
    if (!primaire) return false;

    var bankId = (typeof _getJournalCompteBanqueId === 'function') ? _getJournalCompteBanqueId() : null;
    if (!bankId) {
        if (typeof showErrorToast === 'function') showErrorToast('Aucun compte banque configuré sur ce journal');
        return false;
    }

    // Reset le formulaire (ligne vide)
    clearFormLigne();

    // Force la sélection + verrouillage du compte banque
    var p1Sel = document.getElementById(primaire.selectId);
    if (!p1Sel) return false;
    p1Sel.value = bankId;
    p1Sel.disabled = true;
    p1Sel.style.backgroundColor = '#e2e8f0';
    p1Sel.style.cursor = 'not-allowed';
    p1Sel.setAttribute('title', _t('saisie.hint.plan1_forced_treso',
        'Compte trésorerie imposé par le journal (non modifiable).'));

    // Déverrouille les champs de détail
    ['flLibelle', 'flMontantLocal', 'flMontantRep', 'flEcheance'].forEach(function (id) {
        var el = document.getElementById(id);
        if (el) { el.disabled = false; el.style.backgroundColor = ''; el.style.cursor = ''; }
    });
    document.querySelectorAll('input[name="flSens"]').forEach(function (r) { r.disabled = false; });

    // Auto-fill montant équilibrant
    var sumD = 0, sumC = 0;
    AppState.lignes.forEach(function (l) { sumD += (l.debit || 0); sumC += (l.credit || 0); });
    var diff = sumD - sumC;
    if (Math.abs(diff) > 0.01) {
        var sensToUse = diff > 0 ? 'C' : 'D';
        var amount = Math.abs(diff);
        var mntInput = document.getElementById('flMontantLocal');
        if (mntInput) {
            if (typeof window.setMoneyValue === 'function') {
                window.setMoneyValue('flMontantLocal', amount);
            } else {
                mntInput.value = amount.toFixed(2).replace('.', ',');
            }
        }
        var sensRadio = document.querySelector('input[name="flSens"][value="' + sensToUse + '"]');
        if (sensRadio) sensRadio.checked = true;
    }

    window._detailLocked = false;
    console.log('[form] addBankLineManually → compte banque '
        + (typeof _getJournalCompteBanqueCode === 'function' ? _getJournalCompteBanqueCode() : '?')
        + ' prêt, montant équilibrant auto-rempli');
    return true;
}

// ============================================================
// ⭐ PATCH B.2 — Helper : forcer la réouverture de la modale OD
//    (cas des reprises multiples dans la même écriture)
// ============================================================
function _reopenOdModal() {
    if (typeof openOdModal !== 'function') return;
    var primaire = getPrimaryPlanField();
    if (!primaire) return;
    var compteId = _getVal(primaire.selectId);
    if (!compteId) return;
    var compte = _findCompteByPlanAndId(primaire.ordre, compteId);
    if (!compte || String(compte.CODE).charAt(0) !== '4') return;
    var auxSel = document.getElementById('flAux');
    if (!auxSel || !auxSel.value) return;

    var filter = {
        compteId: compte.ID,
        compteCode: String(compte.CODE || ''),
        auxiliaireId: auxSel.value,
        auxiliaireLabel: (auxSel.options[auxSel.selectedIndex] || {}).textContent || '',
        sens: (document.querySelector('input[name="flSens"]:checked') || {}).value || 'D',
        generateCounterpart: false
    };
    console.log('[form] reopenOdModal forcé', filter);
    openOdModal(filter);
}

// ============================================================
// INITIALISATION
// ============================================================
function _initDetailLock() {
    var attempts = 0;
    var interval = setInterval(function () {
        attempts++;
        var journalSel = document.getElementById('ecrJournal');
        var populated = journalSel && journalSel.options && journalSel.options.length > 1;
        if (populated || attempts >= 20) {
            clearInterval(interval);
            _bindTreasuryUnlockOnReferenceBlur();
            _bindTreasuryOdModalTrigger();
            _bindComptePrefixUnlock();
            applyDetailLockByContext();
            console.log('[form] Verrouillage initial DÉTAIL appliqué ('
                + (window._detailLocked ? 'verrouillé' : 'déverrouillé') + ')');
        }
    }, 100);
}

document.addEventListener('DOMContentLoaded', _initDetailLock);

document.addEventListener('change', function (e) {
    if (e.target
        && ['ecrSite', 'ecrJournal', 'ecrDate', 'ecrDatePiece'].indexOf(e.target.id) >= 0) {
        applyDetailLockByContext();
    }
    if (e.target && e.target.id === 'ecrJournal') {
        setTimeout(function () {
            _bindTreasuryUnlockOnReferenceBlur();
            _bindTreasuryOdModalTrigger();
            _bindComptePrefixUnlock();
            applyDetailLockByContext();
        }, 200);
    }
});

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

window.setDetailLock             = setDetailLock;
window.setLineEditLocked         = setLineEditLocked;
window.applyDetailLockByContext  = applyDetailLockByContext;
window._hasDetailHeaderPrerequisites = _hasDetailHeaderPrerequisites;
window._lockAllDetailFields      = _lockAllDetailFields;
window._unlockAllDetailFields    = _unlockAllDetailFields;
window._applyLockByComptePrefix  = _applyLockByComptePrefix;
window._lockOnlyAuxiliaire       = _lockOnlyAuxiliaire;
window._maybeAutoBankForTreasury = _maybeAutoBankForTreasury;
window._unlockTreasuryManualLineAfterOdCancel = _unlockTreasuryManualLineAfterOdCancel;
window.addBankLineManually       = _addBankLineManually;
window.reopenOdModal             = _reopenOdModal;
