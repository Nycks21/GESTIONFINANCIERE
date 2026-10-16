// loaders.js — MARCHE (version robuste)
'use strict';
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// ============================================================
// FETCH JSON ROBUSTE — détecte tout type de réponse anormale
// ============================================================
async function _fetchJson(url, label) {
    var resp;
    try {
        resp = await fetch(url);
    } catch (netErr) {
        throw new Error((label || 'Requête') + ' : impossible de joindre le serveur (' + netErr.message + ')');
    }

    var ct   = (resp.headers.get('content-type') || '').toLowerCase();
    var text = await resp.text();

    // 1. Statut HTTP anormal
    if (!resp.ok) {
        var preview = text.substring(0, 200).replace(/\s+/g, ' ');
        throw new Error(
            (label || 'Requête') + ' : HTTP ' + resp.status + ' — ' + preview
        );
    }

    // 2. Réponse HTML au lieu de JSON
    if (text.trim().charAt(0) === '<') {
        var preview2 = text.substring(0, 200).replace(/\s+/g, ' ');
        throw new Error(
            (label || 'Requête') + ' : réponse HTML reçue (session expirée ou erreur serveur). Extrait : ' + preview2
        );
    }

    // 3. Parse JSON
    try {
        return JSON.parse(text);
    } catch (e) {
        throw new Error((label || 'Requête') + ' : JSON invalide — ' + e.message);
    }
}

// ============================================================
// CHARGEMENT DES LOOKUPS
// ============================================================
async function loadLookups() {
    try {
        var url  = API.BASE + API.HANDLERS_PATH + API.LOOKUPS;
        var data = await _fetchJson(url, 'GetMarcheLookups');

        if (!data.success) {
            console.warn('[loadLookups] Réponse non OK :', data.message);
            if (typeof showErrorToast === 'function')
                showErrorToast(data.message || 'Erreur lookups');
            return false;
        }

        // ─── Remplissage AppState ───
        AppState.sites         = data.sites         || [];
        AppState.fournisseurs  = data.fournisseurs  || [];
        AppState.articles      = data.articles      || [];
        AppState.monnaies      = data.monnaies      || [];
        AppState.plansActifs   = data.plansActifs   || [];
        AppState.marcheLinesCache = AppState.marcheLinesCache || {};
        AppState.expandedMarches  = AppState.expandedMarches  || {};

        // ─── Remplissage des selects ───
        populateHeaderSelects();

        // ⭐ marAuxi vide tant qu'aucun fournisseur (règle métier)
        populateMarAuxiOptions(null, false);

        renderFormPlanFields();

        // ─── Diagnostic lisible ───
        var missing = [];
        if (!AppState.fournisseurs.length) missing.push('FOURNISSEURS (PLAN1)');
        if (!AppState.articles.length)     missing.push('ARTICLES (MARTICLE)');
        if (!AppState.monnaies.length)     missing.push('MONNAIES (FMONNAIE)');

        console.log('[loadLookups] ✅',
            '| sites='        + AppState.sites.length,
            '| fournisseurs=' + AppState.fournisseurs.length,
            '| articles='     + AppState.articles.length,
            '| monnaies='     + AppState.monnaies.length,
            '| plans='        + AppState.plansActifs.length);

        if (missing.length) {
            console.warn('[loadLookups] ⚠️ Tables vides :', missing.join(', '),
                         '→ insérez des données de test (voir SEED MYSET)');
        }

        return true;
    } catch (err) {
        console.error('[loadLookups] ❌', err.message || err);
        if (typeof showErrorToast === 'function')
            showErrorToast(err.message || 'Erreur lors du chargement des référentiels.');
        return false;
    }
}

// ============================================================
// PEUPLEMENT DES SELECTS D'ENTÊTE
// ============================================================
function populateHeaderSelects() {
    _fillSelect('marSite',        AppState.sites,        'ID', '—');
    _fillSelect('marFournisseur', AppState.fournisseurs, 'ID', '—');
    _fillSelect('mlArticle',      AppState.articles,     'ID', '—');
}

