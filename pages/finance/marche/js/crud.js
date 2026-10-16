// crud.js — MARCHE (actions CRUD + dirty tracking + auxi dépendant du fournisseur)
// ⭐ Aligné sur le schéma SQL :
//    - FMARCHE.TYPE_MARCHE    VARCHAR(5)   → FRT/TRX/SRV/PIS/ATR
//    - FMARCHE.MODE_PASSATION VARCHAR(5)   → AON/AOI/CST/GAG/EDT/ATR
//    - FMARCHE.STATUT         TINYINT      → 1/2/3/4
//    - FMARCHE.AUXILIAIRE     NVARCHAR(50) → FTIERS.CODE
//    - FTIERS.PLAN_ELEMENT_ID → PLAN1.ID pour filtrer marAuxi
'use strict';
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// ============================================================
// DIRTY TRACKING
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
        _t('marche.msg.confirm_leave') ||
        'Quitter sans enregistrer ? Vos modifications seront perdues.'
    );
}

window.addEventListener('beforeunload', function (e) {
    if (hasUnsavedChanges()) {
        e.preventDefault();
        e.returnValue = _t('marche.msg.unsaved_changes') ||
                        'Vous avez des modifications non enregistrées.';
        return e.returnValue;
    }
});

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
// HELPER — FOURNISSEUR COURANT (objet)
// ============================================================
function _getCurrentFournisseur() {
    var id = _getVal('marFournisseur');
    if (!id) return null;
    return (AppState.fournisseurs || []).find(function (f) { return f.ID === id; }) || null;
}

// ============================================================
// ⭐ CALLBACK : changement de fournisseur
//    → reset immédiat de l'auxi + fetch des nouveaux auxiliaires
// ============================================================
function onFournisseurChange() {
    var fourId = _getVal('marFournisseur') || null;

    // Reset visuel immédiat pour éviter toute sélection fantôme
    var aux = document.getElementById('marAuxi');
    if (aux) aux.value = '';

    // ⭐ Toujours preserveValue = false (changement de contexte)
    populateMarAuxiOptions(fourId, false);

    markDirty();
}

