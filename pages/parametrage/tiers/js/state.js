// state.js — TIERS
const AppState = {
    tiers: [],
    total: 0,
    page: 1,
    pageSize: DEFAULTS.PAGE_SIZE,
    totalPages: 0,
    sortField: DEFAULTS.SORT_FIELD,
    sortOrder: DEFAULTS.SORT_ORDER,
    filters: {
        search: '',
        type: '',
        compteId: '',
        planOrder: '',     // 🆕 filtre par plan
        status: ''
    },
    // Référentiels
    comptesAuxiliaires: [],   // { ID, CODE, LIBELLE, NIVEAU, PLAN_ORDER, PLAN_CODE, PLAN_NOM }
    editingId: null
};

window.AppState = AppState;
window.updateState = function (n) { Object.assign(AppState, n || {}); };
