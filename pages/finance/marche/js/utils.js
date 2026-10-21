// utils.js — SAISIE
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

function escapeHtml(s) {
    if (s === null || s === undefined) return '';
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function showToast(title, message, icon, timer) {
    icon = icon || 'success';
    timer = timer || 3000;
    if (typeof Swal === 'undefined') { alert((title || '') + (message ? '\n' + message : '')); return; }
    var ft = (title || '').toString();
    var fm = (message || '').toString();
    if (!ft && !fm) ft = _t('message.warning') || 'Notification';
    Swal.mixin({
        toast: true, position: 'top-end', showConfirmButton: false, timer: timer,
        timerProgressBar: true,
        didOpen: function (t) {
            t.addEventListener('mouseenter', Swal.stopTimer);
            t.addEventListener('mouseleave', Swal.resumeTimer);
        }
    }).fire({ icon: icon, title: ft, text: fm || undefined });
}

function showErrorToast(m)   { showToast(_t('message.error'), m, 'error'); }
function showSuccessToast(m) { showToast(_t('message.success'), m, 'success'); }

// ============================================================
// ⭐ PARSING MONTANT — robuste FR / EN / formats mixtes
//    parseMontant("2 000 000,00") → 2000000
//    parseMontant("2,000,000.00") → 2000000
//    parseMontant("1.234,56")     → 1234.56
//    parseMontant("2000000")      → 2000000
//    parseMontant("")             → 0
// ============================================================
function parseMontant(raw) {
    if (raw === null || raw === undefined) return 0;
    if (typeof raw === 'number') return isFinite(raw) ? raw : 0;
    if (typeof raw !== 'string') return 0;

    var s = String(raw).trim();
    if (!s) return 0;

    // 1. Retirer espaces classiques + insécables + thin space
    s = s.replace(/[\s\u00A0\u202F\u2009]/g, '');

    // 2. Retirer symboles monétaires
    s = s.replace(/[€$£¥]/g, '').replace(/Ar$/i, '');

    // 3. Ne garder que chiffres, point, virgule, signe
    s = s.replace(/[^\d.,\-+]/g, '');

    if (!s || s === '-' || s === '+') return 0;

    // 4. Normaliser le séparateur décimal
    var hasComma = s.indexOf(',') !== -1;
    var dotCount = (s.match(/\./g) || []).length;

    if (hasComma) {
        // Format FR : "1.234.567,89" → "1234567.89"
        s = s.replace(/\./g, '').replace(',', '.');
    } else if (dotCount > 1) {
        // Plusieurs points → milliers : "1.234.567" → "1234567"
        s = s.replace(/\./g, '');
    }
    // 1 seul point = décimal standard ("1234.56") → inchangé

    var n = parseFloat(s);
    return isFinite(n) ? n : 0;
}

function formatMontant(v) {
    var n = parseMontant(v);
    var s = n.toFixed(2);
    var p = s.split('.');
    var intPart = p[0].replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
    return intPart + ',' + (p[1] || '00');
}

function _el(id) { return document.getElementById(id); }
function _setText(id, txt) { var e = _el(id); if (e) e.textContent = txt; }
function _setHtml(id, h) { var e = _el(id); if (e) e.innerHTML = h; }
function _setVal(id, v) { var e = _el(id); if (e) e.value = v; }
function _getVal(id) { var e = _el(id); return e ? e.value : ''; }

window.showToast        = showToast;
window.showErrorToast   = showErrorToast;
window.showSuccessToast = showSuccessToast;
window.escapeHtml       = escapeHtml;
window.parseMontant     = parseMontant;      // ⭐ NOUVEAU
window.formatMontant    = formatMontant;
window._el = _el; window._setText = _setText; window._setHtml = _setHtml;
window._setVal = _setVal; window._getVal = _getVal;
