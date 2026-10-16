// i18n-refresh.js — Rafraîchissement dynamique au changement de langue (MARCHE)
'use strict';

function refreshI18nDynamic() {
    try {
        // 1) Re-render des en-têtes de plans
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

        // 3) Re-render de la liste des marchés (Vue gère son rendu)
        if (window._VueMarcheList) {
            window.dispatchEvent(new Event('languagechange'));
        }

        // 4) Re-render du hint auxiliaire
        if (typeof refreshAuxiliaireField === 'function') {
            var aux = document.getElementById('flAux');
            if (aux) refreshAuxiliaireField({ preserveValue: true });
        }

        var marcheAuxHint = document.getElementById('marAuxHint');
        if (marcheAuxHint) {
            var marcheAuxHintKey = marcheAuxHint.getAttribute('data-hint-key');
            if (marcheAuxHintKey) marcheAuxHint.textContent = _t(marcheAuxHintKey) || '';
        }

        // 5) Re-render du compteur de lignes
        _refreshLinesCounter();

        // 6) Re-render des options dynamiques déjà chargées
        if (typeof populateHeaderSelects === 'function') {
            var saveVals = {};
            ['marSite','marFournisseur','marArticle'].forEach(function (id) {
                var el = document.getElementById(id);
                if (el) saveVals[id] = el.value;
            });
            populateHeaderSelects();
            Object.keys(saveVals).forEach(function (id) {
                var el = document.getElementById(id);
                if (el) el.value = saveVals[id];
            });
        }

        console.log('[i18n-refresh] Composants dynamiques rafraîchis.');
    } catch (err) {
        console.error('[i18n-refresh] Erreur :', err);
    }
}

function _refreshLinesCounter() {
    var el = document.getElementById('marLinesCounter');
    if (!el || !AppState || !AppState.lignes) return;
    var n = AppState.lignes.length;
    el.textContent = '(' + n + ' ' + _t('marche.lines_count_unit') + ')';
    el.style.display = n > 0 ? 'inline-block' : 'none';
}

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

window.refreshI18nDynamic = refreshI18nDynamic;

console.log('[i18n-refresh] Module chargé.');
