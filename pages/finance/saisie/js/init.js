// init.js — SAISIE (orchestrateur + listeners + raccourcis + mode compact + money inputs + Vue)
'use strict';

$(document).ready(function () {

    // ============================================================
    // 0) PRÉ-INITIALISATION
    // ============================================================
    if (typeof restoreCompactMode === 'function') {
        restoreCompactMode();
    }
    if (typeof initKeyboardShortcuts === 'function') {
        initKeyboardShortcuts();
    }
    if (typeof initMoneyInputs === 'function') {
        initMoneyInputs();
    }

    // ============================================================
    // 1) CHARGEMENT INITIAL
    //    - loadLookups → référentiels + comptes des plans
    //    - editEcriture → écriture demandée, sinon nouvelle écriture
    // ============================================================
    loadLookups()
        .then(function () {
            bindDynamicPlanListeners();
            var query = new URLSearchParams(window.location.search);
            var editId = query.get('editId') || query.get('id');
            if (editId) {
                return editEcriture(editId);
            }
            newEcriture();
        })
        .catch(function (err) {
            console.error('[init] Erreur chargement initial :', err);
            showErrorToast(
                _t('saisie.msg.init_error') ||
                'Erreur lors du chargement initial.'
            );
        });

    // La liste est gérée sur liste-ecritures.aspx, pas sur le formulaire de saisie.
    $(document).on('input change', '#tab-edit input, #tab-edit select, #tab-edit textarea', function () {
        if (typeof markDirty === 'function') markDirty();
    });

    // ============================================================
    // 3) ENTÊTE — Journal → numéro auto
    // ============================================================
    $(document).on('change', '#ecrJournal', function () {
        if (!AppState.editingId) loadNextNumero();
    });

    // ============================================================
    // 4) ENTÊTE — Exercice → recharge les périodes
    // ============================================================
    $(document).on('change', '#ecrExercice', function () {
        var exId = this.value;
        loadPeriodes(exId).then(function () {
            var d = _getVal('ecrDate');
            if (d) _setVal('ecrPeriode', findPeriodeId(d));
        }).catch(function (err) {
            showErrorToast(err.message);
        });
    });

    // ============================================================
    // 5) ENTÊTE — Date comptable → auto-détection période
    // ============================================================
    $(document).on('change', '#ecrDate', function () {
        var d = this.value;
        if (!d) return;
        _setVal('ecrPeriode', findPeriodeId(d));
    });

    // ============================================================
    // 6) ENTÊTE — Devise → cours
    // ============================================================
    $(document).on('change', '#ecrDevise', function () {
        var id = this.value;
        var m = (AppState.monnaies || []).find(function (x) { return x.ID === id; });
        if (m && m.EST_REFERENCE) _setVal('ecrCours', '1');
    });

});

// ============================================================
// LISTENERS SUR LES CHAMPS DE PLANS DYNAMIQUES
// ============================================================
function bindDynamicPlanListeners() {
    if (typeof getActivePlanFields !== 'function') return;

    var active = getActivePlanFields();
    active.forEach(function (plan) {
        var sel = document.getElementById(plan.selectId);
        if (!sel || sel.dataset.bound === '1') return;
        sel.dataset.bound = '1';

        sel.addEventListener('change', function () {
            if (plan.isPrimary) {
                refreshAuxiliaireField({ preserveValue: false });
            }
            if (typeof markDirty === 'function') markDirty();
        });
    });

    refreshAuxiliaireField({ preserveValue: false });

    console.log('[init] Listeners attachés sur', active.length, 'champ(s) plan.');
}

window.bindDynamicPlanListeners = bindDynamicPlanListeners;
