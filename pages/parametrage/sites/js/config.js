// config.js
window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/parametrage/sites/handlers/',
    LIST: 'GetSites.ashx',
    ADD: 'SiteAdd.ashx',
    EDIT: 'SiteEdit.ashx',
    DELETE: 'SiteDelete.ashx',
    STATS: 'GetSiteStats.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'CODE',
    SORT_ORDER: 'ASC'
};
