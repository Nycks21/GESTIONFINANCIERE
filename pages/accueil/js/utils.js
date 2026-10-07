'use strict';

window.DashUtils = {

    formatMontant: function (val) {
        if (val === null || val === undefined || isNaN(val)) return '0 ' + DASHBOARD_DEFAULTS.CURRENCY;
        return new Intl.NumberFormat(DASHBOARD_DEFAULTS.LOCALE, { maximumFractionDigits: 0 })
                    .format(val) + ' ' + DASHBOARD_DEFAULTS.CURRENCY;
    },

    formatEntier: function (val) {
        if (val === null || val === undefined || isNaN(val)) return '0';
        return new Intl.NumberFormat(DASHBOARD_DEFAULTS.LOCALE).format(val);
    },

    formatPct: function (val) {
        if (val === null || val === undefined || isNaN(val)) return '0%';
        var sign = val > 0 ? '+' : '';
        return sign + Math.round(val) + '%';
    },

    formatHeure: function (iso) {
        if (!iso) return '';
        var d = new Date(iso);
        var now = new Date();
        var diffH = Math.floor((now - d) / 3600000);
        if (diffH < 1)  return d.toLocaleTimeString(DASHBOARD_DEFAULTS.LOCALE, { hour: '2-digit', minute: '2-digit' });
        if (diffH < 24) return d.toLocaleTimeString(DASHBOARD_DEFAULTS.LOCALE, { hour: '2-digit', minute: '2-digit' });
        if (diffH < 48) return 'Hier';
        return d.toLocaleDateString(DASHBOARD_DEFAULTS.LOCALE, { day: '2-digit', month: '2-digit' });
    },

    formatDateLongue: function (d) {
        return d.toLocaleDateString(DASHBOARD_DEFAULTS.LOCALE, {
            weekday: 'long', day: 'numeric', month: 'long', year: 'numeric'
        });
    },

    escapeHtml: function (s) {
        if (s === null || s === undefined) return '';
        return String(s)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    },

    statutClass: function (statut) {
        var s = (statut || '').toUpperCase();
        if (s === 'VALIDEE' || s === 'VALIDE' || s === 'COMPTABILISEE') return 'validee';
        if (s === 'BROUILLON')      return 'brouillon';
        if (s === 'ANNULE' || s === 'ANNULEE') return 'annulee';
        if (s === 'EN_COURS' || s === 'ENREGISTREE') return 'en_cours';
        if (s === 'RAPPROCHE')      return 'validee';
        return 'enregistree';
    },

    typeIcon: function (type) {
        var t = (type || '').toUpperCase();
        if (t === 'ECRITURE') return { cls: 'ecriture', icon: 'fa-file-invoice-dollar' };
        if (t === 'ENTREE')   return { cls: 'entree',   icon: 'fa-arrow-down' };
        if (t === 'SORTIE')   return { cls: 'sortie',   icon: 'fa-arrow-up' };
        if (t === 'RAPPRO')   return { cls: 'rappro',   icon: 'fa-university' };
        return { cls: 'ecriture', icon: 'fa-circle' };
    }
};
