// config.js — MARCHE
window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/finance/marche/handlers/',
    LOOKUPS:        'GetMarcheLookups.ashx',
    LIST:           'GetMarches.ashx',
    DETAIL:         'GetMarcheDetail.ashx',
    SAVE:           'MarcheSave.ashx',
    DELETE:         'MarcheDelete.ashx',
    NEXT_NUMERO:    'GetNextNumeroMarche.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 20,
    SORT_FIELD: 'DATE_SIGNATURE',
    SORT_ORDER: 'DESC'
};

window.STATUTS_MARCHE = [
    { code: 'ATTRIBUE',     label: 'Attribué' },
    { code: 'EN_EXECUTION', label: 'En exécution' },
    { code: 'TERMINE',      label: 'Terminé' },
    { code: 'ANNULE',       label: 'Annulé' },
    { code: 'RESILIE',      label: 'Résilié' }
];
