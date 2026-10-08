'use strict';

// ============================================================
// LOADERS — Module Utilisateurs
// ============================================================

// ────────────────────────────────────────────────────────────
// fetchJson — une seule responsabilité : URL valide → JSON
// ------------------------------------------------------------
// Lève une exception explicite si :
//   - statut HTTP ≥ 400
//   - content-type non JSON
//   - parsing JSON échoue
//   - réponse = page HTML (détection explicite)
// ────────────────────────────────────────────────────────────
async function fetchJson(url, options) {
    options = options || {};

    if (!url || typeof url !== 'string') {
        throw new Error('[fetchJson] URL invalide : ' + url);
    }

    console.log('[fetchJson] →', url);

    var response = await fetch(url, {
        credentials: 'same-origin',
        cache: options.cache || 'default',
        headers: options.headers || {}
    });

    var contentType = response.headers.get('content-type') || '';
    var info = {
        url: response.url,
        status: response.status,
        contentType: contentType,
        redirected: response.redirected
    };

    console.log('[fetchJson] ←', info);

    // 🔴 Statut HTTP d'erreur → message clair
    if (response.status >= 400) {
        var preview = '';
        try { preview = (await response.text()).substring(0, 300); } catch (e) {}
        throw new Error(
            '[fetchJson] HTTP ' + response.status + ' sur ' + url +
            (preview ? ' — ' + preview : '')
        );
    }

    // 🔴 Redirection vers Login
    if (response.redirected && /login\.aspx/i.test(response.url)) {
        console.warn('[fetchJson] Session expirée → redirection Login');
        window.location.href = response.url;
        throw new Error('Session expirée');
    }

    // 🔴 Content-type non JSON
    if (contentType.indexOf('application/json') === -1) {
        var text = await response.text();
        throw new Error(
            '[fetchJson] Content-Type inattendu "' + contentType + '" sur ' + url +
            ' — début du corps : ' + text.substring(0, 200)
        );
    }

    // 🔴 Parsing JSON
    try {
        return await response.json();
    } catch (e) {
        throw new Error('[fetchJson] JSON invalide sur ' + url + ' — ' + e.message);
    }
}

// ────────────────────────────────────────────────────────────
// fetchJsonWithRetry — retry uniquement sur erreurs transitoires
// ────────────────────────────────────────────────────────────
async function fetchJsonWithRetry(url, options) {
    options = options || {};
    var retries = (typeof options.retries === 'number') ? options.retries : 2;
    var delayMs = (typeof options.delayMs === 'number') ? options.delayMs : 400;

    var lastError = null;

    for (var attempt = 0; attempt <= retries; attempt++) {
        try {
            return await fetchJson(url, {
                cache: attempt === 0 ? 'default' : 'reload'
            });
        } catch (err) {
            lastError = err;

            // Erreurs fatales → on arrête immédiatement
            if (/HTTP 4|Session expirée|URL invalide/.test(err.message)) {
                throw err;
            }

            console.warn('[fetchJsonWithRetry] Tentative ' + (attempt + 1) +
                '/' + (retries + 1) + ' échouée :', err.message);

            if (attempt < retries) {
                await new Promise(function (r) { setTimeout(r, delayMs * (attempt + 1)); });
            }
        }
    }

    throw lastError || new Error('[fetchJsonWithRetry] Échec après plusieurs tentatives');
}

// ────────────────────────────────────────────────────────────
// Vérification licence
// ────────────────────────────────────────────────────────────
async function checkLicenceLimit() {
    try {
        var cfg = await waitForConfig();
        var url = cfg.buildApiUrl(cfg.API_USERS.checkLicence);
        var data = await fetchJsonWithRetry(url, { retries: 1 });

        if (data && data.success) {
            maxUsersAllowed = data.maxUsers || 0;
            var currentUsers = data.currentUsers || 0;
            isLicenceLimitReached = currentUsers >= maxUsersAllowed;

            var maxUsersSpan = document.getElementById('maxUsersCount');
            if (maxUsersSpan) {
                maxUsersSpan.textContent = currentUsers + ' / ' + maxUsersAllowed;
                maxUsersSpan.style.color = isLicenceLimitReached ? '#ff6b6b' : '#adb5bd';
                maxUsersSpan.style.fontWeight = isLicenceLimitReached ? 'bold' : 'normal';
            }

            var userCountInfo = document.getElementById('userCountInfo');
            if (userCountInfo) userCountInfo.textContent = currentUsers + ' / ' + maxUsersAllowed;

            return { reached: isLicenceLimitReached, current: currentUsers, max: maxUsersAllowed };
        }
    } catch (err) {
        console.error('[checkLicenceLimit] Erreur :', err);
        return { reached: false, current: 0, max: 0 };
    }
    return { reached: false, current: 0, max: 0 };
}

