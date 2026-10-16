// crud.js — GÉNÉRALE (CRUD Plans + Éléments)
'use strict';
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

function _esc(s) {
    if (typeof window.escapeHtml === 'function') return window.escapeHtml(s);
    if (s === null || s === undefined) return '';
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

// ════════════════════════════════════════════════════════════
// PLANS — CRUD par ORDRE
// ════════════════════════════════════════════════════════════

function editPlan(ordre) {
    var plan = (AppState.plans || []).find(function (p) { return p.ORDRE === ordre; });
    if (!plan) return;

    var elementCount = parseInt(plan.ELEMENT_COUNT || 0, 10);
    if (elementCount > 0) {
        Swal.fire({
            icon: 'warning',
            title: _t('generale.plans.edit_locked_title', 'Modification impossible'),
            html: _t('generale.plans.edit_locked_msg',
                    'Ce plan contient déjà <strong>{count}</strong> élément(s). '
                    + 'Supprimez-les d\'abord pour pouvoir modifier ses paramètres.')
                    .replace('{count}', elementCount),
            confirmButtonText: _t('button.understand', 'Compris')
        });
        return;
    }

    AppState.editingPlanOrdre = ordre;

    document.getElementById('planOrdre').value       = plan.ORDRE || '';
    document.getElementById('planCode').value        = plan.CODE || '';
    document.getElementById('planNom').value         = plan.NOM || '';
    document.getElementById('planDescription').value = plan.DESCRIPTION || '';
    document.getElementById('planNiveau').value      = plan.NIVEAU || 1;
    document.getElementById('planType').value        = plan.PLAN_TYPE_CODE || '';
    document.getElementById('planPrincipal').checked = !!plan.EST_PRINCIPAL;

    clearErrors('#planEditModal');
    openPlanEditModal();
}

async function savePlan(e) {
    if (e) e.preventDefault();
    var ordre = AppState.editingPlanOrdre;
    if (!ordre) return;

    var data = {
        ordre:         ordre,
        code:          (document.getElementById('planCode').value || '').trim().toUpperCase(),
        nom:           (document.getElementById('planNom').value || '').trim(),
        description:   (document.getElementById('planDescription').value || '').trim(),
        niveau:        parseInt(document.getElementById('planNiveau').value, 10),
        planTypeCode:  document.getElementById('planType').value || null,
        estPrincipal:  document.getElementById('planPrincipal').checked
    };

    var valid = true;
    clearErrors('#planEditModal');
    if (!data.code) { showFieldError('planCode', _t('generale.plans.msg.code_required')); valid = false; }
    if (!data.nom)  { showFieldError('planNom',  _t('generale.plans.msg.nom_required'));  valid = false; }
    if (isNaN(data.niveau) || data.niveau < 1 || data.niveau > 10) {
        showFieldError('planNiveau', _t('generale.plans.msg.niveau_invalid'));
        valid = false;
    }
    if (!valid) return;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.PLANS_SAVE;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        var result = await resp.json();
        if (result.success) {
            showSuccessToast(result.message || _t('generale.plans.msg.saved'));
            closePlanEditModal();
            loadPlans();
        } else {
            showErrorToast(result.message || _t('message.error'));
        }
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

async function deletePlanConfig(ordre) {
    var plan = (AppState.plans || []).find(function (p) { return p.ORDRE === ordre; });
    if (!plan) return;

    var elementCount = parseInt(plan.ELEMENT_COUNT || 0, 10);
    if (elementCount > 0) {
        Swal.fire({
            icon: 'warning',
            title: _t('generale.plans.delete_locked_title', 'Suppression impossible'),
            html: _t('generale.plans.delete_locked_msg',
                    'Ce plan contient déjà <strong>{count}</strong> élément(s). Supprimez-les d\'abord.')
                    .replace('{count}', elementCount),
            confirmButtonText: _t('button.understand', 'Compris')
        });
        return;
    }

    var label = plan.NOM || plan.CODE || ('Slot ' + ordre);

    var conf = await Swal.fire({
        title: _t('generale.plans.confirm.delete_title', 'Supprimer ce plan ?'),
        html: _t('generale.plans.confirm.delete_text',
                'Le slot sera réinitialisé : <strong>{nom}</strong> sera effacé.<br>'
                + '<small style="color:#888;">Cette action est irréversible.</small>')
                .replace('{nom}', _esc(label)),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#6c757d',
        confirmButtonText: _t('generale.plans.confirm.delete_yes', 'Oui, supprimer'),
        cancelButtonText: _t('button.cancel')
    });
    if (!conf.isConfirmed) return;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.PLANS_DELETE;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ordre: ordre })
        });
        var result = await resp.json();
        if (result.success) {
            showSuccessToast(result.message || _t('generale.plans.msg.deleted', 'Plan supprimé.'));
            loadPlans();
        } else {
            showErrorToast(result.message || _t('message.error'));
        }
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

