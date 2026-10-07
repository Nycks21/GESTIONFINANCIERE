// config.js – Module MONNAIES
window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/finance/parametrage/monnaies/handlers/',
    LIST: 'GetMonnaies.ashx',
    ADD: 'MonnaieAdd.ashx',
    EDIT: 'MonnaieEdit.ashx',
    DELETE: 'MonnaieDelete.ashx',
    STATS: 'GetMonnaieStats.ashx',
    CHECK_CODE: 'GetMonnaieByCode.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'CODE',
    SORT_ORDER: 'ASC'
};
