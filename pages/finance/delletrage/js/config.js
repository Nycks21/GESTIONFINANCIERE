// config.js — DÉLETTRAGE
window.API = {
  BASE: window.BASE_PATH || "/",

  HANDLERS_PATH: "pages/finance/delletrage/handlers/",
  SHARED_HANDLERS_PATH: "pages/finance/saisie/handlers/",

  COMPTES_BY_PLAN:  "GetComptesByPlan.ashx",
  LOOKUPS:          "GetSaisieLookups.ashx",   // ⭐ AJOUT pour la liste des tiers
  LIGNES_DELETTRAGE:"GetLignesDelletrage.ashx",
  SAVE_DELETTRAGE:  "SaveDelletrage.ashx"
};

window.DEFAULTS = {
  PAGE_SIZE: 50
};

console.log('[config-delletrage] Chargé — handlers :', window.API.HANDLERS_PATH);