// ────────────────────────────────────────────────────────────
// canActivateUser
// ────────────────────────────────────────────────────────────
async function canActivateUser() {
    var licenceInfo = await checkLicenceLimit();
    if (licenceInfo.reached) {
        if (typeof showLicenceLimitAlert === 'function') {
            showLicenceLimitAlert(licenceInfo.current, licenceInfo.max);
        }
        return false;
    }
    return true;
}

// ────────────────────────────────────────────────────────────
// loadUsers — idempotent + attend la config
// ────────────────────────────────────────────────────────────
var _usersLoadPromise = null;

function loadUsers() {
    if (_usersLoadPromise) return _usersLoadPromise;

    _usersLoadPromise = (async function () {
        if (typeof showSpinner === 'function') showSpinner();
        if (typeof showPreloader === 'function') showPreloader();

        var listUrl = null;

        try {
            // ═══ 1. Attente config ═══
            var cfg = await waitForConfig();
            console.log('[loadUsers] Config prête :', cfg);

            // ═══ 2. Construction URL (throw si invalide) ═══
            listUrl = cfg.buildApiUrl(cfg.API_USERS.list);
            console.log('[loadUsers] URL calculée :', listUrl);

            // ═══ 3. Récupération ═══
            var data = await fetchJsonWithRetry(listUrl, { retries: 2 });

            // ═══ 4. Validation ═══
            if (!Array.isArray(data)) {
                console.error('[loadUsers] Réponse non-tableau :', data);
                throw new Error('Réponse invalide : tableau attendu, reçu ' + typeof data);
            }

            // ═══ 5. Application ═══
            usersData = data;
            filteredUsers = usersData.slice();

            if (typeof createFilterControls === 'function') createFilterControls();
            renderSimpleTable();

            if (typeof hidePreloader === 'function') hidePreloader();

            // Licence en arrière-plan
            checkLicenceLimit();

        } catch (err) {
            console.error('[loadUsers] ❌ Échec :', err);
            console.error('[loadUsers] URL tentée :', listUrl);

            var msg = (typeof T === 'function'
                ? T('message.load_users_error', 'Impossible de charger les utilisateurs')
                : 'Impossible de charger les utilisateurs');

            if (/Session expirée/.test(err.message)) {
                msg = 'Session expirée, reconnexion en cours…';
            } else if (/HTTP 404/.test(err.message)) {
                msg = 'API introuvable (404). Vérifiez que ' + (listUrl || 'ListUser.aspx') + ' existe.';
            } else if (/Content-Type inattendu/.test(err.message)) {
                msg = 'Le serveur renvoie du HTML au lieu de JSON.<br>' +
                      '<small>Ouvrez F12 → Network pour voir la réponse.</small>';
            }

            if (typeof Swal !== 'undefined') {
                Swal.fire({
                    icon: 'error',
                    title: (typeof T === 'function' ? T('message.error', 'Erreur') : 'Erreur'),
                    html: '<div style="text-align:left;">' + msg + '</div>' +
                          '<details style="margin-top:12px;font-size:12px;text-align:left;">' +
                          '<summary style="cursor:pointer;color:#888;">Détails techniques</summary>' +
                          '<pre style="background:#f5f5f5;padding:8px;border-radius:4px;overflow:auto;font-size:11px;">' +
                          (typeof escapeHtml === 'function' ? escapeHtml(err.message) : err.message) +
                          '\n\nURL : ' + (listUrl || '?') +
                          '</pre></details>'
                });
            }

            if (typeof hidePreloader === 'function') hidePreloader();

        } finally {
            if (typeof hideSpinner === 'function') hideSpinner();
            if (typeof forceHideSpinner === 'function') forceHideSpinner();
            _usersLoadPromise = null;
        }
    })();

    return _usersLoadPromise;
}

