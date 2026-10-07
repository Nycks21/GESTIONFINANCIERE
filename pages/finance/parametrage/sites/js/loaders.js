// loaders.js – SITES : chargement liste + stats + rendu table (avec EN_COURS)
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// CHARGEMENT DE LA LISTE
// ============================================================
async function loadSites(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();
    try {
        var params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search,
            status: AppState.filters.status,
            sort: AppState.sortField,
            order: AppState.sortOrder
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.sites = data.Sites || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages) AppState.page = AppState.totalPages;
            renderTable(AppState.sites);
            loadStats();
            createPaginationControls(AppState.totalPages);
        } else {
            showToast(_t('message.error'), data.message || _t('sites.msg.load_error'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

// ============================================================
// CHARGEMENT DES STATISTIQUES
// ============================================================
async function loadStats() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.STATS;
        var resp = await fetch(url);
        if (!resp.ok) throw new Error('HTTP ' + resp.status);
        var data = await resp.json();
        if (data.success) {
            document.getElementById('statTotal').textContent     = data.total     != null ? data.total     : 0;
            document.getElementById('statActives').textContent   = data.actives   != null ? data.actives   : 0;
            document.getElementById('statInactives').textContent = data.inactives != null ? data.inactives : 0;
        } else {
            console.warn('Stats API returned success=false:', data.message);
        }
    } catch (err) {
        console.error('Erreur stats :', err);
        showToast(_t('message.error'), _t('sites.msg.stats_error'), 'error');
    }
}

// ============================================================
// RENDU DU TABLEAU
// ============================================================
function renderTable(sites) {
    var tbody = document.getElementById('sitesTableBody');
    if (!sites.length) {
        tbody.innerHTML = '<tr><td colspan="6" class="table-loading" data-label="">' +
            _t('sites.msg.no_data') + '</td></tr>';
        document.getElementById('resultsCounter').textContent = _t('sites.counter').replace('{n}', 0);
        return;
    }

    var html = '';
    sites.forEach(function (s) {
        var isCurrent = !!s.EN_COURS;

        var statusHtml = s.ACTIVE
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">' + _t('sites.status.active') + '</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">' + _t('sites.status.inactive') + '</span>';

        var codeHtml = s.CODE
            ? '<span class="badge bg-secondary" style="color:#6c757d; font-weight:bold; background-color:#e9e9e9; padding:4px 10px; border-radius:20px;color:#333;">' + _t_escape(s.CODE) + '</span>'
            : '<span class="badge bg-secondary" style="color:#6c757d; background-color:#f8f9fa; padding:4px 10px; border-radius:20px;color:#333;">N/A</span>';

        var nomHtml = s.NOM
            ? '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">' + _t_escape(s.NOM) + '</span>'
            : '<span class="badge bg-secondary" style="font-weight:bold; padding:4px 10px;">N/A</span>';

        var descHtml = s.DESCRIPTION
            ? '<span style="color:#6c757d; font-size:13px;">' + _t_escape(s.DESCRIPTION) + '</span>'
            : '<span style="color:#ccc;">—</span>';

        var etatHtml = isCurrent
            ? '<span style="display:inline-flex;align-items:center;gap:5px;background:#d1fae5;color:#047857;font-weight:700;font-size:11px;padding:4px 11px;border-radius:999px;">' +
              '<i class="fas fa-circle" style="font-size:6px;"></i> ' + _t('sites.etat.en_cours') + '</span>'
            : '<span style="color:#ccc;">—</span>';

        // ✅ data-label : utilisé par le CSS mobile via ::before
        var labelCode    = _t('sites.table.code');
        var labelNom     = _t('sites.table.nom');
        var labelDesc    = _t('sites.table.description');
        var labelEtat    = _t('sites.table.etat');
        var labelStatut  = _t('sites.table.statut');

        html += '<tr>'
            + '<td class="col-code"    data-label="' + labelCode    + '">' + codeHtml    + '</td>'
            + '<td class="col-nom"     data-label="' + labelNom     + '">' + nomHtml     + '</td>'
            + '<td class="col-desc"    data-label="' + labelDesc    + '">' + descHtml    + '</td>'
            + '<td class="col-etat"    data-label="' + labelEtat    + '">' + etatHtml    + '</td>'
            + '<td class="col-statut"  data-label="' + labelStatut  + '">' + statusHtml  + '</td>'
            + '<td class="col-actions" data-label="">'
            +   '<button type="button" class="btn btn-sm btn-info" onclick="viewSite(\'' + s.ID + '\')" title="' + _t('sites.action.view_details') + '"><i class="fas fa-eye"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-primary" onclick="editSite(\'' + s.ID + '\')" title="' + _t('button.edit') + '"><i class="fas fa-edit"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-danger" onclick="deleteSite(\'' + s.ID + '\')" title="' + _t('button.delete') + '"><i class="fas fa-trash"></i></button>'
            + '</td>'
            + '</tr>';
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent =
        _t('sites.counter').replace('{n}', AppState.total);
}

// ============================================================
// HELPER : échappement HTML simple
// ============================================================
function _t_escape(s) {
    if (s === null || s === undefined) return '';
    return String(s)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.loadSites = loadSites;
window.loadStats = loadStats;
window.renderTable = renderTable;
