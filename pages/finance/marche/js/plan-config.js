// plan-config.js — Configuration DYNAMIQUE des plans (pilote toute l'UI)
'use strict';

// ============================================================
// RETOURNE LA LISTE DES PLANS ACTIFS, ORDONNÉE PAR ORDRE
//
//   Aucune config en dur : on se base UNIQUEMENT sur AppState.plansActifs
//   (déjà filtré ACTIVE=1 côté serveur par GetSaisieLookups.ashx).
//
//   Chaque plan → {
//     key       : 'P1', 'P2', ...   (stable, basé sur ORDRE)
//     ordre     : 1..10             (position dans FPLAN_HEADER)
//     typeCode  : 'COMPTABLE', 'ANALYTIQUE', ...
//     label     : CODE (fallback NOM) → affiché à l'utilisateur
//     nom       : NOM  (fallback CODE) → info secondaire
//     isPrimary : true si PLAN_TYPE_CODE = 'COMPTABLE'
//     selectId  : 'flP1'            (ID du <select>)
//     wrapperId : 'wrapP1'          (ID du conteneur .eb-field)
//   }
// ============================================================
function getActivePlanFields() {
    var plans = (typeof AppState !== 'undefined' && AppState.plansActifs)
                ? AppState.plansActifs
                : [];

    var result = [];

    plans.forEach(function (p) {
        var ordre = parseInt(p.ORDRE, 10);
        if (isNaN(ordre) || ordre < 1 || ordre > 10) return;

        var typeCode = (p.PLAN_TYPE_CODE || '').toString().toUpperCase();
        var code     = (p.CODE || '').toString().trim();
        var nom      = (p.NOM  || '').toString().trim();
        var key      = 'P' + ordre;

        result.push({
            key:       key,
            ordre:     ordre,
            typeCode:  typeCode,
            label:     code || nom || ('Plan ' + ordre),
            nom:       nom  || code || '',
            isPrimary: typeCode === 'COMPTABLE',
            selectId:  'fl' + key,
            wrapperId: 'wrap' + key
        });
    });

    result.sort(function (a, b) { return a.ordre - b.ordre; });
    return result;
}

// ============================================================
// HELPERS DE RECHERCHE
// ============================================================
function getPlanFieldByKey(key) {
    var a = getActivePlanFields();
    for (var i = 0; i < a.length; i++) if (a[i].key === key) return a[i];
    return null;
}

function getPlanFieldByTypeCode(typeCode) {
    var a = getActivePlanFields();
    var tc = (typeCode || '').toUpperCase();
    for (var i = 0; i < a.length; i++) if (a[i].typeCode === tc) return a[i];
    return null;
}

function getPrimaryPlanField() {
    var a = getActivePlanFields();
    for (var i = 0; i < a.length; i++) if (a[i].isPrimary) return a[i];
    return a[0] || null;
}

// ============================================================
// MAPPINGS
// ============================================================
function buildKeyToOrdreMap() {
    var map = {};
    getActivePlanFields().forEach(function (f) { map[f.key] = f.ordre; });
    return map;
}

function buildOrdreToKeyMap() {
    var map = {};
    getActivePlanFields().forEach(function (f) { map[f.ordre] = f.key; });
    return map;
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.getActivePlanFields     = getActivePlanFields;
window.getPlanFieldByKey       = getPlanFieldByKey;
window.getPlanFieldByTypeCode  = getPlanFieldByTypeCode;
window.getPrimaryPlanField     = getPrimaryPlanField;
window.buildKeyToOrdreMap      = buildKeyToOrdreMap;
window.buildOrdreToKeyMap      = buildOrdreToKeyMap;

console.log('[plan-config] Module chargé (mode dynamique).');
