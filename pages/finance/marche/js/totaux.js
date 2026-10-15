// totaux.js — Calcul temps réel des totaux
'use strict';

function computeTotaux() {
    var debitLocal = 0, creditLocal = 0;
    var debitRep = 0, creditRep = 0;

    (AppState.lignes || []).forEach(function (l) {
        debitLocal  += (l.debit  || 0);
        creditLocal += (l.credit || 0);
        if (l.sens === 'D') debitRep  += (l.montantRep || 0);
        if (l.sens === 'C') creditRep += (l.montantRep || 0);
    });

    _setText('ttDebitLocal',  formatMontant(debitLocal));
    _setText('ttCreditLocal', formatMontant(creditLocal));
    _setText('ttSolde',       formatMontant(debitLocal - creditLocal));
    _setText('ttDebitRep',    formatMontant(debitRep));
    _setText('ttCreditRep',   formatMontant(creditRep));

    if (typeof updateSaveButtonState === 'function') {
        updateSaveButtonState();
    }

    return {
        debitLocal: debitLocal, creditLocal: creditLocal,
        debitRep: debitRep, creditRep: creditRep,
        ecart: debitLocal - creditLocal
    };
}

window.computeTotaux = computeTotaux;
