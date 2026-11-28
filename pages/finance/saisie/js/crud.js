// crud.js — SAISIE (actions CRUD) avec plans dynamiques + équilibre double + dirty tracking
// ⭐ Mise à jour : gestion du champ MARCHE (ecrMarche)
// ⭐ Mise à jour : badge CATEGORIE_JOURNAL + restriction PLAN1 (journal trésorerie)
// ⭐ Mise à jour : rechargement complet de la page après enregistrement + routage SAVE/EDIT
'use strict';
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// ============================================================
// TRACKING DES MODIFICATIONS NON ENREGISTRÉES
// ============================================================
var _isDirty = false;

function markDirty() {
    if (_isDirty) return;
    _isDirty = true;
    var ind = document.getElementById('dirtyIndicator');
    if (ind) ind.style.display = 'inline-flex';
}

function markClean() {
    _isDirty = false;
    var ind = document.getElementById('dirtyIndicator');
    if (ind) ind.style.display = 'none';
}

function hasUnsavedChanges() {
    return _isDirty && AppState && AppState.lignes && AppState.lignes.length > 0;
}

function confirmLeaveEdit() {
    if (!hasUnsavedChanges()) return true;
    return confirm(
        _t('saisie.msg.confirm_leave') ||
        'Quitter sans enregistrer ? Vos modifications seront perdues.'
    );
}

window.addEventListener('beforeunload', function (e) {
    if (hasUnsavedChanges()) {
        e.preventDefault();
        e.returnValue = _t('saisie.msg.unsaved_changes') ||
                        'Vous avez des modifications non enregistrées.';
        return e.returnValue;
    }
});

// ============================================================
// CONVERSIONS LIGNE
// ============================================================
function _serverLigneToClient(l) {
    var ordreToKey = buildOrdreToKeyMap();

    var sens    = l.SENS  || null;
    var montant = parseFloat(l.MONTANT || 0);

    var debit  = (sens === 'D') ? montant : (parseFloat(l.DEBIT  || 0) || 0);
    var credit = (sens === 'C') ? montant : (parseFloat(l.CREDIT || 0) || 0);

    if (!sens) {
        debit  = parseFloat(l.DEBIT  || 0);
        credit = parseFloat(l.CREDIT || 0);
    }

    var out = {
        auxiliaire:   l.AUXILIAIRE || '',
        tiersId:      l.TIERS_ID || null,
        compteIdSUB:  l.SOURCE_FINANCEMENT || '',
        sourceFinancement: l.SOURCE_FINANCEMENT || '',
        mode:         l.MODE_REGULARISATION || '',
        libelle:      l.LIBELLE || '',
        montantRep:   parseFloat(l.MONTANT_DEVISE || 0) || 0,
        coursDevise:  parseFloat(l.COURS_DEVISE || 0) || 0,
        sens:         debit > 0 ? 'D' : 'C',
        debit:        debit,
        credit:       credit,
        echeance:     l.DATE_ECHEANCE || '',
        // ⭐ Récupération de la catégorie historisée
        categorieJournal: (l.CATEGORIE_JOURNAL === 1 || l.CATEGORIE_JOURNAL === 2) ? l.CATEGORIE_JOURNAL : null
    };

    for (var k = 1; k <= 10; k++) {
        var key = ordreToKey[k];
        if (key) {
            out['compteId' + key] = l['PLAN' + k] || null;
        }
    }
    return out;
}

function _clientLigneToPayload(l) {
    var keyToOrdre = buildKeyToOrdreMap();
    var primaire = getPrimaryPlanField();

    // ⭐ Détermination de la catégorie (soit présente sur la ligne, soit via le journal)
    var cat = l.categorieJournal;
    if (cat !== 1 && cat !== 2) {
        if (typeof _resolveCategorieJournal === 'function') {
            cat = _resolveCategorieJournal(_getVal('ecrJournal'));
        }
    }
    if (cat !== 1 && cat !== 2) cat = 1;

    var out = {
        compteId:          primaire ? (l['compteId' + primaire.key] || null) : null,
        comptePlanOrder:   primaire ? primaire.ordre : null,
        tiersId:           l.tiersId || null,
        auxiliaire:        l.auxiliaire || null,
        libelle:           l.libelle || null,
        dateEcheance:      l.echeance || null,
        debit:             l.debit || 0,
        credit:            l.credit || 0,
        montantDevise:     l.montantRep || 0,
        coursDevise:       parseMoneyFR(_getVal('ecrCours')),
        modeRegularisation: l.mode || null,
        sourceFinancement: l.sourceFinancement || l.compteIdSUB || null,
        categorieJournal:  cat // ⭐ Envoi au serveur
    };

    for (var k = 1; k <= 10; k++) {
        var val = null;
        Object.keys(keyToOrdre).forEach(function (key) {
            if (keyToOrdre[key] === k) {
                val = l['compteId' + key] || null;
            }
        });
        out['plan' + k] = val;
    }
    return out;
}

