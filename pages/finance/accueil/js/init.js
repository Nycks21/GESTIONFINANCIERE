'use strict';

document.addEventListener('DOMContentLoaded', function () {
    console.log('[Finance] Dashboard init — Modern UI');

    // Hero : date + heure
    FinUI.renderHeroDate();
    setInterval(FinUI.renderHeroDate, 30000);

    // Chargement initial
    loadFinanceDashboard();

    // Auto-refresh KPI
    if (FIN_CONFIG.REFRESH_INTERVAL > 0) {
        setInterval(function () {
            if (!document.hidden) {
                FinLoaders.loadStats().catch(function () {});
            }
        }, FIN_CONFIG.REFRESH_INTERVAL);
    }

    // ✅ Observer les changements de dark mode pour rafraîchir les charts
    var toggle = document.getElementById('toggleDarkMode');
    if (toggle) {
        toggle.addEventListener('change', function () {
            // Laisser le temps à body.dark-mode d'être appliqué
            setTimeout(function () {
                if (window.FinCharts && FinCharts.refreshTheme) {
                    FinCharts.refreshTheme();
                }
            }, 60);
        });
    }
});

function loadFinanceDashboard() {
    FinLoaders.loadStats().catch(function (e) { console.error('Stats', e); });
    FinLoaders.loadEvolution().catch(function (e) { console.error('Evolution', e); });
    FinLoaders.loadRepartition().catch(function (e) { console.error('Repartition', e); });
    FinLoaders.loadActivites().catch(function (e) { console.error('Activites', e); });
}

window.loadFinanceDashboard = loadFinanceDashboard;
