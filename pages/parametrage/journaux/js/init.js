// init.js — JOURNAUX (multi-sites + catégorie)
$(document).ready(function () {
    // 1) Référentiels
    loadLookups().then(function () {
        loadJournaux();
        loadStats();
    });

    initUIControls();

    // ─── 🆕 Changement de catégorie → toggle compte ───
    $(document).on('change', 'input[name="categorieJournal"]', function () {
        toggleCompteBanqueField();
    });

    // ─── Recherche sites ───
    $('#sitesSearch').on('input', function () {
        filterSitesList();
    });

    // ─── Tri ───
    window.sortData = function (field) {
        if (AppState.sortField === field) {
            AppState.sortOrder = AppState.sortOrder === 'ASC' ? 'DESC' : 'ASC';
        } else {
            AppState.sortField = field;
            AppState.sortOrder = 'ASC';
        }
        loadJournaux();
    };
});
