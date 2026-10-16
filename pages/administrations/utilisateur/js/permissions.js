// permissions.js — Définit les constantes attendues par crud.js
//   • PERMISSIONS_LIST          → liste de codes
//   • CHECKBOX_ID_MAP           → { "dashboard.view": "chk_dashboard_view", ... }
//   • DEFAULT_ROLE_PERMISSIONS  → { "0": [...], "1": [...], ... }
'use strict';

(function () {

    // ============================================================
    // DÉCOUVERTE DES CHECKBOXES DE PERMISSIONS
    // ============================================================
    function discoverPermissions() {
        var list = [];
        var map  = {};
        var seen = {};

        // Sélecteurs larges : tous les checkboxes dans la modale utilisateur,
        // dans un conteneur `permissions`, ou avec data-permission
        var checkboxes = document.querySelectorAll(
            '#addUserModal input[type="checkbox"], ' +
            '#userModal input[type="checkbox"], ' +
            '.permissions-container input[type="checkbox"], ' +
            'input[type="checkbox"][data-permission], ' +
            'input[type="checkbox"][data-perm]'
        );

        checkboxes.forEach(function (cb) {
            if (!cb.id) return;

            // 1) Priorité : data-permission ou data-perm
            var perm = cb.getAttribute('data-permission')
                    || cb.getAttribute('data-perm');

            // 2) Sinon : déduire depuis l'ID
            if (!perm && /^perm|^chk[_-]|^cb[_-]|^permission[_-]/i.test(cb.id)) {
                perm = cb.id
                    .replace(/^permission[_-]?/i, '')
                    .replace(/^perm[_-]?/i, '')
                    .replace(/^chk[_-]?/i, '')
                    .replace(/^cb[_-]?/i, '')
                    .replace(/[_-]+/g, '.')
                    .toLowerCase();
            }

            if (perm && !seen[perm]) {
                seen[perm] = true;
                list.push(perm);
                map[perm] = cb.id;
            }
        });

        return { list: list, map: map };
    }

    // ============================================================
    // INITIALISATION (défensive — peut être vide)
    // ============================================================
    var discovered = discoverPermissions();

    window.PERMISSIONS_LIST = discovered.list;
    window.CHECKBOX_ID_MAP  = discovered.map;

    // Par défaut :
    //   Role 0 (SuperAdmin) → toutes
    //   Role 1 (Admin)      → toutes
    //   Role 2, 3, 4        → aucune (à cocher manuellement)
    window.DEFAULT_ROLE_PERMISSIONS = {
        "0": discovered.list.slice(),
        "1": discovered.list.slice(),
        "2": [],
        "3": [],
        "4": []
    };

    console.log('[permissions.js] Découvertes :', discovered.list.length,
                'permission(s)',
                discovered.list.length ? '→ ' + discovered.list.join(', ') : '(aucune — attendez le DOM)');

    // ⭐ Re-découverte différée : le DOM peut ne pas être prêt
    //    au moment de l'exécution du script.
    if (document.readyState !== 'complete') {
        document.addEventListener('DOMContentLoaded', function () {
            var d = discoverPermissions();
            if (d.list.length > discovered.list.length) {
                window.PERMISSIONS_LIST         = d.list;
                window.CHECKBOX_ID_MAP          = d.map;
                window.DEFAULT_ROLE_PERMISSIONS = {
                    "0": d.list.slice(),
                    "1": d.list.slice(),
                    "2": [],
                    "3": [],
                    "4": []
                };
                console.log('[permissions.js] Re-découverte :', d.list.length, 'permission(s)');
            }
        });
    }

    // Exposer pour debug
    window.__discoverPermissions = discoverPermissions;
})();

