// crud.js — JOURNAUX (multi-sites + catégorie OD/Trésorerie)
'use strict';

function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// ════════════════════════════════════════════════════════════
// CATÉGORIE — Radio helpers
// ════════════════════════════════════════════════════════════
function getSelectedCategorie() {
    var radios = document.querySelectorAll('input[name="categorieJournal"]');
    for (var i = 0; i < radios.length; i++) {
        if (radios[i].checked) return parseInt(radios[i].value, 10);
    }
    return 1;
}

function setSelectedCategorie(value) {
    var radios = document.querySelectorAll('input[name="categorieJournal"]');
    for (var i = 0; i < radios.length; i++) {
        radios[i].checked = (parseInt(radios[i].value, 10) === value);
    }
}

// ════════════════════════════════════════════════════════════
// HELPER : récupère PLAN_ORDER depuis l'option compte
// ════════════════════════════════════════════════════════════
function getSelectedPlanOrderFromCompte() {
    var sel = document.getElementById('journalCompteBanque');
    if (!sel) return 0;
    var opt = sel.options[sel.selectedIndex];
    if (!opt) return 0;
    var v = parseInt(opt.getAttribute('data-plan-order'), 10);
    return isNaN(v) ? 0 : v;
}

// ════════════════════════════════════════════════════════════
// MULTI-SELECT SITES
// ════════════════════════════════════════════════════════════
function renderSitesCheckboxes(selectedIds) {
    var container = document.getElementById('sitesList');
    if (!container) return;

    selectedIds = selectedIds || [];
    var searchInput = document.getElementById('sitesSearch');
    var search = (searchInput ? searchInput.value : '').toLowerCase();

    var sites = (AppState.sites || []).filter(function (s) {
        if (!search) return true;
        return (s.CODE || '').toLowerCase().indexOf(search) !== -1
            || (s.NOM  || '').toLowerCase().indexOf(search) !== -1;
    });

    if (!sites.length) {
        container.innerHTML = '<div class="multiselect-empty">'
                            + _t('journaux.modal.no_site_found') + '</div>';
        updateSitesCount();
        return;
    }

    var html = '';
    sites.forEach(function (s) {
        var checked = selectedIds.indexOf(s.ID) !== -1;
        html += '<label class="multiselect-item' + (checked ? ' is-checked' : '') + '">'
              + '  <input type="checkbox" class="site-checkbox" value="' + s.ID + '"'
              +      (checked ? ' checked' : '') + ' />'
              + '  <span class="multiselect-code">' + escapeHtml(s.CODE || '?') + '</span>'
              + '  <span class="multiselect-name">' + escapeHtml(s.NOM || '') + '</span>'
              + '</label>';
    });
    container.innerHTML = html;

    container.querySelectorAll('.site-checkbox').forEach(function (cb) {
        cb.addEventListener('change', function () {
            var lbl = this.closest('.multiselect-item');
            if (lbl) lbl.classList.toggle('is-checked', this.checked);
            updateSitesCount();
        });
    });

    updateSitesCount();
}

function updateSitesCount() {
    var count = document.querySelectorAll('#sitesList .site-checkbox:checked').length;
    var el = document.getElementById('sitesCount');
    if (el) el.textContent = count;
}

function getSelectedSiteIds() {
    var ids = [];
    document.querySelectorAll('#sitesList .site-checkbox:checked').forEach(function (cb) {
        ids.push(cb.value);
    });
    return ids;
}

function selectAllSites(select) {
    document.querySelectorAll('#sitesList .site-checkbox').forEach(function (cb) {
        cb.checked = select;
        var lbl = cb.closest('.multiselect-item');
        if (lbl) lbl.classList.toggle('is-checked', select);
    });
    updateSitesCount();
}

function filterSitesList() {
    var selected = getSelectedSiteIds();
    renderSitesCheckboxes(selected);
}

// ════════════════════════════════════════════════════════════
// AJOUT
// ════════════════════════════════════════════════════════════
function openAddJournalModal(e) {
    if (e) e.preventDefault();
    AppState.editingId = null;

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-plus"></i> ' + _t('journaux.modal.add_title');

    document.getElementById('journalFormPage').reset();
    document.getElementById('journalActive').checked = true;
    document.getElementById('journalType').value = '';
    document.getElementById('journalMonnaie').value = '';
    document.getElementById('journalCompteBanque').value = '';
    document.getElementById('sitesSearch').value = '';

    setSelectedCategorie(1);   // OD par défaut
    renderSitesCheckboxes([]);

    toggleCompteBanqueField();

    clearErrors();
    document.getElementById('journalModal').style.display = 'flex';
}

// ════════════════════════════════════════════════════════════
// ÉDITION
// ════════════════════════════════════════════════════════════
function editJournal(id) {
    var j = AppState.journaux.find(function (x) { return x.ID === id; });
    if (!j) return;
    AppState.editingId = id;

    document.getElementById('modalTitle').innerHTML =
        '<i class="fas fa-edit"></i> ' + _t('journaux.modal.edit_title');

    document.getElementById('journalCode').value         = j.CODE || '';
    document.getElementById('journalLibelle').value      = j.LIBELLE || '';
    document.getElementById('journalType').value         = j.TYPE_JOURNAL || '';
    document.getElementById('journalMonnaie').value      = j.MONNAIE_ID || '';
    document.getElementById('journalCompteBanque').value = j.COMPTE_BANQUE_ID || '';
    document.getElementById('journalPrefixe').value      = j.PREFIXE_NUMERO || '';
    document.getElementById('journalActive').checked     = !!j.ACTIVE;
    document.getElementById('sitesSearch').value         = '';

    // 🆕 Catégorie
    var cat = parseInt(j.CATEGORIE_JOURNAL || 1, 10);
    setSelectedCategorie(cat);

    var selectedIds = (j.SITES || []).map(function (s) { return s.ID; });
    renderSitesCheckboxes(selectedIds);

    toggleCompteBanqueField();

    clearErrors();
    document.getElementById('journalModal').style.display = 'flex';
}

