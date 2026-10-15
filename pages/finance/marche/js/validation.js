// validation.js — SAISIE (règles métier + équilibre double + bouton Enregistrer)
'use strict';
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// Précision monétaire (2 décimales)
var MONEY_EPSILON = 0.005;   // tolérance pour arrondir à 2 décimales

// ============================================================
// ARRONDI MONÉTAIRE SÛR
// ============================================================
function _roundMoney(v) {
    if (typeof v !== 'number' || isNaN(v)) return 0;
    return Math.round(v * 100) / 100;
}

// ============================================================
// VÉRIFICATION DE L'ÉQUILIBRE DOUBLE
//   - Colonne MONTANT       (montant local = debit/credit)
//   - Colonne MONTANT_DEVISE (montant référence = montantRep)
// ============================================================
function checkEquilibre() {
    var totalDebitMontant  = 0;
    var totalCreditMontant = 0;
    var totalDebitDevise   = 0;
    var totalCreditDevise  = 0;

    var lignes = (AppState && AppState.lignes) ? AppState.lignes : [];

    lignes.forEach(function (l) {
        var debit       = parseFloat(l.debit  || 0) || 0;
        var credit      = parseFloat(l.credit || 0) || 0;
        var montantRep  = parseFloat(l.montantRep || 0) || 0;

        // Colonne MONTANT
        totalDebitMontant  += debit;
        totalCreditMontant += credit;

        // Colonne MONTANT_DEVISE (dépend du sens)
        if (l.sens === 'D')      totalDebitDevise  += montantRep;
        else if (l.sens === 'C') totalCreditDevise += montantRep;
    });

    // Arrondi monétaire
    totalDebitMontant  = _roundMoney(totalDebitMontant);
    totalCreditMontant = _roundMoney(totalCreditMontant);
    totalDebitDevise   = _roundMoney(totalDebitDevise);
    totalCreditDevise  = _roundMoney(totalCreditDevise);

    var ecartMontant = _roundMoney(totalDebitMontant - totalCreditMontant);
    var ecartDevise  = _roundMoney(totalDebitDevise  - totalCreditDevise);

    var balancedMontant = Math.abs(ecartMontant) < MONEY_EPSILON;
    var balancedDevise  = Math.abs(ecartDevise)  < MONEY_EPSILON;

    return {
        totalDebitMontant:  totalDebitMontant,
        totalCreditMontant: totalCreditMontant,
        totalDebitDevise:   totalDebitDevise,
        totalCreditDevise:  totalCreditDevise,
        ecartMontant:       ecartMontant,
        ecartDevise:        ecartDevise,
        balancedMontant:    balancedMontant,
        balancedDevise:     balancedDevise,
        balanced:           balancedMontant && balancedDevise
    };
}

// ============================================================
// MISE À JOUR DE L'ÉTAT DU BOUTON ENREGISTRER
// ============================================================
function updateSaveButtonState() {
    var btn = document.getElementById('btnSaveEcriture');
    if (!btn) return;

    var eq = checkEquilibre();

    // Le bouton n'est actif QUE si les deux colonnes sont équilibrées
    // ET s'il y a au moins une ligne
    var hasLignes = (AppState.lignes && AppState.lignes.length > 0);
    var canSave = eq.balanced && hasLignes;

    btn.disabled = !canSave;

    // Indicateur visuel (title dynamique)
    if (canSave) {
        btn.title = _t('saisie.action.save_ecriture');
    } else if (!hasLignes) {
        btn.title = _t('saisie.msg.no_lignes') || 'Aucune ligne';
    } else if (!eq.balancedMontant && !eq.balancedDevise) {
        btn.title = (_t('saisie.msg.not_balanced_both') ||
            'Écriture déséquilibrée (MONTANT et MONTANT_DEVISE)');
    } else if (!eq.balancedMontant) {
        btn.title = (_t('saisie.msg.not_balanced_montant') ||
            'Écart MONTANT : {ecart}')
            .replace('{ecart}', formatMontant(eq.ecartMontant));
    } else if (!eq.balancedDevise) {
        btn.title = (_t('saisie.msg.not_balanced_devise') ||
            'Écart MONTANT_DEVISE : {ecart}')
            .replace('{ecart}', formatMontant(eq.ecartDevise));
    }

    // Log discret pour debug
    console.log('[équilibre] MONTANT:', eq.totalDebitMontant, '=', eq.totalCreditMontant,
                '(' + (eq.balancedMontant ? 'OK' : 'ÉCART ' + eq.ecartMontant) + ')',
                '| DEVISE:', eq.totalDebitDevise, '=', eq.totalCreditDevise,
                '(' + (eq.balancedDevise ? 'OK' : 'ÉCART ' + eq.ecartDevise) + ')',
                '→ bouton', canSave ? 'ACTIF' : 'désactivé');
}

// ============================================================
// VALIDATION COMPLÈTE (appelée avant sauvegarde)
// ============================================================
function validateEcriture() {
    var errors = [];

    var date     = _getVal('ecrDate');
    var journal  = _getVal('ecrJournal');
    var exercice = _getVal('ecrExercice');
    var devise   = _getVal('ecrDevise');

    if (!date)     errors.push(_t('saisie.msg.date_required')     || 'La date comptable est obligatoire.');
    if (!journal)  errors.push(_t('saisie.msg.journal_required')  || 'Le journal est obligatoire.');
    if (!exercice) errors.push(_t('saisie.msg.exercice_required') || 'L\'exercice est obligatoire.');
    if (!devise)   errors.push(_t('saisie.msg.devise_required')   || 'La devise est obligatoire.');

    if (date && exercice && !findPeriodeId(date)) {
        errors.push(_t('saisie.msg.no_period') || 'Aucune période ouverte ne correspond à cette date.');
    }

    if (!AppState.lignes.length) {
        errors.push(_t('saisie.msg.no_lignes') || 'Au moins une ligne est requise.');
    }

    // ⭐ Équilibre double (MONTANT + MONTANT_DEVISE)
    var eq = checkEquilibre();

    if (!eq.balancedMontant) {
        errors.push(
            (_t('saisie.msg.not_balanced_montant') || 'Écart MONTANT : {ecart}')
                .replace('{ecart}', formatMontant(eq.ecartMontant))
        );
    }
    if (!eq.balancedDevise) {
        errors.push(
            (_t('saisie.msg.not_balanced_devise') || 'Écart MONTANT_DEVISE : {ecart}')
                .replace('{ecart}', formatMontant(eq.ecartDevise))
        );
    }

    return { valid: errors.length === 0, errors: errors, equilibre: eq };
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.validateEcriture      = validateEcriture;
window.checkEquilibre        = checkEquilibre;
window.updateSaveButtonState = updateSaveButtonState;
window._roundMoney           = _roundMoney;
