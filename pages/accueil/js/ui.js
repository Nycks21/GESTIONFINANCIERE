'use strict';

window.DashUI = {

    renderDateHeure: function () {
        var d = new Date();
        var elDate = document.getElementById('finWelcomeDate');
        var elTime = document.getElementById('finWelcomeTime');
        if (elDate) elDate.textContent = DashUtils.formatDateLongue(d);
        if (elTime) elTime.textContent = d.toLocaleTimeString(DASHBOARD_DEFAULTS.LOCALE, {
            hour: '2-digit', minute: '2-digit'
        });
    },

    renderKpi: function (k) {
        document.getElementById('finKpiSolde').textContent     = DashUtils.formatMontant(k.soldeActuel);
        document.getElementById('finKpiEcritures').textContent = DashUtils.formatEntier(k.ecrituresMois);
        document.getElementById('finKpiEntrees').textContent   = DashUtils.formatMontant(k.entreesTotales);
        document.getElementById('finKpiSorties').textContent   = DashUtils.formatMontant(k.sortiesTotales);

        DashUI._setTrend('finTrendSolde',     k.soldeVar);
        DashUI._setTrend('finTrendEcritures', k.ecrituresVar);
        DashUI._setTrend('finTrendEntrees',   k.entreesVar);
        DashUI._setTrend('finTrendSorties',   k.sortiesVar);
    },

    _setTrend: function (id, pct) {
        var el = document.getElementById(id);
        if (!el) return;
        var num = (pct === null || pct === undefined) ? 0 : Number(pct);
        el.textContent = DashUtils.formatPct(num);
        el.classList.toggle('negative', num < 0);
    },

    renderDonutTotal: function (total) {
        var el = document.getElementById('donutTotal');
        if (el) el.textContent = DashUtils.formatMontant(total);
    },

    renderDonutLegend: function (labels, valeurs, colors) {
        var el = document.getElementById('donutLegend');
        if (!el) return;
        if (!labels || labels.length === 0) {
            el.innerHTML = '<div class="loading-mini">—</div>';
            return;
        }
        var total = valeurs.reduce(function (a, b) { return a + b; }, 0) || 1;
        var html = '';
        labels.forEach(function (lbl, i) {
            var pct = Math.round((valeurs[i] / total) * 100);
            html += '<div class="leg-item">' +
                        '<span class="leg-sq" style="background:' + colors[i % colors.length] + '"></span>' +
                        '<span class="leg-label">' + DashUtils.escapeHtml(lbl) + '</span>' +
                        '<span class="leg-val">' + pct + '%</span>' +
                    '</div>';
        });
        el.innerHTML = html;
    },

    renderActivites: function (list) {
        var el = document.getElementById('activityList');
        if (!el) return;

        if (!list || list.length === 0) {
            el.innerHTML = '<div class="loading-mini" data-i18n="dashboard.no_activity"></div>';
            if (window.I18N && window.I18N.apply) window.I18N.apply(el);
            return;
        }

        var html = '';
        list.forEach(function (a) {
            var t  = DashUtils.typeIcon(a.type);
            var bc = DashUtils.statutClass(a.statut);
            var heure = DashUtils.formatHeure(a.dt);
            var meta = [a.ctx, a.ref].filter(Boolean).join(' · ');
            html += '<div class="act-item">' +
                        '<div class="act-icon ' + t.cls + '"><i class="fas ' + t.icon + '"></i></div>' +
                        '<div class="act-body">' +
                            '<div class="act-title">' + DashUtils.escapeHtml(a.titre) + '</div>' +
                            '<div class="act-meta">' + DashUtils.escapeHtml(meta) + '</div>' +
                        '</div>' +
                        '<span class="act-time">' + heure + '</span>' +
                        '<span class="act-badge ' + bc + '">' + DashUtils.escapeHtml(a.statut) + '</span>' +
                    '</div>';
        });
        el.innerHTML = html;
    }
};
