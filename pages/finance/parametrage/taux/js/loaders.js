// loaders.js — TAUX : chargement liste + stats + monnaies + rendu
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// CHARGEMENT DES MONNAIES (pour les dropdowns)
// ============================================================
async function loadMonnaies() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.MONNAIES;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.monnaies = data.monnaies || [];
            populateMonnaieSelects(AppState.monnaies, true);
        } else {
            console.warn('loadMonnaies success=false :', data.message);
        }
    } catch (err) {
        console.error('Erreur chargement monnaies :', err);
    }
}

// ============================================================
// CHARGEMENT LISTE TAUX
// ============================================================
async function loadTaux(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();
    try {
        var params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search,
            sourceId: AppState.filters.sourceId,
            targetId: AppState.filters.targetId,
            status: AppState.filters.status,
            sort: AppState.sortField,
            order: AppState.sortOrder
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.taux = data.taux || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages) AppState.page = AppState.totalPages;
            renderTable(AppState.taux);
            loadStats();
            createPaginationControls(AppState.totalPages);
        } else {
            showToast(_t('message.error'), data.message || _t('taux.msg.load_error'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

// ============================================================
// STATS
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
        }
    } catch (err) {
        console.error('Erreur stats :', err);
    }
}

// ============================================================
// RENDU DU TABLEAU
// ============================================================
function renderTable(taux) {
    var tbody = document.getElementById('tauxTableBody');
    if (!taux.length) {
        tbody.innerHTML = '<tr><td colspan="8" class="table-loading" style="text-align:center;">' +
            _t('taux.msg.no_data') + '</td></tr>';
        document.getElementById('resultsCounter').textContent = _t('taux.counter').replace('{n}', 0);
        return;
    }

    var html = '';
    taux.forEach(function (t) {
        var sourceBadge = '<span class="badge badge-currency">' + _t_escape(t.SOURCE_CODE || '?') + '</span>';
        var cibleBadge  = '<span class="badge badge-currency">' + _t_escape(t.CIBLE_CODE  || '?') + '</span>';

        var tauxHtml = '<span class="taux-value">' + formatTaux(t.TAUX) + '</span>';

        var dateHtml = '<span class="taux-date">' + formatDateFr(t.DATE_EFFET) + '</span>';

        var infoHtml = t.SOURCE
            ? '<span style="color:#6c757d;font-size:13px;">' + _t_escape(t.SOURCE) + '</span>'
            : '<span style="color:#ccc;">—</span>';

        var statusHtml = t.ACTIVE
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">' + _t('taux.status.active') + '</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">' + _t('taux.status.inactive') + '</span>';

        html += '<tr>'
            + '<td data-label="' + _t('taux.table.source') + '">' + sourceBadge + '</td>'
            + '<td style="text-align:center;"><i class="fas fa-arrow-right" style="color:#007bff;font-size:14px;"></i></td>'
            + '<td data-label="' + _t('taux.table.cible')  + '">' + cibleBadge  + '</td>'
            + '<td style="text-align:right;" data-label="' + _t('taux.table.taux') + '">' + tauxHtml + '</td>'
            + '<td style="text-align:center;" data-label="' + _t('taux.table.date_effet') + '">' + dateHtml + '</td>'
            + '<td data-label="' + _t('taux.table.source_info') + '">' + infoHtml + '</td>'
            + '<td data-label="' + _t('taux.table.statut') + '">' + statusHtml + '</td>'
            + '<td style="text-align:right;" data-label="">'
            +   '<button type="button" class="btn btn-sm btn-primary" onclick="editTaux(\'' + t.ID + '\')" title="' + _t('button.edit') + '"><i class="fas fa-edit"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-danger" onclick="deleteTaux(\'' + t.ID + '\')" title="' + _t('button.delete') + '"><i class="fas fa-trash"></i></button>'
            + '</td>'
            + '</tr>';
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent =
        _t('taux.counter').replace('{n}', AppState.total);
}

function _t_escape(s) {
    if (s === null || s === undefined) return '';
    return String(s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

window.loadTaux     = loadTaux;
window.loadStats    = loadStats;
window.loadMonnaies = loadMonnaies;
window.renderTable  = renderTable;