async function togglePlan(ordre, activate) {
    if (!activate) {
        var plan = (AppState.plans || []).find(function (p) { return p.ORDRE === ordre; });
        if (plan && plan.CODE && plan.NOM) {
            var conf = await Swal.fire({
                title: _t('generale.plans.confirm.deactivate_title'),
                html: _t('generale.plans.confirm.deactivate_text').replace('{nom}', _esc(plan.NOM)),
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#d33',
                cancelButtonColor: '#6c757d',
                confirmButtonText: _t('generale.plans.confirm.deactivate_yes'),
                cancelButtonText: _t('button.cancel')
            });
            if (!conf.isConfirmed) return;
        }
    }

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.PLANS_TOGGLE;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ ordre: ordre, active: activate })
        });
        var result = await resp.json();
        if (result.success) {
            showSuccessToast(result.message || _t('generale.plans.msg.toggled'));
            loadPlans();
        } else {
            showErrorToast(result.message || _t('message.error'));
        }
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

// Navigation vers Éléments
function openElementsPage(ordre) {
    window.location.href = 'elements/elements.aspx?planOrder=' + encodeURIComponent(ordre);
}

// ════════════════════════════════════════════════════════════
// ÉLÉMENTS DE PLAN (utilisé par elements.aspx)
// ════════════════════════════════════════════════════════════

function openAddElementModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;

    var title = document.getElementById('elementModalTitle');
    if (title) title.innerHTML = '<i class="fas fa-plus"></i> ' + _t('elements.modal.add_title');

    document.getElementById('elementId').value       = '';
    document.getElementById('elementCode').value     = '';
    document.getElementById('elementLibelle').value  = '';
    document.getElementById('elementActive').checked = true;

    var niveauEl = document.getElementById('elementNiveau');
    if (niveauEl) niveauEl.value = AppState.currentLevel || 1;

    populateParentSelect((AppState.currentLevel || 1) - 1, null);

    var planNiveau = (AppState.plan && AppState.plan.NIVEAU) ? AppState.plan.NIVEAU : 1;
    var grpAux = document.getElementById('grpAuxiliaire');
    var chkAux = document.getElementById('elementAuxiliaire');
    if (grpAux && chkAux) {
        chkAux.checked = false;
        grpAux.style.display = ((AppState.currentLevel || 1) === planNiveau) ? '' : 'none';
    }

    clearErrors('#elementModal');
    document.getElementById('elementModal').style.display = 'flex';
}

function editElement(id) {
    var el = (AppState.elements || []).find(function (x) { return x.ID === id; });
    if (!el) return;

    AppState.editingId = id;

    var title = document.getElementById('elementModalTitle');
    if (title) title.innerHTML = '<i class="fas fa-edit"></i> ' + _t('elements.modal.edit_title');

    document.getElementById('elementId').value       = el.ID;
    document.getElementById('elementCode').value     = el.CODE || '';
    document.getElementById('elementLibelle').value  = el.LIBELLE || '';
    document.getElementById('elementActive').checked = !!el.ACTIVE;

    var niveauEl = document.getElementById('elementNiveau');
    if (niveauEl) niveauEl.value = el.NIVEAU || 1;

    populateParentSelect((el.NIVEAU || 1) - 1, el.PARENT_ID);

    var grpAux = document.getElementById('grpAuxiliaire');
    var chkAux = document.getElementById('elementAuxiliaire');
    if (grpAux && chkAux) {
        var hasChildren = !!el.HAS_CHILDREN;
        if (!hasChildren) {
            grpAux.style.display = '';
            chkAux.checked = !!el.EST_AUXILIAIRE;
        } else {
            grpAux.style.display = 'none';
            chkAux.checked = false;
        }
    }

    clearErrors('#elementModal');
    document.getElementById('elementModal').style.display = 'flex';
}

