// balance.js — Page Balance Générale
'use strict';

// ══════════════════════════════════════════════════════════════
// STATE
// ══════════════════════════════════════════════════════════════
window.BalanceState = {
    exercices:   [],
    sites:       [],
    plansActifs: [],   // plans actifs (pour détecter l'ordre du plan COMPTABLE)
    comptes:     [],   // comptes feuilles (niveau MAX) pour les dropdowns
    lignes:      [],
    totaux:      null,
    planOrder:   1,
    loading:     false,
    loaded:      false // ⭐ Reste à false tant que l'utilisateur n'a pas cliqué sur "Charger"
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
    document.getElementById('btnLoadBalance').addEventListener('click', loadBalance);
    document.getElementById('btnExportBalance').addEventListener('click', exportBalanceCSV);
    document.getElementById('btnPrintBalance').addEventListener('click', function () { window.print(); });
    document.getElementById('btnResetBalance').addEventListener('click', resetFilters);

    // Changement d'exercice → pré-remplir les dates
    document.getElementById('balExercice').addEventListener('change', function () {
        var exId = this.value;
        if (!exId) return;
        var ex = BalanceState.exercices.find(function (e) { return e.ID === exId; });
        if (ex) {
            document.getElementById('balDateDebut').value = ex.DATE_DEBUT || '';
            document.getElementById('balDateFin').value   = ex.DATE_FIN   || '';
        }
    });

    // Mise à jour du résumé à chaque changement de filtre (si replié)
    ['balExercice', 'balDateDebut', 'balDateFin', 'balSite',
     'balCompteDebut', 'balCompteFin'].forEach(function (id) {
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

    container.innerHTML = ''; // Reset

    // ─── Exercice ───
    var exSelect = document.getElementById('balExercice');
    var exId = exSelect.value;
    if (exId && BalanceState.exercices.length) {
        var ex = BalanceState.exercices.find(function (e) { return e.ID === exId; });
        if (ex) {
            addSummaryBadge(container, 'fa-calendar-alt', 'Exercice: ' + ex.CODE);
        }
    }

    // ─── Période ───
    var dateDebut = document.getElementById('balDateDebut').value;
    var dateFin   = document.getElementById('balDateFin').value;
    if (dateDebut || dateFin) {
        addSummaryBadge(container, 'fa-clock',
            'Période: ' + formatDateShort(dateDebut) + ' → ' + formatDateShort(dateFin));
    }

    // ─── Comptes (dropdown → la valeur est le CODE) ───
    var cptDebut = document.getElementById('balCompteDebut').value;
    var cptFin   = document.getElementById('balCompteFin').value;
    if (cptDebut || cptFin) {
        addSummaryBadge(container, 'fa-hashtag',
            'Comptes: ' + (cptDebut || '*') + ' - ' + (cptFin || '*'));
    }

    // ─── Site ───
    var siteId = document.getElementById('balSite').value;
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

        populateFilterSelects();

        // Auto-sélectionner le premier exercice
        if (BalanceState.exercices.length > 0) {
            var first = BalanceState.exercices[0];
            document.getElementById('balExercice').value  = first.ID;
            document.getElementById('balDateDebut').value = first.DATE_DEBUT || '';
            document.getElementById('balDateFin').value   = first.DATE_FIN   || '';
        }

        // ⭐ Charger les comptes FEUILLES pour les dropdowns Compte début/fin
        await loadComptesForFilters();

        // ⭐ On force l'affichage de l'état initial "En attente de chargement"
        renderEmptyState();

    } catch (err) {
        console.error('[balance] Erreur init :', err);
        showErrorToast(err.message);
    }
}

function populateFilterSelects() {
    // Exercices
    var ex = document.getElementById('balExercice');
    ex.innerHTML = '<option value="">—</option>';
    BalanceState.exercices.forEach(function (e) {
        var opt = document.createElement('option');
        opt.value = e.ID;
        opt.textContent = e.CODE + ' — ' + (e.LIBELLE || '')
                        + (e.STATUT && e.STATUT !== 'OUVERT' ? ' [' + e.STATUT + ']' : '');
        ex.appendChild(opt);
    });

    // Sites
    var s = document.getElementById('balSite');
    s.innerHTML = '<option value="">— Tous les sites —</option>';
    BalanceState.sites.forEach(function (x) {
        var opt = document.createElement('option');
        opt.value = x.ID;
        opt.textContent = x.CODE + ' — ' + x.NOM;
        s.appendChild(opt);
    });
}

// ══════════════════════════════════════════════════════════════
// CHARGEMENT DES COMPTES (niveau MAX = comptes feuilles)
// ══════════════════════════════════════════════════════════════
async function loadComptesForFilters() {
    // Détecter l'ordre du plan COMPTABLE à partir des plans actifs
    var planOrder = 1;
    if (BalanceState.plansActifs && BalanceState.plansActifs.length) {
        var pcg = BalanceState.plansActifs.find(function (p) {
            return p.PLAN_TYPE_CODE === 'COMPTABLE';
        });
        if (pcg) planOrder = pcg.ORDRE;
    }

    try {
        var fileName = API.COMPTES_BY_PLAN || 'GetComptesByPlan.ashx';
        var url = API.BASE + API.HANDLERS_PATH + fileName + '?planOrder=' + planOrder;

        var resp = await fetch(url);
        var text = await resp.text();

        if (!resp.ok || text.trim().charAt(0) === '<') {
            console.warn('[balance] Comptes non chargés — HTTP', resp.status);
            return;
        }

        var data = JSON.parse(text);
        if (!data.success) {
            console.warn('[balance] Comptes non chargés :', data.message);
            return;
        }

        BalanceState.comptes = data.comptes || [];
        populateCompteSelects(BalanceState.comptes);

    } catch (err) {
        console.error('[balance] Erreur chargement comptes :', err);
    }
}

function populateCompteSelects(comptes) {
    var debutSel = document.getElementById('balCompteDebut');
    var finSel   = document.getElementById('balCompteFin');
    if (!debutSel || !finSel) return;

    debutSel.innerHTML = '<option value="">— Tous —</option>';
    finSel.innerHTML   = '<option value="">— Tous —</option>';

    comptes.forEach(function (c) {
        var label = c.CODE + ' — ' + c.LIBELLE;

        var o1 = document.createElement('option');
        o1.value = c.CODE;
        o1.textContent = label;
        debutSel.appendChild(o1);

        var o2 = document.createElement('option');
        o2.value = c.CODE;
        o2.textContent = label;
        finSel.appendChild(o2);
    });
}

// ══════════════════════════════════════════════════════════════
// CHARGEMENT DE LA BALANCE (Déclenché par le bouton)
// ══════════════════════════════════════════════════════════════
async function loadBalance() {
    var exerciceId = document.getElementById('balExercice').value;
    if (!exerciceId) {
        showErrorToast('Sélectionnez un exercice.');
        return;
    }

    var statuts = [];
    document.querySelectorAll('.bal-statut:checked').forEach(function (c) {
        statuts.push(c.value);
    });
    if (statuts.length === 0) {
        showErrorToast('Sélectionnez au moins un statut.');
        return;
    }

    // ⭐ Validation : compte début <= compte fin
    var compteDebut = document.getElementById('balCompteDebut').value;
    var compteFin   = document.getElementById('balCompteFin').value;
    if (compteDebut && compteFin && compteDebut > compteFin) {
        showErrorToast('Le compte début doit être inférieur ou égal au compte fin.');
        return;
    }

    var params = new URLSearchParams({
        exerciceId:       exerciceId,
        dateDebut:        document.getElementById('balDateDebut').value || '',
        dateFin:          document.getElementById('balDateFin').value   || '',
        siteId:           document.getElementById('balSite').value      || '',
        compteDebut:      compteDebut || '',
        compteFin:        compteFin   || '',
        statuts:          statuts.join(','),
        masquerSansMvt:   '1',
        masquerRubriques: '1'
    });

    var url = API.BASE + API.HANDLERS_PATH + API.BALANCE + '?' + params.toString();
    showSpinner();

    try {
        var resp = await fetch(url);
        var text = await resp.text();

        if (!resp.ok) {
            try {
                var errData = JSON.parse(text);
                throw new Error(errData.message || ('HTTP ' + resp.status));
            } catch (parseErr) {
                if (parseErr.message && parseErr.message.indexOf('HTTP') === 0) throw parseErr;
                throw new Error('HTTP ' + resp.status + ' — voir console pour la YSOD');
            }
        }

        if (text.trim().charAt(0) === '<') {
            console.error('[balance] YSOD HTML reçue :', text.substring(0, 2000));
            throw new Error('Réponse HTML reçue (voir console)');
        }

        var data = JSON.parse(text);
        if (!data.success) {
            throw new Error(data.message || 'Erreur balance');
        }

        BalanceState.lignes    = data.lignes || [];
        BalanceState.totaux    = data.totaux || {};
        BalanceState.planOrder = data.planOrder || 1;
        BalanceState.loaded    = true; // ⭐ Marque le chargement comme effectué

        renderBalanceTable();
        updateCounter(data.count);

        refreshSummaryIfCollapsed();

    } catch (err) {
        console.error('[balance] ❌', err);
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
        var isRubrique = l.TYPE_ELEMENT === 'RUBRIQUE';
        var indent = Math.max(0, (l.NIVEAU - 1)) * 15;

        html += '<tr class="bal-row ' + (isRubrique ? 'bal-rubrique' : '') + '">';
        html += '<td class="bal-code" style="padding-left:' + (8 + indent) + 'px;">'
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

    // ⭐ Ligne SOLDE FINAL (Débit - Crédit)
    var netSolde = (t.finalDebit || 0) - (t.finalCredit || 0);
    var isZero = Math.abs(netSolde) < 0.01;
    var soldeClass = isZero ? 'bal-solde-zero' : 'bal-solde-nonzero';

    totHtml += '<tr class="bal-solde-final-row ' + soldeClass + '">';
    totHtml += '<td colspan="7" class="bal-solde-label">SOLDE FINAL (DÉBIT - CRÉDIT)</td>';
    totHtml += '<td class="bal-num bal-solde-value">' + fmt(netSolde) + '</td>';
    totHtml += '</tr>';

    // Indicateur d'équilibre
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

// ⭐ Afficher l'état initial avant le premier chargement
function renderEmptyState() {
    var tbody = document.getElementById('balanceBody');
    var tfoot = document.getElementById('balanceFooter');

    if (tbody) {
        tbody.innerHTML = '<tr><td colspan="8" class="table-empty">'
            + '<i class="fas fa-search"></i>'
            + '<span>Sélectionnez vos filtres et cliquez sur <strong>Charger</strong> pour afficher la balance.</span>'
            + '</td></tr>';
    }
    if (tfoot) {
        tfoot.innerHTML = '';
    }
    updateCounter(0);
}

function updateCounter(n) {
    var el = document.getElementById('balanceCounter');
    if (el) el.textContent = (n || 0) + ' compte(s)';
}

// ══════════════════════════════════════════════════════════════
// RESET
// ══════════════════════════════════════════════════════════════
function resetFilters() {
    if (BalanceState.exercices.length > 0) {
        var first = BalanceState.exercices[0];
        document.getElementById('balExercice').value  = first.ID;
        document.getElementById('balDateDebut').value = first.DATE_DEBUT || '';
        document.getElementById('balDateFin').value   = first.DATE_FIN   || '';
    }
    document.getElementById('balSite').value        = '';
    document.getElementById('balCompteDebut').value = '';
    document.getElementById('balCompteFin').value   = '';

    document.querySelectorAll('.bal-statut').forEach(function (c) {
        c.checked = (c.value === 'VALIDEE' || c.value === 'COMPTABILISEE');
    });

    // On remet l'état à "non chargé" après le reset
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
    link.download = 'balance-generale_' + dateStr + '.csv';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);

    showSuccessToast('Balance exportée en CSV.');
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

console.log('[balance] Module chargé.'); // On garde celui-ci pour confirmer que le script est bien chargé
