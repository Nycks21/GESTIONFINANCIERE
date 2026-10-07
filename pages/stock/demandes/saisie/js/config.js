window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: '',  // vide car les chemins sont complets
    LIST: 'pages/stock/demandes/saisie/handlers/GetDemandes.ashx',
    STATS: 'pages/stock/demandes/saisie/handlers/GetDemandesStats.ashx',
    ADD: 'pages/stock/modules/sorties/handlers/SortieAdd.ashx',
    EDIT: 'pages/stock/modules/sorties/handlers/SortieEdit.ashx',
    DELETE: 'pages/stock/modules/sorties/handlers/SortieDelete.ashx',
    ARTICLES: '../../../modules/sorties/handlers/GetArticles.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'DATE_SORTIE',
    SORT_ORDER: 'DESC'
};