// ============================================================
// CONVERSION LIGNE SERVEUR → CLIENT
// ============================================================
function _serverLigneToClient(l) {
    var ordreToKey = buildOrdreToKeyMap();

    var out = {
        id:                l.ID || null,
        articleId:         l.ARTICLE_ID || '',
        designation:       l.DESIGNATION || '',
        referenceLigne:    l.REFERENCE_LIGNE || '',
        exerciceId:        l.EXERCICE_ID || '',
        description:       l.DESCRIPTION || '',
        taxe:              parseFloat(l.TAXE || 0),
        montantLocHT:      parseFloat(l.MONTANT_LOC_HT  || 0),
        montantLocTVA:     parseFloat(l.MONTANT_LOC_TVA || 0),
        montantLocTTC:     parseFloat(l.MONTANT_LOC_TTC || 0),
        montantRapHT:      parseFloat(l.MONTANT_RAP_HT  || 0),
        montantRapTVA:     parseFloat(l.MONTANT_RAP_TVA || 0),
        montantRapTTC:     parseFloat(l.MONTANT_RAP_TTC || 0),
        sourceFinancement: l.SOURCE_FINANCEMENT || '',
        observations:      l.OBSERVATIONS || ''
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
// CONVERSION LIGNE CLIENT → PAYLOAD
// ============================================================
function _clientLigneToPayload(l) {
    var keyToOrdre = buildKeyToOrdreMap();

    var out = {
        id:                l.id || null,
        articleId:         l.articleId || null,
        designation:       l.designation || null,
        referenceLigne:    l.referenceLigne || null,
        exerciceId:        l.exerciceId || null,
        description:       l.description || null,
        taxe:              l.taxe || 0,
        montantLocHT:      l.montantLocHT || 0,
        montantLocTVA:     l.montantLocTVA || 0,
        montantLocTTC:     l.montantLocTTC || 0,
        montantRapHT:      l.montantRapHT || 0,
        montantRapTVA:     l.montantRapTVA || 0,
        montantRapTTC:     l.montantRapTTC || 0,
        sourceFinancement: l.sourceFinancement || null,
        observations:      l.observations || null
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
// NOUVEAU MARCHÉ
// ============================================================
function newMarche() {
    AppState.editingId = null;
    AppState.lignes = [];
    AppState.selectedLigneIndex = -1;

    _setVal('editingId', '');
    _setVal('marNumeroInput', '');
    _setVal('marSite', _getDefaultSiteId() || '');
    _setVal('marFournisseur', '');
    _setVal('marType', 'FRT');                 // ⭐ code BDD
    _setVal('marMode', 'AON');                 // ⭐ code BDD
    _setVal('marDateLancement', '');
    _setVal('marDateAttribution', '');
    _setVal('marDateSignature', new Date().toISOString().slice(0, 10));
    _setVal('marDateDebut', '');
    _setVal('marDateFin', '');
    _setVal('marCoursDevise', '1');
    _setVal('marStatut', '1');                 // ⭐ TINYINT 1..4
    _setVal('marDescription', '');

    // ⭐ Aucun fournisseur → marAuxi vide et désactivé
    populateMarAuxiOptions(null, false);

    clearFormLigne();
    renderGrid();
    computeTotaux();
    switchTab('edit');

    if (typeof updateSaveButtonState === 'function') updateSaveButtonState();
    markClean();
}

// ============================================================
// VIDER LE MARCHÉ (avec confirmation si dirty)
// ============================================================
function clearMarche() {
    if (AppState.lignes.length && AppState.editingId) {
        Swal.fire({
            icon: 'warning',
            title: _t('marche.confirm.clear_title') || 'Vider le marché ?',
            text:  _t('marche.confirm.clear_text')  || 'Toutes les lignes non enregistrées seront perdues.',
            showCancelButton: true,
            confirmButtonText: _t('button.yes') || 'Oui',
            cancelButtonText:  _t('button.cancel') || 'Annuler'
        }).then(function (r) {
            if (r.isConfirmed) newMarche();
        });
    } else {
        newMarche();
    }
}

// ============================================================
// CHARGER UN MARCHÉ POUR ÉDITION
// ============================================================
async function editMarche(id) {
    if (hasUnsavedChanges() && !confirmLeaveEdit()) return;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.DETAIL + '?id=' + encodeURIComponent(id);
        var resp = await fetch(url);
        var data = await resp.json();
        if (!data.success) { showErrorToast(data.message); return; }

        var m = data.marche;
        AppState.editingId = m.ID;
        AppState.selectedLigneIndex = -1;
        AppState.lignes = [];

        // ─── En-tête ───
        _setVal('editingId', m.ID);
        _setVal('marNumeroInput', m.NUMERO || '');
        _setVal('marSite', m.SITE_ID || '');
        _setVal('marType', m.TYPE_MARCHE || 'FRT');            // ⭐ code court
        _setVal('marMode', m.MODE_PASSATION || 'AON');         // ⭐ code court
        _setVal('marDateLancement',   m.DATE_LANCEMENT   || '');
        _setVal('marDateAttribution', m.DATE_ATTRIBUTION || '');
        _setVal('marDateSignature',   m.DATE_SIGNATURE   || '');
        _setVal('marDateDebut',       m.DATE_DEBUT       || '');
        _setVal('marDateFin',         m.DATE_FIN         || '');
        _setVal('marCoursDevise', m.COURS_DEVISE || 0);
        _setVal('marStatut', String(m.STATUT || '1'));         // ⭐ "1".."4"
        _setVal('marDescription', m.DESCRIPTION || '');

        // ⭐ Fournisseur → chargement async des auxiliaires → puis sélection de l'auxi
        _setVal('marFournisseur', m.FOURNISSEUR_ID || '');

        await populateMarAuxiOptions(m.FOURNISSEUR_ID || null, false);

        if (m.AUXILIAIRE) {
            var auxSel = document.getElementById('marAuxi');
            if (auxSel) {
                auxSel.value = m.AUXILIAIRE;
                // Si l'auxi enregistré n'existe plus dans la liste → reset propre
                if (auxSel.value !== m.AUXILIAIRE) {
                    auxSel.value = '';
                    _setAuxHint(
                        document.getElementById('marAuxHint'),
                        'marche.hint.aux_orphan',
                        'warning'
                    );
                }
            }
        }

        await loadAllComptesActifs();

        // ─── Lignes ───
        (data.lignes || []).forEach(function (l) {
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
// SAUVEGARDER LE MARCHÉ
// ============================================================
async function saveMarche(e) {
    if (e) e.preventDefault();

    var btnSave = document.getElementById('btnSaveMarche');
    if (btnSave && btnSave.disabled) {
        showToast(
            _t('marche.msg.cannot_save') || 'Impossible d\'enregistrer',
            _t('marche.msg.save_disabled') || 'Marché incomplet',
            'warning', 2500
        );
        return;
    }

    // ─── Validation ───
    var validation = validateMarche();
    if (!validation.valid) {
        Swal.fire({
            icon: 'warning',
            title: _t('marche.msg.validation_error') || 'Erreur de validation',
            html: '<ul style="text-align:left;padding-left:20px;">'
                + validation.errors.map(function (x) { return '<li>' + escapeHtml(x) + '</li>'; }).join('')
                + '</ul>'
        });
        return;
    }

    // ─── Récupération du fournisseur ───
    var fourId  = _getVal('marFournisseur') || null;
    var fourObj = _getCurrentFournisseur();

    // ─── Payload ───
    var payload = {
        id:               AppState.editingId,
        siteId:           _getVal('marSite') || _getDefaultSiteId() || null,
        numero:           (_getVal('marNumeroInput') || '').trim(),
        fournisseurId:    fourId,
        fournisseurNom:   fourObj ? (fourObj.NOM || '') : '',
        auxiliaire:       _getVal('marAuxi') || null,           // ⭐ CODE FTIERS
        typeMarche:       _getVal('marType'),                   // ⭐ FRT/TRX/...
        modePassation:    _getVal('marMode'),                   // ⭐ AON/AOI/...
        statut:           _getVal('marStatut'),                 // ⭐ "1".."4"
        description:      (_getVal('marDescription') || '').trim(),
        coursDevise:      parseFloat(_getVal('marCoursDevise') || 0) || 0,
        dateLancement:    _getVal('marDateLancement')   || null,
        dateAttribution:  _getVal('marDateAttribution') || null,
        dateSignature:    _getVal('marDateSignature')   || null,
        dateDebut:        _getVal('marDateDebut')       || null,
        dateFin:          _getVal('marDateFin')         || null,
        lignes:           AppState.lignes.map(_clientLigneToPayload)
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
            showSuccessToast(result.message || _t('marche.msg.save_ok') || 'Marché enregistré');
            markClean();
            newMarche();
            if (window._VueMarcheList && typeof window._VueMarcheList.load === 'function') {
                window._VueMarcheList.load();
            }
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
function deleteCurrentMarche() {
    if (!AppState.editingId) {
        showErrorToast(_t('marche.msg.no_marche_loaded') || 'Aucun marché chargé.');
        return;
    }
    deleteMarche(AppState.editingId);
}

async function deleteMarche(id) {
    var m = (AppState.marches || []).find(function (x) { return x.ID === id; });
    var num = m ? (m.NUMERO || '') : '';

    var conf = await Swal.fire({
        icon: 'warning',
        title: _t('marche.confirm.delete_title') || 'Supprimer le marché ?',
        html: (_t('marche.confirm.delete_text') || 'Le marché <strong>{num}</strong> sera définitivement supprimé.')
            .replace('{num}', escapeHtml(num)),
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#6c757d',
        confirmButtonText: _t('marche.confirm.delete_yes') || 'Oui, supprimer',
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
            showSuccessToast(result.message || _t('marche.msg.delete_ok') || 'Marché supprimé');
            markClean();
            AppState.editingId = null;
            AppState.lignes = [];
            newMarche();
            if (window._VueMarcheList && typeof window._VueMarcheList.load === 'function') {
                window._VueMarcheList.load();
            }
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
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.NEXT_NUMERO;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) _setVal('marNumeroInput', data.numero || '');
    } catch (err) { console.error('[loadNextNumero]', err); }
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.newMarche               = newMarche;
window.clearMarche             = clearMarche;
window.editMarche              = editMarche;
window.saveMarche              = saveMarche;
window.deleteMarche            = deleteMarche;
window.deleteCurrentMarche     = deleteCurrentMarche;
window.loadNextNumero          = loadNextNumero;
window.onFournisseurChange     = onFournisseurChange;     // ⭐
window.populateMarAuxiOptions  = populateMarAuxiOptions;  // ⭐ async désormais

window._getDefaultSiteId       = _getDefaultSiteId;
window._getCurrentFournisseur  = _getCurrentFournisseur;
window._fillAuxSelect          = _fillAuxSelect;          // ⭐ utilitaire
window._setAuxHint             = _setAuxHint;             // ⭐ utilitaire
window._serverLigneToClient    = _serverLigneToClient;
window._clientLigneToPayload   = _clientLigneToPayload;

// ⭐ Dirty tracking
window.markDirty            = markDirty;
window.markClean            = markClean;
window.hasUnsavedChanges    = hasUnsavedChanges;
window.confirmLeaveEdit     = confirmLeaveEdit;