function _fillSelect(selectId, arr, valueKey, placeholder) {
    var sel = document.getElementById(selectId);
    if (!sel) return;

    sel.innerHTML = '';
    var o0 = document.createElement('option');
    o0.value = '';
    o0.textContent = placeholder || '—';
    sel.appendChild(o0);

    (arr || []).forEach(function (x) {
        var o = document.createElement('option');
        o.value = x[valueKey] || '';
        o.textContent = ((x.CODE || '') + ' — ' + (x.NOM || '')).replace(/^ — | — $/g, '');
        sel.appendChild(o);
    });
}

// ============================================================
// AUXILIAIRES — Chargement dynamique par fournisseur
// ============================================================
var _auxFetchToken = 0;

async function populateMarAuxiOptions(filterByFournisseurId, preserveValue) {
    var sel  = document.getElementById('marAuxi');
    var hint = document.getElementById('marAuxHint');
    if (!sel) return;

    var currentVal = preserveValue ? sel.value : '';
    var token = ++_auxFetchToken;

    // Cas 1 : aucun fournisseur → vide
    if (!filterByFournisseurId) {
        sel.innerHTML = '<option value="">—</option>';
        sel.value = '';
        sel.disabled = true;
        sel.setAttribute('data-count', '0');
        sel.setAttribute('data-filtered', '0');
        _setAuxHint(hint, 'marche.hint.aux_initial', 'info');
        return;
    }

    // Cas 2 : chargement
    sel.disabled = true;
    sel.innerHTML = '<option value="">' + (_t('common.loading') || 'Chargement…') + '</option>';
    _setAuxHint(hint, 'marche.hint.aux_loading', 'info');

    try {
        var url  = API.BASE + API.HANDLERS_PATH + API.AUX_BY_FOURNISSEUR
                 + '?fournisseurId=' + encodeURIComponent(filterByFournisseurId);
        var data = await _fetchJson(url, 'GetAuxiliairesByFournisseur');

        if (token !== _auxFetchToken) return;   // réponse obsolète

        if (!data.success) {
            _fillAuxSelect(sel, [], '');
            sel.disabled = false;
            sel.setAttribute('data-count', '0');
            sel.setAttribute('data-filtered', '1');
            _setAuxHint(hint, 'marche.hint.aux_error', 'error');
            console.error('[populateMarAuxiOptions]', data.message || 'Réponse invalide.');
            return;
        }

        var auxiliaires = data.auxiliaires || [];
        _fillAuxSelect(sel, auxiliaires, currentVal);
        sel.disabled = false;
        sel.setAttribute('data-count', auxiliaires.length);

        if (auxiliaires.length === 0) {
            _setAuxHint(hint, 'marche.hint.aux_empty', 'warning');
            return;
        }
        if (auxiliaires.length === 1) {
            sel.value = auxiliaires[0].CODE;
        }
        _setAuxHint(hint, 'marche.hint.aux_filtered', 'success');

    } catch (err) {
        if (token !== _auxFetchToken) return;
        _fillAuxSelect(sel, [], '');
        sel.disabled = false;
        sel.setAttribute('data-count', '0');
        sel.setAttribute('data-filtered', '1');
        _setAuxHint(hint, 'marche.hint.aux_error', 'error');
        console.error('[populateMarAuxiOptions]', err.message || err);
    }
}

function _fillAuxSelect(sel, auxiliaires, currentVal) {
    sel.innerHTML = '<option value="">—</option>';
    (auxiliaires || []).forEach(function (t) {
        var o = document.createElement('option');
        o.value = t.CODE;
        o.textContent = (t.CODE || '') + ' — ' + (t.NOM || '');
        o.setAttribute('data-tiers-id', t.ID || '');
        if (t.TYPE_TIERS)      o.setAttribute('data-type-tiers', t.TYPE_TIERS);
        if (t.PLAN_ELEMENT_ID) o.setAttribute('data-plan-element-id', t.PLAN_ELEMENT_ID);
        sel.appendChild(o);
    });
    if (currentVal) {
        sel.value = currentVal;
        if (sel.value !== currentVal) sel.value = '';
    }
}

function _setAuxHint(el, key, type) {
    if (!el) return;
    el.textContent = _t(key) || '';
    el.setAttribute('data-hint-type', type || 'info');
    el.setAttribute('data-hint-key', key);
}

