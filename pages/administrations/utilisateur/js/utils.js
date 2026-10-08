'use strict';

// ============================================================
// Helper i18n : T(key, fallback, params)
// ============================================================
function T(key, fallback, params) {
    var v;
    try {
        if (typeof window.t === 'function') v = window.t(key, params);
    } catch (e) { v = key; }
    if (v && v !== key) return v;
    return (fallback !== undefined) ? fallback : key;
}

// ============================================================
// escapeHtml — prévention XSS
// ============================================================
function escapeHtml(text) {
    if (!text) return '';
    return String(text)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

// ============================================================
// formatDate — gère /Date(…)/, timestamp, Date, string
// ============================================================
function formatDate(dateValue) {
    if (!dateValue) return '-';
    var timestamp;
    if (typeof dateValue === 'string' && dateValue.match(/\/Date\((\d+)\)\//)) {
        timestamp = parseInt(dateValue.match(/\/Date\((\d+)\)\//)[1]);
    } else if (typeof dateValue === 'number') {
        timestamp = dateValue;
    } else if (dateValue instanceof Date) {
        timestamp = dateValue.getTime();
    } else {
        var parsed = new Date(dateValue);
        if (!isNaN(parsed.getTime())) timestamp = parsed.getTime();
        else return '-';
    }
    var date = new Date(timestamp);
    if (isNaN(date.getTime())) return '-';
    return String(date.getDate()).padStart(2, '0') + '/' +
           String(date.getMonth() + 1).padStart(2, '0') + '/' +
           date.getFullYear();
}

// ============================================================
// getRoleId — accepte numérique ou nom, retourne 0..4 ou null
// ============================================================
function getRoleId(roleValue) {
    if (roleValue === null || roleValue === undefined || roleValue === '') return null;

    var asNum = parseInt(roleValue, 10);
    if (!isNaN(asNum) && String(asNum) === String(roleValue).trim() && asNum >= 0 && asNum <= 4) {
        return asNum;
    }

    var byName = {
        'SuperAdmin': 0, 'Admin': 1, 'Administrateur': 1,
        'User': 2, 'Utilisateur': 2,
        'Logisticien': 3, 'Comptable': 4
    };
    if (Object.prototype.hasOwnProperty.call(byName, roleValue)) {
        return byName[roleValue];
    }
    console.error('❌ getRoleId : rôle invalide → "' + roleValue + '"');
    return null;
}

// ============================================================
// getUserRoleName — ROLEID → libellé i18n
// ============================================================
function getUserRoleName(roleId) {
    var keyMap = {
        0: 'role.superadmin',
        1: 'role.admin',
        2: 'role.user',
        3: 'role.logisticien',
        4: 'role.comptable'
    };
    var key = keyMap[roleId];
    if (key) return T(key, key);
    return T('role.user', 'User');
}

// ============================================================
// findUserById — recherche locale
// ============================================================
function findUserById(userId) {
    return usersData.find(function (u) { return u.IDUSER == userId; });
}

// ============================================================
// safeJson — lecture robuste d'une réponse fetch
// ------------------------------------------------------------
// CONTRAT : retourne TOUJOURS un objet, jamais d'exception.
// ============================================================
async function safeJson(res) {
    var url = '';
    var status = 0;
    var contentType = '';
    var redirected = false;

    try {
        url = res.url || '';
        status = res.status;
        contentType = res.headers.get('content-type') || '';
        redirected = res.redirected === true;

        var text = await res.text();

        // ─── Corps vide ───
        if (!text || text.trim() === '') {
            console.warn('[safeJson] Réponse vide', { url: url, status: status });
            return { success: false, message: T('users.msg.empty_response', 'Empty response') };
        }

        // ─── Nettoyage BOM / caractères invisibles ───
        text = text.replace(/^\uFEFF/, '');
        text = text.replace(/[\u200B\u200C\u200D\uFEFF]/g, '');
        text = text.trim();

        // ─── Détection explicite d'une réponse HTML ───
        var looksLikeHtml =
            text.charAt(0) === '<' ||
            text.indexOf('<!DOCTYPE') === 0 ||
            text.indexOf('<!doctype') === 0 ||
            contentType.indexOf('text/html') !== -1;

        if (looksLikeHtml) {
            console.error('[safeJson] Réponse HTML reçue au lieu de JSON', {
                url: url,
                status: status,
                contentType: contentType,
                redirected: redirected,
                preview: text.substring(0, 500)
            });

            if (redirected && /Login\.aspx/i.test(url)) {
                console.warn('[safeJson] Redirection vers Login détectée → reconnexion');
                window.location.href = url;
            } else if (redirected && /Error500\.aspx/i.test(url)) {
                console.error('[safeJson] Redirection vers Error500.aspx détectée');
            }

            return {
                success: false,
                message: T('users.msg.html_response', 'Server returned an HTML page instead of JSON'),
                __htmlDetected: true,
                __url: url,
                __status: status
            };
        }

        // ─── Parsing JSON ───
        try {
            return JSON.parse(text);
        } catch (parseErr) {
            console.error('[safeJson] JSON invalide', {
                url: url,
                status: status,
                contentType: contentType,
                preview: text.substring(0, 500),
                error: parseErr.message
            });
            return {
                success: false,
                message: T('users.msg.json_error', 'JSON parsing error'),
                __parseError: true
            };
        }

    } catch (e) {
        console.error('[safeJson] Exception inattendue', {
            url: url,
            status: status,
            contentType: contentType,
            error: e.message
        });
        return { success: false, message: T('users.msg.json_error', 'JSON parsing error') };
    }
}

// ============================================================
// getActiveUsersCount
// ============================================================
function getActiveUsersCount() {
    return usersData.filter(function (u) {
        return u.ACTIVE === true || u.ACTIVE === 1 || u.ACTIVE === 'true';
    }).length;
}

// ============================================================
// showLicenceLimitAlert — modale SweetAlert
// ============================================================
function showLicenceLimitAlert(currentUsers, maxUsers, action) {
    action = action || T('licence.action.activate', 'activer');

    var currentLabel = T('licence.current_users',
        'Vous avez actuellement <strong style="color:#dc3545;">{current}</strong> utilisateur(s) <strong>actif(s)</strong>.',
        { current: currentUsers });

    var maxLabel = T('licence.max_users',
        'Votre licence autorise un maximum de <strong>{max}</strong> utilisateur(s) actif(s).',
        { max: maxUsers });

    var infoLabel = T('licence.info_deactivate',
        "Pour {action} cet utilisateur, vous devez d'abord désactiver un autre utilisateur actif.",
        { action: action });

    var title      = T('licence.limit_reached', '⚠️ Limite d\'utilisateurs atteinte');
    var modalTitle = T('licence.limit_title',   'Licence dépassée');
    var btnText    = T('licence.understand',    'Compris');

    var modalHtml =
        '<div style="text-align:center;padding:10px;">' +
            '<i class="fas fa-exclamation-triangle" style="font-size:48px;color:#dc3545;margin-bottom:20px;"></i>' +
            '<h3 style="color:#dc3545;margin-bottom:15px;">' + title + '</h3>' +
            '<p style="font-size:14px;color:#555;margin-bottom:10px;">' + currentLabel + '</p>' +
            '<p style="font-size:14px;color:#555;margin-bottom:20px;">' + maxLabel + '</p>' +
            '<div style="background:#fff3cd;border-left:4px solid #ffc107;padding:12px;border-radius:5px;text-align:left;">' +
                '<i class="fas fa-info-circle" style="color:#ffc107;margin-right:8px;"></i>' +
                '<span style="font-size:13px;">' + infoLabel + '</span>' +
            '</div>' +
        '</div>';

    Swal.fire({
        title: modalTitle,
        html: modalHtml,
        icon: 'warning',
        confirmButtonText: btnText,
        confirmButtonColor: '#dc3545'
    });
}

// ============================================================
// getDefaultTime — HH:MM dans 5 minutes
// ============================================================
function getDefaultTime() {
    var now = new Date();
    now.setMinutes(now.getMinutes() + 5);
    return now.toTimeString().slice(0, 5);
}

// ============================================================
// waitForConfig — Attend que la config soit prête (max 3 s)
// Usage : await waitForConfig(); puis window.APP_CONFIG.buildApiUrl(...)
// ============================================================
function waitForConfig(timeoutMs) {
    timeoutMs = timeoutMs || 3000;

    return new Promise(function (resolve, reject) {
        // Déjà prêt ?
        if (window.APP_CONFIG && window.APP_CONFIG.ready) {
            return resolve(window.APP_CONFIG);
        }

        var resolved = false;

        function onReady() {
            if (resolved) return;
            resolved = true;
            clearTimeout(timer);
            document.removeEventListener('config:ready', onReady);
            resolve(window.APP_CONFIG);
        }

        document.addEventListener('config:ready', onReady);

        var timer = setTimeout(function () {
            if (resolved) return;
            resolved = true;
            document.removeEventListener('config:ready', onReady);
            reject(new Error('[waitForConfig] Timeout après ' + timeoutMs + ' ms — ' +
                'la config ne s\'est jamais chargée. Vérifiez que config.js est bien inclus.'));
        }, timeoutMs);
    });
}

window.waitForConfig = waitForConfig;

// ============================================================
// Exposition globale
// ============================================================
window.T                     = T;
window.escapeHtml            = escapeHtml;
window.formatDate            = formatDate;
window.getRoleId             = getRoleId;
window.getUserRoleName       = getUserRoleName;
window.findUserById          = findUserById;
window.safeJson              = safeJson;
window.getActiveUsersCount   = getActiveUsersCount;
window.showLicenceLimitAlert = showLicenceLimitAlert;
window.getDefaultTime        = getDefaultTime;
