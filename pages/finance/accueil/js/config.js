'use strict';

/* ═══════════════════════════════════════════════════════════════
   FINANCE — Configuration du dashboard
   ═══════════════════════════════════════════════════════════════ */

window.FIN_CONFIG = {

    PAGE: 'dashboard',

    /* ─── Handlers ─── */
    URLS: {
        stats:     'handlers/GetFinanceStats.ashx',
        chart:     'handlers/GetChartData.ashx',
        activites: 'handlers/GetDernieresActivites.ashx'
    },

    /* ─── Routes internes ─── */
    ROUTES: {
        ecritures:     '../ecritures/saisie/saisie.aspx',
        consultation:  '../ecritures/consultation/consultation.aspx',
        lettrage:      '../lettrage/lettrage.aspx',
        rapprochement: '../rapprochement/reconciliation/reconciliation.aspx',
        parametres:    '../parametrage/sites/sites.aspx',
        rapports:      '../rapports/balance/balance.aspx'
    },

    /* ─── Options ─── */
    REFRESH_INTERVAL: 60000,   // auto-refresh KPI (0 = désactivé)
    MAX_ACTIVITES:    8,

    /* ─── Formatage ─── */
    CURRENCY: 'Ar',
    LOCALE:   'fr-FR',

    /* ─── Palette charts ─── */
    COLORS: {
        entrees:  '#10b981',
        sorties:  '#8b5cf6',
        emerald:  '#10b981',
        blue:     '#3b82f6',
        violet:   '#8b5cf6',
        amber:    '#f59e0b',
        red:      '#ef4444',
        gray:     '#6b7280',
        donut:    ['#3b82f6', '#10b981', '#f59e0b', '#8b5cf6', '#ef4444', '#6b7280']
    }
};
