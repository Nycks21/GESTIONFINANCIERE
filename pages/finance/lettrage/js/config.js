// config.js — LETTRAGE
window.API = {
  BASE: window.BASE_PATH || "/",

  HANDLERS_PATH: "pages/finance/lettrage/handlers/",
  SHARED_HANDLERS_PATH: "pages/finance/saisie/handlers/",

  COMPTES_BY_PLAN:  "GetComptesByPlan.ashx",
  LOOKUPS:          "GetSaisieLookups.ashx",   // ⭐ AJOUT pour la liste des tiers
  LIGNES_LETTRAGE:  "GetLignesLettrage.ashx",
  SAVE_LETTRAGE:    "SaveLettrage.ashx"
};

window.DEFAULTS = {
  PAGE_SIZE: 50
};

console.log('[config-lettrage] Chargé — handlers :', window.API.HANDLERS_PATH);
