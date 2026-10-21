// money-input.js — Formatage monétaire centralisé (FR)
'use strict';

// ============================================================
// FORMATAGE / PARSING
// ============================================================
function formatMoneyFR(value) {
    var n = (typeof parseMontant === 'function') ? parseMontant(value) : parseFloat(value);
    if (isNaN(n)) n = 0;
    var s = n.toFixed(2);
    var parts = s.split('.');
    var intPart = parts[0];
    var decPart = parts[1] || '00';

    var negative = intPart.charAt(0) === '-';
    if (negative) intPart = intPart.substring(1);

    intPart = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ' ');

    return (negative ? '-' : '') + intPart + ',' + decPart;
}

function parseMoneyFR(str) {
    if (typeof parseMontant === 'function') return parseMontant(str);
    if (str === null || str === undefined) return 0;
    var s = String(str).trim();
    if (!s) return 0;
    s = s.replace(/[\s\u00A0]/g, '').replace(',', '.');
    s = s.replace(/[^0-9.\-]/g, '');
    var negative = s.charAt(0) === '-';
    s = s.replace(/-/g, '');
    s = s.replace(/\.(?=.*\.)/g, '');
    var n = parseFloat(s);
    if (isNaN(n)) return 0;
    return negative ? -n : n;
}

// ============================================================
// ATTACHEMENT DES ÉVÉNEMENTS
// ============================================================
function attachMoneyFormatting(input) {
    if (!input || input.dataset.moneyAttached === '1') return;
    input.dataset.moneyAttached = '1';
    input.dataset.moneyField = '1';

    input.setAttribute('type', 'text');
    input.setAttribute('inputmode', 'decimal');
    input.setAttribute('autocomplete', 'off');
    input.setAttribute('spellcheck', 'false');
    input.style.textAlign = 'right';

    var initialRaw = input.value;
    var num = (initialRaw === '' || initialRaw === null) ? 0 : parseMoneyFR(initialRaw);

    // ⭐ Double stockage (compat ascendante + clarté)
    input.dataset.numericValue = String(num);
    input.dataset.rawValue     = String(num);
    input.value = formatMoneyFR(num);

    // Focus : édition sans séparateurs
    input.addEventListener('focus', function () {
        var n = parseFloat(input.dataset.numericValue) || 0;
        if (n === 0) {
            input.value = '';
        } else {
            input.value = String(n).replace('.', ',');
        }
        setTimeout(function () {
            try { input.select(); } catch (e) { /* ignore */ }
        }, 0);
    });

    // Blur : reformatage complet
    input.addEventListener('blur', function () {
        var n = parseMoneyFR(input.value);
        input.dataset.numericValue = String(n);
        input.dataset.rawValue     = String(n);
        input.value = formatMoneyFR(n);
    });

    // Keydown : filtre caractères
    input.addEventListener('keydown', function (e) {
        var allowedKeys = [
            'Backspace', 'Delete', 'Tab', 'Escape', 'Enter',
            'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown',
            'Home', 'End'
        ];
        if (allowedKeys.indexOf(e.key) >= 0) return;
        if (e.ctrlKey || e.metaKey) return;
        if (e.altKey) return;
        if (/^[0-9]$/.test(e.key)) return;
        if (e.key === ',' || e.key === '.') return;
        if (e.key === '-') return;
        e.preventDefault();
    });

    // Paste : nettoyage
    input.addEventListener('paste', function (e) {
        e.preventDefault();
        var pasted = (e.clipboardData || window.clipboardData).getData('text') || '';
        var n = parseMoneyFR(pasted);
        input.value = String(n).replace('.', ',');
        input.dataset.numericValue = String(n);
        input.dataset.rawValue     = String(n);
    });

    // ⭐ Input : resync IMMÉDIAT (indispensable pour submit sans blur)
    input.addEventListener('input', function () {
        var n = parseMoneyFR(input.value);
        input.dataset.numericValue = String(n);
        input.dataset.rawValue     = String(n);
    });
}

// ============================================================
// INITIALISATION GLOBALE
// ============================================================
function initMoneyInputs() {
    var list = document.querySelectorAll('[data-money-field="1"], input.money-input');
    var n = 0;
    list.forEach(function (input) {
        attachMoneyFormatting(input);
        n++;
    });
    console.log('[money-input] Champs monétaires initialisés :', n);
}

// ============================================================
// ⭐ HELPERS PUBLICS
// ============================================================
/**
 * Retourne la valeur numérique d'un champ money.
 * Priorité : data-numeric-value (money-input.js) > parseMontant(.value) > 0
 */
function getMoneyNumericValue(inputId) {
    var el = document.getElementById(inputId);
    if (!el) return 0;

    // Priorité 1 : valeur canonique posée par money-input.js
    var raw = el.dataset.numericValue;
    if (raw !== undefined && raw !== null && raw !== '') {
        var n1 = parseFloat(raw);
        if (isFinite(n1)) return n1;
    }

    // Priorité 2 : parse robuste de .value (gère "2 000 000,00")
    if (typeof parseMontant === 'function') return parseMontant(el.value);
    return parseMoneyFR(el.value);
}

function setMoneyValue(inputId, value) {
    var el = document.getElementById(inputId);
    if (!el) return;

    if (el.dataset.moneyAttached !== '1' && typeof attachMoneyFormatting === 'function') {
        attachMoneyFormatting(el);
    }

    var n = (typeof parseMontant === 'function') ? parseMontant(value) : parseFloat(value);
    if (isNaN(n)) n = 0;

    el.dataset.numericValue = String(n);
    el.dataset.rawValue     = String(n);

    if (document.activeElement === el) {
        el.value = n === 0 ? '' : String(n).replace('.', ',');
    } else {
        el.value = formatMoneyFR(n);
    }
}

window.formatMoneyFR         = formatMoneyFR;
window.parseMoneyFR          = parseMoneyFR;
window.attachMoneyFormatting = attachMoneyFormatting;
window.initMoneyInputs       = initMoneyInputs;
window.getMoneyNumericValue  = getMoneyNumericValue;
window.setMoneyValue         = setMoneyValue;

console.log('[money-input] Module chargé.');
