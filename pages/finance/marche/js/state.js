// state.js — MARCHE
const AppState = {
    // Liste
    marches: [],
    total: 0,
    page: 1,
    pageSize: DEFAULTS.PAGE_SIZE,
    totalPages: 0,
    filters: { search: '', statut: '', typeMarche: '' },

    // Référentiels
    sites: [],
    fournisseurs: [],
    articles: [],
    monnaies: [],
    plansActifs: [],
    tiers: [],

    // Édition
    editingId: null,
    lignes: [],
    selectedLigneIndex: -1,
    lastLigneSnapshot: null,

    // Caches
    marcheLinesCache: {},
    expandedMarches: {}
};

window.AppState = AppState;
