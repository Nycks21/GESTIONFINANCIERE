// init.js — TIERS
$(document).ready(function () {
    loadLookups().then(function () {
        loadTiers();
        loadStats();
    });

    initUIControls();

    window.sortData = function (field) {
        if (AppState.sortField === field) {
            AppState.sortOrder = AppState.sortOrder === 'ASC' ? 'DESC' : 'ASC';
        } else {
            AppState.sortField = field;
            AppState.sortOrder = 'ASC';
        }
        loadTiers();
    };
});