// ============================================================
// HELPER — SITE PAR DÉFAUT
// ============================================================
function _getDefaultSiteId() {
    var sites = AppState.sites || [];
    for (var i = 0; i < sites.length; i++) {
        if (sites[i].EN_COURS === true || sites[i].EN_COURS === 1) return sites[i].ID;
    }
    for (var j = 0; j < sites.length; j++) {
        if (sites[j].CODE === '01') return sites[j].ID;
    }
    return sites.length ? sites[0].ID : '';
}

// ============================================================
// HELPER — SÉLECTION DU MARCHÉ
// ============================================================
function _applyMarcheToSelect(marcheId) {
    var mrcSel = document.getElementById('ecrMarche');
    if (!mrcSel) return;

    mrcSel.value = '';
    if (!marcheId) return;

    mrcSel.value = marcheId;

    if (mrcSel.value !== marcheId) {
        var opt = document.createElement('option');
        opt.value = marcheId;
        opt.textContent = marcheId + ' (' +
            (_t('saisie.hint.marche_orphan') || 'marché supprimé ou annulé') + ')';
        mrcSel.appendChild(opt);
        mrcSel.value = marcheId;
        console.warn('[crud] Marché orphelin référencé :', marcheId);
    }
}

// ============================================================
// HELPERS DE RAFRAÎCHISSEMENT
// ============================================================
function _refreshCategorieBadgeSafe() {
    if (typeof _refreshCategorieJournalDisplay === 'function') {
        try { _refreshCategorieJournalDisplay(); } catch (e) { /* ignore */ }
    }
}

function _refreshPlanRestrictionSafe() {
    if (typeof refreshPlanRestrictionUI === 'function') {
        try { refreshPlanRestrictionUI(); } catch (e) { /* ignore */ }
    }
}

// ============================================================
// NOUVELLE ÉCRITURE
// ============================================================
function newEcriture() {
    AppState.editingId = null;
    AppState.editingJournalId = null;
    AppState.lignes = [];
    AppState.selectedLigneIndex = -1;
    AppState.lettrageSources = [];
    if (typeof setLineEditLocked === 'function') setLineEditLocked(false);

    _setVal('editingId', '');
    _setVal('ecrNumero', '');
    _setVal('ecrDate', '');
    _setVal('ecrExercice', '');
    _setVal('ecrPeriode', '');
    _setVal('ecrDatePiece', '');
    _setVal('ecrReference', '');
    _setVal('ecrReferenceFacture', '');
    _setVal('ecrDateFacture', '');
    _setVal('ecrLibelle', '');
    _setVal('ecrStatut', 'BROUILLON');
    _setVal('ecrCours', '1');

    var mrcSel = document.getElementById('ecrMarche');
    if (mrcSel) mrcSel.value = '';

    var defaultSiteId = _getDefaultSiteId();
    if (defaultSiteId) _setVal('ecrSite', defaultSiteId);

    clearFormLigne();
    renderGrid();
    computeTotaux();
    switchTab('edit');

    if (typeof updateSaveButtonState === 'function') updateSaveButtonState();

    _refreshCategorieBadgeSafe();
    _refreshPlanRestrictionSafe();

    markClean();
}

// ============================================================
// VIDER L'ÉCRITURE
// ============================================================
function clearEcriture() {
    if (AppState.lignes.length && AppState.editingId) {
        Swal.fire({
            icon: 'warning',
            title: _t('saisie.confirm.clear_title') || 'Vider l\'écriture ?',
            text:  _t('saisie.confirm.clear_text')  || 'Toutes les lignes non enregistrées seront perdues.',
            showCancelButton: true,
            confirmButtonText: _t('button.yes') || 'Oui',
            cancelButtonText:  _t('button.cancel') || 'Annuler'
        }).then(function (r) {
            if (r.isConfirmed) newEcriture();
        });
    } else {
        newEcriture();
    }
}