// ────────────────────────────────────────────────────────────
// Rendu du tableau (inchangé)
// ────────────────────────────────────────────────────────────
function renderSimpleTable() {
    var tbody = document.getElementById('usersTableBody');
    if (!tbody) return;

    var startIndex = (currentPage - 1) * rowsPerPage;
    var endIndex = startIndex + rowsPerPage;
    var pageUsers = filteredUsers.slice(startIndex, endIndex);
    var totalPages = Math.ceil(filteredUsers.length / rowsPerPage);

    tbody.innerHTML = '';

    if (!pageUsers.length) {
        tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:60px;">' +
            '<i class="fas fa-search" style="font-size:48px;color:#ccc;"></i><br>' +
            T('message.no_users_found', 'Aucun utilisateur trouvé') +
            '</td></tr>';
        if (typeof updateCounter === 'function') updateCounter();
        if (typeof createPaginationControls === 'function') createPaginationControls(totalPages);
        return;
    }

    var currentUserRole = parseInt(
        (document.getElementById('hfUserRole') || {}).value || '-1',
        10
    );

    pageUsers.forEach(function (user) {
        var row = tbody.insertRow();

        var nameBadge = user.USERNAME
            ? '<span class="badge-name">' + escapeHtml(user.USERNAME) + '</span>'
            : '';
        row.insertCell(0).innerHTML = nameBadge;
        row.insertCell(1).innerHTML = escapeHtml(user.NOM || '-');
        row.insertCell(2).innerHTML = escapeHtml(user.EMAIL || '-');
        row.insertCell(3).innerHTML = getUserRoleName(user.ROLEID);
        row.insertCell(4).innerHTML = escapeHtml(user.TELEPHONE || '-');
        row.insertCell(5).innerHTML = formatDate(user.CREATED_AT);

        row.insertCell(6).innerHTML =
            (user.ACTIVE === true || user.ACTIVE === 1 || user.ACTIVE === 'true')
                ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">✓ ' +
                  T('status.active', 'Actif') + '</span>'
                : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">✗ ' +
                  T('status.inactive', 'Inactif') + '</span>';

        var isProtected = (user.ROLEID === 0 && currentUserRole !== 0);

        var editTitle = isProtected
            ? T('message.only_superadmin_edit', 'Seul un SuperAdmin peut modifier un SuperAdmin')
            : T('button.edit', 'Modifier');
        var deleteTitle = isProtected
            ? T('message.only_superadmin_delete', 'Seul un SuperAdmin peut supprimer un SuperAdmin')
            : T('button.delete', 'Supprimer');

        var editBtn = '<button type="button" class="btn btn-sm ' +
            (isProtected ? 'btn-secondary' : 'btn-primary') + '" ' +
            (isProtected ? 'disabled ' : '') +
            'title="' + editTitle + '" ' +
            'onclick="openEditUserModal(' + user.IDUSER + ', event)">' +
            '<i class="fas fa-edit"></i></button>';

        var deleteBtn = '<button type="button" class="btn btn-sm ' +
            (isProtected ? 'btn-secondary' : 'btn-danger') + '" ' +
            (isProtected ? 'disabled ' : '') +
            'title="' + deleteTitle + '" ' +
            'onclick="supprimerContact(' + user.IDUSER + ', event)">' +
            '<i class="fas fa-trash"></i></button>';

        row.insertCell(7).innerHTML = editBtn + ' ' + deleteBtn;
    });

    if (typeof updateCounter === 'function') updateCounter();
    if (typeof createPaginationControls === 'function') createPaginationControls(totalPages);
}

// ────────────────────────────────────────────────────────────
// Tri
// ────────────────────────────────────────────────────────────
function sortData(column) {
    sortDirection *= -1;
    filteredUsers.sort(function (a, b) {
        var va = (a[column] || '').toString().toLowerCase();
        var vb = (b[column] || '').toString().toLowerCase();
        return va < vb ? -sortDirection : va > vb ? sortDirection : 0;
    });
    currentPage = 1;
    renderSimpleTable();
}

// ────────────────────────────────────────────────────────────
// Exposition globale
// ────────────────────────────────────────────────────────────
window.fetchJson          = fetchJson;
window.fetchJsonWithRetry = fetchJsonWithRetry;
window.checkLicenceLimit  = checkLicenceLimit;
window.canActivateUser    = canActivateUser;
window.loadUsers          = loadUsers;
window.renderSimpleTable  = renderSimpleTable;
window.sortData           = sortData;
