// od-modal.js — Modale OD : sélection des écritures OD non soldées à reprendre
// ⭐ Ouverture conditionnelle déclenchée par form.js (_maybeOpenOdModal)
// ⭐ Filtrage serveur par compte PLAN1 + auxiliaire
// ⭐ Filtrage client local par recherche texte (défensif)
// ⭐ Action "Reprendre la sélection" :
//    - Génère 2 lignes par OD
//      • Ligne 4xxx : reprise de l'OD (contre-passation) +
//                     imputations PLAN2..PLAN10 de la ligne OD 2xxx/6xxx,
//                     SOURCE_FINANCEMENT, COMPTE_ID_SUB
//                     ⚠️ PLAN1 N'EST PAS copié de l'OD : il reste = compte choisi
//      • Ligne 5xxx : contrepartie banque (imputations analytiques à null)
//    - Insère les lignes dans AppState.lignes
//    - Accumule les sources de lettrage dans AppState.lettrageSources
'use strict';

// ============================================================
// ÉTAT LOCAL DE LA MODALE
// ============================================================
var _odState = {
    rows: [],
    filtered: [],
    page: 0,
    pageSize: 20,
    selected: {},
    context: null,
    loading: false,
    search: ''
};

// ============================================================
// POINT D'ENTRÉE PUBLIC
// ============================================================
async function openOdModal(filter) {
    filter = filter || {};
    _odState.context = {
        compteId:        filter.compteId || null,
        compteCode:      filter.compteCode || '',
        auxiliaireId:    filter.auxiliaireId || null,
        auxiliaireLabel: filter.auxiliaireLabel || '',
        sens:            filter.sens || 'D'
    };
    _odState.selected = {};
    _odState.page = 0;

    console.log('%c[od-modal] ouverture', 'color:#0a7;font-weight:bold', _odState.context);

    _showModal();
    _setModalTitle();
    _bindModalOnce();
    await _loadOdEntries();
}

function closeOdModal() {
    var modal = document.getElementById('odLettrageModal');
    if (modal) {
        modal.style.display = 'none';
        modal.classList.remove('show');
    }
    _odState.selected = {};
    _odState.rows = [];
    _odState.filtered = [];
    var search = document.getElementById('odSearchInput');
    if (search) search.value = '';
    _updateValidateButton();
}

function cancelOdModal() {
    closeOdModal();
    if (typeof window._unlockTreasuryManualLineAfterOdCancel === 'function') {
        window._unlockTreasuryManualLineAfterOdCancel();
    }
}

// ============================================================
// CHARGEMENT DES DONNÉES
// ============================================================
async function _loadOdEntries() {
    if (_odState.loading) return;
    _odState.loading = true;
    _renderLoading();

    try {
        var url = _buildOdUrl();
        console.log('[od-modal] GET', url);
        var resp = await fetch(url);
        var text = await resp.text();

        if (text.trim().charAt(0) === '<' || /^\s*using\s+System/i.test(text)) {
            _renderError(
                'Le handler répond en texte brut (source C#). ' +
                'Vérifiez que GetEcrituresODARegler.ashx est bien exécuté par IIS.'
            );
            return;
        }

        var data;
        try { data = JSON.parse(text); }
        catch (e) {
            _renderError('Réponse non JSON : ' + text.substring(0, 120));
            return;
        }

        if (data && data.success === false) {
            _renderError(data.message || 'Erreur de chargement');
            return;
        }

        var raw = data.lignes
               || data.rows
               || data.data
               || (Array.isArray(data) ? data : []);

        if (typeof data.total === 'number' && data.total > raw.length) {
            console.warn(
                '[od-modal] Seules ' + raw.length + '/' + data.total +
                ' lignes chargées (limite pageSize=200).'
            );
        }

        _odState.rows = raw.map(_normalizeRow);

        // ⭐ Diagnostic : combien d'OD ont des imputations à reprendre ?
        var withPlans = _odState.rows.filter(function (r) {
            var plans = _getImputationSource(r);
            for (var k = 2; k <= 10; k++) if (plans[k]) return true;
            return false;
        }).length;

        // ⭐ Diagnostic : détail des imputations pour CHAQUE OD (console)
        console.log(
            '[od-modal] ' + raw.length + ' ligne(s) chargée(s) — ' +
            withPlans + ' avec imputations PLAN2..PLAN10'
        );
        _odState.rows.forEach(function (r) {
            var imput = _describeImputations(r);
            console.log(
                '[od-modal] OD ' + (r.numero || r.id) +
                ' | aux=' + (r.auxiliaire || '—') +
                ' | sens=' + r.sens +
                ' | solde=' + r.soldeRestant +
                ' | ' + imput
            );
        });

        _applyFilter(_odState.search || '');
    } catch (err) {
        console.error('[od-modal] erreur chargement', err);
        _renderError(err.message || 'Erreur réseau');
    } finally {
        _odState.loading = false;
    }
}

