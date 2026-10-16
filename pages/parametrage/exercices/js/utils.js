// utils.js — EXERCICES
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

function formatDateFr(dateStr) {
    if (!dateStr) return '—';
    var d = new Date(dateStr);
    if (isNaN(d.getTime())) return dateStr;
    return String(d.getDate()).padStart(2, '0') + '/' +
           String(d.getMonth() + 1).padStart(2, '0') + '/' +
           d.getFullYear();
}

// Calcule la durée en mois entre 2 dates (approximatif, arrondi)
function formatDureeMois(debut, fin) {
    if (!debut || !fin) return '—';
    var d1 = new Date(debut), d2 = new Date(fin);
    if (isNaN(d1) || isNaN(d2)) return '—';
    var mois = (d2.getFullYear() - d1.getFullYear()) * 12 + (d2.getMonth() - d1.getMonth());
    if (mois < 0) return '—';
    if (mois === 0) return '< 1 mois';
    if (mois === 1) return '1 mois';
    if (mois < 12) return mois + ' mois';
    var ans = Math.floor(mois / 12);
    var rest = mois % 12;
    return ans + ' an' + (ans > 1 ? 's' : '') + (rest > 0 ? ' ' + rest + ' mois' : '');
}

window.showToast        = showToast;
window.showErrorToast   = showErrorToast;
window.showSuccessToast = showSuccessToast;
window.formatDateFr     = formatDateFr;
window.formatDureeMois  = formatDureeMois;
