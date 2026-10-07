// crud.js – SITES : génération auto du CODE + checkbox EN_COURS
var currentSiteId = null;
var currentMode = 'add'; // 'add', 'edit', 'view'

function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// ACTIVER / DÉSACTIVER LES CHAMPS DU MODAL
// ============================================================
function setFieldsEnabled(enabled) {
    var inputs = document.querySelectorAll('#siteModal input, #siteModal select, #siteModal textarea');
    for (var i = 0; i < inputs.length; i++) {
        inputs[i].disabled = !enabled;
        if (!enabled) {
            inputs[i].style.backgroundColor = '#e9ecef';
            inputs[i].style.cursor = 'not-allowed';
        } else {
            inputs[i].style.backgroundColor = '';
            inputs[i].style.cursor = '';
        }
    }
}

// ============================================================
// AJOUT
// ============================================================
function openAddSiteModal(e) {
    if (e) e.preventDefault();
    currentSiteId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-map-marker-alt"></i> ' + _t('sites.modal.add_title');

    document.getElementById('siteFormPage').reset();
    document.getElementById('siteActif').value = '1';
    document.getElementById('siteEnCours').checked = false;

    // 🔒 Le CODE est généré côté serveur → champ vide, en lecture seule
    var codeEl = document.getElementById('siteCode');
    codeEl.value = '';
    codeEl.placeholder = _t('sites.modal.code_auto_placeholder');
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    setFieldsEnabled(true);

    // Réapplique readonly sur le code
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveSite').style.display = '';
    clearErrors();
    document.getElementById('siteModal').style.display = 'flex';
}

// ============================================================
// MODIFICATION
// ============================================================
function editSite(id) {
    var site = AppState.sites.find(function (s) { return s.ID === id; });
    if (!site) return;
    currentSiteId = id;
    currentMode = 'edit';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + _t('sites.modal.edit_title');

    var codeEl = document.getElementById('siteCode');
    codeEl.value = site.CODE || '';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('siteNom').value = site.NOM || '';
    document.getElementById('siteDescription').value = site.DESCRIPTION || '';
    document.getElementById('siteEnCours').checked = !!site.EN_COURS;
    document.getElementById('siteActif').value = site.ACTIVE ? '1' : '0';

    setFieldsEnabled(true);

    // Réapplique readonly sur le code
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('btnSaveSite').style.display = '';
    clearErrors();
    document.getElementById('siteModal').style.display = 'flex';
}

// ============================================================
// VISUALISATION
// ============================================================
function viewSite(id) {
    var site = AppState.sites.find(function (s) { return s.ID === id; });
    if (!site) return;
    currentSiteId = id;
    currentMode = 'view';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-eye"></i> ' + _t('sites.modal.view_title');

    var codeEl = document.getElementById('siteCode');
    codeEl.value = site.CODE || '';
    codeEl.readOnly = true;
    codeEl.style.backgroundColor = '#e9ecef';
    codeEl.style.cursor = 'not-allowed';

    document.getElementById('siteNom').value = site.NOM || '';
    document.getElementById('siteDescription').value = site.DESCRIPTION || '';
    document.getElementById('siteEnCours').checked = !!site.EN_COURS;
    document.getElementById('siteActif').value = site.ACTIVE ? '1' : '0';

    setFieldsEnabled(false);
    document.getElementById('btnSaveSite').style.display = 'none';
    clearErrors();
    document.getElementById('siteModal').style.display = 'flex';
}

// ============================================================
// ENREGISTREMENT
// ============================================================
async function saveSite(e) {
    e.preventDefault();

    if (currentMode === 'view') {
        showToast(_t('sites.msg.info'), _t('sites.msg.view_mode'), 'info');
        return;
    }

    var id = currentSiteId;

    // ⚠️ Le CODE n'est PAS envoyé :
    //    - à l'ajout → généré côté serveur (SIT-PROJET-00001)
    //    - en modification → immuable
    var data = {
        nom: document.getElementById('siteNom').value.trim(),
        description: document.getElementById('siteDescription').value.trim(),
        enCours: document.getElementById('siteEnCours').checked,
        actif: parseInt(document.getElementById('siteActif').value) === 1
    };

    // Validation : seul le nom est requis
    var valid = true;
    clearErrors();
    if (!data.nom) {
        showError('siteNom', _t('sites.msg.name_required'));
        valid = false;
    }
    if (!valid) return;

    var endpoint = id ? API.EDIT : API.ADD;
    var payload = id ? Object.assign({}, data, { id: id }) : data;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + endpoint;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        var result = await resp.json();

        if (result.success) {
            var msg = result.message || (id ? _t('sites.msg.updated') : _t('sites.msg.added'));
            if (result.code && !id) {
                msg = _t('sites.msg.added_with_code').replace('{code}', result.code);
            }
            showToast(_t('message.success'), msg, 'success');
            closeSiteModal();
            loadSites();
            loadStats();
        } else {
            showToast(_t('message.error'), result.message || _t('message.error'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// SUPPRESSION
// ============================================================
async function deleteSite(id) {
    var confirmResult = await Swal.fire({
        title: _t('sites.confirm.delete_title'),
        text: _t('sites.confirm.delete_text'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: _t('sites.confirm.delete_yes'),
        cancelButtonText: _t('button.cancel')
    });
    if (!confirmResult.isConfirmed) return;

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
            showToast(_t('message.success'), _t('sites.msg.deleted'), 'success');
            loadSites();
            loadStats();
        } else {
            showToast(_t('message.error'), result.message || _t('sites.msg.delete_failed'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// FERMETURE DU MODAL
// ============================================================
function closeSiteModal() {
    document.getElementById('siteModal').style.display = 'none';
    currentSiteId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-map-marker-alt"></i> ' + _t('sites.modal.add_title');

    setFieldsEnabled(true);

    var codeEl = document.getElementById('siteCode');
    if (codeEl) {
        codeEl.value = '';
        codeEl.placeholder = _t('sites.modal.code_auto_placeholder');
        codeEl.readOnly = true;
        codeEl.style.backgroundColor = '#e9ecef';
        codeEl.style.cursor = 'not-allowed';
    }

    document.getElementById('btnSaveSite').style.display = '';
    clearErrors();
}

// ============================================================
// GESTION DES ERREURS DE CHAMP
// ============================================================
function showError(fieldId, msg) {
    var errEl = document.getElementById('err-' + fieldId);
    if (errEl) {
        errEl.textContent = msg;
        errEl.style.display = 'block';
    }
}

function clearErrors() {
    var errors = document.querySelectorAll('.field-error');
    for (var i = 0; i < errors.length; i++) {
        errors[i].textContent = '';
        errors[i].style.display = 'none';
    }
}

// ============================================================
// EXPOSITIONS GLOBALES
// ============================================================
window.openAddSiteModal = openAddSiteModal;
window.editSite = editSite;
window.viewSite = viewSite;
window.saveSite = saveSite;
window.deleteSite = deleteSite;
window.closeSiteModal = closeSiteModal;
window.clearErrors = clearErrors;
window.setFieldsEnabled = setFieldsEnabled;
