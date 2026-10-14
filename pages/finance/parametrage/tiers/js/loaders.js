// loaders.js — TIERS
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// ════════════════════════════════════════════════════════════
// LOOKUPS — comptes auxiliaires depuis VW_ALL_PLAN_ELEMENTS
// ════════════════════════════════════════════════════════════
async function loadLookups() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.LOOKUPS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) {
            AppState.comptesAuxiliaires = data.comptes || [];
            populateCompteSelects();
        } else {
            console.warn('[loadLookups] success=false :', data.message);
        }
    } catch (err) {
        console.error('[loadLookups] Erreur :', err);
    }
}

function populateCompteSelects() {
    // ─── Filtre toolbar ───
    var cf = document.getElementById('compte-filter');
    if (cf) {
        cf.innerHTML = '<option value="">' + _t('tiers.filter.all_comptes') + '</option>';
        AppState.comptesAuxiliaires.forEach(function (c) {
            var opt = document.createElement('option');
            opt.value = c.ID;
            // Affiche : "PLAN3 · 401100 — Fournisseurs"
            opt.textContent = 'PLAN' + c.PLAN_ORDER + ' · ' + c.CODE + ' — ' + c.LIBELLE;
            opt.setAttribute('data-plan-order', c.PLAN_ORDER);
            cf.appendChild(opt);
        });
        if (AppState.filters.compteId) cf.value = AppState.filters.compteId;
    }

    // ─── Modal : select compte collectif ───
    var cm = document.getElementById('tiersCompte');
    if (cm) {
        cm.innerHTML = '<option value="">— ' + _t('tiers.modal.select_compte') + ' —</option>';
        AppState.comptesAuxiliaires.forEach(function (c) {
            var opt = document.createElement('option');
            opt.value = c.ID;
            opt.textContent = 'PLAN' + c.PLAN_ORDER + ' · ' + c.CODE + ' — ' + c.LIBELLE;
            opt.setAttribute('data-plan-order', c.PLAN_ORDER);
            cm.appendChild(opt);
        });
    }
}

// ════════════════════════════════════════════════════════════
// CHARGEMENT DE LA LISTE
// ════════════════════════════════════════════════════════════
async function loadTiers(options) {
    options = options || {};
    var silent = !!options.silent;
    if (!silent) showSpinner();
    try {
        var params = new URLSearchParams({
            page:      AppState.page,
            pageSize:  AppState.pageSize,
            search:    AppState.filters.search,
            type:      AppState.filters.type,
            compteId:  AppState.filters.compteId,
            planOrder: AppState.filters.planOrder || '',
            status:    AppState.filters.status,
            sort:      AppState.sortField,
            order:     AppState.sortOrder
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
        var resp = await fetch(url);
        var data = await resp.json();

        if (data.success) {
            AppState.tiers = data.tiers || [];
            AppState.total = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || Math.ceil(AppState.total / AppState.pageSize) || 0);
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages) AppState.page = AppState.totalPages;
            renderTable(AppState.tiers);
            loadStats();
            createPaginationControls(AppState.totalPages);
            updateCounter();
        } else {
            showErrorToast(data.message || _t('tiers.msg.load_error'));
        }
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        if (!silent) hideSpinner();
    }
}

function updateCounter() {
    var el = document.getElementById('resultsCounter');
    if (el) el.textContent = _t('tiers.counter').replace('{n}', AppState.total);
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
    } catch (err) { console.error('[loadStats] Erreur :', err); }
}

window.loadLookups = loadLookups;
window.loadTiers   = loadTiers;
window.loadStats   = loadStats;
