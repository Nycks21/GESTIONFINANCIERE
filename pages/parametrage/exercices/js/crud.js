// crud.js — EXERCICES
var currentExerciceId = null;
var currentMode = 'add';

function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// ─── AJOUT ───
function openAddExerciceModal(e) {
    if (e) e.preventDefault();
    currentExerciceId = null;
    currentMode = 'add';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-calendar-alt"></i> ' + _t('exercices.modal.add_title');

    document.getElementById('exerciceFormPage').reset();
    document.getElementById('exerciceStatut').value = 'OUVERT';
    document.getElementById('exerciceActive').value = '1';

    // Pré-remplir les dates : année en cours
    var now = new Date();
    document.getElementById('exerciceDateDebut').value = now.getFullYear() + '-01-01';
    document.getElementById('exerciceDateFin').value   = now.getFullYear() + '-12-31';

    document.getElementById('btnSaveExercice').style.display = '';
    clearErrors();
    document.getElementById('exerciceModal').style.display = 'flex';
}

// ─── MODIFICATION ───
function editExercice(id) {
    var e = AppState.exercices.find(function (x) { return x.ID === id; });
    if (!e) return;
    currentExerciceId = id;
    currentMode = 'edit';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + _t('exercices.modal.edit_title');

    document.getElementById('exerciceCode').value    = e.CODE || '';
    document.getElementById('exerciceLibelle').value = e.LIBELLE || '';
    document.getElementById('exerciceDateDebut').value = (e.DATE_DEBUT || '').slice(0, 10);
    document.getElementById('exerciceDateFin').value   = (e.DATE_FIN   || '').slice(0, 10);
    document.getElementById('exerciceStatut').value = e.STATUT || 'OUVERT';
    document.getElementById('exerciceActive').value = e.ACTIVE ? '1' : '0';

    document.getElementById('btnSaveExercice').style.display = '';
    clearErrors();
    document.getElementById('exerciceModal').style.display = 'flex';
}

// ─── VISUALISATION ───
function viewExercice(id) {
    var e = AppState.exercices.find(function (x) { return x.ID === id; });
    if (!e) return;
    currentExerciceId = id;
    currentMode = 'view';

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-eye"></i> ' + _t('exercices.modal.view_title');

    document.getElementById('exerciceCode').value    = e.CODE || '';
    document.getElementById('exerciceLibelle').value = e.LIBELLE || '';
    document.getElementById('exerciceDateDebut').value = (e.DATE_DEBUT || '').slice(0, 10);
    document.getElementById('exerciceDateFin').value   = (e.DATE_FIN   || '').slice(0, 10);
    document.getElementById('exerciceStatut').value = e.STATUT || 'OUVERT';
    document.getElementById('exerciceActive').value = e.ACTIVE ? '1' : '0';

    setFieldsEnabled(false);
    document.getElementById('btnSaveExercice').style.display = 'none';
    clearErrors();
    document.getElementById('exerciceModal').style.display = 'flex';
}

function setFieldsEnabled(enabled) {
    var inputs = document.querySelectorAll('#exerciceModal input, #exerciceModal select');
    for (var i = 0; i < inputs.length; i++) {
        inputs[i].disabled = !enabled;
        inputs[i].style.backgroundColor = enabled ? '' : '#e9ecef';
    }
}

