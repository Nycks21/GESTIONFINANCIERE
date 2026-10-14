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

function formatMontant(v) {
    var n = parseFloat(v || 0);
    if (isNaN(n)) n = 0;
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
window.formatMontant    = formatMontant;
window._el = _el; window._setText = _setText; window._setHtml = _setHtml;
window._setVal = _setVal; window._getVal = _getVal;
