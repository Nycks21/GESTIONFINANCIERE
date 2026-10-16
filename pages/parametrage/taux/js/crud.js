// crud.js — TAUX : ajout / édition / suppression
var currentTauxId = null;
var currentMode = 'add';

function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// INVERSEUR DE MONNAIES
// ============================================================
function swapCurrencies(e) {
    if (e) e.preventDefault();
    var source = document.getElementById('tauxSourceId');
    var cible  = document.getElementById('tauxCibleId');
    if (!source || !cible) return;
    var tmp = source.value;
    source.value = cible.value;
    cible.value = tmp;
}

// ============================================================
// AJOUT
// ============================================================
function openAddTauxModal(e) {
    if (e) e.preventDefault();
    currentTauxId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-exchange-alt"></i> ' + _t('taux.modal.add_title');

    document.getElementById('tauxFormPage').reset();
    document.getElementById('tauxActif').value = '1';
    document.getElementById('tauxDateEffet').value = new Date().toISOString().slice(0, 10);

    // Reset selects (après reset, il faut forcer la 1re option)
    var src = document.getElementById('tauxSourceId');
    var cib = document.getElementById('tauxCibleId');
    if (src && src.options.length > 0) src.selectedIndex = 0;
    if (cib && cib.options.length > 0) cib.selectedIndex = 0;

    document.getElementById('btnSaveTaux').style.display = '';
    clearErrors();
    document.getElementById('tauxModal').style.display = 'flex';
}

// ============================================================
// MODIFICATION
// ============================================================
function editTaux(id) {
    var t = AppState.taux.find(function (x) { return x.ID === id; });
    if (!t) return;
    currentTauxId = id;
    currentMode = 'edit';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + _t('taux.modal.edit_title');

    document.getElementById('tauxSourceId').value = t.MONNAIE_SOURCE_ID || '';
    document.getElementById('tauxCibleId').value  = t.MONNAIE_CIBLE_ID  || '';
    document.getElementById('tauxValeur').value   = t.TAUX || '';
    document.getElementById('tauxDateEffet').value = (t.DATE_EFFET || '').slice(0, 10);
    document.getElementById('tauxSourceInfo').value = t.SOURCE || '';
    document.getElementById('tauxActif').value = t.ACTIVE ? '1' : '0';

    document.getElementById('btnSaveTaux').style.display = '';
    clearErrors();
    document.getElementById('tauxModal').style.display = 'flex';
}

// ============================================================
// ENREGISTREMENT
// ============================================================
async function saveTaux(e) {
    e.preventDefault();
    var id = currentTauxId;

    var data = {
        monnaieSourceId: document.getElementById('tauxSourceId').value,
        monnaieCibleId:  document.getElementById('tauxCibleId').value,
        taux:            parseFloat(document.getElementById('tauxValeur').value),
        dateEffet:       document.getElementById('tauxDateEffet').value,
        source:          document.getElementById('tauxSourceInfo').value.trim(),
        actif:           parseInt(document.getElementById('tauxActif').value) === 1
    };

    // Validation
    var valid = true;
    clearErrors();

    if (!data.monnaieSourceId) { showError('tauxSourceId', _t('taux.msg.source_required')); valid = false; }
    if (!data.monnaieCibleId)  { showError('tauxCibleId',  _t('taux.msg.cible_required'));  valid = false; }
    if (data.monnaieSourceId && data.monnaieSourceId === data.monnaieCibleId) {
        showError('tauxCibleId', _t('taux.msg.currencies_different'));
        valid = false;
    }
    if (isNaN(data.taux) || data.taux <= 0) {
        showError('tauxValeur', _t('taux.msg.taux_required'));
        valid = false;
    }
    if (!data.dateEffet) { showError('tauxDateEffet', _t('taux.msg.date_required')); valid = false; }

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
            var msg = result.message || (id ? _t('taux.msg.updated') : _t('taux.msg.added'));
            showToast(_t('message.success'), msg, 'success');
            closeTauxModal();
            loadTaux();
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
async function deleteTaux(id) {
    var confirmResult = await Swal.fire({
        title: _t('taux.confirm.delete_title'),
        text:  _t('taux.confirm.delete_text'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: _t('taux.confirm.delete_yes'),
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
            showToast(_t('message.success'), _t('taux.msg.deleted'), 'success');
            loadTaux();
            loadStats();
        } else {
            showToast(_t('message.error'), result.message || _t('taux.msg.delete_failed'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally {
        hideSpinner();
    }
}

// ============================================================
// FERMETURE
// ============================================================
function closeTauxModal() {
    document.getElementById('tauxModal').style.display = 'none';
    currentTauxId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-exchange-alt"></i> ' + _t('taux.modal.add_title');
    document.getElementById('btnSaveTaux').style.display = '';
    clearErrors();
}

// ============================================================
// ERREURS DE CHAMP
// ============================================================
function showError(fieldId, msg) {
    var errEl = document.getElementById('err-' + fieldId);
    if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; }
    var field = document.getElementById(fieldId);
    if (field) field.classList.add('is-invalid');
}
function clearErrors() {
    document.querySelectorAll('.field-error').forEach(function (el) {
        el.textContent = '';
        el.style.display = 'none';
    });
    document.querySelectorAll('.is-invalid').forEach(function (el) {
        el.classList.remove('is-invalid');
    });
}

window.openAddTauxModal = openAddTauxModal;
window.editTaux         = editTaux;
window.saveTaux         = saveTaux;
window.deleteTaux       = deleteTaux;
window.closeTauxModal   = closeTauxModal;
window.swapCurrencies   = swapCurrencies;
window.clearErrors      = clearErrors;
