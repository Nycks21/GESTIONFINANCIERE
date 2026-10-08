'use strict';

// ============================================================
// CONFIG — Déclaration API + signal de disponibilité
// ============================================================
(function () {

    // Base de tous les endpoints API (relative au dossier de la page)
    var API_BASE = 'api/';

    // Endpoints métier
    var API_USERS = {
        list:         'ListUser.aspx',
        create:       'users.aspx',
        update:       'updateUser.aspx',
        delete:       'DeleteUser.aspx',
        checkLicence: 'CheckLicence.aspx',
        backupDatabase:  'BackupDatabase.aspx'
    };

    // ─── Construction d'URL robuste ───
    function buildApiUrl(endpoint) {
        if (!endpoint || typeof endpoint !== 'string' || endpoint.trim() === '') {
            throw new Error('[config] buildApiUrl: endpoint vide ou invalide → ' + endpoint);
        }

        // Base = dossier de la page courante (sans le nom de fichier)
        var base = window.location.href
            .replace(/[?#].*$/, '')      // enlève query + hash
            .replace(/[^/]*$/, '');      // enlève le fichier

        // On normalise pour éviter les doubles slashs
        var full = base + API_BASE + endpoint.replace(/^\/+/, '');

        // Sécurité finale : ne JAMAIS retourner l'URL de la page elle-même
        var pageUrl = window.location.href.split('?')[0].split('#')[0];
        if (full === pageUrl) {
            throw new Error('[config] URL API identique à la page : ' + full);
        }

        return full;
    }

    // ─── Exposition globale ───
    window.APP_CONFIG = {
        API_BASE:     API_BASE,
        API_USERS:    API_USERS,
        buildApiUrl:  buildApiUrl,
        ready:        false
    };

    // Compatibilité avec le code existant (le temps de migrer)
    window.API_USERS = API_USERS;
    window.apiUrl    = function (endpoint) { return buildApiUrl(endpoint); };

    // ─── Signal de disponibilité ───
    window.APP_CONFIG.ready = true;

    // Événement pour les consommateurs qui attendent
    try {
        document.dispatchEvent(new CustomEvent('config:ready', {
            detail: { API_USERS: API_USERS, buildApiUrl: buildApiUrl }
        }));
    } catch (e) {
        console.warn('[config] CustomEvent non supporté', e);
    }

    console.log('✅ [config] Prêt — base API =', API_BASE);
    console.log('✅ [config] Exemple :', buildApiUrl(API_USERS.list));
})();
