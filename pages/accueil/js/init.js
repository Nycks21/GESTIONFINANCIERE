'use strict';

document.addEventListener('DOMContentLoaded', function () {
    console.log('[Dashboard] Init — Gestion Financière');

    // Horloge + date du bandeau
    DashUI.renderDateHeure();
    setInterval(DashUI.renderDateHeure, 60000);

    // Chargement initial
    loadDashboard();

    // Auto-refresh des KPI uniquement
    if (DASHBOARD_DEFAULTS.REFRESH_INTERVAL > 0) {
        setInterval(function () {
            if (!document.hidden) {
                DashLoaders.loadKpi().catch(function () {});
            }
        }, DASHBOARD_DEFAULTS.REFRESH_INTERVAL);
    }
});

function loadDashboard() {
    DashLoaders.loadKpi().catch(function (e) { console.error('KPI', e); });
    DashLoaders.loadEvolution().catch(function (e) { console.error('Evolution', e); });
    DashLoaders.loadRepartition().catch(function (e) { console.error('Repartition', e); });
    DashLoaders.loadActivites().catch(function (e) { console.error('Activites', e); });
}
