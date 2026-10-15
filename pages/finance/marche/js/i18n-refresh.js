// i18n-refresh.js — Rafraîchissement dynamique au changement de langue
'use strict';

function refreshI18nDynamic() {
    try {
        // 1) Re-render des en-têtes de plans (labels dynamiques FPLAN_HEADER.CODE)
        if (typeof renderGridHead === 'function') {
            var sel = AppState && AppState.selectedLigneIndex;
            renderGridHead();
            if (typeof renderGrid === 'function' && AppState && AppState.lignes) {
                renderGrid();
            }
            if (sel != null && AppState) AppState.selectedLigneIndex = sel;
        }

        // 2) Re-render du formulaire de plans
        if (typeof renderFormPlanFields === 'function') {
            var preserved = {};
            document.querySelectorAll('#dynPlanFieldsRow select').forEach(function (s) {
                preserved[s.id] = s.value;
            });
            renderFormPlanFields();
            if (typeof populatePlanSelectsForm === 'function') {
                populatePlanSelectsForm();
            }
            Object.keys(preserved).forEach(function (id) {
                var el = document.getElementById(id);
                if (el) el.value = preserved[id];
            });
        }

        // 3) Re-render de la liste des écritures
        //    ⭐ Si Vue est présent, il gère son propre rendu via réactivité
        if (window._VueSaisieList) {
            // Déclenche un re-render Vue en forçant un tick réactif
            window.dispatchEvent(new Event('languagechange'));
        } else if (typeof renderEcrituresList === 'function') {
            renderEcrituresList();
        }

        // 4) Re-render des lignes d'écriture déployées (fallback vanilla uniquement)
        if (!window._VueSaisieList
            && AppState && AppState.expandedEcritures
            && typeof buildEcritureLinesRow === 'function') {
            Object.keys(AppState.expandedEcritures).forEach(function (ecrId) {
                if (!AppState.expandedEcritures[ecrId]) return;
                var lignes = AppState.ecritureLinesCache && AppState.ecritureLinesCache[ecrId];
                if (!lignes) return;
                var sub = document.querySelector('tr.ecr-sub-row[data-ecriture-id="' + ecrId + '"]');
                if (!sub) return;
                var tmp = document.createElement('tbody');
                tmp.innerHTML = buildEcritureLinesRow(ecrId, lignes);
                sub.parentNode.replaceChild(tmp.firstChild, sub);
            });
        }

        // 5) Re-render du hint auxiliaire
        if (typeof refreshAuxiliaireField === 'function') {
            var aux = document.getElementById('flAux');
            if (aux) {
                refreshAuxiliaireField({ preserveValue: true });
            }
        }

        // 6) Re-render du compteur de lignes
        _refreshLinesCounter();

        // 7) Re-render des options dynamiques déjà chargées
        if (typeof populateHeaderSelects === 'function') {
            var saveVals = {};
            ['ecrSite','ecrJournal','ecrExercice','ecrDevise','flMode','flSub'].forEach(function (id) {
                var el = document.getElementById(id);
                if (el) saveVals[id] = el.value;
            });
            populateHeaderSelects();
            Object.keys(saveVals).forEach(function (id) {
                var el = document.getElementById(id);
                if (el) el.value = saveVals[id];
            });
        }

        // 8) Compteur de résultats (fallback vanilla uniquement)
        if (!window._VueSaisieList && AppState && AppState.total != null) {
            var c = document.getElementById('resultsCounter');
            if (c) c.textContent = AppState.total + ' ' + _t('saisie.counter_unit');
        }

        console.log('[i18n-refresh] Composants dynamiques rafraîchis.');
    } catch (err) {
        console.error('[i18n-refresh] Erreur :', err);
    }
}

// ============================================================
// COMPTEUR DE LIGNES
// ============================================================
function _refreshLinesCounter() {
    var el = document.getElementById('ecrLinesCounter');
    if (!el || !AppState || !AppState.lignes) return;
    var n = AppState.lignes.length;
    el.textContent = '(' + n + ' ' + _t('saisie.lines_count_unit') + ')';
    el.style.display = n > 0 ? 'inline-block' : 'none';
}

// ============================================================
// ÉCOUTE DU CHANGEMENT DE LANGUE
// ============================================================
document.addEventListener('languagechange', refreshI18nDynamic);

document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('[data-lang], .lang-selector, #languageSelector')
        .forEach(function (el) {
            el.addEventListener('click', function () {
                setTimeout(refreshI18nDynamic, 150);
            });
        });
});

document.addEventListener('DOMContentLoaded', function () {
    var html = document.documentElement;
    var lastLang = html.getAttribute('lang');

    var obs = new MutationObserver(function () {
        var cur = html.getAttribute('lang');
        if (cur && cur !== lastLang) {
            lastLang = cur;
            setTimeout(refreshI18nDynamic, 150);
        }
    });
    obs.observe(html, { attributes: true, attributeFilter: ['lang'] });
});

// ============================================================
// EXPOSITION GLOBALE
// ============================================================
window.refreshI18nDynamic = refreshI18nDynamic;

console.log('[i18n-refresh] Module chargé.');
