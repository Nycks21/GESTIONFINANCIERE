// utils.js — JOURNAUX
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

function showToast(title, message, icon, timer) {
    icon = icon || 'success';
    timer = timer || 3000;
    if (typeof Swal === 'undefined') { alert((title || '') + (message ? '\n' + message : '')); return; }
    var finalTitle = (title || '').toString();
    var finalMessage = (message || '').toString();
    if (!finalTitle && !finalMessage) finalTitle = _t('message.warning') || 'Notification';
    if (!finalTitle && finalMessage) { finalTitle = finalMessage; finalMessage = ''; }
    Swal.mixin({
        toast: true, position: 'top-end', showConfirmButton: false, timer: timer,
        timerProgressBar: true,
        didOpen: function (toast) {
            toast.addEventListener('mouseenter', Swal.stopTimer);
            toast.addEventListener('mouseleave', Swal.resumeTimer);
        }
    }).fire({ icon: icon, title: finalTitle, text: finalMessage || undefined });
}

function showErrorToast(message)   { showToast(_t('message.error'),   message, 'error');   }
function showSuccessToast(message) { showToast(_t('message.success'), message, 'success'); }

function escapeHtml(s) {
    if (s === null || s === undefined) return '';
    return String(s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

window.showToast        = showToast;
window.showErrorToast   = showErrorToast;
window.showSuccessToast = showSuccessToast;
window.escapeHtml       = escapeHtml;
