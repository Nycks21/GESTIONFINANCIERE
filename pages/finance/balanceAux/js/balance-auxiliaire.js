// balance-auxiliaire.js — Page Balance Auxiliaire
'use strict';

// ══════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════
window.BalanceState = {
    exercices:   [],
    sites:       [],
    plansActifs: [],
    comptes:     [],
    tiers:       [],
    lignes:      [],
    totaux:      null,
    planOrder:   1,
    loading:     false,
    loaded:      false
};

// ══════════════════════════════════════════════════════════════
// INITIALISATION
// ══════════════════════════════════════════════════════════════
document.addEventListener('DOMContentLoaded', function () {
    bindEvents();
    loadLookupsAndInit();
    initFilterPanel();
});

function bindEvents() {
    var btnLoad = document.getElementById('btnLoadBalance');
    if (btnLoad) btnLoad.addEventListener('click', loadBalance);

    var btnExport = document.getElementById('btnExportBalance');
    if (btnExport) btnExport.addEventListener('click', exportBalanceCSV);

    var btnPrint = document.getElementById('btnPrintBalance');
    if (btnPrint) btnPrint.addEventListener('click', function () { window.print(); });

    var btnReset = document.getElementById('btnResetBalance');
    if (btnReset) btnReset.addEventListener('click', resetFilters);

    // Gestion du changement de compte pour filtrer les AUXILIAIRES (Du / Au)
    var cptSel = document.getElementById('balCompteAux');
    var auxDuSel = document.getElementById('balAuxiliaireDu');
    var auxAuSel = document.getElementById('balAuxiliaireAu');

    if (cptSel) {
        cptSel.addEventListener('change', function () {
            var cptId = this.value;
            if (!auxDuSel || !auxAuSel) return; // Protection

            // On réinitialise les deux listes
            auxDuSel.innerHTML = '<option value="">— Du —</option>';
            auxAuSel.innerHTML = '<option value="">— Au —</option>';

            // On filtre les tiers selon le compte sélectionné
            var filteredTiers = BalanceState.tiers;
            if (cptId) {
                filteredTiers = filteredTiers.filter(function(t) { return t.PLAN_ELEMENT_ID === cptId; });
            }

            // On remplit les deux listes avec les mêmes options
            filteredTiers.forEach(function(t) {
                var txt = t.CODE + ' — ' + t.NOM;

                var optDu = document.createElement('option');
                optDu.value = t.CODE; // ⭐ On envoie le CODE au backend
                optDu.textContent = txt;
                auxDuSel.appendChild(optDu);

                var optAu = document.createElement('option');
                optAu.value = t.CODE;
                optAu.textContent = txt;
                auxAuSel.appendChild(optAu);
            });

            refreshSummaryIfCollapsed();
        });
    }

    var exSel = document.getElementById('balExercice');
    if (exSel) {
        exSel.addEventListener('change', function () {
            var exId = this.value;
            if (!exId) return;
            var ex = BalanceState.exercices.find(function (e) { return e.ID === exId; });
            if (ex) {
                var dDebut = document.getElementById('balDateDebut');
                if (dDebut) dDebut.value = ex.DATE_DEBUT || '';
                var dFin = document.getElementById('balDateFin');
                if (dFin) dFin.value = ex.DATE_FIN || '';
            }
        });
    }

    ['balExercice', 'balDateDebut', 'balDateFin', 'balSite', 'balCompteAux', 'balAuxiliaireDu', 'balAuxiliaireAu'].forEach(function (id) {
        var el = document.getElementById(id);
        if (el) el.addEventListener('change', refreshSummaryIfCollapsed);
    });

    document.querySelectorAll('.bal-statut').forEach(function (el) {
        el.addEventListener('change', refreshSummaryIfCollapsed);
    });
}

