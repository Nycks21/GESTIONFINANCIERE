// init.js — SAISIE (orchestrateur + listeners + raccourcis + mode compact + money inputs + Vue)
'use strict';

$(document).ready(function () {

    // ============================================================
    // 0) PRÉ-INITIALISATION
    // ============================================================
    if (typeof restoreCompactMode === 'function') {
        restoreCompactMode();
    }
    if (typeof initKeyboardShortcuts === 'function') {
        initKeyboardShortcuts();
    }
    if (typeof initMoneyInputs === 'function') {
        initMoneyInputs();
    }

    // ============================================================
    // 1) CHARGEMENT INITIAL
    //    - loadLookups → référentiels + comptes des plans
    //    - editEcriture → écriture demandée, sinon nouvelle écriture
    // ============================================================
    loadLookups()
        .then(function () {
            bindDynamicPlanListeners();
            var query = new URLSearchParams(window.location.search);
            var editId = query.get('editId') || query.get('id');
            if (editId) {
                return editEcriture(editId);
            }
            newEcriture();
        })
        .catch(function (err) {
            console.error('[init] Erreur chargement initial :', err);
            showErrorToast(
                _t('saisie.msg.init_error') ||
                'Erreur lors du chargement initial.'
            );
        });

    // La liste est gérée sur liste-ecritures.aspx, pas sur le formulaire de saisie.
    $(document).on('input change', '#tab-edit input, #tab-edit select, #tab-edit textarea', function () {
        if (typeof markDirty === 'function') markDirty();
    });

    // ============================================================
    // 3) ENTÊTE — Journal → numéro auto
    // ============================================================
    $(document).on('change', '#ecrJournal', function () {
        if (!AppState.editingId) loadNextNumero();
    });

    // ============================================================
    // 4) ENTÊTE — Exercice → recharge les périodes
    // ============================================================
    $(document).on('change', '#ecrExercice', function () {
        var exId = this.value;
        loadPeriodes(exId).then(function () {
            var d = _getVal('ecrDate');
            if (d) _setVal('ecrPeriode', findPeriodeId(d));
        }).catch(function (err) {
            showErrorToast(err.message);
        });
    });

    // ============================================================
    // 5) ENTÊTE — À la sortie de la date, vérifie l'exercice puis la période
    // ============================================================
    var dateOrderAlertPromise = null;
    var blockedDateOrderShortcutKeys = [
        'n', 'v', 's', 'd', 'e', 'c', 'z', 'f', 'k', 'delete', 'backspace'
    ];

    function showDateOrderWarning() {
        if (!isDatePieceAfterComptable()) return Promise.resolve();
        if (dateOrderAlertPromise) return dateOrderAlertPromise;

        var date = _getVal('ecrDate');
        var exerciceUnavailable = !!(date
            && typeof findExerciceIdByDate === 'function'
            && !findExerciceIdByDate(date));
        dateOrderAlertPromise = showDatePieceOrderAlert(exerciceUnavailable).then(function (result) {
            dateOrderAlertPromise = null;
            return result;
        }, function (err) {
            dateOrderAlertPromise = null;
            throw err;
        });
        return dateOrderAlertPromise;
    }

    function isDateCorrectionTarget(target) {
        return !!(target && target.closest && target.closest('#ecrDate, #ecrDatePiece'));
    }

    function isAlertTarget(target) {
        return !!(target && target.closest && target.closest('.swal2-container'));
    }

    function blockInvalidDateAction(event) {
        if (!isDatePieceAfterComptable() || isDateCorrectionTarget(event.target)
            || isAlertTarget(event.target)) {
            return;
        }

        event.preventDefault();
        event.stopPropagation();
        if (typeof event.stopImmediatePropagation === 'function') {
            event.stopImmediatePropagation();
        }
        showDateOrderWarning();
    }

    function isActionTarget(target) {
        return !!(target && target.closest
            && target.closest('button, a[href], input, select, textarea, [onclick], [role="button"], [tabindex]'));
    }

    // Keep the entry form locked to date corrections until the date order is valid.
    document.addEventListener('click', function (event) {
        if (isActionTarget(event.target)) blockInvalidDateAction(event);
    }, true);

    document.addEventListener('focusin', function (event) {
        if (!isActionTarget(event.target) || !isDatePieceAfterComptable()
            || isDateCorrectionTarget(event.target) || isAlertTarget(event.target)) {
            return;
        }
        blockInvalidDateAction(event);
        event.target.blur();
    }, true);

    document.addEventListener('keydown', function (event) {
        if (!isDatePieceAfterComptable() || isAlertTarget(event.target)) return;

        if (isDateCorrectionTarget(event.target)) {
            var shortcutKey = (event.key || '').toLowerCase();
            if (event.altKey && blockedDateOrderShortcutKeys.indexOf(shortcutKey) >= 0) {
                event.preventDefault();
                event.stopPropagation();
                if (typeof event.stopImmediatePropagation === 'function') {
                    event.stopImmediatePropagation();
                }
                showDateOrderWarning();
            } else if (event.key === 'Tab') {
                var nextDateId = event.target.id === 'ecrDate' && !event.shiftKey
                    ? 'ecrDatePiece'
                    : event.target.id === 'ecrDatePiece' && event.shiftKey
                        ? 'ecrDate'
                        : '';
                event.preventDefault();
                if (nextDateId) {
                    document.getElementById(nextDateId).focus();
                } else {
                    showDateOrderWarning();
                }
            }
            return;
        }

        blockInvalidDateAction(event);
    }, true);

    function checkDatePieceOrderOnBlur() {
        return showDateOrderWarning();
    }

    $(document).on('blur', '#ecrDatePiece', function () {
        checkDatePieceOrderOnBlur();
    });

    $(document).on('blur', '#ecrDate', function () {
        var d = this.value;
        if (!d) return;
        checkDatePieceOrderOnBlur().then(function () {
            return syncExerciceFromDate(d);
        }).catch(function (err) {
            showErrorToast(err.message);
        });
    });

    // ============================================================
    // 6) ENTÊTE — Devise → cours
    // ============================================================
    $(document).on('change', '#ecrDevise', function () {
        var id = this.value;
        var m = (AppState.monnaies || []).find(function (x) { return x.ID === id; });
        if (m && m.EST_REFERENCE) _setVal('ecrCours', '1');
    });

});

// ============================================================
// LISTENERS SUR LES CHAMPS DE PLANS DYNAMIQUES
// ============================================================
function bindDynamicPlanListeners() {
    if (typeof getActivePlanFields !== 'function') return;

    var active = getActivePlanFields();
    active.forEach(function (plan) {
        var sel = document.getElementById(plan.selectId);
        if (!sel || sel.dataset.bound === '1') return;
        sel.dataset.bound = '1';

        sel.addEventListener('change', function () {
            if (plan.isPrimary) {
                refreshAuxiliaireField({ preserveValue: false });
            }
            if (typeof markDirty === 'function') markDirty();
        });
    });

    refreshAuxiliaireField({ preserveValue: false });

    console.log('[init] Listeners attachés sur', active.length, 'champ(s) plan.');
}

window.bindDynamicPlanListeners = bindDynamicPlanListeners;
