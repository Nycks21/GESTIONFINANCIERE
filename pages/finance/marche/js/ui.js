// ui.js — SAISIE
'use strict';
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

function showSpinner() {
    var s = _el('spinnerOverlay');
    if (!s) return;
    s.style.display = 'flex'; s.style.visibility = 'visible'; s.style.opacity = '1';
    s.removeAttribute('aria-hidden');
}
function hideSpinner() {
    var s = _el('spinnerOverlay');
    if (!s) return;
    s.style.display = 'none'; s.style.visibility = 'hidden'; s.style.opacity = '0';
    s.setAttribute('aria-hidden', 'true');
}
function forceHideSpinner() { hideSpinner(); }

// ─── TABS ───
function switchTab(tabName) {
    // ⭐ Confirmation si on quitte l'onglet edit avec des modifs non enregistrées
    if (typeof hasUnsavedChanges === 'function' && hasUnsavedChanges()) {
        var current = document.querySelector('.saisie-tab-panel.active');
        if (current && current.id === 'tab-edit' && tabName !== 'edit') {
            if (typeof confirmLeaveEdit === 'function' && !confirmLeaveEdit()) return;
        }
    }

    document.querySelectorAll('.saisie-tab').forEach(function (t) {
        t.classList.toggle('active', t.getAttribute('data-tab') === tabName);
    });
    document.querySelectorAll('.saisie-tab-panel').forEach(function (p) {
        p.classList.toggle('active', p.id === 'tab-' + tabName);
    });

    // ⭐ Si Vue gère la liste et qu'on revient dessus, on peut recharger
    if (tabName === 'list' && window._VueSaisieList && typeof window._VueSaisieList.load === 'function') {
        // Pas obligatoire, mais permet de rafraîchir après un save
        // (l'appel à loadEcritures() dans saveEcriture le fait déjà)
    }
}

// ─── TOOLBAR ACTIONS (placeholders) ───
function focusSearch() {
    switchTab('list');
    var s = _el('search-filter');
    if (s) s.focus();
}
function printEcriture() {
    if (!AppState.editingId) { showErrorToast('Aucune écriture chargée.'); return; }
    window.print();
}
function openVentilations() {
    Swal.fire({ icon: 'info', title: 'Ventilations', text: 'Fonctionnalité à venir.' });
}
function openFichesImputation() {
    Swal.fire({ icon: 'info', title: 'Fiches d\'imputation', text: 'Fonctionnalité à venir.' });
}
function focusHeader() {
    var el = _el('ecrLibelle');
    if (el) el.focus();
}

// ─── PAGINATION (fallback vanilla) ───
function createPaginationControls(totalPages) {
    // ⭐ Si Vue gère la pagination, ne rien faire
    if (window._VueSaisieList) return;

    var w = _el('paginationWrapper');
    if (!w) return;
    w.innerHTML = '';
    if (totalPages <= 1) return;

    var c = document.createElement('div');
    c.style.cssText = 'margin:12px 0;display:flex;justify-content:center;gap:5px;flex-wrap:wrap;';

    var mkBtn = function (text, onClick, disabled, isDots) {
        var b = document.createElement('button');
        b.type = 'button'; b.textContent = text;
        if (isDots) {
            b.style.cssText = 'padding:8px 12px;border:none;background:transparent;color:#6c757d;cursor:default;';
            b.disabled = true; return b;
        }
        var num = Number(text);
        var isActive = !isNaN(num) && num === AppState.page;
        b.style.cssText = 'padding:8px 14px;border:1px solid ' + (isActive ? '#007bff' : '#dee2e6') + ';'
            + 'background:' + (isActive ? '#007bff' : (disabled ? '#e9ecef' : 'white')) + ';'
            + 'color:' + (isActive ? 'white' : (disabled ? '#6c757d' : '#007bff')) + ';'
            + 'cursor:' + (disabled || isActive ? 'default' : 'pointer') + ';'
            + 'border-radius:6px;font-weight:' + (isActive ? '700' : '500') + ';min-width:40px;';
        if (onClick && !disabled && !isActive) b.addEventListener('click', function (e) { e.preventDefault(); onClick(); });
        if (disabled) b.disabled = true;
        return b;
    };

    c.appendChild(mkBtn('«', function () { AppState.page = 1; loadEcritures(); }, AppState.page === 1));
    c.appendChild(mkBtn('‹', function () { AppState.page--; loadEcritures(); }, AppState.page === 1));

    var start = Math.max(1, AppState.page - 2);
    var end = Math.min(totalPages, start + 4);
    if (end - start + 1 < 5) start = Math.max(1, end - 4);

    for (var i = start; i <= end; i++) {
        (function (p) {
            c.appendChild(mkBtn(String(p), function () { AppState.page = p; loadEcritures(); }));
        })(i);
    }

    c.appendChild(mkBtn('›', function () { AppState.page++; loadEcritures(); }, AppState.page === totalPages));
    c.appendChild(mkBtn('»', function () { AppState.page = totalPages; loadEcritures(); }, AppState.page === totalPages));

    w.appendChild(c);
}

window.switchTab            = switchTab;
window.showSpinner          = showSpinner;
window.hideSpinner          = hideSpinner;
window.forceHideSpinner     = forceHideSpinner;
window.createPaginationControls = createPaginationControls;
window.focusSearch          = focusSearch;
window.printEcriture        = printEcriture;
window.openVentilations     = openVentilations;
window.openFichesImputation = openFichesImputation;
window.focusHeader          = focusHeader;