// ══════════════════════════════════════════════════════════════
// GESTION DU PANNEAU DE FILTRES (Repli / Résumé)
// ══════════════════════════════════════════════════════════════
function initFilterPanel() {
    var btnToggle = document.getElementById('btnToggleFilter');
    if (!btnToggle) return;

    btnToggle.addEventListener('click', function () {
        var panel = document.getElementById('filterPanel');
        if (!panel) return;

        panel.classList.toggle('collapsed');

        if (panel.classList.contains('collapsed')) {
            generateActiveFiltersSummary();
            document.getElementById('activeFiltersSummary').style.display = 'flex';
        } else {
            document.getElementById('activeFiltersSummary').style.display = 'none';
        }
    });
}

function refreshSummaryIfCollapsed() {
    var panel = document.getElementById('filterPanel');
    if (panel && panel.classList.contains('collapsed')) {
        generateActiveFiltersSummary();
    }
}

function generateActiveFiltersSummary() {
    var container = document.getElementById('activeFiltersSummary');
    if (!container) return;

    container.innerHTML = '';

    // ─── Exercice ───
    var exSelect = document.getElementById('balExercice');
    var exId = exSelect ? exSelect.value : '';
    if (exId && BalanceState.exercices.length) {
        var ex = BalanceState.exercices.find(function (e) { return e.ID === exId; });
        if (ex) addSummaryBadge(container, 'fa-calendar-alt', 'Exercice: ' + ex.CODE);
    }

    // ─── Période ───
    var dDebut = document.getElementById('balDateDebut');
    var dFin = document.getElementById('balDateFin');
    var dateDebut = dDebut ? dDebut.value : '';
    var dateFin   = dFin ? dFin.value : '';

    if (dateDebut || dateFin) {
        addSummaryBadge(container, 'fa-clock', 'Période: ' + formatDateShort(dateDebut) + ' → ' + formatDateShort(dateFin));
    }

    // ─── Compte et Auxiliaires ───
    var cptEl = document.getElementById('balCompteAux');
    var auxDuEl = document.getElementById('balAuxiliaireDu');
    var auxAuEl = document.getElementById('balAuxiliaireAu');

    var cptId = cptEl ? cptEl.value : '';
    var auxDu = auxDuEl ? auxDuEl.value : '';
    var auxAu = auxAuEl ? auxAuEl.value : '';

    if (cptId) {
        var c = BalanceState.comptes.find(function(x) { return x.ID === cptId; });
        if (c) addSummaryBadge(container, 'fa-folder', 'Compte: ' + c.CODE);
    }
    if (auxDu || auxAu) {
        addSummaryBadge(container, 'fa-users', 'Aux: ' + (auxDu || '*') + ' - ' + (auxAu || '*'));
    }

    // ─── Site ───
    var sEl = document.getElementById('balSite');
    var siteId = sEl ? sEl.value : '';
    if (siteId) {
        var s = BalanceState.sites.find(function (x) { return x.ID === siteId; });
        if (s) addSummaryBadge(container, 'fa-map-marker-alt', 'Site: ' + s.CODE);
    }

    // ─── Statuts ───
    var statutsChecked = [];
    document.querySelectorAll('.bal-statut:checked').forEach(function (c) {
        statutsChecked.push(c.value);
    });
    if (statutsChecked.length > 0) {
        addSummaryBadge(container, 'fa-tags', 'Statuts: ' + statutsChecked.join(', '));
    }
}

function addSummaryBadge(container, iconClass, text) {
    var badge = document.createElement('span');
    badge.className = 'active-filter-badge';
    badge.innerHTML = '<i class="fas ' + iconClass + '"></i> ' + text;
    container.appendChild(badge);
}

function formatDateShort(dateString) {
    if (!dateString) return '...';
    var parts = dateString.split('-');
    if (parts.length === 3) {
        return parts[2] + '/' + parts[1] + '/' + parts[0];
    }
    return dateString;
}

