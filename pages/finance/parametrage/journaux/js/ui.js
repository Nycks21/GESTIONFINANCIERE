// ui.js — JOURNAUX (multi-sites + catégorie)
'use strict';
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// ════════════════════════════════════════════════════════════
// SPINNER
// ════════════════════════════════════════════════════════════
function forceHideSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'none';
    s.style.visibility = 'hidden';
    s.style.opacity = '0';
    s.setAttribute('aria-hidden', 'true');
}
function showSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'flex';
    s.style.visibility = 'visible';
    s.style.opacity = '1';
    s.removeAttribute('aria-hidden');
}
function hideSpinner() { forceHideSpinner(); }

// ════════════════════════════════════════════════════════════
// RENDU DU TABLEAU
// ════════════════════════════════════════════════════════════
function renderTable(journaux) {
    var tbody = document.getElementById('journauxTableBody');
    if (!tbody) return;

    if (!journaux.length) {
        tbody.innerHTML = '<tr><td colspan="9" style="text-align:center;padding:60px;color:#94A3B8;">'
                        + '<i class="fas fa-book-open" style="font-size:38px;opacity:.3;display:block;margin-bottom:10px;"></i>'
                        + _t('journaux.msg.no_data') + '</td></tr>';
        return;
    }

    var html = '';
    journaux.forEach(function (j) {
        // Code
        var codeHtml = j.CODE
            ? '<span class="badge-code">' + escapeHtml(j.CODE) + '</span>'
            : '<span class="badge-empty">—</span>';

        // Libellé
        var libelleHtml = '<span class="journal-libelle">' + escapeHtml(j.LIBELLE || '—') + '</span>';

        // Nature (TYPE_JOURNAL)
        var typeHtml = getTypeBadge(j.TYPE_JOURNAL);

        // 🆕 Catégorie (CATEGORIE_JOURNAL)
        var categorieHtml = getCategorieBadge(j.CATEGORIE_JOURNAL);

        // Sites
        var sitesHtml = renderSitesBadges(j.SITES);

        // Monnaie
        var monnaieHtml = j.MONNAIE_CODE
            ? '<span class="badge-monnaie">' + escapeHtml(j.MONNAIE_CODE) + '</span>'
            : '<span class="badge-empty">—</span>';

        // Préfixe
        var prefixeHtml = j.PREFIXE_NUMERO
            ? '<code class="prefix-code">' + escapeHtml(j.PREFIXE_NUMERO) + '…</code>'
            : '<span class="badge-empty">—</span>';

        // Statut
        var activeHtml = j.ACTIVE
            ? '<span class="badge-active-ok">' + _t('status.active') + '</span>'
            : '<span class="badge-active-off">' + _t('status.inactive') + '</span>';

        html += '<tr' + (j.ACTIVE ? '' : ' class="row-inactive"') + '>'
            + '<td>' + codeHtml + '</td>'
            + '<td>' + libelleHtml + '</td>'
            + '<td>' + typeHtml + '</td>'
            + '<td style="text-align:center;">' + categorieHtml + '</td>'
            + '<td>' + sitesHtml + '</td>'
            + '<td style="text-align:center;">' + monnaieHtml + '</td>'
            + '<td>' + prefixeHtml + '</td>'
            + '<td style="text-align:center;">' + activeHtml + '</td>'
            + '<td style="text-align:right;">'
            +   '<button type="button" class="btn btn-sm btn-primary" '
            +           'onclick="editJournal(\'' + j.ID + '\')" title="' + _t('button.edit') + '">'
            +     '<i class="fas fa-edit"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-danger" '
            +           'onclick="deleteJournal(\'' + j.ID + '\')" title="' + _t('button.delete') + '">'
            +     '<i class="fas fa-trash"></i></button>'
            + '</td>'
            + '</tr>';
    });
    tbody.innerHTML = html;
}

// ─── Badge nature (TYPE_JOURNAL) ───
function getTypeBadge(typeCode) {
    if (!typeCode) return '<span class="badge-empty">—</span>';
    var cls = 'badge-type-' + typeCode.toLowerCase().replace(/_/g, '-');
    var label = _t('journaux.type.' + typeCode.toLowerCase());
    return '<span class="' + cls + '">' + label + '</span>';
}

