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
    //    - loadLookups → référentiels + plans
    //    - loadAllComptesActifs → comptes des plans
    //    - loadEcritures → liste (bridge Vue si présent)
    // ============================================================
    loadLookups()
        .then(function () {
            return loadAllComptesActifs();
        })
        .then(function () {
            bindDynamicPlanListeners();
            loadEcritures();
        })
        .catch(function (err) {
            console.error('[init] Erreur chargement initial :', err);
            showErrorToast(
                _t('saisie.msg.init_error') ||
                'Erreur lors du chargement initial.'
            );
        });

    // ============================================================
    // 2) FILTRES LISTE
    //    ⭐ Uniquement si Vue n'est PAS chargé.
    //       Sinon, Vue gère ses propres filtres via v-model.
    // ============================================================
    if (!window._VueSaisieList) {
        var tid = null;
        $(document).on('input', '#search-filter', function () {
            clearTimeout(tid);
            tid = setTimeout(function () {
                AppState.filters.search = _getVal('search-filter');
                AppState.page = 1;
                loadEcritures({ silent: true });
            }, 300);
        });

        $(document).on('change', '#journal-filter, #statut-filter', function () {
            AppState.filters.journalId = _getVal('journal-filter');
            AppState.filters.statut    = _getVal('statut-filter');
            AppState.page = 1;
            loadEcritures({ silent: true });
        });
    }

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

    // ============================================================
    // 7) RESET FILTRES (fallback vanilla)
    // ============================================================
    window.resetFilters = function () {
        if (window._VueSaisieList && typeof window._VueSaisieList.resetFilters === 'function') {
            window._VueSaisieList.resetFilters();
            return;
        }
        _setVal('search-filter', '');
        _setVal('journal-filter', '');
        _setVal('statut-filter', '');
        AppState.filters = { search: '', journalId: '', statut: '' };
        AppState.page = 1;
        loadEcritures({ silent: true });
    };

    // ============================================================
    // 8) RAFRAÎCHIT LE BOUTON ENREGISTRER au démarrage
    // ============================================================
    setTimeout(function () {
        if (typeof updateSaveButtonState === 'function') {
            updateSaveButtonState();
        }
    }, 500);
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
