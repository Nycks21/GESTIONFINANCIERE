'use strict';

window.DashLoaders = {

    _get: function (url) {
        return fetch(url, { credentials: 'same-origin' })
            .then(function (r) {
                if (!r.ok) throw new Error('HTTP ' + r.status);
                return r.json();
            });
    },

    loadKpi: function () {
        return DashLoaders._get(DASHBOARD_API.KPI)
            .then(function (d) {
                if (d.success) { DASHBOARD_STATE.kpi = d; DashUI.renderKpi(d); }
                return d;
            });
    },

    loadEvolution: function () {
        return DashLoaders._get(DASHBOARD_API.EVOLUTION)
            .then(function (d) {
                if (d.success) { DASHBOARD_STATE.evolution = d; DashCharts.renderEvolution(d); }
                return d;
            });
    },

    loadRepartition: function () {
        return DashLoaders._get(DASHBOARD_API.REPARTITION)
            .then(function (d) {
                if (d.success) { DASHBOARD_STATE.repartition = d; DashCharts.renderRepartition(d); }
                return d;
            });
    },

    loadActivites: function () {
        return DashLoaders._get(DASHBOARD_API.ACTIVITES)
            .then(function (d) {
                if (d.success) { DASHBOARD_STATE.activites = d.data; DashUI.renderActivites(d.data); }
                return d;
            });
    }
};