// ══════════════════════════════════════════════════════════════
// CHARGEMENT DES RÉFÉRENTIELS
// ══════════════════════════════════════════════════════════════
async function loadLookupsAndInit() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.LOOKUPS + '?includeAllStatuses=1';
        var resp = await fetch(url);
        var data = await resp.json();

        if (!data.success) {
            showErrorToast(data.message || 'Erreur lookups');
            return;
        }

        BalanceState.exercices   = data.exercices   || [];
        BalanceState.sites       = data.sites       || [];
        BalanceState.plansActifs = data.plansActifs || [];
        BalanceState.tiers       = data.tiers       || [];

        populateFilterSelects();

        if (BalanceState.exercices.length > 0) {
            var first = BalanceState.exercices[0];
            var exEl = document.getElementById('balExercice');
            if (exEl) exEl.value = first.ID;

            var dDebut = document.getElementById('balDateDebut');
            if (dDebut) dDebut.value = first.DATE_DEBUT || '';

            var dFin = document.getElementById('balDateFin');
            if (dFin) dFin.value = first.DATE_FIN || '';
        }

        await loadComptesForFilters();

        // Initialise la liste des auxiliaires avec tous les tiers
        var cptSel = document.getElementById('balCompteAux');
        if (cptSel) {
            var changeEvent = new Event('change');
            cptSel.dispatchEvent(changeEvent);
        }

        renderEmptyState();
    } catch (err) {
        console.error('[balance-aux] Erreur init :', err);
        showErrorToast(err.message);
    }
}

function populateFilterSelects() {
    var ex = document.getElementById('balExercice');
    if (ex) {
        ex.innerHTML = '<option value="">—</option>';
        BalanceState.exercices.forEach(function (e) {
            var opt = document.createElement('option');
            opt.value = e.ID;
            opt.textContent = e.CODE + ' — ' + (e.LIBELLE || '');
            ex.appendChild(opt);
        });
    }

    var s = document.getElementById('balSite');
    if (s) {
        s.innerHTML = '<option value="">— Tous les sites —</option>';
        BalanceState.sites.forEach(function (x) {
            var opt = document.createElement('option');
            opt.value = x.ID;
            opt.textContent = x.CODE + ' — ' + x.NOM;
            s.appendChild(opt);
        });
    }
}

async function loadComptesForFilters() {
    var planOrder = 1;
    if (BalanceState.plansActifs && BalanceState.plansActifs.length) {
        var pcg = BalanceState.plansActifs.find(function (p) { return p.PLAN_TYPE_CODE === 'COMPTABLE'; });
        if (pcg) planOrder = pcg.ORDRE;
    }

    try {
        var fileName = API.COMPTES_BY_PLAN || 'GetComptesByPlan.ashx';
        var url = API.BASE + API.HANDLERS_PATH + fileName + '?planOrder=' + planOrder + '&onlyAuxiliaire=1';

        var resp = await fetch(url);
        var text = await resp.text();

        if (!resp.ok || text.trim().charAt(0) === '<') return;

        var data = JSON.parse(text);
        if (!data.success) return;

        BalanceState.comptes = data.comptes || [];
        populateCompteSelects(BalanceState.comptes);
    } catch (err) {
        console.error('[balance-aux] Erreur chargement comptes :', err);
    }
}

function populateCompteSelects(comptes) {
    var cptSel = document.getElementById('balCompteAux');
    if (!cptSel) return;

    cptSel.innerHTML = '<option value="">— Tous les comptes 4xxxxx —</option>';

    comptes.forEach(function (c) {
        var opt = document.createElement('option');
        opt.value = c.ID;
        opt.textContent = c.CODE + ' — ' + c.LIBELLE;
        cptSel.appendChild(opt);
    });
}