// ============================================================
// CHARGER UNE ÉCRITURE POUR ÉDITION
// ============================================================
async function editEcriture(id) {
    if (hasUnsavedChanges()) {
        if (!confirmLeaveEdit()) return;
    }

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.DETAIL + '?id=' + encodeURIComponent(id);
        var resp = await fetch(url);
        var data = await resp.json();
        if (!data.success) { showErrorToast(data.message); return; }

        var ecr = data.ecriture;
        AppState.editingId = ecr.ID;
        AppState.editingJournalId = String(ecr.JOURNAL_ID || '');
        AppState.selectedLigneIndex = -1;
        AppState.lignes = [];

        _setVal('editingId', ecr.ID);
        _setVal('ecrSite', ecr.SITE_ID || '');
        _setVal('ecrJournal', ecr.JOURNAL_ID);
        _setVal('ecrExercice', ecr.EXERCICE_ID);
        _setVal('ecrDevise', ecr.MONNAIE_ID);
        _setVal('ecrCours', '1');
        _setVal('ecrNumero', ecr.NUMERO);
        _setVal('ecrDate', ecr.DATE_COMPTABLE);
        _setVal('ecrDatePiece', ecr.DATE_PIECE || '');
        _setVal('ecrReference', ecr.REFERENCE || '');
        _setVal('ecrReferenceFacture', ecr.REFERENCE_FACTURE || '');
        _setVal('ecrDateFacture',      ecr.DATE_FACTURE      || '');
        _setVal('ecrLibelle', ecr.LIBELLE);
        _setVal('ecrStatut', ecr.STATUT);

        _applyMarcheToSelect(ecr.MARCHE);

        await loadPeriodes(ecr.EXERCICE_ID);
        _setVal('ecrPeriode', ecr.PERIODE_ID || findPeriodeId(ecr.DATE_COMPTABLE));
        var firstCourseLine = (data.lignes || []).find(function (line) {
            return line.COURS_DEVISE !== null && line.COURS_DEVISE !== undefined;
        });
        if (firstCourseLine) _setVal('ecrCours', firstCourseLine.COURS_DEVISE);

        data.lignes.forEach(function (l) {
            var client = _serverLigneToClient(l);

            getActivePlanFields().forEach(function (plan) {
                var prop = 'compteId' + plan.key;
                client['code' + plan.key] = client[prop]
                    ? findCodeCompteByKey(plan.key, client[prop])
                    : '';
            });

            AppState.lignes.push(client);
        });

        renderGrid();
        if (AppState.lignes.length) {
            selectLigne(0);
        } else {
            clearFormLigne();
            if (typeof setLineEditLocked === 'function') setLineEditLocked(true);
        }
        computeTotaux();

        if (typeof updateSaveButtonState === 'function') updateSaveButtonState();

        switchTab('edit');

        _refreshCategorieBadgeSafe();
        _refreshPlanRestrictionSafe();
        if (typeof _applyJournalPlan1Lock === 'function') {
            _applyJournalPlan1Lock();
        }

        markClean();
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

// ============================================================
// SAUVEGARDER L'ÉCRITURE (CREATE ou UPDATE)
// ============================================================
async function saveEcriture(e) {
    if (e) e.preventDefault();

    var btnSave = document.getElementById('btnSaveEcriture');
    if (btnSave && btnSave.disabled) {
        showToast(
            _t('saisie.msg.cannot_save') || 'Impossible d\'enregistrer',
            _t('saisie.msg.save_disabled') || 'Écriture déséquilibrée ou incomplète',
            'warning', 2500
        );
        return;
    }

    var validation = validateEcriture();
    if (!validation.valid) {
        Swal.fire({
            icon: 'warning',
            title: _t('saisie.msg.validation_error') || 'Erreur de validation',
            html: '<ul style="text-align:left;padding-left:20px;">'
                + validation.errors.map(function (x) { return '<li>' + escapeHtml(x) + '</li>'; }).join('')
                + '</ul>',
            confirmButtonText: _t('button.ok') || 'OK',
            allowOutsideClick: false,
            allowEscapeKey: false
        });
        return;
    }

    var lignesPayload = AppState.lignes.map(_clientLigneToPayload);

    var periodeId = _getVal('ecrPeriode');
    if (!periodeId) {
        periodeId = findPeriodeId(_getVal('ecrDate'));
        _setVal('ecrPeriode', periodeId);
    }

    var libelleFinal = _getVal('ecrLibelle').trim();
    if (!libelleFinal) {
        if (lignesPayload.length && lignesPayload[0].libelle) {
            libelleFinal = lignesPayload[0].libelle;
        } else if (_getVal('ecrReference').trim()) {
            libelleFinal = _getVal('ecrReference').trim();
        } else {
            libelleFinal = 'Écriture du ' + _getVal('ecrDate');
        }
        _setVal('ecrLibelle', libelleFinal);
    }

    var numeroFinal = _getVal('ecrNumero').trim();
    if (!numeroFinal && _getVal('ecrJournal')) {
        await loadNextNumero();
        numeroFinal = _getVal('ecrNumero').trim();
    }

    var siteId = _getVal('ecrSite') || _getDefaultSiteId() || null;

    var payload = {
        id:               AppState.editingId,
        siteId:           siteId,
        exerciceId:       _getVal('ecrExercice'),
        periodeId:        periodeId,
        journalId:        _getVal('ecrJournal'),
        monnaieId:        _getVal('ecrDevise'),
        coursDevise:      parseMoneyFR(_getVal('ecrCours')),
        numero:           numeroFinal,
        dateComptable:    _getVal('ecrDate'),
        datePiece:        _getVal('ecrDatePiece'),
        reference:        _getVal('ecrReference').trim(),
        referenceFacture: _getVal('ecrReferenceFacture').trim(),
        dateFacture:      _getVal('ecrDateFacture') || null,
        libelle:          libelleFinal,
        statut:           _getVal('ecrStatut'),
        marche:           _getVal('ecrMarche') || null,
        lignes:           lignesPayload,
        lettrageSources:  AppState.lettrageSources || []
    };

    if (btnSave) btnSave.disabled = true;

    try {
        showSpinner();

        // ⭐ Routage dynamique SAVE vs EDIT
        var endpoint = AppState.editingId ? API.EDIT : API.SAVE;
        var url = API.BASE + API.HANDLERS_PATH + endpoint;

        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        var result = await resp.json();

        if (result.success) {
            showSuccessToast(result.message || (AppState.editingId ? 'Écriture modifiée' : 'Écriture enregistrée'));

            // ⭐ Marquer clean AVANT le reload pour désactiver beforeunload
            markClean();

            // ⭐ Rechargement complet de la page après 800 ms
            setTimeout(function () {
                window.location.reload();
            }, 800);
            return;
        } else {
            var errorMessage = result.message || _t('message.error') || 'Erreur';
            if (result.code === 'DATE_PIECE_AFTER_COMPTABLE'
                && typeof showDatePieceOrderAlert === 'function') {
                showDatePieceOrderAlert();
            } else if (/exercice introuvable ou fermé/i.test(errorMessage)
                && typeof showExerciceUnavailableAlert === 'function') {
                showExerciceUnavailableAlert();
            } else {
                showErrorToast(errorMessage);
            }
            if (btnSave) btnSave.disabled = false;
        }
    } catch (err) {
        showErrorToast(err.message);
        if (btnSave) btnSave.disabled = false;
    } finally {
        hideSpinner();
        if (typeof updateSaveButtonState === 'function') updateSaveButtonState();
    }
}

// ============================================================
// SUPPRIMER
// ============================================================
function deleteCurrentEcriture() {
    if (!AppState.editingId) {
        showErrorToast(_t('saisie.msg.no_ecriture_loaded') || 'Aucune écriture chargée.');
        return;
    }
    deleteEcriture(AppState.editingId);
}

async function deleteEcriture(id) {
    var ecr = (AppState.ecritures || []).find(function (x) { return x.ID === id; });
    var num = ecr ? (ecr.REFERENCE || ecr.NUMERO || '') : '';

    var conf = await Swal.fire({
        icon: 'warning',
        title: _t('saisie.confirm.delete_title') || 'Supprimer l\'écriture ?',
        html: (_t('saisie.confirm.delete_text') || 'L\'écriture <strong>{num}</strong> sera définitivement supprimée.')
            .replace('{num}', escapeHtml(num)),
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#6c757d',
        confirmButtonText: _t('saisie.confirm.delete_yes') || 'Oui, supprimer',
        cancelButtonText:  _t('button.cancel') || 'Annuler'
    });
    if (!conf.isConfirmed) return;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.DELETE;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id })
        });
        var result = await resp.json();

        if (result.success) {
            showSuccessToast(result.message || _t('saisie.msg.delete_ok') || 'Écriture supprimée');

            markClean();

            AppState.editingId = null;
            AppState.lignes = [];
            newEcriture();
        } else {
            showErrorToast(result.message || _t('message.error') || 'Erreur');
        }
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

// ============================================================
// NUMÉRO AUTO
// ============================================================
async function loadNextNumero() {
    var journalId = _getVal('ecrJournal');
    if (!journalId) { _setVal('ecrNumero', ''); return; }
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.NEXT_NUMERO + '?journalId=' + encodeURIComponent(journalId);
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) _setVal('ecrNumero', data.numero || '');
    } catch (err) { console.error('[loadNextNumero]', err); }
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.newEcriture           = newEcriture;
window.clearEcriture         = clearEcriture;
window.editEcriture          = editEcriture;
window.saveEcriture          = saveEcriture;
window.deleteEcriture        = deleteEcriture;
window.deleteCurrentEcriture = deleteCurrentEcriture;
window.loadNextNumero        = loadNextNumero;
window._getDefaultSiteId     = _getDefaultSiteId;
window._applyMarcheToSelect  = _applyMarcheToSelect;
window._serverLigneToClient  = _serverLigneToClient;
window._clientLigneToPayload = _clientLigneToPayload;

window.markDirty            = markDirty;
window.markClean            = markClean;
window.hasUnsavedChanges    = hasUnsavedChanges;
window.confirmLeaveEdit     = confirmLeaveEdit;
