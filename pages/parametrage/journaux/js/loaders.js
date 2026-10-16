// loaders.js — JOURNAUX (multi-sites + plan routing + catégorie)
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

async function loadLookups() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.LOOKUPS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.sites         = data.sites || [];
            AppState.monnaies      = data.monnaies || [];
            AppState.comptesBanque = data.comptesBanque || [];
            populateLookupSelects();
        } else {
            console.warn('[loadLookups] success=false :', data.message);
        }
    } catch (err) {
        console.error('[loadLookups] Erreur :', err);
    }
}

function populateLookupSelects() {
    // Filtre toolbar : sites
    var fs = document.getElementById('site-filter');
    if (fs) {
        fs.innerHTML = '<option value="">' + _t('journaux.filter.all_sites') + '</option>';
        AppState.sites.forEach(function (item) {
            var opt = document.createElement('option');
            opt.value = item.ID;
            opt.textContent = item.CODE + ' — ' + item.NOM;
            fs.appendChild(opt);
        });
        if (AppState.filters.siteId) fs.value = AppState.filters.siteId;
    }

    // Monnaies
    var m = document.getElementById('journalMonnaie');
    if (m) {
        m.innerHTML = '<option value="">— ' + _t('journaux.modal.none') + ' —</option>';
        AppState.monnaies.forEach(function (item) {
            var opt = document.createElement('option');
            opt.value = item.ID;
            opt.textContent = item.CODE + ' — ' + item.NOM;
            m.appendChild(opt);
        });
    }

    // Comptes bancaires (avec data-plan-order)
    var c = document.getElementById('journalCompteBanque');
    if (c) {
        c.innerHTML = '<option value="">— ' + _t('journaux.modal.none') + ' —</option>';
        AppState.comptesBanque.forEach(function (item) {
            var opt = document.createElement('option');
            opt.value = item.ID;
            opt.textContent = 'PLAN' + item.PLAN_ORDER + ' · ' + item.CODE + ' — ' + item.LIBELLE;
            opt.setAttribute('data-plan-order', item.PLAN_ORDER);
            c.appendChild(opt);
        });
    }
}

async function loadJournaux(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();
    try {
        var params = new URLSearchParams({
            page:      AppState.page,
            pageSize:  AppState.pageSize,
            search:    AppState.filters.search,
            type:      AppState.filters.type,
            categorie: AppState.filters.categorie || '',   // 🆕
            status:    AppState.filters.status,
            siteId:    AppState.filters.siteId || '',
            sort:      AppState.sortField,
            order:     AppState.sortOrder
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
        var resp = await fetch(url);
        var data = await resp.json();

        if (data.success) {
            AppState.journaux = data.journaux || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages) AppState.page = AppState.totalPages;
            renderTable(AppState.journaux);
            loadStats();
            createPaginationControls(AppState.totalPages);
            updateCounter();
        } else {
            showErrorToast(data.message || _t('journaux.msg.load_error'));
        }
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        if (!silent) hideSpinner();
    }
}

function updateCounter() {
    var el = document.getElementById('resultsCounter');
    if (el) el.textContent = _t('journaux.counter').replace('{n}', AppState.total);
}

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
        console.error('[loadStats] Erreur :', err);
    }
}

window.loadLookups  = loadLookups;
window.loadJournaux = loadJournaux;
window.loadStats    = loadStats;
