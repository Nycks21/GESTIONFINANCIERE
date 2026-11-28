// loaders.js — SAISIE (orchestrateur + options auxiliaire + expansion lignes + Vue bridge)
// ⭐ Mise à jour : chargement des comptes par plan dans loadLookups()
// ⭐ Mise à jour : hook afterLookupsLoaded() → applique la restriction PLAN1
// ⭐ NOUVEAU : pré-sélection du site par défaut (EN_COURS prioritaire)
'use strict';
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// ============================================================
// ⭐ HELPER — DÉTERMINATION DU SITE PAR DÉFAUT
//    Priorité 1 : site EN_COURS = true
//    Priorité 2 : site CODE = '01'
//    Priorité 3 : premier site de la liste
//    Retourne '' si aucun site actif.
// ============================================================
function getDefaultSiteId() {
    var sites = (AppState && AppState.sites) ? AppState.sites : [];
    if (!sites.length) return '';

    // Priorité 1 : site marqué "en cours"
    for (var i = 0; i < sites.length; i++) {
        if (sites[i].EN_COURS === true || sites[i].EN_COURS === 1) {
            return sites[i].ID;
        }
    }
    // Priorité 2 : site avec CODE = '01'
    for (var j = 0; j < sites.length; j++) {
        if (String(sites[j].CODE) === '01') {
            return sites[j].ID;
        }
    }
    // Priorité 3 : premier site de la liste
    return sites[0].ID;
}

// ============================================================
// ⭐ HELPER — APPLIQUE LE SITE PAR DÉFAUT AU <select id="ecrSite">
//    Peut être appelé plusieurs fois (idempotent).
// ============================================================
function applyDefaultSiteToSelect() {
    var s = document.getElementById('ecrSite');
    if (!s) return;

    var defaultSiteId = getDefaultSiteId();
    if (!defaultSiteId) {
        s.value = '';
        return;
    }
    s.value = defaultSiteId;

    // Log pour debug
    var found = null;
    var sites = AppState.sites || [];
    for (var i = 0; i < sites.length; i++) {
        if (sites[i].ID === defaultSiteId) { found = sites[i]; break; }
    }
    console.log('[applyDefaultSiteToSelect] Site par défaut →',
        defaultSiteId,
        found ? ('(' + found.CODE + ' — ' + found.NOM + ')') : '');
}

// ============================================================
// CHARGEMENT DES LOOKUPS
// ============================================================
async function loadLookups() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.LOOKUPS;
        var resp = await fetch(url);
        if (!resp.ok) throw new Error('HTTP ' + resp.status + ' lors du chargement des référentiels.');
        var data = await resp.json();

        if (!data.success) {
            throw new Error(data.message || 'Impossible de charger les référentiels.');
        }

        AppState.sites              = data.sites              || [];
        AppState.journaux           = data.journaux           || [];
        AppState.exercices          = data.exercices          || [];
        AppState.monnaies           = data.monnaies           || [];
        AppState.plansActifs        = data.plansActifs        || [];
        AppState.sourcesFinancement = data.sourcesFinancement || [];
        AppState.modes              = data.modes              || [];
        AppState.tiers              = data.tiers              || [];

        AppState.ecritureLinesCache = AppState.ecritureLinesCache || {};
        AppState.expandedEcritures  = AppState.expandedEcritures  || {};

        // Chargement parallèle des marchés
        await loadMarchesLookup();

        populateHeaderSelects();
        populateAuxiliaireOptions();
        renderFormPlanFields();
        renderGridHead();

        // ⭐ NOUVEAU : charge les comptes de chaque plan et peuple les <select>
        //    (indispensable pour que la restriction PLAN1 puisse être évaluée
        //    dès l'ouverture d'une écriture, et pour voir les options)
        await loadAllComptesActifs();

        // ⭐ NOUVEAU : applique la catégorie journal + restriction PLAN1
        //    (fonction définie dans grid.js)
        if (typeof afterLookupsLoaded === 'function') {
            afterLookupsLoaded();
        }

        // ⭐ NOUVEAU : garantit le binding du select journal même si grid.js
        //    a chargé avant que populateHeaderSelects() ne soit exécuté
        if (typeof _bindJournalCategoryListener === 'function') {
            try { _bindJournalCategoryListener(); } catch (e) { /* ignore */ }
        }

        // ⭐ Sync des journaux dans Vue si présent
        if (window._VueSaisieList && typeof window._VueSaisieList.syncJournaux === 'function') {
            window._VueSaisieList.syncJournaux();
        }
    } catch (err) {
        console.error('[loadLookups] Erreur :', err);
        throw err;
    }
}

