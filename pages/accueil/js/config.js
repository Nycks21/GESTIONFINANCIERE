'use strict';

// ============================================================
// CONFIGURATION — Dashboard global Gestion Financière
// ============================================================

window.DASHBOARD_API = {
    KPI:         'index.aspx?action=kpi',
    EVOLUTION:   'index.aspx?action=evolution',
    REPARTITION: 'index.aspx?action=repartition',
    ACTIVITES:   'index.aspx?action=activites'
};

window.DASHBOARD_COLORS = {
    emerald: '#10b981',
    blue:    '#3b82f6',
    violet:  '#8b5cf6',
    amber:   '#f59e0b',
    red:     '#ef4444',
    gray:    '#6b7280',
    donut:   ['#3b82f6', '#10b981', '#f59e0b', '#8b5cf6', '#6b7280']
};

window.DASHBOARD_DEFAULTS = {
    CURRENCY:         'Ar',
    LOCALE:           'fr-FR',
    REFRESH_INTERVAL: 60000,
    ACTIVITE_MAX:     5
};
