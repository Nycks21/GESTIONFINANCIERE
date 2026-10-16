'use strict';

// ============================================================
// CONFIG — Déclaration API + signal de disponibilité
// ============================================================
(function () {

    // Base de tous les endpoints API (relative au dossier de la page)
    var API_BASE = 'api/';

    // ============================================================
    // Endpoints métier
    // ============================================================
    var API_USERS = {
        // ─── Utilisateurs (CRUD) ───
        list:             'ListUser.aspx',
        create:           'users.aspx',
        update:           'updateUser.aspx',
        delete:           'DeleteUser.aspx',

        // ─── Licence ───
        checkLicence:     'CheckLicence.aspx',

        // ─── Sauvegarde ───
        backup:           'BackupDatabase.aspx',
        downloadBackup:   'DownloadBackup.aspx',
        getBackupList:    'GetBackupList.aspx',

        // ─── Restauration ───
        restore:          'RestoreDatabase.aspx',
        restoreUpload:    'UploadBackup.aspx',
        checkFile:        'CheckBackupFile.aspx',
        deleteFile:       'DeleteBackupFile.aspx',

        // ─── Maintenance / Notifications ───
        notifyMaintenance:'NotifyMaintenance.aspx',

        // ─── Mises à jour de l'application ───
        checkUpdates:     'CheckUpdates.aspx',

        // ─── Migrations base de données ───
        updateDatabase:   'UpdateDatabase.aspx',

        // ─── Alias rétro-compatible (ancien nom utilisé ailleurs) ───
        backupDatabase:   'BackupDatabase.aspx'
    };

    // ============================================================
    // Construction d'URL robuste
    // ============================================================
    function buildApiUrl(endpoint) {
        if (!endpoint || typeof endpoint !== 'string' || endpoint.trim() === '') {
            throw new Error('[config] buildApiUrl: endpoint vide ou invalide → ' + endpoint);
        }

        // Base = dossier de la page courante (sans le nom de fichier)
        var base = window.location.href
            .replace(/[?#].*$/, '')      // enlève query + hash
            .replace(/[^/]*$/, '');      // enlève le fichier

        // Normalise les slashs
        var full = base + API_BASE + endpoint.replace(/^\/+/, '');

        // Sécurité : ne JAMAIS retourner l'URL de la page elle-même
        var pageUrl = window.location.href.split('?')[0].split('#')[0];
        if (full === pageUrl) {
            throw new Error('[config] URL API identique à la page : ' + full);
        }

        return full;
    }

    // ============================================================
    // Exposition globale
    // ============================================================
    window.APP_CONFIG = {
        API_BASE:     API_BASE,
        API_USERS:    API_USERS,
        buildApiUrl:  buildApiUrl,
        ready:        false
    };

    window.API_USERS = API_USERS;
    window.apiUrl    = function (endpoint) { return buildApiUrl(endpoint); };

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
    console.log('✅ [config] Endpoints :', Object.keys(API_USERS).length);
    console.log('✅ [config] Exemple :', buildApiUrl(API_USERS.list));
})();