// ============================================================
// CHARGEMENT DES MARCHÉS (select ecrMarche)
// ============================================================
async function loadMarchesLookup() {
    AppState.marchesLookup = [];

    if (!API.MARCHES) {
        console.warn('[loadMarchesLookup] API.MARCHES non défini — select ecrMarche vide');
        return;
    }

    try {
        var url = API.BASE + API.HANDLERS_PATH + API.MARCHES;
        var resp = await fetch(url);
        var ct   = (resp.headers.get('content-type') || '').toLowerCase();
        var text = await resp.text();

        // Détection robuste : HTML au lieu de JSON
        if (!resp.ok || !ct.includes('application/json') || text.trim().charAt(0) === '<') {
            console.warn('[loadMarchesLookup] Handler indisponible (HTTP ' + resp.status +
                         ') — select ecrMarche vide');
            return;
        }

        var data = JSON.parse(text);
        if (data.success) {
            AppState.marchesLookup = data.marches || [];
            console.log('[loadMarchesLookup] ' + AppState.marchesLookup.length + ' marché(s) chargé(s)');
        } else {
            console.warn('[loadMarchesLookup] Réponse non OK :', data.message);
        }
    } catch (err) {
        console.warn('[loadMarchesLookup] Ignoré :', err.message || err);
    }
}

// ============================================================
// PEUPLEMENT DES SELECTS D'ENTÊTE
// ============================================================
function populateHeaderSelects() {
    // ─── Sites ───
    var s = document.getElementById('ecrSite');
    if (s) {
        s.innerHTML = '<option value="">—</option>';
        AppState.sites.forEach(function (x) {
            var o = document.createElement('option');
            o.value = x.ID;
            o.textContent = x.CODE + ' — ' + x.NOM;
            if (x.EN_COURS === true || x.EN_COURS === 1) {
                o.setAttribute('data-en-cours', '1');
            }
            s.appendChild(o);
        });

        // ⭐ Pré-sélection du site par défaut (EN_COURS prioritaire)
        applyDefaultSiteToSelect();
    }

    // ─── Journaux (edit panel) ───
    var j = document.getElementById('ecrJournal');
    if (j) {
        j.innerHTML = '<option value="">—</option>';
        AppState.journaux.forEach(function (x) {
            var o = document.createElement('option');
            o.value = x.ID;
            o.textContent = x.CODE + ' — ' + x.LIBELLE;
            // ⭐ attr utilisé par _resolveCategorieJournal() si AppState.journaux
            //    n'expose pas CATEGORIE_JOURNAL (fallback DOM)
            o.setAttribute('data-categorie', x.CATEGORIE_JOURNAL);
            j.appendChild(o);
        });
    }

    // ─── Journal filter (LIST) — SKIP si Vue gère ───
    if (!window._VueSaisieList) {
        var jf = document.getElementById('journal-filter');
        if (jf) {
            jf.innerHTML = '<option value="">' + _t('saisie.filter.all_journals') + '</option>';
            AppState.journaux.forEach(function (x) {
                var o = document.createElement('option');
                o.value = x.ID;
                o.textContent = x.CODE;
                jf.appendChild(o);
            });
        }
    }

    // ─── Exercices ───
    var e = document.getElementById('ecrExercice');
    if (e) {
        e.innerHTML = '<option value="">—</option>';
        AppState.exercices.forEach(function (x) {
            var o = document.createElement('option');
            o.value = x.ID;
            o.textContent = x.CODE;
            e.appendChild(o);
        });
        if (AppState.exercices.length === 1) {
            e.value = AppState.exercices[0].ID;
        }
    }

    // ─── Monnaies ───
    var m = document.getElementById('ecrDevise');
    if (m) {
        m.innerHTML = '<option value="">—</option>';
        AppState.monnaies.forEach(function (x) {
            var o = document.createElement('option');
            o.value = x.ID;
            o.textContent = x.CODE;
            if (x.EST_REFERENCE) o.selected = true;
            m.appendChild(o);
        });
    }

    // ─── Marchés (ecrMarche) ───
    var mrc = document.getElementById('ecrMarche');
    if (mrc) {
        mrc.innerHTML = '<option value="">— Aucun marché —</option>';
        (AppState.marchesLookup || []).forEach(function (x) {
            var o = document.createElement('option');
            o.value = x.ID;

            var label = x.NUMERO;
            if (x.DESCRIPTION)     label += ' — ' + x.DESCRIPTION;
            if (x.FOURNISSEUR_NOM) label += ' (' + x.FOURNISSEUR_NOM + ')';
            o.textContent = label;

            o.setAttribute('data-marche-id',     x.ID);
            o.setAttribute('data-marche-numero', x.NUMERO);
            o.setAttribute('data-statut',        x.STATUT);

            mrc.appendChild(o);
        });

        console.log('[populateHeaderSelects] ecrMarche →',
                    (AppState.marchesLookup || []).length, 'option(s)');
    }

    // ─── Modes ───
    var mo = document.getElementById('flMode');
    if (mo) {
        mo.innerHTML = '<option value="">—</option>';
        (AppState.modes || []).forEach(function (x) {
            var o = document.createElement('option');
            o.value = x.CODE;
            o.textContent = x.LIBELLE;
            mo.appendChild(o);
        });
    }

    // ─── Subvention ───
    var sb = document.getElementById('flSub');
    if (sb) {
        sb.innerHTML = '<option value="">—</option>';
        (AppState.sourcesFinancement || []).forEach(function (x) {
            var o = document.createElement('option');
            o.value = x.CODE;
            o.textContent = x.LIBELLE;
            sb.appendChild(o);
        });
    }
}

