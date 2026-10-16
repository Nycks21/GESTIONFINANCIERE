// init.js — MARCHE (orchestrateur)
'use strict';

$(document).ready(function () {

    // 0) Pré-init
    if (typeof restoreCompactMode === 'function') restoreCompactMode();
    if (typeof initKeyboardShortcuts === 'function') initKeyboardShortcuts();
    if (typeof initMoneyInputs === 'function') initMoneyInputs();

    // 1) Chargement initial
    loadLookups()
        .then(function () {
            return loadAllComptesActifs();
        })
        .then(function () {
            bindDynamicPlanListeners();
            bindFournisseurAuxiListener();
            loadMarches();
        })
        .catch(function (err) {
            console.error('[init] Erreur chargement initial :', err);
            showErrorToast(_t('marche.msg.init_error') || 'Erreur lors du chargement initial.');
        });

    // 2) Filtres liste (uniquement si Vue absent)
    if (!window._VueMarcheList) {
        var tid = null;
        $(document).on('input', '#search-filter', function () {
            clearTimeout(tid);
            tid = setTimeout(function () {
                AppState.filters.search = _getVal('search-filter');
                AppState.page = 1;
                loadMarches({ silent: true });
            }, 300);
        });
    }

    // 3) Reset filtres
    window.resetFilters = function () {
        if (window._VueMarcheList && typeof window._VueMarcheList.resetFilters === 'function') {
            window._VueMarcheList.resetFilters();
            return;
        }
        _setVal('search-filter', '');
        AppState.filters = { search: '', statut: '', typeMarche: '' };
        AppState.page = 1;
        loadMarches({ silent: true });
    };

    // 4) Bouton Enregistrer
    setTimeout(function () {
        if (typeof updateSaveButtonState === 'function') updateSaveButtonState();
    }, 500);
});

// ============================================================
// ⭐ BINDING : Fournisseur → Filtre des Auxiliaires
// ============================================================
function bindFournisseurAuxiListener() {
    var selF = document.getElementById('marFournisseur');
    if (!selF || selF.dataset.boundAuxi === '1') return;
    selF.dataset.boundAuxi = '1';

    selF.addEventListener('change', function () {
        // ⭐ On repart d'un select vide SANS préserver la valeur précédente
        //    (nouveau fournisseur = nouveau contexte)
        populateMarAuxiOptions(selF.value || null, false);
        if (typeof markDirty === 'function') markDirty();
    });

    console.log('[init] Listener marFournisseur → marAuxi attaché.');
}

// ============================================================
// LISTENERS PLANS DYNAMIQUES
// ============================================================
function bindDynamicPlanListeners() {
    if (typeof getActivePlanFields !== 'function') return;
    var active = getActivePlanFields();
    active.forEach(function (plan) {
        var sel = document.getElementById(plan.selectId);
        if (!sel || sel.dataset.bound === '1') return;
        sel.dataset.bound = '1';
        sel.addEventListener('change', function () {
            if (typeof markDirty === 'function') markDirty();
        });
    });
    console.log('[init] Listeners attachés sur', active.length, 'champ(s) plan.');
}

window.bindFournisseurAuxiListener = bindFournisseurAuxiListener;
window.bindDynamicPlanListeners    = bindDynamicPlanListeners;
