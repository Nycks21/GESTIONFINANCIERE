'use strict';

// ============================================================
// INIT — Point d'entrée utilisateur
// ============================================================
$(async function () {
    console.log('🔵 [init] Démarrage');

    try {
        // ⭐ 1. Initialisation UI (sidebar, filtres form, etc.)
        if (typeof initSidebar === 'function') {
            initSidebar();
            console.log('✅ [init] Sidebar initialisée');
        }
        if (typeof initDarkMode === 'function') {
            initDarkMode();
        }
        if (typeof preventFormAutoSubmit === 'function') {
            preventFormAutoSubmit();
        }
        if (typeof ensureButtonsHaveTypeButton === 'function') {
            ensureButtonsHaveTypeButton();
        }

        // ⭐ 2. Attente config (max 3 s)
        await waitForConfig();
        console.log('✅ [init] Config OK');

        // ⭐ 3. Chargement des utilisateurs
        await loadUsers();
        console.log('✅ [init] Utilisateurs chargés');

    } catch (err) {
        console.error('❌ [init] Échec :', err);

        if (typeof Swal !== 'undefined') {
            Swal.fire({
                icon: 'error',
                title: 'Erreur au démarrage',
                html: '<div style="text-align:left;font-size:13px;">' +
                      (typeof escapeHtml === 'function' ? escapeHtml(err.message) : err.message) +
                      '</div>'
            });
        }
    }
});
