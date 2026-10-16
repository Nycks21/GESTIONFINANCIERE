// totaux.js — MARCHE (calcul des totaux HT/TVA/TTC locaux et rapprochement)
'use strict';

function computeTotaux() {
    var totLocHT = 0, totLocTVA = 0, totLocTTC = 0;
    var totRapHT = 0, totRapTVA = 0, totRapTTC = 0;

    (AppState.lignes || []).forEach(function (l) {
        totLocHT  += (l.montantLocHT  || 0);
        totLocTVA += (l.montantLocTVA || 0);
        totLocTTC += (l.montantLocTTC || 0);
        totRapHT  += (l.montantRapHT  || 0);
        totRapTVA += (l.montantRapTVA || 0);
        totRapTTC += (l.montantRapTTC || 0);
    });

    _setText('ttLocHT',  formatMontant(totLocHT));
    _setText('ttLocTVA', formatMontant(totLocTVA));
    _setText('ttLocTTC', formatMontant(totLocTTC));
    _setText('ttRapHT',  formatMontant(totRapHT));
    _setText('ttRapTVA', formatMontant(totRapTVA));
    _setText('ttRapTTC', formatMontant(totRapTTC));

    if (typeof updateSaveButtonState === 'function') updateSaveButtonState();

    return {
        totLocHT: totLocHT, totLocTVA: totLocTVA, totLocTTC: totLocTTC,
        totRapHT: totRapHT, totRapTVA: totRapTVA, totRapTTC: totRapTTC
    };
}

window.computeTotaux = computeTotaux;
