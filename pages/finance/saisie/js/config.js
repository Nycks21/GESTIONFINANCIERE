// config.js — SAISIE
window.API = {
  BASE: window.BASE_PATH || "/",
  HANDLERS_PATH: "pages/finance/saisie/handlers/",
  LOOKUPS: "GetSaisieLookups.ashx",
  LIST: "GetEcritures.ashx",
  DETAIL: "GetEcritureDetail.ashx",
  SAVE: "EcritureSave.ashx",
  VALIDER: "EcritureValider.ashx",
  DELETE: "EcritureDelete.ashx",
  NEXT_NUMERO: "GetNextNumero.ashx",
  COMPTES_BY_PLAN: "GetComptesByPlan.ashx",
  MARCHES: "GetMarche.ashx",
  PERIODES: "GetExercicesPeriodes.ashx",
  BALANCE: "GetBalanceGenerale.ashx",
  BALANCE_AUXILIAIRE: "GetBalanceAuxiliaire.ashx"
};

window.DEFAULTS = {
  PAGE_SIZE: 20,
  SORT_FIELD: "DATE_COMPTABLE",
  SORT_ORDER: "DESC",
};

// Mapping fixe des colonnes de grille → clés des plans
window.GRID_PLANS = [
  { key: "PCG", sql: "PLAN1", label: "PCG", type: "COMPTABLE" },
  { key: "PCOP", sql: "PLAN2", label: "PCOP", type: null },
  { key: "FIN", sql: "PLAN3", label: "Fin", type: null },
  { key: "CAT", sql: "PLAN4", label: "Catégorie", type: null },
  { key: "ACTI", sql: "PLAN5", label: "ACTI", type: null },
  { key: "REG", sql: "PLAN6", label: "REG", type: null },
  { key: "SUB", sql: "PLAN7", label: "Subvention", type: null },
];

window.STATUTS = [
  { code: "BROUILLON", label: "Brouillon" },
  { code: "A_VALIDER", label: "À valider" },
  { code: "VALIDEE", label: "Validée" },
  { code: "COMPTABILISEE", label: "Comptabilisée" },
  { code: "ANNULEE", label: "Annulée" },
];
