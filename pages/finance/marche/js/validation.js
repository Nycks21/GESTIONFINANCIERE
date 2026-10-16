// validation.js — MARCHE (règles métier + bouton Enregistrer)
'use strict';
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

function updateSaveButtonState() {
    var btn = document.getElementById('btnSaveMarche');
    if (!btn) return;

    var hasLignes = (AppState.lignes && AppState.lignes.length > 0);
    var canSave = hasLignes;

    btn.disabled = !canSave;
    btn.title = canSave
        ? _t('marche.action.save_marche') || 'Enregistrer le marché'
        : _t('marche.msg.no_lignes') || 'Aucune ligne';
}

function validateMarche() {
    var errors = [];

    var numero = (_getVal('marNumeroInput') || '').trim();
    if (!numero) errors.push(_t('marche.msg.numero_required') || 'Le numéro est obligatoire.');

    var fournisseur = _getVal('marFournisseur');
    if (!fournisseur) errors.push(_t('marche.msg.fournisseur_required') || 'Le fournisseur est obligatoire.');

    if (!AppState.lignes.length) {
        errors.push(_t('marche.msg.no_lignes') || 'Au moins une ligne est requise.');
    }

    return { valid: errors.length === 0, errors: errors };
}

window.validateMarche        = validateMarche;
window.updateSaveButtonState = updateSaveButtonState;