function _buildOdUrl() {
    var ctx = _odState.context || {};
    var base = (window.API && API.BASE ? API.BASE : '') +
               (window.API && API.HANDLERS_PATH ? API.HANDLERS_PATH : 'handlers/');
    var endpoint = window.OD_API_ENDPOINT || 'GetEcrituresODARegler.ashx';
    var params = new URLSearchParams();

    if (ctx.compteId)     params.set('compteId', ctx.compteId);
    if (ctx.auxiliaireId) params.set('auxiliaire', ctx.auxiliaireId);
    if (_odState.search)  params.set('search', _odState.search);
    params.set('unletteredOnly', '1');
    params.set('page', '1');
    params.set('pageSize', '200');

    return base + endpoint + '?' + params.toString();
}

/**
 * ⭐ Normalise une ligne serveur en objet client.
 *    Capture les plans de la ligne tiers et de la ligne OD 2xxx/6xxx.
 *    PLAN1 est capturé mais NE SERA PAS recopié vers la ligne target
 *    (voir _copyNonPrimaryImputations).
 */
function _normalizeRow(r) {
    var id = r.ECRITURE_LIGNE_ID || r.ID || r.id || r.LIGNE_ID || r.ligneId || '';
    var sourceImputationLineId = r.SOURCE_IMPUTATION_LINE_ID || r.sourceImputationLineId || null;

    var out = {
        id:                id,
        ligneId:           id,
        ecritureId:        r.ECRITURE_ID || r.ecritureId || '',
        datePiece:         r.DATE_PIECE || r.datePiece || r.DATE_COMPTABLE || '',
        numero:            r.NUMERO || r.numero || '',
        reference:         r.REFERENCE || r.reference || '',
        journalCode:       r.JOURNAL_CODE || r.journalCode || '',
        compteCode:        r.COMPTE_CODE || r.compteCode || '',
        auxiliaire:        r.AUXILIAIRE || r.auxiliaire || '',
        libelle:           r.LIBELLE || r.libelle || '',
        montantInit:       _num(r.MONTANT_INITIAL ?? r.MONTANT_INIT ?? r.montantInit),
        regle:             _num(r.MONTANT_REGLE   ?? r.REGLE        ?? r.regle),
        soldeRestant:      _num(r.SOLDE_RESTANT   ?? r.soldeRestant),
        sens:              _normalizeSens(r.SENS || r.sens),
        sourceFinancement: r.SOURCE_FINANCEMENT || r.sourceFinancement || '',
        modeRegularisation: r.MODE_REGULARISATION || r.modeRegularisation || '',
        compteIdSUB:       r.COMPTE_ID_SUB || r.compteIdSUB || null,
        plans: {},
        sourceImputationLineId: sourceImputationLineId,
        sourceImputationFound:  !!sourceImputationLineId,
        sourcePlans: {}
    };

    for (var k = 1; k <= 10; k++) {
        var v = r['PLAN' + k];
        out.plans[k] = (v === null || v === undefined || v === '') ? null : String(v);
    }
    for (var sourcePlan = 2; sourcePlan <= 10; sourcePlan++) {
        var sourceValue = r['SOURCE_PLAN' + sourcePlan];
        out.sourcePlans[sourcePlan] = (sourceValue === null || sourceValue === undefined || sourceValue === '')
            ? null
            : String(sourceValue);
    }
    return out;
}

function _getImputationSource(row) {
    return row.sourceImputationFound ? row.sourcePlans : row.plans;
}

function _normalizeSens(v) {
    v = String(v || '').toUpperCase().charAt(0);
    return v === 'C' ? 'C' : 'D';
}

function _num(v) {
    if (v === null || v === undefined) return 0;
    if (typeof v === 'number') return v;
    var s = String(v).replace(/\s/g, '').replace(',', '.');
    var n = parseFloat(s);
    return isNaN(n) ? 0 : n;
}

