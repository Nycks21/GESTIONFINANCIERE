// money-input.js — Formatage monétaire centralisé (FR)
'use strict';

// ============================================================
// FORMATAGE / PARSING
// ============================================================
function formatMoneyFR(value) {
    var n = parseFloat(value);
    if (isNaN(n)) n = 0;
    var s = n.toFixed(2);
    var parts = s.split('.');
    var intPart = parts[0];
    var decPart = parts[1] || '00';

    // Signe négatif
    var negative = intPart.charAt(0) === '-';
    if (negative) intPart = intPart.substring(1);

    // Séparateur de milliers (espace)
    intPart = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ' ');

    return (negative ? '-' : '') + intPart + ',' + decPart;
}

function parseMoneyFR(str) {
    if (str === null || str === undefined) return 0;
    var s = String(str).trim();
    if (!s) return 0;

    // Retire espaces (y compris insécables) et remplace virgule par point
    s = s.replace(/[\s\u00A0]/g, '')
         .replace(',', '.');

    // Ne garde que chiffres, point et signe -
    s = s.replace(/[^0-9.\-]/g, '');

    // Évite "..", "--" et positions invalides
    var negative = s.charAt(0) === '-';
    s = s.replace(/-/g, '');
    s = s.replace(/\.(?=.*\.)/g, ''); // garde seulement le dernier point

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

    // Force en type=text avec inputmode decimal
    input.setAttribute('type', 'text');
    input.setAttribute('inputmode', 'decimal');
    input.setAttribute('autocomplete', 'off');
    input.setAttribute('spellcheck', 'false');
    input.style.textAlign = 'right';

    // Initialise valeur numérique + affichage
    var initialRaw = input.value;
    var num = (initialRaw === '' || initialRaw === null)
        ? 0
        : parseMoneyFR(initialRaw);
    input.dataset.numericValue = String(num);
    input.value = formatMoneyFR(num);

    // ─── Focus : enlève les séparateurs pour édition facile ───
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

    // ─── Blur : applique le formatage complet ───
    input.addEventListener('blur', function () {
        var n = parseMoneyFR(input.value);
        input.dataset.numericValue = String(n);
        input.value = formatMoneyFR(n);
    });

    // ─── Keydown : filtre les caractères autorisés ───
    input.addEventListener('keydown', function (e) {
        var allowedKeys = [
            'Backspace', 'Delete', 'Tab', 'Escape', 'Enter',
            'ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown',
            'Home', 'End'
        ];
        if (allowedKeys.indexOf(e.key) >= 0) return;
        if (e.ctrlKey || e.metaKey) return;   // Ctrl+C, Ctrl+V, Ctrl+A...
        if (e.altKey) return;

        if (/^[0-9]$/.test(e.key)) return;    // Chiffres
        if (e.key === ',' || e.key === '.') return;  // Séparateurs
        if (e.key === '-') return;            // Signe

        e.preventDefault();
    });

    // ─── Paste : nettoie le presse-papier ───
    input.addEventListener('paste', function (e) {
        e.preventDefault();
        var pasted = (e.clipboardData || window.clipboardData).getData('text') || '';
        var n = parseMoneyFR(pasted);
        input.value = String(n).replace('.', ',');
        input.dataset.numericValue = String(n);
    });

    // ─── Input : met à jour la valeur numérique en temps réel ───
    input.addEventListener('input', function () {
        var n = parseMoneyFR(input.value);
        input.dataset.numericValue = String(n);
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
// HELPERS PUBLICS
// ============================================================
function getMoneyNumericValue(inputId) {
    var el = document.getElementById(inputId);
    if (!el) return 0;
    return parseFloat(el.dataset.numericValue || '0') || 0;
}

function setMoneyValue(inputId, value) {
    var el = document.getElementById(inputId);
    if (!el) return;

    // S'assure que le champ est attaché
    if (el.dataset.moneyAttached !== '1' && typeof attachMoneyFormatting === 'function') {
        attachMoneyFormatting(el);
    }

    var n = parseFloat(value);
    if (isNaN(n)) n = 0;

    el.dataset.numericValue = String(n);

    // Si focus : format "édition", sinon format "affichage"
    if (document.activeElement === el) {
        el.value = n === 0 ? '' : String(n).replace('.', ',');
    } else {
        el.value = formatMoneyFR(n);
    }
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.formatMoneyFR         = formatMoneyFR;
window.parseMoneyFR          = parseMoneyFR;
window.attachMoneyFormatting = attachMoneyFormatting;
window.initMoneyInputs       = initMoneyInputs;
window.getMoneyNumericValue  = getMoneyNumericValue;
window.setMoneyValue         = setMoneyValue;

console.log('[money-input] Module chargé.');
