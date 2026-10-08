// config.js — TAUX
window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/finance/parametrage/taux/handlers/',
    LIST: 'GetTaux.ashx',
    ADD: 'TauxAdd.ashx',
    EDIT: 'TauxEdit.ashx',
    DELETE: 'TauxDelete.ashx',
    STATS: 'GetTauxStats.ashx',
    MONNAIES: 'GetMonnaies.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'DATE_EFFET',
    SORT_ORDER: 'DESC'
};