/**
 * ⭐ Diagnostic : décrit textuellement les imputations d'une OD
 *    (utilisé uniquement pour les logs console)
 */
function _describeImputations(r) {
    var parts = [];
    var plans = _getImputationSource(r);
    for (var k = 2; k <= 10; k++) {
        if (plans[k]) parts.push('PLAN' + k + '=' + String(plans[k]).substring(0, 8) + '…');
    }
    if (r.sourceFinancement) parts.push('SRC=' + r.sourceFinancement);
    if (r.compteIdSUB)       parts.push('SUB=' + String(r.compteIdSUB).substring(0, 8) + '…');
    if (r.sourceImputationFound) parts.push('imputations depuis OD 2xxx/6xxx');
    return parts.length ? parts.join(' ') : '(aucune imputation PLAN2..PLAN10)';
}

// ============================================================
// FILTRE LOCAL
// ============================================================
function _applyFilter(term) {
    term = String(term || '').trim().toLowerCase();
    var searchTerms = term.split(/\s+—\s+/).filter(Boolean);
    if (searchTerms.length > 1) term = searchTerms[0];

    if (!term) {
        _odState.filtered = _odState.rows.slice();
    } else {
        _odState.filtered = _odState.rows.filter(function (r) {
            return String(r.numero).toLowerCase().indexOf(term) >= 0
                || String(r.reference).toLowerCase().indexOf(term) >= 0
                || String(r.libelle).toLowerCase().indexOf(term) >= 0
                || String(r.auxiliaire).toLowerCase().indexOf(term) >= 0;
        });
    }

    _odState.page = 0;
    _renderTable();
}

// ============================================================
// RENDU
// ============================================================
function _setModalTitle() {
    var h3 = document.querySelector('#odLettrageModal .modal-header h3');
    if (!h3) return;
    var ctx = _odState.context || {};
    var parts = ['Reprise d\'écritures OD'];
    if (ctx.compteCode)      parts.push('compte ' + ctx.compteCode);
    if (ctx.auxiliaireLabel) parts.push('aux. ' + String(ctx.auxiliaireLabel).split(/\s+—\s+/)[0]);
    h3.innerHTML = '<i class="fas fa-copy"></i> ' + _escapeHtml(parts.join(' — '));
}

function _renderLoading() {
    var body = document.getElementById('odLettrageBody');
    if (body) {
        body.innerHTML = '<tr><td colspan="10" style="text-align:center;padding:24px;">'
            + '<i class="fas fa-spinner fa-spin"></i> Chargement…</td></tr>';
    }
    _updateValidateButton();
}

function _renderError(msg) {
    var body = document.getElementById('odLettrageBody');
    if (body) {
        body.innerHTML = '<tr><td colspan="10" style="text-align:center;padding:24px;color:#B91C1C;">'
            + '<i class="fas fa-exclamation-triangle"></i> ' + _escapeHtml(msg) + '</td></tr>';
    }
    _updateValidateButton();
}