// ============================================================
// COMPTES PAR PLAN
// ============================================================
async function loadComptesByPlan(ordre) {
    if (AppState.comptesParPlan[ordre]) return AppState.comptesParPlan[ordre];
    try {
        var url  = API.BASE + API.HANDLERS_PATH + API.COMPTES_BY_PLAN + '?planOrder=' + ordre;
        var data = await _fetchJson(url, 'GetComptesByPlan(' + ordre + ')');
        if (data.success) {
            AppState.comptesParPlan[ordre] = data.comptes || [];
            return data.comptes || [];
        }
    } catch (err) {
        console.error('[loadComptesByPlan ' + ordre + ']', err.message || err);
    }
    return [];
}

async function loadAllComptesActifs() {
    var active = getActivePlanFields();
    if (!active.length) return;
    await Promise.all(active.map(function (p) { return loadComptesByPlan(p.ordre); }));
    populatePlanSelectsForm();
}

function resolvePlanCodeByOrdre(ordre, compteId) {
    if (!compteId) return '';
    var arr = AppState.comptesParPlan[ordre] || [];
    for (var i = 0; i < arr.length; i++) {
        if (arr[i].ID === compteId) return arr[i].CODE;
    }
    return compteId.substring(0, 8) + '…';
}

// ============================================================
// MARCHÉS — LISTE
// ============================================================
async function loadMarches(opts) {
    opts = opts || {};
    if (window._VueMarcheList && typeof window._VueMarcheList.load === 'function') {
        if (!opts.silent) showSpinner();
        try { await window._VueMarcheList.load(); }
        finally { if (!opts.silent) hideSpinner(); }
    }
}

// ============================================================
// PÉRIODES
// ============================================================
async function loadPeriodes(exerciceId) {
    AppState.periodes = [];
    if (!exerciceId) return;
    try {
        var url  = API.BASE + API.HANDLERS_PATH + API.PERIODES
                 + '?exerciceId=' + encodeURIComponent(exerciceId);
        var data = await _fetchJson(url, 'GetPeriodes');
        if (data.success) AppState.periodes = data.periodes || [];
    } catch (err) {
        console.error('[loadPeriodes]', err.message || err);
    }
}

function findPeriodeId(dateStr) {
    if (!dateStr) return '';
    var d = dateStr.substring(0, 10);
    if (AppState.periodes && AppState.periodes.length) {
        for (var i = 0; i < AppState.periodes.length; i++) {
            var p = AppState.periodes[i];
            if (d >= (p.DATE_DEBUT || '').substring(0, 10)
                && d <= (p.DATE_FIN || '').substring(0, 10)) return p.ID;
        }
    }
    return '';
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.loadLookups               = loadLookups;
window.populateHeaderSelects     = populateHeaderSelects;
window.populateMarAuxiOptions    = populateMarAuxiOptions;
window._fetchJson                = _fetchJson;
window.loadComptesByPlan         = loadComptesByPlan;
window.loadAllComptesActifs      = loadAllComptesActifs;
window.loadMarches               = loadMarches;
window.loadPeriodes              = loadPeriodes;
window.findPeriodeId             = findPeriodeId;
window.resolvePlanCodeByOrdre    = resolvePlanCodeByOrdre;

// ============================================================
// DIAGNOSTIC MANUEL — tapez `diagMarche()` dans la console
// ============================================================
window.diagMarche = async function () {
    console.log('═══════ DIAGNOSTIC MARCHE ═══════');
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.LOOKUPS;
        console.log('URL  :', url);

        var resp = await fetch(url);
        console.log('HTTP :', resp.status);
        console.log('TYPE :', resp.headers.get('content-type'));

        var data = await resp.json();
        console.log('success      :', data.success);
        console.log('sites        :', (data.sites || []).length);
        console.log('fournisseurs :', (data.fournisseurs || []).length, '← doit être > 0');
        console.log('articles     :', (data.articles || []).length);
        console.log('monnaies     :', (data.monnaies || []).length);
        console.log('plansActifs  :', (data.plansActifs || []).length);
        if (!(data.fournisseurs || []).length) {
            console.warn('⚠️  Aucun compte fournisseur admissible dans PLAN1.');
        }
    } catch (e) {
        console.error('❌ Erreur :', e.message);
    }
    console.log('═════════════════════════════════');
};
