// config.js — GÉNÉRALE
window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/finance/generale/handlers/',

    SECTIONS:         'GetSections.ashx',
    PLANS_LIST:       'GetPlansComptables.ashx',
    PLANS_SAVE:       'PlanComptableSave.ashx',
    PLANS_TOGGLE:     'PlanComptableToggle.ashx',
    PLANS_DELETE:     'PlanComptableDelete.ashx',

    ELEMENTS_LIST:    'GetPlanElements.ashx',
    ELEMENTS_SAVE:    'PlanElementSave.ashx',
    ELEMENTS_DELETE:  'PlanElementDelete.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'ORDRE',
    SORT_ORDER: 'ASC'
};

window.HUB_SECTIONS = [
    {
        code: 'COMPTABILITE',
        nom: 'Comptabilité',
        icone: 'fas fa-calculator',
        ordre: 1,
        cards: [
            { code: 'plans',     nom: 'Plans Comptables',  icone: 'fas fa-book',        description: 'Configurer jusqu\'à 10 plans comptables', action: 'modal', modal: 'plansModal' },
            { code: 'exercices', nom: 'Exercices',         icone: 'fas fa-calendar-alt', description: 'Gérer les exercices comptables',         action: 'link', href: '../parametrage/exercices/exercices.aspx' },
            { code: 'journaux',  nom: 'Journaux',          icone: 'fas fa-book-open',    description: 'Journaux comptables',          action: 'link', href: '../parametrage/journaux/journaux.aspx' }
        ]
    },
    {
        code: 'REFERENTIELS',
        nom: 'Référentiels',
        icone: 'fas fa-database',
        ordre: 2,
        cards: [
            { code: 'monnaies',  nom: 'Monnaies',       icone: 'fas fa-coins',           description: 'Gérer les devises',              action: 'link', href: '../parametrage/monnaies/monnaies.aspx' },
            { code: 'sites',     nom: 'Sites',          icone: 'fas fa-map-marker-alt',  description: 'Gérer les sites / agences',      action: 'link', href: '../parametrage/sites/sites.aspx' },
            { code: 'taux',      nom: 'Taux de change', icone: 'fas fa-exchange-alt',    description: 'Historique des taux',            action: 'link', href: '../parametrage/taux/taux.aspx' },
            { code: 'tiers',     nom: 'Tiers',          icone: 'fas fa-users',           description: 'Clients, fournisseurs',          action: 'link', href: '../parametrage/tiers/tiers.aspx' }
        ]
    }
];
