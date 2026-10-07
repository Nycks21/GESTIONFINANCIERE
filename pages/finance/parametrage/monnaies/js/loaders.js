// loaders.js – Module MONNAIES
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// CHARGEMENT LISTE
// ============================================================
async function loadMonnaies(options) {
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
            AppState.monnaies = data.Monnaies || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages) AppState.page = AppState.totalPages;
            renderTable(AppState.monnaies);
            loadStats();
            createPaginationControls(AppState.totalPages);
        } else {
            showToast(_t('message.error'), data.message || _t('monnaies.msg.load_error'), 'error');
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
            document.getElementById('statTotal').textContent = data.total != null ? data.total : 0;
            document.getElementById('statActives').textContent = data.actives != null ? data.actives : 0;
            document.getElementById('statInactives').textContent = data.inactives != null ? data.inactives : 0;
            document.getElementById('statReference').textContent = data.reference != null ? data.reference : 0;
        } else {
            console.warn('Stats API returned success=false:', data.message);
        }
    } catch (err) {
        console.error('Erreur stats :', err);
    }
}

// ============================================================
// RENDU TABLEAU
// ============================================================
function renderTable(monnaies) {
    var tbody = document.getElementById('monnaiesTableBody');
    if (!monnaies.length) {
        tbody.innerHTML = '<tr><td colspan="8" class="text-center">' + _t('monnaies.msg.no_data') + '</td></tr>';
        document.getElementById('resultsCounter').textContent = _t('monnaies.counter').replace('{n}', 0);
        return;
    }

    var html = '';
    monnaies.forEach(function (m) {
        var statusHtml = m.ACTIVE
            ? '<span class="badge" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">' + _t('monnaies.status.active') + '</span>'
            : '<span class="badge" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">' + _t('monnaies.status.inactive') + '</span>';

        var codeHtml = m.CODE
            ? '<span class="badge" style="font-weight:bold;background-color:#e9e9e9;padding:4px 10px;border-radius:20px;color:#333;">' + m.CODE + '</span>'
            : '<span class="badge" style="background-color:#f8f9fa;padding:4px 10px;border-radius:20px;color:#333;">N/A</span>';

        var nomHtml = m.NOM
            ? '<span style="font-weight:600;">' + m.NOM + '</span>'
            : '<span>N/A</span>';

        var symboleHtml = m.SYMBOLE
            ? '<span style="font-size:16px;font-weight:bold;color:#f39c12;">' + m.SYMBOLE + '</span>'
            : '<span style="color:#ccc;">—</span>';

        var decHtml = '<span class="badge" style="background:#6c757d;color:#fff;">' + (m.DECIMALES != null ? m.DECIMALES : 2) + '</span>';

        var tauxHtml = '<span style="font-family:monospace;font-size:12px;">' + formatTaux(m.TAUX_REFERENCE) + '</span>';

        var refHtml = m.EST_REFERENCE
            ? '<span title="' + _t('monnaies.status.reference') + '" style="color:#f39c12;font-size:16px;"><i class="fas fa-star"></i></span>'
            : '<span style="color:#dee2e6;font-size:16px;"><i class="far fa-star"></i></span>';

        html += '<tr>'
            + '<td>' + codeHtml + '</td>'
            + '<td>' + nomHtml + '</td>'
            + '<td style="text-align:center;">' + symboleHtml + '</td>'
            + '<td style="text-align:center;">' + decHtml + '</td>'
            + '<td style="text-align:right;">' + tauxHtml + '</td>'
            + '<td style="text-align:center;">' + refHtml + '</td>'
            + '<td>' + statusHtml + '</td>'
            + '<td>'
            +   '<button type="button" class="btn btn-sm btn-info" onclick="viewMonnaie(\'' + m.ID + '\')" title="' + _t('monnaies.action.view_details') + '"><i class="fas fa-eye"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-primary" onclick="editMonnaie(\'' + m.ID + '\')" title="' + _t('button.edit') + '"><i class="fas fa-edit"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-danger" onclick="deleteMonnaie(\'' + m.ID + '\')" title="' + _t('button.delete') + '"><i class="fas fa-trash"></i></button>'
            + '</td>'
            + '</tr>';
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent =
        _t('monnaies.counter').replace('{n}', AppState.total);
}

window.loadMonnaies = loadMonnaies;
window.loadStats = loadStats;
window.renderTable = renderTable;