// 🆕 Badge catégorie (CATEGORIE_JOURNAL)
function getCategorieBadge(cat) {
    var c = parseInt(cat, 10);
    if (c === 2) {
        return '<span class="badge-cat-tresorerie"><i class="fas fa-coins"></i> '
             + _t('journaux.categorie.tresorerie') + '</span>';
    }
    return '<span class="badge-cat-od"><i class="fas fa-file-alt"></i> '
         + _t('journaux.categorie.od') + '</span>';
}

// ─── Badges sites ───
function renderSitesBadges(sites) {
    if (!sites || !sites.length) return '<span class="badge-empty">—</span>';

    var maxDisplay = 3;
    var shown = sites.slice(0, maxDisplay);
    var rest = sites.length - shown.length;

    var html = '<div class="sites-badges">';
    shown.forEach(function (s) {
        html += '<span class="badge-site" title="' + escapeHtml(s.NOM || '') + '">'
              + escapeHtml(s.CODE || '?') + '</span>';
    });
    if (rest > 0) {
        var restCodes = sites.slice(maxDisplay).map(function (x) { return x.CODE; }).join(', ');
        html += '<span class="badge-site-more" title="' + escapeHtml(restCodes) + '">+' + rest + '</span>';
    }
    html += '</div>';
    return html;
}

// ════════════════════════════════════════════════════════════
// PAGINATION
// ════════════════════════════════════════════════════════════
function createPaginationControls(totalPages) {
    var wrapper = document.getElementById('paginationWrapper');
    if (!wrapper) return;
    wrapper.innerHTML = '';
    if (totalPages <= 1) return;

    var container = document.createElement('div');
    container.id = 'pagination-container';
    container.style.cssText = 'margin:5px 0;display:flex;justify-content:center;gap:5px;flex-wrap:wrap;';

    var createBtn = function (text, onClick, disabled, isDots) {
        disabled = disabled || false; isDots = isDots || false;
        var btn = document.createElement('button');
        btn.type = 'button'; btn.textContent = text;

        if (isDots) {
            btn.style.cssText = 'padding:8px 12px;border:none;background:transparent;color:#6c757d;cursor:default;';
            btn.disabled = true;
            return btn;
        }

        var num = Number(text);
        var isActive = !isNaN(num) && num === AppState.page;
        btn.style.cssText = 'padding:8px 14px;border:1px solid ' + (isActive ? '#007bff' : '#dee2e6') + ';' +
            'background:' + (isActive ? '#007bff' : (disabled ? '#e9ecef' : 'white')) + ';' +
            'color:' + (isActive ? 'white' : (disabled ? '#6c757d' : '#007bff')) + ';' +
            'cursor:' + (disabled || isActive ? 'default' : 'pointer') + ';' +
            'border-radius:6px;font-weight:' + (isActive ? '700' : '500') + ';min-width:40px;';
        if (onClick && !disabled && !isActive) {
            btn.addEventListener('click', function (e) { e.preventDefault(); onClick(); });
        }
        if (disabled) btn.disabled = true;
        return btn;
    };

    container.appendChild(createBtn('«', function () { if (AppState.page !== 1) { AppState.page = 1; loadJournaux(); } }, AppState.page === 1));
    container.appendChild(createBtn('‹', function () { if (AppState.page > 1) { AppState.page--; loadJournaux(); } }, AppState.page === 1));

    var maxVisible = 5;
    var start = Math.max(1, AppState.page - Math.floor(maxVisible / 2));
    var end = Math.min(totalPages, start + maxVisible - 1);
    if (end - start + 1 < maxVisible) start = Math.max(1, end - maxVisible + 1);

    if (start > 1) {
        container.appendChild(createBtn('1', function () { AppState.page = 1; loadJournaux(); }));
        if (start > 2) container.appendChild(createBtn('...', null, true, true));
    }
    for (var i = start; i <= end; i++) {
        (function (page) {
            container.appendChild(createBtn(String(page), function () {
                if (page !== AppState.page) { AppState.page = page; loadJournaux(); }
            }));
        })(i);
    }
    if (end < totalPages) {
        if (end < totalPages - 1) container.appendChild(createBtn('...', null, true, true));
        (function (tp) {
            container.appendChild(createBtn(String(tp), function () { AppState.page = tp; loadJournaux(); }));
        })(totalPages);
    }
    container.appendChild(createBtn('›', function () { if (AppState.page < totalPages) { AppState.page++; loadJournaux(); } }, AppState.page === totalPages));
    container.appendChild(createBtn('»', function () { if (AppState.page !== totalPages) { AppState.page = totalPages; loadJournaux(); } }, AppState.page === totalPages));

    wrapper.appendChild(container);
}

