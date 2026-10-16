// config.js — JOURNAUX
window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/parametrage/journaux/handlers/',
    LIST:     'GetJournaux.ashx',
    ADD:      'JournalAdd.ashx',
    EDIT:     'JournalEdit.ashx',
    DELETE:   'JournalDelete.ashx',
    STATS:    'GetJournauxStats.ashx',
    LOOKUPS:  'GetJournauxLookups.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'CODE',
    SORT_ORDER: 'ASC'
};

// Types de journaux (miroir du CHECK SQL)
window.JOURNAL_TYPES = [
    { code: 'ACHATS',              label: 'journaux.type.achats' },
    { code: 'VENTES',              label: 'journaux.type.ventes' },
    { code: 'BANQUE',              label: 'journaux.type.banque' },
    { code: 'CAISSE',              label: 'journaux.type.caisse' },
    { code: 'OPERATIONS_DIVERSES', label: 'journaux.type.operations_diverses' },
    { code: 'GENERAL',             label: 'journaux.type.general' }
];
