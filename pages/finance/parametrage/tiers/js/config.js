// config.js — TIERS
window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/finance/parametrage/tiers/handlers/',
    LIST:    'GetTiers.ashx',
    ADD:     'TiersAdd.ashx',
    EDIT:    'TiersEdit.ashx',
    DELETE:  'TiersDelete.ashx',
    STATS:   'GetTiersStats.ashx',
    LOOKUPS: 'GetTiersLookups.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'CODE',
    SORT_ORDER: 'ASC'
};

window.TIERS_TYPES = [
    { code: 'FOURNISSEUR', label: 'tiers.type.fournisseur' },
    { code: 'CLIENT',      label: 'tiers.type.client' },
    { code: 'AGENT',       label: 'tiers.type.agent' },
    { code: 'PARTENAIRE',  label: 'tiers.type.partenaire' },
    { code: 'AUTRE',       label: 'tiers.type.autre' }
];
