// state.js — ÉLÉMENTS DE PLAN
const AppState = {
    planOrder: null,      // ← ORDRE (1..10) — lu depuis ?planOrder=X
    plan: null,
    elements: [],
    currentLevel: 1,
    filters: { search: '', active: '' },
    editingId: null
};

window.AppState = AppState;
window.updateState = function (n) { Object.assign(AppState, n || {}); };