// ============================================================
// ⭐ HELPER PUBLIC — rafraîchir le select marché
// ============================================================
async function refreshMarchesLookup() {
    await loadMarchesLookup();
    var mrc = document.getElementById('ecrMarche');
    if (!mrc) return;

    var current = mrc.value;

    mrc.innerHTML = '<option value="">— Aucun marché —</option>';
    (AppState.marchesLookup || []).forEach(function (x) {
        var o = document.createElement('option');
        o.value = x.ID;
        var label = x.NUMERO;
        if (x.DESCRIPTION)     label += ' — ' + x.DESCRIPTION;
        if (x.FOURNISSEUR_NOM) label += ' (' + x.FOURNISSEUR_NOM + ')';
        o.textContent = label;
        o.setAttribute('data-marche-id', x.ID);
        o.setAttribute('data-marche-numero', x.NUMERO);
        o.setAttribute('data-statut', x.STATUT);
        mrc.appendChild(o);
    });

    if (current) mrc.value = current;
}

// ============================================================
// PEUPLEMENT DU <select id="flAux"> DEPUIS FTIERS
// ============================================================
function populateAuxiliaireOptions(filterByPlanElementId, preserveValue) {
    var sel = document.getElementById('flAux');
    if (!sel) return;

    var currentVal = preserveValue ? sel.value : '';
    sel.innerHTML = '<option value="">—</option>';

    var allTiers = AppState.tiers || [];
    var tiers = allTiers;
    var isFiltered = false;

    if (filterByPlanElementId) {
        var filtered = allTiers.filter(function (t) {
            return t.PLAN_ELEMENT_ID === filterByPlanElementId;
        });
        if (filtered.length) {
            tiers = filtered;
            isFiltered = true;
        }
    }

    tiers.forEach(function (t) {
        var o = document.createElement('option');
        o.value = t.CODE;
        o.textContent = t.CODE + ' — ' + t.NOM;
        o.setAttribute('data-tiers-id', t.ID);
        o.setAttribute('data-type-tiers', t.TYPE_TIERS || '');
        if (t.PLAN_ORDER != null) {
            o.setAttribute('data-plan-order', t.PLAN_ORDER);
        }
        sel.appendChild(o);
    });

    if (currentVal) {
        sel.value = currentVal;
        if (sel.value !== currentVal) {
            var opt = document.createElement('option');
            opt.value = currentVal;
            opt.textContent = currentVal + ' (' + _t('saisie.hint.out_of_filter') + ')';
            sel.appendChild(opt);
            sel.value = currentVal;
        }
    }

    sel.setAttribute('data-filtered', isFiltered ? '1' : '0');
    sel.setAttribute('data-count', tiers.length);
}