function _renderTable() {
    var body = document.getElementById('odLettrageBody');
    if (!body) return;

    var total = _odState.filtered.length;
    var start = _odState.page * _odState.pageSize;
    var end   = Math.min(start + _odState.pageSize, total);
    var slice = _odState.filtered.slice(start, end);

    if (!total) {
        body.innerHTML = '<tr><td colspan="10" style="text-align:center;padding:24px;color:#6c757d;">'
            + '<i class="fas fa-inbox"></i> Aucune écriture OD non soldée pour ce compte et cet auxiliaire.</td></tr>';
        _renderPagination();
        _updateValidateButton();
        return;
    }

    var html = '';
    slice.forEach(function (r) {
        var checked = !!_odState.selected[r.id];
        var checkedAttr = checked ? ' checked' : '';
        var rowStyle = checked ? ' style="background:#e0f2fe;"' : '';
        var color = (r.sens === 'D') ? '#B91C1C' : '#047857';

        var hasAnalytic = false;
        for (var k = 2; k <= 10; k++) if (r.plans[k]) { hasAnalytic = true; break; }
        var analyticIcon = hasAnalytic
            ? ' <i class="fas fa-sitemap" style="color:#0a7;font-size:10px;" '
              + 'title="' + _escapeAttr(_describeImputations(r)) + '"></i>'
            : '';

        html += '<tr' + rowStyle + '>'
            + '<td style="text-align:center;">'
            +   '<input type="checkbox" data-od-row="' + _escapeAttr(r.id) + '"' + checkedAttr + ' />'
            + '</td>'
            + '<td>' + _escapeHtml(r.datePiece || '—') + '</td>'
            + '<td><span class="badge-code">' + _escapeHtml(r.numero || '—') + '</span>'
            +     (r.reference ? ' <small style="color:#6c757d;">' + _escapeHtml(r.reference) + '</small>' : '')
            +     analyticIcon
            + '</td>'
            + '<td>' + _escapeHtml(r.journalCode || '') + '</td>'
            + '<td><span class="cell-badge">' + _escapeHtml(r.compteCode || '') + '</span></td>'
            + '<td>' + _escapeHtml(r.auxiliaire || '') + '</td>'
            + '<td title="' + _escapeAttr(r.libelle) + '">' + _escapeHtml(_truncate(r.libelle, 50)) + '</td>'
            + '<td style="text-align:right;font-family:monospace;color:' + color + ';">'
            +     _formatMontant(r.montantInit) + '</td>'
            + '<td style="text-align:right;font-family:monospace;color:#6c757d;">'
            +     _formatMontant(r.regle) + '</td>'
            + '<td style="text-align:right;font-family:monospace;font-weight:600;color:' + color + ';">'
            +     _formatMontant(r.soldeRestant) + '</td>'
            + '</tr>';
    });

    body.innerHTML = html;

    body.querySelectorAll('input[data-od-row]').forEach(function (cb) {
        cb.addEventListener('change', function () {
            var id = cb.getAttribute('data-od-row');
            if (cb.checked) _odState.selected[id] = true;
            else delete _odState.selected[id];
            _updateValidateButton();
            _highlightSelectedRows();
        });
    });

    _renderPagination();
    _updateValidateButton();
}

function _renderPagination() {
    var total = _odState.filtered.length;
    var pages = Math.ceil(total / _odState.pageSize);
    var btnPrev = document.getElementById('odBtnPrev');
    var btnNext = document.getElementById('odBtnNext');
    if (!btnPrev || !btnNext) return;

    var container = btnPrev.parentNode;
    var info = container.querySelector('.od-page-info');
    if (!info) {
        info = document.createElement('span');
        info.className = 'od-page-info';
        info.style.cssText = 'margin-left:12px;font-size:12px;color:#6c757d;';
        container.appendChild(info);
    }

    if (pages <= 1) {
        info.textContent = total ? ('(' + total + ')') : '';
        btnPrev.disabled = true;
        btnNext.disabled = true;
    } else {
        info.textContent = 'Page ' + (_odState.page + 1) + ' / ' + pages + ' (' + total + ')';
        btnPrev.disabled = _odState.page === 0;
        btnNext.disabled = _odState.page >= pages - 1;
    }
}

function _highlightSelectedRows() {
    var body = document.getElementById('odLettrageBody');
    if (!body) return;
    body.querySelectorAll('tr').forEach(function (tr) {
        var cb = tr.querySelector('input[data-od-row]');
        if (!cb) return;
        tr.style.backgroundColor = cb.checked ? '#e0f2fe' : '';
    });
}

function _updateValidateButton() {
    var btn = document.getElementById('odBtnValidate');
    if (!btn) return;
    var count = Object.keys(_odState.selected).length;
    btn.disabled = count === 0;
    btn.innerHTML = '<i class="fas fa-copy"></i> Reprendre la sélection'
        + (count ? ' (' + count + ')' : '');
}

// ============================================================
// BINDINGS
// ============================================================
var _odBound = false;
function _bindModalOnce() {
    if (_odBound) return;
    _odBound = true;

    var btnClose = document.getElementById('odBtnClose');
    if (btnClose) btnClose.addEventListener('click', cancelOdModal);

    var btnRefresh = document.getElementById('odBtnRefresh');
    if (btnRefresh) btnRefresh.addEventListener('click', function () {
        _odState.selected = {};
        _loadOdEntries();
    });

    var search = document.getElementById('odSearchInput');
    if (search) {
        search.addEventListener('input', function () {
            _applyFilter(search.value);
        });
    }

    var btnPrev = document.getElementById('odBtnPrev');
    if (btnPrev) btnPrev.addEventListener('click', function () {
        if (_odState.page > 0) { _odState.page--; _renderTable(); }
    });

    var btnNext = document.getElementById('odBtnNext');
    if (btnNext) btnNext.addEventListener('click', function () {
        var pages = Math.ceil(_odState.filtered.length / _odState.pageSize);
        if (_odState.page < pages - 1) { _odState.page++; _renderTable(); }
    });

    var btnValidate = document.getElementById('odBtnValidate');
    if (btnValidate) btnValidate.addEventListener('click', _handleReprendre);

    var modal = document.getElementById('odLettrageModal');
    if (modal) {
        modal.addEventListener('click', function (e) {
            if (e.target === modal) closeOdModal();
        });
    }

    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            var m = document.getElementById('odLettrageModal');
            if (m && m.style.display !== 'none' && m.style.display !== '') closeOdModal();
        }
    });
}

