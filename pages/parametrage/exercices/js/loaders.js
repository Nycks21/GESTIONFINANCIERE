// loaders.js — EXERCICES
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

async function loadExercices(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();
    try {
        var params = new URLSearchParams({
            page: AppState.page,
            pageSize: AppState.pageSize,
            search: AppState.filters.search,
            status: AppState.filters.status,
            active: AppState.filters.active,
            sort: AppState.sortField,
            order: AppState.sortOrder
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.exercices = data.exercices || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages) AppState.page = AppState.totalPages;
            renderTable(AppState.exercices);
            loadStats();
            createPaginationControls(AppState.totalPages);
        } else {
            showToast(_t('message.error'), data.message || _t('exercices.msg.load_error'), 'error');
        }
    } catch (err) {
        showToast(_t('message.error'), err.message, 'error');
    } finally {
        if (!silent) hideSpinner();
    }
}

async function loadStats() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.STATS;
        var resp = await fetch(url);
        if (!resp.ok) throw new Error('HTTP ' + resp.status);
        var data = await resp.json();
        if (data.success) {
            document.getElementById('statTotal').textContent    = data.total     != null ? data.total     : 0;
            document.getElementById('statOuverts').textContent  = data.ouverts   != null ? data.ouverts   : 0;
            document.getElementById('statClotures').textContent = data.clotures  != null ? data.clotures  : 0;
            document.getElementById('statArchives').textContent = data.archives  != null ? data.archives  : 0;
        }
    } catch (err) { console.error('Erreur stats :', err); }
}

function renderTable(exercices) {
    var tbody = document.getElementById('exercicesTableBody');
    if (!exercices.length) {
        tbody.innerHTML = '<tr><td colspan="8" class="table-loading" style="text-align: center;">' + _t('exercices.msg.no_data') + '</td></tr>';
        document.getElementById('resultsCounter').textContent = _t('exercices.counter').replace('{n}', 0);
        return;
    }
    var html = '';
    exercices.forEach(function (e) {
        var codeBadge = e.CODE
            ? '<span class="badge-code">' + _t_escape(e.CODE) + '</span>'
            : '<span class="badge-code">—</span>';

        var libelleHtml = '<span style="font-weight:600;">' + _t_escape(e.LIBELLE || '—') + '</span>';

        var duree = formatDureeMois(e.DATE_DEBUT, e.DATE_FIN);

        var statutHtml = '';
        if (e.STATUT === 'OUVERT') {
            statutHtml = '<span class="badge-statut badge-ouvert"><i class="fas fa-lock-open"></i> ' + _t('exercices.status.ouvert') + '</span>';
        } else if (e.STATUT === 'CLOTURE') {
            statutHtml = '<span class="badge-statut badge-cloture"><i class="fas fa-lock"></i> ' + _t('exercices.status.cloture') + '</span>';
        } else {
            statutHtml = '<span class="badge-statut badge-archive"><i class="fas fa-archive"></i> ' + _t('exercices.status.archive') + '</span>';
        }

        var activeHtml = e.ACTIVE
            ? '<span class="badge bg-success" style="background:#28a745;padding:4px 10px;border-radius:20px;color:white;">' + _t('exercices.status.actif') + '</span>'
            : '<span class="badge bg-danger" style="background:#dc3545;padding:4px 10px;border-radius:20px;color:white;">' + _t('exercices.status.inactif') + '</span>';

        // Actions : Clôturer (si OUVERT) OU Réouvrir (si CLOTURE)
        var actionCloturer = (e.STATUT === 'OUVERT')
            ? '<button type="button" class="btn btn-sm btn-warning" onclick="cloturerExercice(\'' + e.ID + '\')" title="' + _t('exercices.action.cloturer') + '"><i class="fas fa-lock"></i></button> '
            : '';
        var actionReouvrir = (e.STATUT === 'CLOTURE')
            ? '<button type="button" class="btn btn-sm btn-success" onclick="reouvrirExercice(\'' + e.ID + '\')" title="' + _t('exercices.action.reouvrir') + '"><i class="fas fa-lock-open"></i></button> '
            : '';

        html += '<tr>'
            + '<td data-label="' + _t('exercices.table.code') + '">' + codeBadge + '</td>'
            + '<td data-label="' + _t('exercices.table.libelle') + '">' + libelleHtml + '</td>'
            + '<td style="text-align:center;" data-label="' + _t('exercices.table.date_debut') + '">' + formatDateFr(e.DATE_DEBUT) + '</td>'
            + '<td style="text-align:center;" data-label="' + _t('exercices.table.date_fin') + '">' + formatDateFr(e.DATE_FIN) + '</td>'
            + '<td style="text-align:center;"><span class="badge-duree">' + duree + '</span></td>'
            + '<td style="text-align:center;" data-label="' + _t('exercices.table.statut') + '">' + statutHtml + '</td>'
            + '<td data-label="' + _t('exercices.table.active') + '">' + activeHtml + '</td>'
            + '<td style="text-align:right;" data-label="">'
            +   '<button type="button" class="btn btn-sm btn-info" onclick="viewExercice(\'' + e.ID + '\')" title="' + _t('exercices.action.view') + '"><i class="fas fa-eye"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-primary" onclick="editExercice(\'' + e.ID + '\')" title="' + _t('button.edit') + '"><i class="fas fa-edit"></i></button> '
            +   actionCloturer + actionReouvrir
            +   '<button type="button" class="btn btn-sm btn-danger" onclick="deleteExercice(\'' + e.ID + '\')" title="' + _t('button.delete') + '"><i class="fas fa-trash"></i></button>'
            + '</td>'
            + '</tr>';
    });
    tbody.innerHTML = html;
    document.getElementById('resultsCounter').textContent = _t('exercices.counter').replace('{n}', AppState.total);
}

function _t_escape(s) {
    if (s === null || s === undefined) return '';
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

window.loadExercices = loadExercices;
window.loadStats     = loadStats;
window.renderTable   = renderTable;