// ─── ENREGISTREMENT ───
async function saveExercice(e) {
    e.preventDefault();
    if (currentMode === 'view') return;

    var id = currentExerciceId;
    var data = {
        code:      document.getElementById('exerciceCode').value.trim().toUpperCase(),
        libelle:   document.getElementById('exerciceLibelle').value.trim(),
        dateDebut: document.getElementById('exerciceDateDebut').value,
        dateFin:   document.getElementById('exerciceDateFin').value,
        statut:    document.getElementById('exerciceStatut').value,
        active:    parseInt(document.getElementById('exerciceActive').value, 10) === 1
    };

    var valid = true;
    clearErrors();

    if (!data.code) { showError('exerciceCode', _t('exercices.msg.code_required')); valid = false; }
    else if (data.code.length > 20) { showError('exerciceCode', _t('exercices.msg.code_too_long')); valid = false; }

    if (!data.libelle) { showError('exerciceLibelle', _t('exercices.msg.libelle_required')); valid = false; }
    if (!data.dateDebut) { showError('exerciceDateDebut', _t('exercices.msg.date_debut_required')); valid = false; }
    if (!data.dateFin)   { showError('exerciceDateFin',   _t('exercices.msg.date_fin_required')); valid = false; }
    if (data.dateDebut && data.dateFin && data.dateFin < data.dateDebut) {
        showError('exerciceDateFin', _t('exercices.msg.date_fin_after_debut'));
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
            showToast(_t('message.success'), result.message || (id ? _t('exercices.msg.updated') : _t('exercices.msg.added')), 'success');
            closeExerciceModal();
            loadExercices();
            loadStats();
        } else {
            showToast(_t('message.error'), result.message || _t('message.error'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally { hideSpinner(); }
}

// ─── SUPPRESSION ───
async function deleteExercice(id) {
    var confirmResult = await Swal.fire({
        title: _t('exercices.confirm.delete_title'),
        text:  _t('exercices.confirm.delete_text'),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: _t('exercices.confirm.delete_yes'),
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
            showToast(_t('message.success'), _t('exercices.msg.deleted'), 'success');
            loadExercices(); loadStats();
        } else {
            showToast(_t('message.error'), result.message || _t('exercices.msg.delete_failed'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally { hideSpinner(); }
}

// ─── CLÔTURER ───
async function cloturerExercice(id) {
    var e = AppState.exercices.find(function (x) { return x.ID === id; });
    if (!e) return;

    var confirmResult = await Swal.fire({
        title: _t('exercices.confirm.cloturer_title'),
        html:  _t('exercices.confirm.cloturer_html').replace('{code}', e.CODE || ''),
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#ffc107',
        cancelButtonColor: '#6c757d',
        confirmButtonText: _t('exercices.confirm.cloturer_yes'),
        cancelButtonText: _t('button.cancel')
    });
    if (!confirmResult.isConfirmed) return;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.CLOTURER;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id })
        });
        var result = await resp.json();
        if (result.success) {
            showToast(_t('message.success'), _t('exercices.msg.clotured'), 'success');
            loadExercices(); loadStats();
        } else {
            showToast(_t('message.error'), result.message || _t('message.error'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally { hideSpinner(); }
}

// ─── RÉOUVRIR ───
async function reouvrirExercice(id) {
    var e = AppState.exercices.find(function (x) { return x.ID === id; });
    if (!e) return;

    var confirmResult = await Swal.fire({
        title: _t('exercices.confirm.reouvrir_title'),
        html:  _t('exercices.confirm.reouvrir_html').replace('{code}', e.CODE || ''),
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#28a745',
        cancelButtonColor: '#6c757d',
        confirmButtonText: _t('exercices.confirm.reouvrir_yes'),
        cancelButtonText: _t('button.cancel')
    });
    if (!confirmResult.isConfirmed) return;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.REOUVRIR;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id })
        });
        var result = await resp.json();
        if (result.success) {
            showToast(_t('message.success'), _t('exercices.msg.reouvert'), 'success');
            loadExercices(); loadStats();
        } else {
            showToast(_t('message.error'), result.message || _t('message.error'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally { hideSpinner(); }
}

// ─── FERMETURE ───
function closeExerciceModal() {
    document.getElementById('exerciceModal').style.display = 'none';
    currentExerciceId = null;
    currentMode = 'add';
    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-calendar-alt"></i> ' + _t('exercices.modal.add_title');
    setFieldsEnabled(true);
    document.getElementById('btnSaveExercice').style.display = '';
    clearErrors();
}

// ─── ERREURS ───
function showError(fieldId, msg) {
    var errEl = document.getElementById('err-' + fieldId);
    if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; }
    var f = document.getElementById(fieldId); if (f) f.classList.add('is-invalid');
}
function clearErrors() {
    document.querySelectorAll('.field-error').forEach(function (el) { el.textContent = ''; el.style.display = 'none'; });
    document.querySelectorAll('.is-invalid').forEach(function (el) { el.classList.remove('is-invalid'); });
}

window.openAddExerciceModal = openAddExerciceModal;
window.editExercice         = editExercice;
window.viewExercice         = viewExercice;
window.saveExercice         = saveExercice;
window.deleteExercice       = deleteExercice;
window.cloturerExercice     = cloturerExercice;
window.reouvrirExercice     = reouvrirExercice;
window.closeExerciceModal   = closeExerciceModal;
window.setFieldsEnabled     = setFieldsEnabled;
window.clearErrors          = clearErrors;
