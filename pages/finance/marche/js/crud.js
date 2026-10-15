// crud.js — SAISIE (actions CRUD) avec plans dynamiques + équilibre double + dirty tracking
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

// Serveur (PLAN1..PLAN10 + SENS/MONTANT) → Client (compteIdPn + debit/credit)
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
        compteIdSUB:  null,
        mode:         l.SOURCE_FINANCEMENT || '',
        libelle:      l.LIBELLE || '',
        montantRep:   parseFloat(l.MONTANT_DEVISE || 0) || 0,
        sens:         debit > 0 ? 'D' : 'C',
        debit:        debit,
        credit:       credit,
        echeance:     l.DATE_ECHEANCE || ''
    };

    for (var k = 1; k <= 10; k++) {
        var key = ordreToKey[k];
        if (key) {
            out['compteId' + key] = l['PLAN' + k] || null;
        }
    }
    return out;
}

// ============================================================
// CONVERSION LIGNE → PAYLOAD (client → serveur)
// ============================================================
function _clientLigneToPayload(l) {
    var keyToOrdre = buildKeyToOrdreMap();
    var primaire = getPrimaryPlanField();

    var out = {
        compteId:          primaire ? (l['compteId' + primaire.key] || null) : null,
        comptePlanOrder:   primaire ? primaire.ordre : null,
        tiersId:           l.tiersId || null,
        auxiliaire:        l.auxiliaire || null,
        libelle:           l.libelle || null,
        debit:             l.debit || 0,
        credit:            l.credit || 0,
        montantDevise:     l.montantRep || 0,
        sourceFinancement: l.mode || null
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
// NOUVELLE ÉCRITURE
// ============================================================
function newEcriture() {
    AppState.editingId = null;
    AppState.lignes = [];
    AppState.selectedLigneIndex = -1;

    _setVal('editingId', '');
    _setVal('ecrNumero', '');
    _setVal('ecrDate', new Date().toISOString().slice(0, 10));
    _setVal('ecrDatePiece', '');
    _setVal('ecrReference', '');
    // ⭐ NOUVEAUX CHAMPS
    _setVal('ecrReferenceFacture', '');
    _setVal('ecrDateFacture', '');
    _setVal('ecrLibelle', '');
    _setVal('ecrStatut', 'BROUILLON');
    _setVal('ecrCours', '1');

    var defaultSiteId = _getDefaultSiteId();
    if (defaultSiteId) _setVal('ecrSite', defaultSiteId);

    _setVal('ecrPeriode', findPeriodeId(_getVal('ecrDate')));

    if (AppState.exercices.length === 1) {
        _setVal('ecrExercice', AppState.exercices[0].ID);
        loadPeriodes(AppState.exercices[0].ID).then(function () {
            _setVal('ecrPeriode', findPeriodeId(_getVal('ecrDate')));
        });
    }

    clearFormLigne();
    renderGrid();
    computeTotaux();
    switchTab('edit');

    if (typeof updateSaveButtonState === 'function') updateSaveButtonState();

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
        AppState.selectedLigneIndex = -1;
        AppState.lignes = [];

        _setVal('editingId', ecr.ID);
        _setVal('ecrSite', ecr.SITE_ID || '');
        _setVal('ecrJournal', ecr.JOURNAL_ID);
        _setVal('ecrExercice', ecr.EXERCICE_ID);
        _setVal('ecrDevise', ecr.MONNAIE_ID);
        _setVal('ecrNumero', ecr.NUMERO);
        _setVal('ecrDate', ecr.DATE_COMPTABLE);
        _setVal('ecrDatePiece', ecr.DATE_PIECE || '');
        _setVal('ecrReference', ecr.REFERENCE || '');
        // ⭐ NOUVEAUX CHAMPS
        _setVal('ecrReferenceFacture', ecr.REFERENCE_FACTURE || '');
        _setVal('ecrDateFacture',      ecr.DATE_FACTURE      || '');
        _setVal('ecrLibelle', ecr.LIBELLE);
        _setVal('ecrStatut', ecr.STATUT);

        await loadPeriodes(ecr.EXERCICE_ID);
        _setVal('ecrPeriode', ecr.PERIODE_ID || findPeriodeId(ecr.DATE_COMPTABLE));

        await loadAllComptesActifs();

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
        computeTotaux();

        if (typeof updateSaveButtonState === 'function') updateSaveButtonState();

        switchTab('edit');

        markClean();
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

// ============================================================
// SAUVEGARDER L'ÉCRITURE
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
                + '</ul>'
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

    // ⭐ Payload avec REFERENCE_FACTURE + DATE_FACTURE
    var payload = {
        id:               AppState.editingId,
        siteId:           siteId,
        exerciceId:       _getVal('ecrExercice'),
        periodeId:        periodeId,
        journalId:        _getVal('ecrJournal'),
        monnaieId:        _getVal('ecrDevise'),
        numero:           numeroFinal,
        dateComptable:    _getVal('ecrDate'),
        datePiece:        _getVal('ecrDatePiece'),
        reference:        _getVal('ecrReference').trim(),
        // ⭐ NOUVEAUX CHAMPS
        referenceFacture: _getVal('ecrReferenceFacture').trim(),
        dateFacture:      _getVal('ecrDateFacture') || null,
        libelle:          libelleFinal,
        statut:           _getVal('ecrStatut'),
        lignes:           lignesPayload
    };

    if (btnSave) btnSave.disabled = true;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.SAVE;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        var result = await resp.json();

        if (result.success) {
            showSuccessToast(result.message || _t('saisie.msg.save_ok') || 'Écriture enregistrée');

            markClean();

            newEcriture();
            loadEcritures();
            switchTab('list');
        } else {
            showErrorToast(result.message || _t('message.error') || 'Erreur');
        }
    } catch (err) {
        showErrorToast(err.message);
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
            loadEcritures();
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
window._serverLigneToClient  = _serverLigneToClient;
window._clientLigneToPayload = _clientLigneToPayload;

// ⭐ Dirty tracking
window.markDirty            = markDirty;
window.markClean            = markClean;
window.hasUnsavedChanges    = hasUnsavedChanges;
window.confirmLeaveEdit     = confirmLeaveEdit;