// ════════════════════════════════════════════════════════════
// AFFICHER / MASQUER compte selon CATÉGORIE
// ════════════════════════════════════════════════════════════
function toggleCompteBanqueField() {
    var categorie = getSelectedCategorie();
    var grp = document.getElementById('grpCompteBanque');
    if (!grp) return;

    if (categorie === 2) {
        // Trésorerie : compte obligatoire → visible
        grp.style.display = '';
    } else {
        // OD : aucun compte → caché + reset
        grp.style.display = 'none';
        var sel = document.getElementById('journalCompteBanque');
        if (sel) sel.value = '';
    }
}

// ════════════════════════════════════════════════════════════
// SAUVEGARDE
// ════════════════════════════════════════════════════════════
async function saveJournal(e) {
    if (e) e.preventDefault();
    var id = AppState.editingId;
    var type = document.getElementById('journalType').value;
    var categorie = getSelectedCategorie();

    var siteIds = getSelectedSiteIds();

    // Plan uniquement si Trésorerie
    var planOrder = (categorie === 2) ? getSelectedPlanOrderFromCompte() : 0;

    var data = {
        id:                id,
        code:              (document.getElementById('journalCode').value || '').trim().toUpperCase(),
        libelle:           (document.getElementById('journalLibelle').value || '').trim(),
        typeJournal:       type,
        categorieJournal:  categorie,                          // 🆕
        siteIds:           siteIds,
        monnaieId:         document.getElementById('journalMonnaie').value || null,
        compteBanqueId:    (categorie === 2)
                                ? (document.getElementById('journalCompteBanque').value || null)
                                : null,
        planOrder:         planOrder,
        prefixeNumero:     (document.getElementById('journalPrefixe').value || '').trim().toUpperCase(),
        active:            document.getElementById('journalActive').checked
    };

    // ─── Validation ───
    clearErrors();
    var valid = true;

    if (!data.code) {
        showFieldError('journalCode', _t('journaux.msg.code_required'));
        valid = false;
    }
    if (!data.libelle) {
        showFieldError('journalLibelle', _t('journaux.msg.libelle_required'));
        valid = false;
    }
    if (!data.typeJournal) {
        showFieldError('journalType', _t('journaux.msg.type_required'));
        valid = false;
    }
    // 🆕 Validation catégorie
    if (categorie === 2) {
        if (!data.compteBanqueId) {
            showFieldError('journalCompteBanque', _t('journaux.msg.compte_obligatoire_tresorerie'));
            valid = false;
        } else if (!data.planOrder || data.planOrder < 1 || data.planOrder > 10) {
            showFieldError('journalCompteBanque', _t('journaux.msg.plan_invalid', 'Plan du compte invalide.'));
            valid = false;
        }
    }
    if (siteIds.length === 0) {
        var errEl = document.getElementById('err-journalSites');
        if (errEl) {
            errEl.textContent = _t('journaux.msg.sites_required');
            errEl.style.display = 'block';
        }
        valid = false;
    }

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
            showSuccessToast(result.message || (id ? _t('journaux.msg.updated') : _t('journaux.msg.added')));
            closeJournalModal();
            loadJournaux();
        } else {
            showErrorToast(result.message || _t('message.error'));
        }
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

// ════════════════════════════════════════════════════════════
// SUPPRESSION
// ════════════════════════════════════════════════════════════
async function deleteJournal(id) {
    var j = AppState.journaux.find(function (x) { return x.ID === id; });
    if (!j) return;

    var conf = await Swal.fire({
        title: _t('journaux.confirm.delete_title'),
        html: _t('journaux.confirm.delete_text').replace('{code}', escapeHtml(j.CODE)),
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#6c757d',
        confirmButtonText: _t('journaux.confirm.delete_yes'),
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
            showSuccessToast(result.message || _t('journaux.msg.deleted'));
            loadJournaux();
        } else {
            showErrorToast(result.message || _t('message.error'));
        }
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

// ════════════════════════════════════════════════════════════
// FERMETURE
// ════════════════════════════════════════════════════════════
function closeJournalModal() {
    document.getElementById('journalModal').style.display = 'none';
    AppState.editingId = null;
    clearErrors();

    var container = document.getElementById('sitesList');
    if (container) container.innerHTML = '';
    var countEl = document.getElementById('sitesCount');
    if (countEl) countEl.textContent = '0';
}

// ════════════════════════════════════════════════════════════
// EXPOSITION
// ════════════════════════════════════════════════════════════
window.openAddJournalModal     = openAddJournalModal;
window.editJournal             = editJournal;
window.saveJournal             = saveJournal;
window.deleteJournal           = deleteJournal;
window.closeJournalModal       = closeJournalModal;
window.toggleCompteBanqueField = toggleCompteBanqueField;

window.getSelectedCategorie = getSelectedCategorie;
window.setSelectedCategorie = setSelectedCategorie;
window.getSelectedPlanOrderFromCompte = getSelectedPlanOrderFromCompte;

window.renderSitesCheckboxes  = renderSitesCheckboxes;
window.getSelectedSiteIds     = getSelectedSiteIds;
window.selectAllSites         = selectAllSites;
window.updateSitesCount       = updateSitesCount;
window.filterSitesList        = filterSitesList;
