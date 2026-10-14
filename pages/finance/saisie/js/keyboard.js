// keyboard.js — Raccourcis clavier + navigation rapide + mode compact
'use strict';
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// ============================================================
// RACCOURCIS CLAVIER
//   Alt+N → Nouvelle ligne
//   Alt+V → Valider ligne
//   Alt+S → Enregistrer écriture (si possible)
//   Alt+D → Dupliquer ligne
//   Alt+Suppr → Supprimer ligne
//   Alt+E → Éditer ligne courante
//   Alt+C → Clear / vider la ligne
//   Alt+Z → Undo
//   Alt+F → Focus recherche
//   Alt+K → Toggle mode compact
//   Escape → Vider le formulaire ligne
// ============================================================
function initKeyboardShortcuts() {
    document.addEventListener('keydown', function (e) {
        // Ne pas capturer si l'utilisateur tape dans un champ avec Alt
        if (!e.altKey) return;
        if (e.ctrlKey || e.metaKey) return;

        var key = (e.key || '').toLowerCase();

        switch (key) {
            case 'n':
                e.preventDefault();
                if (typeof newLigne === 'function') newLigne();
                break;
            case 'v':
                e.preventDefault();
                if (typeof validateLigne === 'function') validateLigne();
                break;
            case 's':
                e.preventDefault();
                var btnSave = document.getElementById('btnSaveEcriture');
                if (btnSave && !btnSave.disabled && typeof saveEcriture === 'function') {
                    saveEcriture(new Event('submit'));
                } else {
                    showToast(_t('saisie.msg.cannot_save') || 'Impossible d\'enregistrer',
                              _t('saisie.msg.save_disabled') || 'Écriture déséquilibrée ou incomplète',
                              'warning', 2500);
                }
                break;
            case 'd':
                e.preventDefault();
                if (typeof duplicateLigne === 'function') duplicateLigne();
                break;
            case 'e':
                e.preventDefault();
                if (typeof editCurrentLigne === 'function') editCurrentLigne();
                break;
            case 'c':
                e.preventDefault();
                if (typeof clearCurrentLigne === 'function') clearCurrentLigne();
                break;
            case 'z':
                e.preventDefault();
                if (typeof undoLigne === 'function') undoLigne();
                break;
            case 'f':
                e.preventDefault();
                if (typeof focusSearch === 'function') focusSearch();
                break;
            case 'k':
                e.preventDefault();
                toggleCompactMode();
                break;
            case 'delete':
            case 'backspace':
                e.preventDefault();
                if (typeof deleteCurrentLigne === 'function') deleteCurrentLigne();
                break;
        }
    });

    // Escape → vide le formulaire ligne (si focus dans le form)
    document.addEventListener('keydown', function (e) {
        if (e.key !== 'Escape') return;
        if (e.altKey || e.ctrlKey || e.metaKey) return;
        var active = document.activeElement;
        if (!active || !active.closest) return;
        if (active.closest('#tab-edit')) {
            // Si focus est dans un champ du formulaire de ligne → clear
            if (active.closest('.eb-form')) {
                if (typeof clearCurrentLigne === 'function') clearCurrentLigne();
            }
        }
    });

    console.log('[keyboard] Raccourcis Alt+N/V/S/D/E/C/Z/F/K actifs.');
}

// ============================================================
// MODE COMPACT (toggle)
// ============================================================
function toggleCompactMode() {
    var body = document.body;
    body.classList.toggle('saisie-compact');

    var isCompact = body.classList.contains('saisie-compact');
    try {
        localStorage.setItem('saisie_compact', isCompact ? '1' : '0');
    } catch (e) { /* ignore */ }

    // MAJ l'icône du bouton
    var btn = document.getElementById('btnToggleCompact');
    if (btn) {
        var icon = btn.querySelector('i');
        if (icon) {
            icon.className = isCompact ? 'fas fa-expand' : 'fas fa-compress';
        }
    }

    showToast(
        _t('saisie.compact.title') || 'Mode compact',
        isCompact
            ? (_t('saisie.compact.on')  || 'Activé — espaces réduits')
            : (_t('saisie.compact.off') || 'Désactivé — affichage normal'),
        'info', 2000
    );
}

function restoreCompactMode() {
    var saved = null;
    try { saved = localStorage.getItem('saisie_compact'); } catch (e) { /* ignore */ }
    if (saved === '1') {
        document.body.classList.add('saisie-compact');
        var btn = document.getElementById('btnToggleCompact');
        if (btn) {
            var icon = btn.querySelector('i');
            if (icon) icon.className = 'fas fa-expand';
        }
    }
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.initKeyboardShortcuts = initKeyboardShortcuts;
window.toggleCompactMode     = toggleCompactMode;
window.restoreCompactMode    = restoreCompactMode;