// ============================================================
// PÉRIODES
// ============================================================
var periodesLoadRequestId = 0;
var lastExerciceWarningDate = '';

async function loadPeriodes(exerciceId) {
    var requestId = ++periodesLoadRequestId;
    AppState.periodes = [];
    AppState.periodesExerciceId = '';
    if (!exerciceId) return;

    try {
        var url = API.BASE + API.HANDLERS_PATH + API.PERIODES
                + '?exerciceId=' + encodeURIComponent(exerciceId);

        var resp = await fetch(url);
        var ct   = (resp.headers.get('content-type') || '').toLowerCase();
        var text = await resp.text();

        if (!resp.ok || !ct.includes('application/json') || text.trim().charAt(0) === '<')
            throw new Error('Impossible de charger les périodes (HTTP ' + resp.status + ').');

        var data = JSON.parse(text);
        if (!data.success) throw new Error(data.message || 'Impossible de charger les périodes.');
        if (requestId !== periodesLoadRequestId) return;
        AppState.periodes = data.periodes || [];
        AppState.periodesExerciceId = String(exerciceId);
        console.log('[loadPeriodes] ' + AppState.periodes.length + ' période(s) chargée(s)');
    } catch (err) {
        if (requestId !== periodesLoadRequestId) return;
        console.error('[loadPeriodes] Erreur :', err);
        throw err;
    }
}

