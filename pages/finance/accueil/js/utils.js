'use strict';

window.FinUtils = {

    formatMontant: function (val) {
        if (val === null || val === undefined || isNaN(val)) return '0 ' + FIN_CONFIG.CURRENCY;
        return new Intl.NumberFormat(FIN_CONFIG.LOCALE, { maximumFractionDigits: 0 })
                    .format(val) + ' ' + FIN_CONFIG.CURRENCY;
    },

    formatEntier: function (val) {
        if (val === null || val === undefined || isNaN(val)) return '0';
        return new Intl.NumberFormat(FIN_CONFIG.LOCALE).format(val);
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
        if (diffH < 1)  return "à l'instant";
        if (diffH < 24) return d.toLocaleTimeString(FIN_CONFIG.LOCALE, { hour: '2-digit', minute: '2-digit' });
        if (diffH < 48) return 'Hier';
        return d.toLocaleDateString(FIN_CONFIG.LOCALE, { day: '2-digit', month: '2-digit' });
    },

    formatDateLongue: function (d) {
        return d.toLocaleDateString(FIN_CONFIG.LOCALE, {
            weekday: 'long', day: 'numeric', month: 'long', year: 'numeric'
        });
    },

    escapeHtml: function (s) {
        if (s === null || s === undefined) return '';
        return String(s)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    },

    statutClass: function (statut) {
        var s = (statut || '').toUpperCase();
        if (s === 'VALIDEE' || s === 'COMPTABILISEE' || s === 'VALIDE' || s === 'TERMINE') return 'validee';
        if (s === 'A_VALIDER' || s === 'EN_COURS' || s === 'ENREGISTREE' || s === 'CORRIGEE')  return 'en_cours';
        if (s === 'BROUILLON')   return 'brouillon';
        if (s === 'ANNULEE' || s === 'ANNULE') return 'annulee';
        if (s === 'RAPPROCHE')   return 'validee';
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