// ============================================================
// ⭐ CŒUR DU SUJET — copie des imputations NON-PLAN1
//    - Parcourt tous les plans actifs (sauf PLAN1)
//    - Copie l'ID si l'OD source a une valeur
//    - Copie le CODE via findCodeCompteByKey
//    - PLAN1 est EXCLU : il reste à la charge de l'appelant
// ============================================================
function _copyNonPrimaryImputations(srcRow, targetLine) {
    var active = (typeof getActivePlanFields === 'function') ? getActivePlanFields() : [];
    var copied = [];

    active.forEach(function (plan) {
        var ordre = Number(plan.ordre);
        if (ordre === 1) return;  // ⭐ PLAN1 exclu par conception

        var sourcePlans = _getImputationSource(srcRow);
        var planId = (sourcePlans && sourcePlans[ordre]) || null;
        targetLine['compteId' + plan.key] = planId;
        targetLine['code' + plan.key] = planId
            ? (typeof findCodeCompteByKey === 'function'
                ? findCodeCompteByKey(plan.key, planId)
                : '')
            : '';

        if (planId) copied.push('PLAN' + ordre + '=' + targetLine['code' + plan.key]);
    });

    return copied;
}

// ============================================================
// REPRISE — génération des lignes
// ============================================================
function _handleReprendre() {
    var selectedRows = _odState.rows.filter(function (r) {
        return _odState.selected[r.id];
    });
    if (!selectedRows.length) return;

    // ─── 1. Vérifications ───
    var ctx = _odState.context || {};
    var primaire = (typeof getPrimaryPlanField === 'function') ? getPrimaryPlanField() : null;
    if (!primaire) {
        _renderError('Aucun plan primaire actif.');
        return;
    }

    var bankId   = (typeof _getJournalCompteBanqueId   === 'function') ? _getJournalCompteBanqueId()   : null;
    var bankCode = (typeof _getJournalCompteBanqueCode === 'function') ? _getJournalCompteBanqueCode() : '';
    if (!bankId) {
        _renderError(
            'Aucun compte banque (COMPTE_BANQUE_ID) configuré sur ce journal.'
        );
        return;
    }

    var active = (typeof getActivePlanFields === 'function') ? getActivePlanFields() : [];

    // ─── 2. Génération ───
    var newLines = [];
    var lettrageSources = [];
    var startIdx = (AppState.lignes || []).length;
    var analyticCount = 0;
    var copiesLog = [];

    selectedRows.forEach(function (r) {
        var montant = r.soldeRestant;
        if (montant <= 0) return;

        var oppositeSens = (r.sens === 'D') ? 'C' : 'D';
        var dateSuffix   = r.datePiece ? (' du ' + r.datePiece) : '';
        var numSuffix    = r.numero || r.reference || '';

        // ────────────────────────────────────────────────
        // ⭐ LIGNE 4xxx : reprise de l'OD + imputations NON-PLAN1
        // ────────────────────────────────────────────────
        var lineOD = {
            auxiliaire:  r.auxiliaire || '',
            compteIdSUB: r.compteIdSUB || null,           // ⭐ subvention reprise
            sourceFinancement: r.sourceFinancement || r.compteIdSUB || '',
            mode:        r.modeRegularisation || '',
            libelle:     'Règlement OD ' + numSuffix + dateSuffix,
            montantRep:  0,
            sens:        oppositeSens,
            debit:       oppositeSens === 'D' ? montant : 0,
            credit:      oppositeSens === 'C' ? montant : 0,
            echeance:    ''
        };
        // ⭐ PLAN1 = compte choisi dans le formulaire (PAS copié de l'OD)
        lineOD['compteId' + primaire.key] = ctx.compteId;
        lineOD['code' + primaire.key]     = r.compteCode;

        // ⭐ PLAN2..PLAN10 : copie depuis l'OD source
        var copied = _copyNonPrimaryImputations(r, lineOD);

        if (copied.length) analyticCount++;
        copiesLog.push({
            od:     r.numero || r.id,
            aux:    r.auxiliaire || '—',
            copied: copied
        });

        // ────────────────────────────────────────────────
        // ⭐ LIGNE 5xxx : contrepartie banque (imputations vides)
        // ────────────────────────────────────────────────
        var lineBank = {
            auxiliaire:  '',
            compteIdSUB: null,
            sourceFinancement: '',
            mode:        '',
            libelle:     'Règlement ' + (r.auxiliaire || '') +
                         (numSuffix ? ' — OD ' + numSuffix : ''),
            montantRep:  0,
            sens:        r.sens,
            debit:       r.sens === 'D' ? montant : 0,
            credit:      r.sens === 'C' ? montant : 0,
            echeance:    ''
        };
        lineBank['compteId' + primaire.key] = bankId;
        lineBank['code' + primaire.key]     = bankCode;

        // Imputations analytiques explicitement nulles (règle 5xxx)
        active.forEach(function (plan) {
            if (Number(plan.ordre) === 1) return;
            lineBank['compteId' + plan.key] = null;
            lineBank['code' + plan.key]     = '';
        });

        newLines.push(lineOD, lineBank);

        lettrageSources.push({
            ligneId:    r.ligneId,
            ecritureId: r.ecritureId,
            montant:    montant,
            sens:       r.sens,
            compteCode: r.compteCode,
            auxiliaire: r.auxiliaire,
            newLineRef: startIdx + (newLines.length - 2)
        });
    });

    if (!newLines.length) {
        _renderError('Aucune ligne générée — les soldes restants sont à zéro ?');
        return;
    }

    // ─── 3. Insertion ───
    if (!AppState.lignes) AppState.lignes = [];
    newLines.forEach(function (l) { AppState.lignes.push(l); });

    if (!AppState.lettrageSources) AppState.lettrageSources = [];
    AppState.lettrageSources = AppState.lettrageSources.concat(lettrageSources);

    AppState.selectedLigneIndex = -1;

    // ─── 4. UI ───
    if (typeof renderGrid            === 'function') renderGrid();
    if (typeof computeTotaux         === 'function') computeTotaux();
    if (typeof updateSaveButtonState === 'function') updateSaveButtonState();
    if (typeof markDirty             === 'function') markDirty();

    // ─── 5. Log structuré ───
    console.log('%c[od-modal] reprise générée',
        'color:#0a7;font-weight:bold', {
            odEntriesSelected: selectedRows.length,
            linesGenerated:    newLines.length,
            odWithAnalytics:   analyticCount
        });
    console.table(copiesLog);
    console.log('[od-modal] Lignes insérées :', newLines);
    console.log('[od-modal] Sources lettrage :', lettrageSources);

    // ─── 6. Toast + fermeture ───
    _odState.selected = {};
    closeOdModal();

    var msg = selectedRows.length + ' OD reprise(s) → ' +
              newLines.length + ' ligne(s) ajoutée(s)';
    if (analyticCount > 0) {
        msg += ' (' + analyticCount + ' avec imputations analytiques reprises)';
    }
    if (typeof showSuccessToast === 'function') showSuccessToast(msg);
}

// ============================================================
// UTILS
// ============================================================
function _showModal() {
    var modal = document.getElementById('odLettrageModal');
    if (!modal) { console.warn('[od-modal] modale #odLettrageModal introuvable'); return; }
    modal.classList.add('show');
    modal.style.display = 'flex';
}

function _escapeHtml(s) {
    return String(s == null ? '' : s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}
function _escapeAttr(s) { return _escapeHtml(s).replace(/\n/g, ' '); }
function _truncate(s, n) { s = String(s || ''); return s.length > n ? s.substring(0, n - 1) + '…' : s; }
function _formatMontant(v) {
    if (typeof window.formatMontant === 'function') return window.formatMontant(v);
    return (Number(v) || 0).toLocaleString('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.openOdModal   = openOdModal;
window.closeOdModal  = closeOdModal;
window._odState      = _odState;
