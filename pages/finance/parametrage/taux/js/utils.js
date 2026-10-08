// utils.js — TAUX
function _t(key, params) {
    if (typeof window.t === 'function') return window.t(key, params);
    return key;
}

// ============================================================
// TOASTS (identique SITES)
// ============================================================
function showToast(title, message, icon, timer) {
    icon = icon || 'success';
    timer = timer || 3000;

    if (typeof Swal === 'undefined') {
        console.warn('SweetAlert2 non chargé');
        alert((title || '') + (message ? '\n' + message : ''));
        return;
    }

    var finalTitle = (title || '').toString();
    var finalMessage = (message || '').toString();

    if (!finalTitle && !finalMessage) finalTitle = _t('message.warning') || 'Notification';
    if (!finalTitle && finalMessage) { finalTitle = finalMessage; finalMessage = ''; }

    Swal.mixin({
        toast: true,
        position: 'top-end',
        showConfirmButton: false,
        timer: timer,
        timerProgressBar: true,
        didOpen: function (toast) {
            toast.addEventListener('mouseenter', Swal.stopTimer);
            toast.addEventListener('mouseleave', Swal.resumeTimer);
        }
    }).fire({ icon: icon, title: finalTitle, text: finalMessage || undefined });
}

function showErrorToast(message)   { showToast(_t('message.error'),   message, 'error');   }
function showSuccessToast(message) { showToast(_t('message.success'), message, 'success'); }

// ============================================================
// FORMATAGE TAUX (précision adaptative)
// ============================================================
function formatTaux(value) {
    var n = parseFloat(value);
    if (isNaN(n)) return '—';
    // Taux < 1 → plus de décimales, sinon 4
    if (n < 0.01) return n.toFixed(8);
    if (n < 1)    return n.toFixed(6);
    return n.toFixed(4);
}

function formatDateFr(dateStr) {
    if (!dateStr) return '—';
    var d = new Date(dateStr);
    if (isNaN(d.getTime())) return dateStr;
    return String(d.getDate()).padStart(2, '0') + '/' +
           String(d.getMonth() + 1).padStart(2, '0') + '/' +
           d.getFullYear();
}

window.showToast        = showToast;
window.showErrorToast   = showErrorToast;
window.showSuccessToast = showSuccessToast;
window.formatTaux       = formatTaux;
window.formatDateFr     = formatDateFr;
