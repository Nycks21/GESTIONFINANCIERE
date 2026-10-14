// state.js — SAISIE
const AppState = {
    // Liste
    ecritures: [],
    total: 0,
    page: 1,
    pageSize: DEFAULTS.PAGE_SIZE,
    totalPages: 0,
    filters: {
        search: '',
        journalId: '',
        statut: ''
    },

    // Référentiels
    sites: [],
    journaux: [],
    exercices: [],
    monnaies: [],
    periodes: [],
    modes: [],         // modes de régularisation (depuis FPARAMETRE)
    plansActifs: [],
    comptesParPlan: {},   // { 1: [...], 2: [...] }

    // Édition
    editingId: null,
    lignes: [],           // Lignes en mémoire
    selectedLigneIndex: -1,

    // Pour undo
    lastLigneSnapshot: null
};

window.AppState = AppState;
