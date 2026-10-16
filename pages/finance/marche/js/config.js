// config.js — MARCHE
// ⭐ Aligné sur le schéma SQL :
//    - FMARCHE.TYPE_MARCHE    VARCHAR(5)  → FRT/TRX/SRV/PIS/ATR
//    - FMARCHE.MODE_PASSATION VARCHAR(5)  → AON/AOI/CST/GAG/EDT/ATR
//    - FMARCHE.STATUT         TINYINT     → 1/2/3/4
//    - FMARCHE.AUXILIAIRE     NVARCHAR(50) (code FTIERS.CODE)

window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/finance/marche/handlers/',

    // Endpoints MARCHE
    LOOKUPS:         'GetMarcheLookups.ashx',
    LIST:            'GetMarches.ashx',
    DETAIL:          'GetMarcheDetail.ashx',
    SAVE:            'MarcheSave.ashx',
    DELETE:          'MarcheDelete.ashx',
    NEXT_NUMERO:     'GetNextNumeroMarche.ashx',
    AUX_BY_FOURNISSEUR:'GetAuxiliairesByFournisseur.ashx',

    // Endpoints réutilisés de SAISIE (plans analytiques)
    COMPTES_BY_PLAN: 'GetComptesByPlan.ashx',
    PERIODES:        'GetExercicesPeriodes.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 20,
    SORT_FIELD: 'DATE_SIGNATURE',
    SORT_ORDER: 'DESC'
};

// ⭐ STATUTS — codes numériques (TINYINT en BDD)
window.STATUTS_MARCHE = [
    { code: '1', label: 'Attribué',     cssClass: 'statut-attribue' },
    { code: '2', label: 'Terminé',      cssClass: 'statut-termine' },
    { code: '3', label: 'Annulé',       cssClass: 'statut-annule' },
    { code: '4', label: 'Résilié',      cssClass: 'statut-resilie' }
];

// ⭐ TYPES — codes courts VARCHAR(5)
window.TYPES_MARCHE = [
    { code: 'FRT', label: 'Fournitures' },
    { code: 'TRX', label: 'Travaux' },
    { code: 'SRV', label: 'Services' },
    { code: 'PIS', label: 'Prestations intellectuelles' },
    { code: 'ATR', label: 'Autre' }
];

// ⭐ MODES DE PASSATION — codes courts VARCHAR(5)
window.MODES_PASSATION = [
    { code: 'AON', label: "Appel d'offres national" },
    { code: 'AOI', label: "Appel d'offres international" },
    { code: 'CST', label: 'Consultation' },
    { code: 'GAG', label: 'Gré à gré' },
    { code: 'EDT', label: 'Entente directe' },
    { code: 'ATR', label: 'Autre' }
];

// ─── Helpers globaux ───
window.getStatutLabel = function (code) {
    var s = (window.STATUTS_MARCHE || []).find(function (x) { return String(x.code) === String(code); });
    return s ? s.label : (code || '—');
};

window.getTypeLabel = function (code) {
    var t = (window.TYPES_MARCHE || []).find(function (x) { return String(x.code) === String(code); });
    return t ? t.label : (code || '—');
};

window.getModeLabel = function (code) {
    var m = (window.MODES_PASSATION || []).find(function (x) { return String(x.code) === String(code); });
    return m ? m.label : (code || '—');
};
