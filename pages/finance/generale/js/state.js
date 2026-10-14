// state.js — GÉNÉRALE
const AppState = {
    sections: [],
    plans: [],
    planTypes: [],
    editingPlanOrdre: null    // ← ORDRE (1..10) au lieu d'un GUID
};

window.AppState = AppState;
window.updateState = function (n) { Object.assign(AppState, n || {}); };
