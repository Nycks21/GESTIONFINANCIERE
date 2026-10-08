// config.js — EXERCICES
window.API = {
    BASE: window.BASE_PATH || '/',
    HANDLERS_PATH: 'pages/finance/parametrage/exercices/handlers/',
    LIST:     'GetExercices.ashx',
    ADD:      'ExerciceAdd.ashx',
    EDIT:     'ExerciceEdit.ashx',
    DELETE:   'ExerciceDelete.ashx',
    STATS:    'GetExercicesStats.ashx',
    CLOTURER: 'ExerciceCloturer.ashx',
    REOUVRIR: 'ExerciceReouvrir.ashx'
};

window.DEFAULTS = {
    PAGE_SIZE: 10,
    SORT_FIELD: 'DATE_DEBUT',
    SORT_ORDER: 'DESC'
};
