'use strict';

window.FinUI = {

    /* ────────────────────────────────────────────────────────
       HERO — Date + heure
       ──────────────────────────────────────────────────────── */
    renderHeroDate: function () {
        var now = new Date();

        var dateEl = document.getElementById('finHeroDate');
        if (dateEl) {
            dateEl.textContent = now.toLocaleDateString(FIN_CONFIG.LOCALE, {
                weekday: 'long', day: 'numeric', month: 'long', year: 'numeric'
            });
        }

        var timeEl = document.getElementById('finHeroTime');
        if (timeEl) {
            timeEl.textContent = now.toLocaleTimeString(FIN_CONFIG.LOCALE, {
                hour: '2-digit', minute: '2-digit'
            });
        }
    },

    /* ────────────────────────────────────────────────────────
       KPI Tiles
       ──────────────────────────────────────────────────────── */
    renderStats: function (s) {
        var soldeEl  = document.getElementById('finKpiSolde');
        var ecritEl  = document.getElementById('finKpiEcritures');
        var debitEl  = document.getElementById('finKpiDebits');
        var creditEl = document.getElementById('finKpiCredits');

        if (soldeEl)  soldeEl.textContent  = FinUtils.formatMontant(s.solde);
        if (ecritEl)  ecritEl.textContent  = FinUtils.formatEntier(s.ecrituresMois);
        if (debitEl)  debitEl.textContent  = FinUtils.formatMontant(s.debits);
        if (creditEl) creditEl.textContent = FinUtils.formatMontant(s.credits);

        FinUI._setTrend('finTrendSolde',     s.soldeVar     || 0);
        FinUI._setTrend('finTrendEcritures', s.ecrituresVar || 0);
        FinUI._setTrend('finTrendDebits',    s.entreesVar   || 0);
        FinUI._setTrend('finTrendCredits',   s.sortiesVar   || 0);
    },

    _setTrend: function (id, pct) {
        var el = document.getElementById(id);
        if (!el) return;
        var num = Number(pct) || 0;
        el.textContent = FinUtils.formatPct(num);
        el.classList.toggle('negative', num < 0);
    },

    /* ────────────────────────────────────────────────────────
       Activités récentes
       ──────────────────────────────────────────────────────── */
    renderActivites: function (list) {
        var el = document.getElementById('activityList');
        if (!el) return;

        if (!list || list.length === 0) {
            el.innerHTML = '<div class="fin-loading"><span style="color:#94a3b8;font-size:13px;">' +
                'Aucune écriture récente</span></div>';
            return;
        }

        var html = '';
        list.slice(0, FIN_CONFIG.MAX_ACTIVITES).forEach(function (a) {
            var cls   = FinUtils.statutClass(a.statut);
            var heure = FinUtils.formatHeure(a.createdAt);
            var meta  = [a.journal, a.numero].filter(Boolean).join(' · ');

            html += '<div class="act-item">' +
                        '<div class="act-icon ecriture"><i class="fas fa-file-invoice"></i></div>' +
                        '<div class="act-body">' +
                            '<div class="act-title">' + FinUtils.escapeHtml(a.libelle) + '</div>' +
                            '<div class="act-meta">' + FinUtils.escapeHtml(meta) +
                                (a.date ? ' · <span>' + a.date + '</span>' : '') +
                            '</div>' +
                        '</div>' +
                        '<span class="act-time">' + heure + '</span>' +
                        '<span class="act-badge ' + cls + '">' + FinUtils.escapeHtml(a.statut) + '</span>' +
                    '</div>';
        });
        el.innerHTML = html;
    },

    /* ────────────────────────────────────────────────────────
       Donut center + légende
       ──────────────────────────────────────────────────────── */
    renderDonutTotal: function (total) {
        var el = document.getElementById('donutTotal');
        if (el) el.textContent = FinUtils.formatMontant(total);
    },

    renderDonutLegend: function (labels, valeurs, colors) {
        var el = document.getElementById('donutLegend');
        if (!el) return;

        if (!labels || labels.length === 0) {
            el.innerHTML = '<li style="color:#94a3b8;font-size:12px;">—</li>';
            return;
        }

        var total = valeurs.reduce(function (a, b) { return a + b; }, 0) || 1;
        var html = '';

        labels.forEach(function (lbl, i) {
            var pct = Math.round((valeurs[i] / total) * 100);
            html += '<li>' +
                        '<span class="fin-leg-dot" style="background:' + colors[i % colors.length] + '"></span>' +
                        '<span class="leg-label">' + FinUtils.escapeHtml(lbl) + '</span>' +
                        '<span class="leg-val">' + pct + '%</span>' +
                    '</li>';
        });
        el.innerHTML = html;
    }
};