function findExerciceIdByDate(dateStr) {
    var date = String(dateStr || '').substring(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return '';

    var exercice = (AppState.exercices || []).find(function (item) {
        var debut = String(item.DATE_DEBUT || '').substring(0, 10);
        var fin = String(item.DATE_FIN || '').substring(0, 10);
        return debut && fin && date >= debut && date <= fin;
    });
    return exercice ? String(exercice.ID || '') : '';
}

function showExerciceUnavailableAlert() {
    return Swal.fire({
        icon: 'warning',
        title: _t('saisie.msg.validation_error') || 'Erreur de validation',
        text: _t('saisie.msg.exercice_unavailable')
            || 'L’exercice correspondant à cette date est clôturé ou n’existe pas. Choisissez un exercice ouvert.',
        confirmButtonText: _t('button.ok') || 'OK',
        allowOutsideClick: false,
        allowEscapeKey: false
    });
}

async function syncExerciceFromDate(dateStr) {
    var date = String(dateStr || '').substring(0, 10);
    var exerciceId = findExerciceIdByDate(date);
    if (!exerciceId) {
        _setVal('ecrExercice', '');
        _setVal('ecrPeriode', '');
        await loadPeriodes('');
        if (date && lastExerciceWarningDate !== date) {
            if (typeof isDatePieceAfterComptable !== 'function'
                || !isDatePieceAfterComptable()) {
                lastExerciceWarningDate = date;
                showExerciceUnavailableAlert();
            }
        }
        return '';
    }
    lastExerciceWarningDate = '';

    if (String(_getVal('ecrExercice') || '') !== exerciceId) {
        _setVal('ecrExercice', exerciceId);
        _setVal('ecrPeriode', '');
    }

    if (String(AppState.periodesExerciceId || '') !== exerciceId) {
        await loadPeriodes(exerciceId);
    }

    if (String(_getVal('ecrDate') || '').substring(0, 10) === date
        && String(AppState.periodesExerciceId || '') === exerciceId) {
        _setVal('ecrPeriode', findPeriodeId(date));
    }
    return exerciceId;
}

function findPeriodeId(dateStr) {
    if (!dateStr) return '';
    var d = dateStr.substring(0, 10);

    if (AppState.periodes && AppState.periodes.length) {
        for (var i = 0; i < AppState.periodes.length; i++) {
            var p = AppState.periodes[i];
            if (String(p.STATUT || '').toUpperCase() !== 'OUVERTE') continue;
            var debut = (p.DATE_DEBUT || '').substring(0, 10);
            var fin   = (p.DATE_FIN   || '').substring(0, 10);
            if (d >= debut && d <= fin) return p.ID;
        }
    }
    var exerciceId = _getVal('ecrExercice');
    return exerciceId
        && AppState.periodesExerciceId === exerciceId
        && AppState.periodes.length === 0
        ? exerciceId
        : '';
}

// ============================================================
// COMPTES PAR PLAN
// ============================================================
async function loadComptesByPlan(ordre) {
    if (AppState.comptesParPlan[ordre]) return AppState.comptesParPlan[ordre];
    var url = API.BASE + API.HANDLERS_PATH + API.COMPTES_BY_PLAN + '?planOrder=' + ordre;
    var resp = await fetch(url);
    if (!resp.ok) throw new Error('HTTP ' + resp.status + ' lors du chargement du plan ' + ordre + '.');
    var data = await resp.json();
    if (!data.success) throw new Error(data.message || 'Impossible de charger le plan ' + ordre + '.');
    AppState.comptesParPlan[ordre] = data.comptes || [];
    return AppState.comptesParPlan[ordre];
}

async function loadAllComptesActifs() {
    var active = getActivePlanFields();
    if (!active.length) return;
    var promises = active.map(function (p) { return loadComptesByPlan(p.ordre); });
    await Promise.all(promises);
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
// ÉCRITURES — LISTE
// ============================================================
var ecrituresListRequestId = 0;

async function loadEcritures(opts) {
    opts = opts || {};
    var silent = !!opts.silent;

    if (window._VueSaisieList && typeof window._VueSaisieList.load === 'function') {
        if (!silent) showSpinner();
        try {
            await window._VueSaisieList.load();
        } finally {
            if (!silent) hideSpinner();
        }
        return;
    }

    var requestId = ++ecrituresListRequestId;
    if (!silent) showSpinner();

    AppState.expandedEcritures = {};

    try {
        var params = new URLSearchParams({
            page:      AppState.page,
            pageSize:  AppState.pageSize,
            search:    AppState.filters.search,
            journalId: AppState.filters.journalId || '',
            statut:    AppState.filters.statut    || ''
        });
        var url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
        var resp = await fetch(url);
        var data = await resp.json();

        if (requestId !== ecrituresListRequestId) return;
        if (!resp.ok) throw new Error(data.message || _t('saisie.msg.load_error'));

        if (data.success) {
            AppState.ecritures  = data.ecritures || [];
            AppState.total      = Number(data.total || 0);
            AppState.totalPages = Number(data.totalPages || 0);
            if (AppState.page < 1) AppState.page = 1;
            if (AppState.totalPages > 0 && AppState.page > AppState.totalPages) {
                AppState.page = AppState.totalPages;
                await loadEcritures({ silent: silent });
                return;
            }
            renderEcrituresList();
            createPaginationControls(AppState.totalPages);

            var c = document.getElementById('resultsCounter');
            if (c) c.textContent = AppState.total + ' ' + _t('saisie.counter_unit');
        } else {
            showEcrituresListError();
            showErrorToast(data.message || _t('message.error'));
        }
    } catch (err) {
        if (requestId !== ecrituresListRequestId) return;
        showEcrituresListError();
        showErrorToast(err.message);
    } finally {
        if (requestId === ecrituresListRequestId) hideSpinner();
    }
}

function showEcrituresListError() {
    AppState.ecritures = [];
    AppState.total = 0;
    AppState.totalPages = 0;

    var tb = document.getElementById('ecrituresBody');
    if (tb) {
        tb.innerHTML = '<tr><td colspan="12" class="table-empty">'
            + escapeHtml(_t('saisie.msg.load_error')) + '</td></tr>';
    }

    var pagination = document.getElementById('paginationWrapper');
    if (pagination) pagination.innerHTML = '';
    var counter = document.getElementById('resultsCounter');
    if (counter) counter.textContent = '0 ' + _t('saisie.counter_unit');
}

function renderEcrituresList() {
    if (window._VueSaisieList) return;

    var tb = document.getElementById('ecrituresBody');
    if (!tb) return;

    if (!AppState.ecritures.length) {
        tb.innerHTML = '<tr><td colspan="12" class="table-empty">'
            + '<i class="fas fa-inbox"></i>'
            + '<span>' + _t('saisie.msg.no_data') + '</span></td></tr>';
        return;
    }

    var html = '';
    AppState.ecritures.forEach(function (e) {
        var sc = 'statut-' + (e.STATUT || 'brouillon').toLowerCase();
        var isExpanded = !!AppState.expandedEcritures[e.ID];
        var chevron = isExpanded
            ? '<i class="fas fa-chevron-down"></i>'
            : '<i class="fas fa-chevron-right"></i>';

        var statutLabel = _t('saisie.statut.' + (e.STATUT || 'BROUILLON')) || e.STATUT;

        var datePiece = e.DATE_PIECE || '';
        var totalDebitRap = parseFloat(e.TOTAL_DEBIT_RAP || 0) || 0;
        var totalCreditRap = parseFloat(e.TOTAL_CREDIT_RAP || 0) || 0;

        html += '<tr class="ecr-main-row" data-id="' + e.ID + '">'
            + '<td style="text-align:center;">'
            +   '<button type="button" class="btn-toggle-ecr" '
            +     'data-toggle-ecr="' + e.ID + '" '
            +     'onclick="toggleEcritureLines(\'' + e.ID + '\', event)" '
            +     'title="' + _t('saisie.action.toggle_lines') + '"'
            +     'style="background:none;border:none;cursor:pointer;color:#007bff;padding:4px 8px;">'
            +     chevron + '</button>'
            + '</td>'
            + '<td><span class="badge-code">' + escapeHtml(e.REFERENCE || '—') + '</span></td>'
            + '<td>' + (datePiece ? escapeHtml(datePiece) : '<span class="cell-empty">—</span>') + '</td>'
            + '<td>' + escapeHtml(e.DATE_COMPTABLE || '') + '</td>'
            + '<td><span class="badge-journal">' + escapeHtml(e.JOURNAL_CODE || '?') + '</span></td>'
            + '<td>' + escapeHtml(e.LIBELLE || '') + '</td>'
            + '<td style="text-align:right;font-family:monospace;color:#B91C1C;">' + formatMontant(e.TOTAL_DEBIT) + '</td>'
            + '<td style="text-align:right;font-family:monospace;color:#047857;">' + formatMontant(e.TOTAL_CREDIT) + '</td>'
            + '<td style="text-align:right;font-family:monospace;color:#B91C1C;">'
            +     (totalDebitRap > 0 ? formatMontant(totalDebitRap) : '<span class="cell-empty">0,00</span>')
            + '</td>'
            + '<td style="text-align:right;font-family:monospace;color:#047857;">'
            +     (totalCreditRap > 0 ? formatMontant(totalCreditRap) : '<span class="cell-empty">0,00</span>')
            + '</td>'
            + '<td style="text-align:center;"><span class="badge-statut ' + sc + '">' + escapeHtml(statutLabel) + '</span></td>'
            + '<td style="text-align:right;">'
            +   '<button type="button" class="btn btn-sm btn-primary" onclick="editEcriture(\'' + e.ID + '\')" title="' + _t('button.edit') + '"><i class="fas fa-edit"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-danger" onclick="deleteEcriture(\'' + e.ID + '\')" title="' + _t('button.delete') + '"><i class="fas fa-trash"></i></button>'
            + '</td>'
            + '</tr>';

        if (isExpanded && AppState.ecritureLinesCache[e.ID]) {
            html += buildEcritureLinesRow(e.ID, AppState.ecritureLinesCache[e.ID]);
        }
    });
    tb.innerHTML = html;
}

function buildEcritureLinesRow(ecritureId, lignes) {
    var plans = getActivePlanFields();

    var headHtml = '<th style="width:36px;">#</th>';
    headHtml += '<th style="width:90px;">' + _t('saisie.col.auxiliaire') + '</th>';
    plans.forEach(function (p) {
        headHtml += '<th style="width:90px;">' + escapeHtml(p.label) + '</th>';
    });
    headHtml += '<th>' + _t('saisie.col.libelle') + '</th>';
    headHtml += '<th style="width:110px;text-align:right;">' + _t('saisie.col.debit')      + '</th>';
    headHtml += '<th style="width:110px;text-align:right;">' + _t('saisie.col.credit')     + '</th>';
    headHtml += '<th style="width:110px;text-align:right;">' + _t('saisie.col.debit_rap')  + '</th>';
    headHtml += '<th style="width:110px;text-align:right;">' + _t('saisie.col.credit_rap') + '</th>';

    var totalCols = 2 + plans.length + 5;

    var bodyHtml = '';
    if (!lignes || !lignes.length) {
        bodyHtml = '<tr><td colspan="' + totalCols + '" '
            + 'style="text-align:center;padding:16px;color:#94A3B8;font-style:italic;">'
            + _t('saisie.msg.no_lines_entry') + '</td></tr>';
    } else {
        lignes.forEach(function (l, i) {
            var debit  = parseFloat(l.DEBIT  || 0);
            var credit = parseFloat(l.CREDIT || 0);

            var montantDevise = parseFloat(l.MONTANT_DEVISE || 0) || 0;
            var sens = l.SENS || (debit > 0 ? 'D' : (credit > 0 ? 'C' : null));

            var debitRap  = (sens === 'D') ? montantDevise : 0;
            var creditRap = (sens === 'C') ? montantDevise : 0;

            bodyHtml += '<tr style="border-bottom:1px solid #e9ecef;">';
            bodyHtml += '<td style="text-align:center;color:#94A3B8;">' + (i + 1) + '</td>';
            bodyHtml += '<td>' + escapeHtml(l.AUXILIAIRE || '\u2014') + '</td>';

            plans.forEach(function (p) {
                var val = l['PLAN' + p.ordre];
                var code = val ? resolvePlanCodeByOrdre(p.ordre, val) : '';
                bodyHtml += '<td><span class="cell-badge" title="' + escapeHtml(code) + '">'
                          + (escapeHtml(code) || '\u2014') + '</span></td>';
            });

            bodyHtml += '<td>' + escapeHtml(l.LIBELLE || '') + '</td>';
            bodyHtml += '<td style="text-align:right;font-family:monospace;color:#B91C1C;">'
                      + (debit  > 0 ? formatMontant(debit)  : '') + '</td>';
            bodyHtml += '<td style="text-align:right;font-family:monospace;color:#047857;">'
                      + (credit > 0 ? formatMontant(credit) : '') + '</td>';
            bodyHtml += '<td style="text-align:right;font-family:monospace;color:#B91C1C;">'
                      + (debitRap  > 0 ? formatMontant(debitRap)  : '') + '</td>';
            bodyHtml += '<td style="text-align:right;font-family:monospace;color:#047857;">'
                      + (creditRap > 0 ? formatMontant(creditRap) : '') + '</td>';
            bodyHtml += '</tr>';
        });
    }

    var sumDebitRap = lignes.reduce(function (s, x) {
        var d = parseFloat(x.DEBIT || 0);
        var sens = x.SENS || (d > 0 ? 'D' : null);
        return s + (sens === 'D' ? (parseFloat(x.MONTANT_DEVISE || 0) || 0) : 0);
    }, 0);
    var sumCreditRap = lignes.reduce(function (s, x) {
        var c = parseFloat(x.CREDIT || 0);
        var sens = x.SENS || (c > 0 ? 'C' : null);
        return s + (sens === 'C' ? (parseFloat(x.MONTANT_DEVISE || 0) || 0) : 0);
    }, 0);

    var summaryHtml = '<div style="margin-top:8px;font-size:11px;color:#6c757d;">'
        + lignes.length + ' ' + _t('saisie.lines_count_unit') + ' \u2014 '
        + _t('saisie.col.debit') + ' : '
        + '<strong style="color:#B91C1C;">'
        + formatMontant(lignes.reduce(function (s, x) { return s + parseFloat(x.DEBIT || 0); }, 0))
        + '</strong> \u2014 ' + _t('saisie.col.credit') + ' : '
        + '<strong style="color:#047857;">'
        + formatMontant(lignes.reduce(function (s, x) { return s + parseFloat(x.CREDIT || 0); }, 0))
        + '</strong>'
        + ' &nbsp;\u00B7&nbsp; '
        + _t('saisie.col.debit_rap') + ' : '
        + '<strong style="color:#B91C1C;">' + formatMontant(sumDebitRap) + '</strong>'
        + ' \u2014 ' + _t('saisie.col.credit_rap') + ' : '
        + '<strong style="color:#047857;">' + formatMontant(sumCreditRap) + '</strong>'
        + '</div>';

    return '<tr class="ecr-sub-row" data-ecriture-id="' + ecritureId + '">'
        +   '<td colspan="12" style="padding:0;background:#f8f9fa;border-bottom:2px solid #dee2e6;">'
        +     '<div style="padding:10px 20px 14px;">'
        +       '<table style="width:100%;font-size:12px;border-collapse:collapse;">'
        +         '<thead><tr style="background:#e9ecef;color:#495057;font-size:11px;text-transform:uppercase;letter-spacing:.5px;">'
        +           headHtml
        +         '</tr></thead>'
        +         '<tbody>' + bodyHtml + '</tbody>'
        +       '</table>'
        +       summaryHtml
        +     '</div>'
        +   '</td>'
        + '</tr>';
}

async function toggleEcritureLines(ecritureId, e) {
    if (e) e.stopPropagation();

    if (window._VueSaisieList && typeof window._VueSaisieList.toggleLines === 'function') {
        window._VueSaisieList.toggleLines(ecritureId);
        return;
    }

    var btn = document.querySelector('button[data-toggle-ecr="' + escritureIdSafe(ecritureId) + '"]');
    var existingSub = document.querySelector('tr.ecr-sub-row[data-ecriture-id="' + escritureIdSafe(ecritureId) + '"]');

    if (existingSub && AppState.expandedEcritures[ecritureId]) {
        AppState.expandedEcritures[ecritureId] = false;
        existingSub.remove();
        if (btn) btn.innerHTML = '<i class="fas fa-chevron-right"></i>';
        return;
    }

    AppState.expandedEcritures[ecritureId] = true;
    if (btn) btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i>';

    var lignes = AppState.ecritureLinesCache[ecritureId];

    if (!lignes) {
        try {
            var url = API.BASE + API.HANDLERS_PATH + API.DETAIL + '?id=' + encodeURIComponent(ecritureId);
            var resp = await fetch(url);
            var data = await resp.json();
            if (!data.success) {
                showErrorToast(data.message || _t('saisie.msg.load_error'));
                AppState.expandedEcritures[ecritureId] = false;
                if (btn) btn.innerHTML = '<i class="fas fa-chevron-right"></i>';
                return;
            }
            lignes = data.lignes || [];
            AppState.ecritureLinesCache[ecritureId] = lignes;
        } catch (err) {
            showErrorToast(err.message);
            AppState.expandedEcritures[ecritureId] = false;
            if (btn) btn.innerHTML = '<i class="fas fa-chevron-right"></i>';
            return;
        }
    }

    var mainRow = document.querySelector('tr.ecr-main-row[data-id="' + escritureIdSafe(ecritureId) + '"]');
    if (mainRow) {
        var tmp = document.createElement('tbody');
        tmp.innerHTML = buildEcritureLinesRow(ecritureId, lignes);
        mainRow.parentNode.insertBefore(tmp.firstChild, mainRow.nextSibling);
    }

    if (btn) btn.innerHTML = '<i class="fas fa-chevron-down"></i>';
}

function escritureIdSafe(id) {
    return String(id || '').replace(/[^a-zA-Z0-9\-]/g, '');
}

function _refreshLinesCounter() {
    var el = document.getElementById('ecrLinesCounter');
    if (!el) return;
    var n = (AppState && AppState.lignes) ? AppState.lignes.length : 0;
    if (n > 0) {
        el.textContent = '(' + n + ' ' + _t('saisie.lines_count_unit') + ')';
        el.style.display = 'inline-block';
    } else {
        el.style.display = 'none';
    }
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.loadLookups               = loadLookups;
window.loadMarchesLookup         = loadMarchesLookup;
window.refreshMarchesLookup      = refreshMarchesLookup;
window.populateHeaderSelects     = populateHeaderSelects;
window.populateAuxiliaireOptions = populateAuxiliaireOptions;
window.loadPeriodes              = loadPeriodes;
window.findPeriodeId             = findPeriodeId;
window.findExerciceIdByDate      = findExerciceIdByDate;
window.syncExerciceFromDate      = syncExerciceFromDate;
window.showExerciceUnavailableAlert = showExerciceUnavailableAlert;
window.loadComptesByPlan         = loadComptesByPlan;
window.loadAllComptesActifs      = loadAllComptesActifs;
window.loadEcritures             = loadEcritures;
window.renderEcrituresList       = renderEcrituresList;
window.toggleEcritureLines       = toggleEcritureLines;
window.buildEcritureLinesRow     = buildEcritureLinesRow;
window.resolvePlanCodeByOrdre    = resolvePlanCodeByOrdre;
window._refreshLinesCounter      = _refreshLinesCounter;

// ⭐ Helpers site par défaut
window.getDefaultSiteId          = getDefaultSiteId;
window.applyDefaultSiteToSelect  = applyDefaultSiteToSelect;
