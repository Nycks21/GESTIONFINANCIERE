// crud.js – Module MONNAIES
var currentMonnaieId = null;
var currentMode = 'add';

function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// UTILITAIRE : activer/désactiver champs
// ============================================================
function setFieldsEnabled(enabled) {
    var inputs = document.querySelectorAll('#monnaieModal input, #monnaieModal select, #monnaieModal textarea');
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
function openAddMonnaieModal(e) {
    if (e) e.preventDefault();
    currentMonnaieId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-coins"></i> ' + _t('monnaies.modal.add_title');

    document.getElementById('monnaieForm').reset();
    document.getElementById('monnaieCode').value = '';
    document.getElementById('monnaieSymbole').value = '';
    document.getElementById('monnaieNom').value = '';
    document.getElementById('monnaieDecimales').value = '2';
    document.getElementById('monnaieTaux').value = '';
    document.getElementById('monnaieReference').value = '0';
    document.getElementById('monnaieActif').value = '1';

    setFieldsEnabled(true);
    document.getElementById('btnSaveMonnaie').style.display = '';
    clearErrors();
    document.getElementById('monnaieModal').style.display = 'flex';
}

// ============================================================
// MODIFICATION
// ============================================================
function editMonnaie(id) {
    var m = AppState.monnaies.find(function (x) { return x.ID === id; });
    if (!m) return;
    currentMonnaieId = id;
    currentMode = 'edit';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + _t('monnaies.modal.edit_title');

    document.getElementById('monnaieCode').value = m.CODE || '';
    document.getElementById('monnaieSymbole').value = m.SYMBOLE || '';
    document.getElementById('monnaieNom').value = m.NOM || '';
    document.getElementById('monnaieDecimales').value = (m.DECIMALES != null ? m.DECIMALES : 2);
    document.getElementById('monnaieTaux').value = (m.TAUX_REFERENCE != null ? m.TAUX_REFERENCE : '');
    document.getElementById('monnaieReference').value = m.EST_REFERENCE ? '1' : '0';
    document.getElementById('monnaieActif').value = m.ACTIVE ? '1' : '0';

    setFieldsEnabled(true);
    document.getElementById('btnSaveMonnaie').style.display = '';
    clearErrors();
    document.getElementById('monnaieModal').style.display = 'flex';
}

// ============================================================
// VISUALISATION
// ============================================================
function viewMonnaie(id) {
    var m = AppState.monnaies.find(function (x) { return x.ID === id; });
    if (!m) return;
    currentMonnaieId = id;
    currentMode = 'view';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-eye"></i> ' + _t('monnaies.modal.view_title');

    document.getElementById('monnaieCode').value = m.CODE || '';
    document.getElementById('monnaieSymbole').value = m.SYMBOLE || '';
    document.getElementById('monnaieNom').value = m.NOM || '';
    document.getElementById('monnaieDecimales').value = (m.DECIMALES != null ? m.DECIMALES : 2);
    document.getElementById('monnaieTaux').value = (m.TAUX_REFERENCE != null ? m.TAUX_REFERENCE : '');
    document.getElementById('monnaieReference').value = m.EST_REFERENCE ? '1' : '0';
    document.getElementById('monnaieActif').value = m.ACTIVE ? '1' : '0';

    setFieldsEnabled(false);
    document.getElementById('btnSaveMonnaie').style.display = 'none';
    clearErrors();
    document.getElementById('monnaieModal').style.display = 'flex';
}

// ============================================================
// ENREGISTREMENT
// ============================================================
async function saveMonnaie(e) {
    e.preventDefault();

    if (currentMode === 'view') {
        showToast(_t('monnaies.msg.info'), _t('monnaies.msg.view_mode'), 'info');
        return;
    }

    var id = currentMonnaieId;
    var code = (document.getElementById('monnaieCode').value || '').trim().toUpperCase();
    var nom = (document.getElementById('monnaieNom').value || '').trim();
    var symbole = (document.getElementById('monnaieSymbole').value || '').trim();
    var decimales = parseInt(document.getElementById('monnaieDecimales').value, 10);
    var tauxRaw = (document.getElementById('monnaieTaux').value || '').trim();
    var taux = tauxRaw === '' ? null : parseFloat(tauxRaw);
    var estReference = document.getElementById('monnaieReference').value === '1';
    var actif = document.getElementById('monnaieActif').value === '1';

    // Validation
    var valid = true;
    clearErrors();

    if (!code) {
        showError('monnaieCode', _t('monnaies.msg.code_required'));
        valid = false;
    } else if (!/^[A-Z0-9]{2,10}$/.test(code)) {
        showError('monnaieCode', _t('monnaies.msg.code_invalid'));
        valid = false;
    }

    if (!nom) {
        showError('monnaieNom', _t('monnaies.msg.name_required'));
        valid = false;
    }

    if (isNaN(decimales) || decimales < 0 || decimales > 6) {
        showError('monnaieDecimales', _t('monnaies.msg.decimales_invalid'));
        valid = false;
    }

    if (taux !== null && (isNaN(taux) || taux < 0)) {
        showError('monnaieTaux', _t('monnaies.msg.taux_invalid'));
        valid = false;
    }

    if (!valid) return;

    var data = {
        code: code,
        nom: nom,
        symbole: symbole || null,
        decimales: decimales,
        tauxReference: taux,
        estReference: estReference,
        actif: actif
    };

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
            var msg = result.message || (id ? _t('monnaies.msg.updated') : _t('monnaies.msg.added'));
            showToast(_t('message.success'), msg, 'success');
            closeMonnaieModal();
            loadMonnaies();
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
async function deleteMonnaie(id) {
    var m = AppState.monnaies.find(function (x) { return x.ID === id; });
    if (m && m.EST_REFERENCE) {
        showToast(_t('message.error'), _t('monnaies.msg.cannot_delete_reference'), 'error');
        return;
    }

    var confirmResult = await Swal.fire({
        title: _t('monnaies.confirm.delete_title'),
        text: _t('monnaies.confirm.delete_text'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: _t('monnaies.confirm.delete_yes'),
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
            showToast(_t('message.success'), _t('monnaies.msg.deleted'), 'success');
            loadMonnaies();
            loadStats();
        } else {
            showToast(_t('message.error'), result.message || _t('monnaies.msg.delete_failed'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// FERMETURE MODAL
// ============================================================
function closeMonnaieModal() {
    document.getElementById('monnaieModal').style.display = 'none';
    currentMonnaieId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-coins"></i> ' + _t('monnaies.modal.add_title');
    setFieldsEnabled(true);
    document.getElementById('btnSaveMonnaie').style.display = '';
    clearErrors();
}

// ============================================================
// ERREURS
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
// VÉRIFICATION LIVE DU CODE (blur)
// ============================================================
async function checkMonnaieCodeAvailability() {
    var codeEl = document.getElementById('monnaieCode');
    var code = (codeEl.value || '').trim().toUpperCase();
    codeEl.value = code;

    if (!code || code.length < 2) return;

    try {
        var params = new URLSearchParams({ code: code });
        if (currentMonnaieId) params.append('excludeId', currentMonnaieId);

        var resp = await fetch(API.BASE + API.HANDLERS_PATH + API.CHECK_CODE + '?' + params);
        var data = await resp.json();

        if (data.success && !data.available) {
            showError('monnaieCode', _t('monnaies.msg.code_exists'));
        } else {
            var errEl = document.getElementById('err-monnaieCode');
            if (errEl) { errEl.textContent = ''; errEl.style.display = 'none'; }
        }
    } catch (err) {
        console.warn('Check code failed:', err);
    }
}

// Dans openAddMonnaieModal, ajouter :
// document.getElementById('monnaieCode').addEventListener('blur', checkMonnaieCodeAvailability);

window.openAddMonnaieModal = openAddMonnaieModal;
window.editMonnaie = editMonnaie;
window.viewMonnaie = viewMonnaie;
window.saveMonnaie = saveMonnaie;
window.deleteMonnaie = deleteMonnaie;
window.closeMonnaieModal = closeMonnaieModal;
window.clearErrors = clearErrors;
window.setFieldsEnabled = setFieldsEnabled;