function populateParentSelect(parentLevel, selectedId) {
    var sel = document.getElementById('elementParent');
    if (!sel) return;

    sel.innerHTML = '<option value="">— ' + _t('elements.modal.no_parent') + ' —</option>';

    if (!parentLevel || parentLevel < 1) { sel.disabled = true; sel.value = ''; return; }
    sel.disabled = false;

    var parents = (AppState.elements || []).filter(function (x) {
        return x.NIVEAU === parentLevel && x.ACTIVE;
    });
    parents.sort(function (a, b) {
        return (a.ORDRE || 0) - (b.ORDRE || 0) || (a.CODE || '').localeCompare(b.CODE || '');
    });
    parents.forEach(function (p) {
        var opt = document.createElement('option');
        opt.value = p.ID;
        opt.textContent = p.CODE + ' — ' + p.LIBELLE;
        if (p.ID === selectedId) opt.selected = true;
        sel.appendChild(opt);
    });
}

async function saveElement(e) {
    if (e) e.preventDefault();

    var id = AppState.editingId;
    var parentSel = document.getElementById('elementParent');
    var grpAux = document.getElementById('grpAuxiliaire');
    var chkAux = document.getElementById('elementAuxiliaire');

    var data = {
        id:             id,
        planOrder:      AppState.planOrder,       // ← ORDRE
        code:           (document.getElementById('elementCode').value || '').trim().toUpperCase(),
        libelle:        (document.getElementById('elementLibelle').value || '').trim(),
        parentId:       (parentSel && !parentSel.disabled) ? (parentSel.value || null) : null,
        active:         document.getElementById('elementActive').checked,
        estAuxiliaire:  (grpAux && chkAux && grpAux.style.display !== 'none') ? chkAux.checked : false
    };

    clearErrors('#elementModal');
    var valid = true;
    if (!data.code)    { showFieldError('elementCode',    _t('elements.msg.code_required'));    valid = false; }
    if (!data.libelle) { showFieldError('elementLibelle', _t('elements.msg.libelle_required')); valid = false; }
    if (!valid) return;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.ELEMENTS_SAVE;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        var result = await resp.json();
        if (result.success) {
            showSuccessToast(result.message || _t('elements.msg.saved'));
            closeElementModal();
            if (typeof window.loadPlanElements === 'function') window.loadPlanElements();
            else location.reload();
        } else {
            showErrorToast(result.message || _t('message.error'));
        }
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

async function deleteElement(id) {
    var el = (AppState.elements || []).find(function (x) { return x.ID === id; });
    if (!el) return;

    var conf = await Swal.fire({
        title: _t('elements.confirm.delete_title'),
        html: _t('elements.confirm.delete_text').replace('{code}', _esc(el.CODE)),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#6c757d',
        confirmButtonText: _t('elements.confirm.delete_yes'),
        cancelButtonText: _t('button.cancel')
    });
    if (!conf.isConfirmed) return;

    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.ELEMENTS_DELETE;
        var resp = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id, planOrder: AppState.planOrder })
        });
        var result = await resp.json();
        if (result.success) {
            showSuccessToast(result.message || _t('elements.msg.deleted'));
            if (typeof window.loadPlanElements === 'function') window.loadPlanElements();
            else location.reload();
        } else {
            showErrorToast(result.message || _t('message.error'));
        }
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

function closeElementModal() {
    var m = document.getElementById('elementModal');
    if (m) m.style.display = 'none';
    AppState.editingId = null;
    clearErrors('#elementModal');
}

// ─── Exposition ───
window.openElementsPage     = openElementsPage;
window.editPlan             = editPlan;
window.savePlan             = savePlan;
window.togglePlan           = togglePlan;
window.deletePlanConfig     = deletePlanConfig;

window.openAddElementModal  = openAddElementModal;
window.editElement          = editElement;
window.saveElement          = saveElement;
window.deleteElement        = deleteElement;
window.closeElementModal    = closeElementModal;
window.populateParentSelect = populateParentSelect;