// ════════════════════════════════════════════════════════════
// FILTRES
// ════════════════════════════════════════════════════════════
function applyFilters() {
    var s  = document.getElementById('search-filter');
    var t  = document.getElementById('type-filter');
    var c  = document.getElementById('categorie-filter');   // 🆕
    var st = document.getElementById('status-filter');
    var si = document.getElementById('site-filter');

    AppState.filters.search    = s  ? s.value  : '';
    AppState.filters.type      = t  ? t.value  : '';
    AppState.filters.categorie = c  ? c.value  : '';       // 🆕
    AppState.filters.status    = st ? st.value : '';
    AppState.filters.siteId    = si ? si.value : '';

    AppState.page = 1;
    loadJournaux({ silent: true });
}

function resetFilters() {
    ['search-filter', 'type-filter', 'categorie-filter', 'status-filter', 'site-filter'].forEach(function (id) {
        var el = document.getElementById(id);
        if (el) el.value = '';
    });
    AppState.filters = { search: '', type: '', categorie: '', status: '', siteId: '' };
    AppState.page = 1;
    loadJournaux({ silent: true });
}

// ════════════════════════════════════════════════════════════
// ROWS PER PAGE
// ════════════════════════════════════════════════════════════
function initRowsPerPage() {
    var select = document.getElementById('rows-per-page-top');
    if (!select) return;
    var currentSize = AppState.pageSize || DEFAULTS.PAGE_SIZE;
    var exists = false;
    for (var i = 0; i < select.options.length; i++) {
        if (select.options[i].value == currentSize) { select.selectedIndex = i; exists = true; break; }
    }
    if (!exists) {
        var opt = document.createElement('option');
        opt.value = currentSize;
        opt.textContent = currentSize + ' / page';
        select.appendChild(opt);
        select.value = currentSize;
    }
    select.addEventListener('change', function () {
        var val = this.value;
        if (val === 'all') AppState.pageSize = 999999;
        else {
            var n = parseInt(val, 10);
            if (!isNaN(n) && n > 0) AppState.pageSize = n;
        }
        AppState.page = 1;
        loadJournaux();
    });
}

// ════════════════════════════════════════════════════════════
// UI INIT
// ════════════════════════════════════════════════════════════
function initUIControls() {
    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            var m = document.getElementById('journalModal');
            if (m && m.style.display === 'flex') closeJournalModal();
        }
    });

    var searchInput = document.getElementById('search-filter');
    var tid = null;
    if (searchInput) {
        searchInput.addEventListener('input', function () {
            clearTimeout(tid);
            tid = setTimeout(applyFilters, 300);
        });
    }

    // 🆕 categorie-filter inclus
    ['type-filter', 'categorie-filter', 'status-filter', 'site-filter'].forEach(function (id) {
        var el = document.getElementById(id);
        if (el) el.addEventListener('change', applyFilters);
    });

    initRowsPerPage();

    document.querySelectorAll('.modal').forEach(function (modal) {
        modal.addEventListener('click', function (e) {
            if (e.target === modal && modal.id === 'journalModal') closeJournalModal();
        });
    });
}

// ════════════════════════════════════════════════════════════
// ERREURS DE CHAMP
// ════════════════════════════════════════════════════════════
function clearErrors() {
    document.querySelectorAll('#journalModal .field-error').forEach(function (el) {
        el.textContent = ''; el.style.display = 'none';
    });
    document.querySelectorAll('#journalModal .is-invalid').forEach(function (el) {
        el.classList.remove('is-invalid');
    });
}
function showFieldError(fieldId, msg) {
    var errEl = document.getElementById('err-' + fieldId);
    if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; }
    var f = document.getElementById(fieldId);
    if (f) f.classList.add('is-invalid');
}

// ════════════════════════════════════════════════════════════
// EXPOSITION
// ════════════════════════════════════════════════════════════
window.showSpinner              = showSpinner;
window.hideSpinner              = hideSpinner;
window.forceHideSpinner         = forceHideSpinner;
window.renderTable              = renderTable;
window.createPaginationControls = createPaginationControls;
window.applyFilters             = applyFilters;
window.resetFilters             = resetFilters;
window.initUIControls           = initUIControls;
window.clearErrors              = clearErrors;
window.showFieldError           = showFieldError;
