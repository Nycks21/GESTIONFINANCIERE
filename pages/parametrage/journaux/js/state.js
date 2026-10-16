// state.js — JOURNAUX
const AppState = {
    journaux: [],
    total: 0,
    page: 1,
    pageSize: DEFAULTS.PAGE_SIZE,
    totalPages: 0,
    sortField: DEFAULTS.SORT_FIELD,
    sortOrder: DEFAULTS.SORT_ORDER,
    filters: {
        search: '',
        type: '',
        categorie: '',   // 🆕
        status: '',
        siteId: ''
    },
    sites: [],
    monnaies: [],
    comptesBanque: [],
    editingId: null
};

window.AppState = AppState;
window.updateState = function (n) { Object.assign(AppState, n || {}); };
