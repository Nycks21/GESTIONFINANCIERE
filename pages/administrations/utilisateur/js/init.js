'use strict';

// ============================================================
// INIT — Point d'entrée utilisateur
// ============================================================
$(async function () {
    console.log('🔵 [init] Démarrage');

    try {
        // 1. Attendre la config (max 3 s)
        await waitForConfig();
        console.log('✅ [init] Config OK');

        // 2. Charger les utilisateurs
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