// ══════════════════════════════════════════════════════════════
// CHARGEMENT DE LA BALANCE
// ══════════════════════════════════════════════════════════════
async function loadBalance() {
    var exEl = document.getElementById('balExercice');
    var exerciceId = exEl ? exEl.value : '';

    if (!exerciceId) { showErrorToast('Sélectionnez un exercice.'); return; }

    var statuts = [];
    document.querySelectorAll('.bal-statut:checked').forEach(function (c) { statuts.push(c.value); });
    if (statuts.length === 0) { showErrorToast('Sélectionnez au moins un statut.'); return; }

    var dDebut = document.getElementById('balDateDebut');
    var dFin = document.getElementById('balDateFin');
    var sEl = document.getElementById('balSite');
    var cptEl = document.getElementById('balCompteAux');
    var auxDuEl = document.getElementById('balAuxiliaireDu');
    var auxAuEl = document.getElementById('balAuxiliaireAu');

    // Validation des bornes auxiliaires
    if (auxDuEl && auxAuEl && auxDuEl.value && auxAuEl.value) {
        if (auxDuEl.value > auxAuEl.value) {
            showErrorToast('L\'auxiliaire "Du" doit être inférieur ou égal à l\'auxiliaire "Au".');
            return;
        }
    }

    var params = new URLSearchParams({
        exerciceId:       exerciceId,
        dateDebut:        dDebut ? dDebut.value : '',
        dateFin:          dFin ? dFin.value : '',
        siteId:           sEl ? sEl.value : '',
        compteId:         cptEl ? cptEl.value : '',
        auxiliaireDu:     auxDuEl ? auxDuEl.value : '',
        auxiliaireAu:     auxAuEl ? auxAuEl.value : '',
        statuts:          statuts.join(','),
        masquerSansMvt:   '1',
        masquerRubriques: '1'
    });

    var url = API.BASE + API.HANDLERS_PATH + API.BALANCE_AUXILIAIRE + '?' + params.toString();

    showSpinner();

    try {
        var resp = await fetch(url);
        var text = await resp.text();

        if (!resp.ok) throw new Error('HTTP ' + resp.status);
        if (text.trim().charAt(0) === '<') throw new Error('Réponse HTML reçue');

        var data = JSON.parse(text);
        if (!data.success) throw new Error(data.message || 'Erreur balance');

        BalanceState.lignes    = data.lignes || [];
        BalanceState.totaux    = data.totaux || {};
        BalanceState.planOrder = data.planOrder || 1;
        BalanceState.loaded    = true;

        renderBalanceTable();
        updateCounter(data.count);
        refreshSummaryIfCollapsed();

    } catch (err) {
        console.error('[balance-aux] ❌', err);
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

// ══════════════════════════════════════════════════════════════
// RENDU DU TABLEAU
// ══════════════════════════════════════════════════════════════
function renderBalanceTable() {
    var tbody  = document.getElementById('balanceBody');
    var tfoot  = document.getElementById('balanceFooter');
    var lignes = BalanceState.lignes;

    if (!tbody || !tfoot) return;

    if (!lignes.length) {
        tbody.innerHTML = '<tr><td colspan="8" class="table-empty">'
            + '<i class="fas fa-inbox"></i>'
            + '<span>Aucun compte ne correspond aux filtres.</span>'
            + '</td></tr>';
        tfoot.innerHTML = '';
        return;
    }

    var html = '';
    lignes.forEach(function (l) {
        html += '<tr class="bal-row">';
        html += '<td class="bal-code" style="padding-left:8px;">'
              + escapeHtml(l.CODE) + '</td>';
        html += '<td>' + escapeHtml(l.LIBELLE) + '</td>';

        html += '<td class="bal-num ' + (l.INIT_DEBIT  > 0 ? 'bal-pos' : '') + '">' + (l.INIT_DEBIT  > 0 ? fmt(l.INIT_DEBIT)  : '') + '</td>';
        html += '<td class="bal-num ' + (l.INIT_CREDIT > 0 ? 'bal-neg' : '') + '">' + (l.INIT_CREDIT > 0 ? fmt(l.INIT_CREDIT) : '') + '</td>';
        html += '<td class="bal-num ' + (l.MVT_DEBIT   > 0 ? 'bal-pos' : '') + '">' + (l.MVT_DEBIT   > 0 ? fmt(l.MVT_DEBIT)   : '') + '</td>';
        html += '<td class="bal-num ' + (l.MVT_CREDIT  > 0 ? 'bal-neg' : '') + '">' + (l.MVT_CREDIT  > 0 ? fmt(l.MVT_CREDIT)  : '') + '</td>';
        html += '<td class="bal-num ' + (l.SOLDE_FINAL_DEBIT  > 0 ? 'bal-pos' : '') + '">' + (l.SOLDE_FINAL_DEBIT  > 0 ? fmt(l.SOLDE_FINAL_DEBIT)  : '') + '</td>';
        html += '<td class="bal-num ' + (l.SOLDE_FINAL_CREDIT > 0 ? 'bal-neg' : '') + '">' + (l.SOLDE_FINAL_CREDIT > 0 ? fmt(l.SOLDE_FINAL_CREDIT) : '') + '</td>';
        html += '</tr>';
    });

    tbody.innerHTML = html;

    // ─── Totaux ───
    var t = BalanceState.totaux || {};
    var totHtml = '<tr class="bal-totaux-row">';
    totHtml += '<td colspan="2" class="bal-totaux-label">TOTAL GÉNÉRAL</td>';
    totHtml += '<td class="bal-num bal-pos">' + (t.initDebit  > 0 ? fmt(t.initDebit)  : '') + '</td>';
    totHtml += '<td class="bal-num bal-neg">' + (t.initCredit > 0 ? fmt(t.initCredit) : '') + '</td>';
    totHtml += '<td class="bal-num bal-pos">' + (t.mvtDebit   > 0 ? fmt(t.mvtDebit)   : '') + '</td>';
    totHtml += '<td class="bal-num bal-neg">' + (t.mvtCredit  > 0 ? fmt(t.mvtCredit)  : '') + '</td>';
    totHtml += '<td class="bal-num bal-pos">' + (t.finalDebit > 0 ? fmt(t.finalDebit) : '') + '</td>';
    totHtml += '<td class="bal-num bal-neg">' + (t.finalCredit > 0 ? fmt(t.finalCredit): '') + '</td>';
    totHtml += '</tr>';

    var netSolde = (t.finalDebit || 0) - (t.finalCredit || 0);
    var isZero = Math.abs(netSolde) < 0.01;
    var soldeClass = isZero ? 'bal-solde-zero' : 'bal-solde-nonzero';

    totHtml += '<tr class="bal-solde-final-row ' + soldeClass + '">';
    totHtml += '<td colspan="7" class="bal-solde-label">SOLDE FINAL (DÉBIT - CRÉDIT)</td>';
    totHtml += '<td class="bal-num bal-solde-value">' + fmt(netSolde) + '</td>';
    totHtml += '</tr>';

    var ecartMvt   = Math.abs((t.mvtDebit   || 0) - (t.mvtCredit   || 0));
    var ecartFinal = Math.abs((t.finalDebit || 0) - (t.finalCredit || 0));
    var tolerance  = 0.01;

    if (ecartMvt < tolerance && ecartFinal < tolerance) {
        totHtml += '<tr class="bal-status-row bal-status-ok">'
                + '<td colspan="8"><i class="fas fa-check-circle"></i> '
                + 'Balance équilibrée (Débit = Crédit)</td></tr>';
    } else {
        totHtml += '<tr class="bal-status-row bal-status-warn">'
                + '<td colspan="8"><i class="fas fa-exclamation-triangle"></i> '
                + '⚠️ Écart détecté — Mouvements : ' + fmt(ecartMvt)
                + ' | Soldes finaux : ' + fmt(ecartFinal) + '</td></tr>';
    }

    tfoot.innerHTML = totHtml;
}

function renderEmptyState() {
    var tbody = document.getElementById('balanceBody');
    var tfoot = document.getElementById('balanceFooter');

    if (tbody) {
        tbody.innerHTML = '<tr><td colspan="8" class="table-empty">'
            + '<i class="fas fa-search"></i>'
            + '<span>Sélectionnez vos filtres et cliquez sur <strong>Charger</strong> pour afficher la balance auxiliaire.</span>'
            + '</td></tr>';
    }
    if (tfoot) {
        tfoot.innerHTML = '';
    }
    updateCounter(0);
}

function updateCounter(n) {
    var el = document.getElementById('balanceCounter');
    if (el) el.textContent = (n || 0) + ' ligne(s)';
}

// ══════════════════════════════════════════════════════════════
// RESET
// ══════════════════════════════════════════════════════════════
function resetFilters() {
    if (BalanceState.exercices.length > 0) {
        var first = BalanceState.exercices[0];
        var exEl = document.getElementById('balExercice');
        if (exEl) exEl.value = first.ID;

        var dDebut = document.getElementById('balDateDebut');
        if (dDebut) dDebut.value = first.DATE_DEBUT || '';

        var dFin = document.getElementById('balDateFin');
        if (dFin) dFin.value = first.DATE_FIN || '';
    }

    var sEl = document.getElementById('balSite');
    if (sEl) sEl.value = '';

    var cptEl = document.getElementById('balCompteAux');
    if (cptEl) {
        cptEl.value = '';
        cptEl.dispatchEvent(new Event('change'));
    }

    var auxDuEl = document.getElementById('balAuxiliaireDu');
    if (auxDuEl) auxDuEl.value = '';

    var auxAuEl = document.getElementById('balAuxiliaireAu');
    if (auxAuEl) auxAuEl.value = '';

    document.querySelectorAll('.bal-statut').forEach(function (c) {
        c.checked = (c.value === 'VALIDEE' || c.value === 'COMPTABILISEE');
    });

    BalanceState.loaded = false;
    renderEmptyState();
}

// ══════════════════════════════════════════════════════════════
// EXPORT CSV
// ══════════════════════════════════════════════════════════════
function exportBalanceCSV() {
    if (!BalanceState.lignes.length || !BalanceState.loaded) {
        showErrorToast('Aucune donnée à exporter. Veuillez d\'abord charger la balance.');
        return;
    }

    var sep = ';';
    var lines = [];

    lines.push([
        'Code', 'Libellé',
        'Solde Init Débit', 'Solde Init Crédit',
        'Mvt Débit', 'Mvt Crédit',
        'Solde Final Débit', 'Solde Final Crédit'
    ].join(sep));

    BalanceState.lignes.forEach(function (l) {
        lines.push([
            l.CODE,
            '"' + String(l.LIBELLE || '').replace(/"/g, '""') + '"',
            num(l.INIT_DEBIT),
            num(l.INIT_CREDIT),
            num(l.MVT_DEBIT),
            num(l.MVT_CREDIT),
            num(l.SOLDE_FINAL_DEBIT),
            num(l.SOLDE_FINAL_CREDIT)
        ].join(sep));
    });

    var t = BalanceState.totaux || {};
    lines.push('');
    lines.push([
        '', 'TOTAL GÉNÉRAL',
        num(t.initDebit),  num(t.initCredit),
        num(t.mvtDebit),   num(t.mvtCredit),
        num(t.finalDebit), num(t.finalCredit)
    ].join(sep));

    var csv = '\uFEFF' + lines.join('\r\n');
    var blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    var link = document.createElement('a');
    var dateStr = new Date().toISOString().slice(0, 10);
    link.href = URL.createObjectURL(blob);
    link.download = 'balance-auxiliaire_' + dateStr + '.csv';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);

    showSuccessToast('Balance auxiliaire exportée en CSV.');
}

// ══════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════
function fmt(v) {
    if (v === null || v === undefined) return '0,00';
    var n = parseFloat(v);
    if (isNaN(n)) return '0,00';
    var s = n.toFixed(2);
    var parts = s.split('.');
    var ip = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
    return ip + ',' + parts[1];
}

function num(v) {
    if (v === null || v === undefined) return '0.00';
    var n = parseFloat(v);
    return isNaN(n) ? '0.00' : n.toFixed(2);
}

console.log('[balance-aux] Module chargé.');
