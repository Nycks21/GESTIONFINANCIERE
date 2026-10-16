// init.js — ÉLÉMENTS DE PLAN
'use strict';

$(document).ready(function () {

    // ✅ Lit planOrder depuis l'URL
    var params = new URLSearchParams(window.location.search);
    var planOrderStr = params.get('planOrder');

    AppState.planOrder = parseInt(planOrderStr, 10);

    if (!AppState.planOrder || AppState.planOrder < 1 || AppState.planOrder > 10) {
        Swal.fire('Erreur', 'Aucun plan sélectionné ou invalide.', 'error').then(function () {
            window.location.href = '../generale.aspx';
        });
        return;
    }

    loadPlanElements();

    $('#search-filter').on('input', function () {
        AppState.filters.search = this.value || '';
        renderElementsTable();
    });
    $('#active-filter').on('change', function () {
        AppState.filters.active = this.value || '';
        renderElementsTable();
    });

    document.addEventListener('keydown', function (e) {
        if (e.key !== 'Escape') return;
        var m = document.getElementById('elementModal');
        if (m && m.style.display === 'flex') closeElementModal();
    });

    document.querySelectorAll('.modal').forEach(function (modal) {
        modal.addEventListener('click', function (e) {
            if (e.target !== modal) return;
            if (modal.id === 'elementModal') closeElementModal();
        });
    });
});

async function loadPlanElements() {
    try {
        showSpinner();

        var url = API.BASE + API.HANDLERS_PATH + API.ELEMENTS_LIST
                + '?planOrder=' + encodeURIComponent(AppState.planOrder);

        var resp = await fetch(url);
        var data = await resp.json();

        if (!data.success) {
            showErrorToast(data.message || _t('elements.msg.load_error'));
            return;
        }

        AppState.plan = data.plan || null;
        AppState.elements = data.elements || [];

        var maxNiveau = (AppState.plan && AppState.plan.NIVEAU) ? AppState.plan.NIVEAU : 1;
        if (!AppState.currentLevel || AppState.currentLevel < 1 || AppState.currentLevel > maxNiveau) {
            AppState.currentLevel = 1;
        }

        if (AppState.plan) {
            var nom  = AppState.plan.NOM  || '—';
            var code = AppState.plan.CODE || '—';
            var niv  = AppState.plan.NIVEAU || '—';
            var type = AppState.plan.TYPE_NOM || '—';

            var hdr = document.getElementById('planNameHeader');
            var ttl = document.getElementById('planInfoTitle');
            var cEl = document.getElementById('planInfoCode');
            var nEl = document.getElementById('planInfoNiveau');
            var yEl = document.getElementById('planInfoType');

            if (hdr) hdr.textContent = nom;
            if (ttl) ttl.textContent = nom;
            if (cEl) cEl.textContent = code;
            if (nEl) nEl.textContent = niv;
            if (yEl) yEl.textContent = type;

            document.title = nom + ' — ' + _t('elements.title', 'Éléments');
        }

        renderLevelTabs();
        renderElementsTable();

    } catch (err) {
        console.error('[loadPlanElements] Erreur :', err);
        showErrorToast(err.message || _t('elements.msg.load_error'));
    } finally {
        hideSpinner();
    }
}

window.loadPlanElements = loadPlanElements;
