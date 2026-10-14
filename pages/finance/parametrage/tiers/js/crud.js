// crud.js — TIERS
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// ─── Ouvrir Ajouter ───
function openAddTiersModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-plus"></i> ' + _t('tiers.modal.add_title');

    document.getElementById('tiersFormPage').reset();
    document.getElementById('tiersActive').checked = true;
    document.getElementById('tiersType').value = '';
    document.getElementById('tiersCompte').value = '';

    clearErrors();
    document.getElementById('tiersModal').style.display = 'flex';
}

// ─── Ouvrir Éditer ───
function editTiers(id) {
    var t = AppState.tiers.find(function (x) { return x.ID === id; });
    if (!t) return;
    AppState.editingId = id;

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + _t('tiers.modal.edit_title');

    document.getElementById('tiersCode').value      = t.CODE || '';
    document.getElementById('tiersNom').value       = t.NOM || '';
    document.getElementById('tiersType').value      = t.TYPE_TIERS || '';
    document.getElementById('tiersCompte').value    = t.PLAN_ELEMENT_ID || '';
    document.getElementById('tiersEmail').value     = t.EMAIL || '';
    document.getElementById('tiersTelephone').value = t.TELEPHONE || '';
    document.getElementById('tiersAdresse').value   = t.ADRESSE || '';
    document.getElementById('tiersActive').checked  = !!t.ACTIVE;

    clearErrors();
    document.getElementById('tiersModal').style.display = 'flex';
}

// ─── Récupère PLAN_ORDER depuis l'option sélectionnée ───
function getSelectedPlanOrder() {
    var sel = document.getElementById('tiersCompte');
    if (!sel) return 0;
    var opt = sel.options[sel.selectedIndex];
    if (!opt) return 0;
    var v = parseInt(opt.getAttribute('data-plan-order'), 10);
    return isNaN(v) ? 0 : v;
}

// ─── Sauvegarder ───
async function saveTiers(e) {
    if (e) e.preventDefault();
    var id = AppState.editingId;

    var data = {
        id:              id,
        code:            (document.getElementById('tiersCode').value || '').trim().toUpperCase(),
        nom:             (document.getElementById('tiersNom').value || '').trim(),
        typeTiers:       document.getElementById('tiersType').value,
        planElementId:   document.getElementById('tiersCompte').value,
        planOrder:       getSelectedPlanOrder(),               // 🆕
        email:           (document.getElementById('tiersEmail').value || '').trim(),
        telephone:       (document.getElementById('tiersTelephone').value || '').trim(),
        adresse:         (document.getElementById('tiersAdresse').value || '').trim(),
        active:          document.getElementById('tiersActive').checked
    };

    clearErrors();
    var valid = true;
    if (!data.code)          { showFieldError('tiersCode',   _t('tiers.msg.code_required'));   valid = false; }
    if (!data.nom)           { showFieldError('tiersNom',    _t('tiers.msg.nom_required'));    valid = false; }
    if (!data.typeTiers)     { showFieldError('tiersType',   _t('tiers.msg.type_required'));   valid = false; }
    if (!data.planElementId) { showFieldError('tiersCompte', _t('tiers.msg.compte_required')); valid = false; }
    if (!valid) return;

    try {
        showSpinner();
        var endpoint = id ? API.EDIT : API.ADD;
        var url = API.BASE + API.HANDLERS_PATH + endpoint;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        var result = await resp.json();

        if (result.success) {
            showSuccessToast(result.message || (id ? _t('tiers.msg.updated') : _t('tiers.msg.added')));
            closeTiersModal();
            loadTiers();
        } else {
            showErrorToast(result.message || _t('message.error'));
        }
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

// ─── Supprimer ───
async function deleteTiers(id) {
    var t = AppState.tiers.find(function (x) { return x.ID === id; });
    if (!t) return;

    var conf = await Swal.fire({
        title: _t('tiers.confirm.delete_title'),
        html: _t('tiers.confirm.delete_text').replace('{code}', escapeHtml(t.CODE)),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#6c757d',
        confirmButtonText: _t('tiers.confirm.delete_yes'),
        cancelButtonText: _t('button.cancel')
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
            showSuccessToast(result.message || _t('tiers.msg.deleted'));
            loadTiers();
        } else {
            showErrorToast(result.message || _t('message.error'));
        }
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

// ─── Fermer ───
function closeTiersModal() {
    document.getElementById('tiersModal').style.display = 'none';
    AppState.editingId = null;
    clearErrors();
}

window.openAddTiersModal = openAddTiersModal;
window.editTiers         = editTiers;
window.saveTiers         = saveTiers;
window.deleteTiers       = deleteTiers;
window.closeTiersModal   = closeTiersModal;
window.getSelectedPlanOrder = getSelectedPlanOrder;
