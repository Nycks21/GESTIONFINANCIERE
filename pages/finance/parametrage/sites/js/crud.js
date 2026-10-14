// crud.js – SITES : saisie manuelle du CODE (2 chiffres) + checkbox EN_COURS
'use strict';

var currentSiteId = null;
var currentMode = 'add'; // 'add' | 'edit' | 'view'

// Regex : exactement 2 chiffres (00 à 99), zéros initiaux conservés
var CODE_REGEX = /^[0-9]{2}$/;

function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// FILTRE DE SAISIE : uniquement 2 chiffres (attache une seule fois)
// ============================================================
function _attachCodeInputFilter() {
    var el = document.getElementById('siteCode');
    if (!el || el.dataset.filterAttached === '1') return;
    el.dataset.filterAttached = '1';

    // Nettoyage à chaque frappe : retire tout non-numérique et limite à 2
    el.addEventListener('input', function () {
        this.value = this.value.replace(/[^0-9]/g, '').slice(0, 2);
    });

    // Blocage des touches non numériques (frappe directe)
    el.addEventListener('keypress', function (e) {
        if (e.key.length === 1 && !/[0-9]/.test(e.key)) {
            e.preventDefault();
        }
    });

    // Nettoyage au collage
    el.addEventListener('paste', function (e) {
        var pasted = (e.clipboardData || window.clipboardData).getData('text') || '';
        e.preventDefault();
        var cleaned = pasted.replace(/[^0-9]/g, '').slice(0, 2);
        this.value = cleaned;
        // déclenche un input pour cohérence
        this.dispatchEvent(new Event('input', { bubbles: true }));
    });
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
// CONFIGURATION DU CHAMP CODE (helper réutilisable)
// ============================================================
function _setupCodeField(mode) {
    // mode : 'editable' | 'readonly'
    var codeEl = document.getElementById('siteCode');
    if (!codeEl) return;

    codeEl.maxLength  = 2;
    codeEl.inputMode  = 'numeric';
    codeEl.pattern    = '[0-9]{2}';
    codeEl.placeholder = _t('sites.modal.code_placeholder') || '2 chiffres (ex. 02)';

    if (mode === 'readonly') {
        codeEl.readOnly = true;
        codeEl.style.backgroundColor = '#e9ecef';
        codeEl.style.cursor = 'not-allowed';
    } else {
        codeEl.readOnly = false;
        codeEl.style.backgroundColor = '';
        codeEl.style.cursor = '';
        _attachCodeInputFilter();
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

    // CODE : saisie manuelle (2 chiffres, zéros initiaux conservés)
    _setupCodeField('editable');
    document.getElementById('siteCode').value = '';

    setFieldsEnabled(true);
    _setupCodeField('editable'); // réapplication après setFieldsEnabled

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

    // CODE : éditable aussi en modification
    _setupCodeField('editable');
    document.getElementById('siteCode').value = site.CODE || '';

    document.getElementById('siteNom').value         = site.NOM || '';
    document.getElementById('siteDescription').value = site.DESCRIPTION || '';
    document.getElementById('siteEnCours').checked   = !!site.EN_COURS;
    document.getElementById('siteActif').value       = site.ACTIVE ? '1' : '0';

    setFieldsEnabled(true);
    _setupCodeField('editable'); // réapplication

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

    // CODE : lecture seule en visualisation
    _setupCodeField('readonly');
    document.getElementById('siteCode').value = site.CODE || '';

    document.getElementById('siteNom').value         = site.NOM || '';
    document.getElementById('siteDescription').value = site.DESCRIPTION || '';
    document.getElementById('siteEnCours').checked   = !!site.EN_COURS;
    document.getElementById('siteActif').value       = site.ACTIVE ? '1' : '0';

    setFieldsEnabled(false);
    _setupCodeField('readonly'); // réapplication après setFieldsEnabled(false)

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

    var id   = currentSiteId;
    var code = (document.getElementById('siteCode').value || '').trim();

    var data = {
        code:        code,
        nom:         document.getElementById('siteNom').value.trim(),
        description: document.getElementById('siteDescription').value.trim(),
        enCours:     document.getElementById('siteEnCours').checked,
        actif:       parseInt(document.getElementById('siteActif').value, 10) === 1
    };

    // ---------- Validation ----------
    var valid = true;
    clearErrors();

    if (!CODE_REGEX.test(code)) {
        showError('siteCode', _t('sites.msg.code_invalid') ||
            'Le code doit contenir exactement 2 chiffres (00 à 99).');
        valid = false;
    }
    if (!data.nom) {
        showError('siteNom', _t('sites.msg.name_required'));
        valid = false;
    }
    if (!valid) return;

    var endpoint = id ? API.EDIT : API.ADD;
    var payload  = id ? Object.assign({}, data, { id: id }) : data;

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
            if (result.code && !id && _t('sites.msg.added_with_code')) {
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
    var modal = document.getElementById('siteModal');
    if (modal) modal.style.display = 'none';
    document.body.style.overflow = '';

    currentSiteId = null;
    currentMode = 'add';

    var titleEl = document.getElementById('modalTitle');
    if (titleEl) {
        titleEl.innerHTML = '<i class="fas fa-map-marker-alt"></i> ' + _t('sites.modal.add_title');
    }

    setFieldsEnabled(true);

    _setupCodeField('editable');
    var codeEl = document.getElementById('siteCode');
    if (codeEl) codeEl.value = '';

    var btn = document.getElementById('btnSaveSite');
    if (btn) btn.style.display = '';

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
window.editSite         = editSite;
window.viewSite         = viewSite;
window.saveSite         = saveSite;
window.deleteSite       = deleteSite;
window.closeSiteModal   = closeSiteModal;
window.clearErrors      = clearErrors;
window.setFieldsEnabled = setFieldsEnabled;
