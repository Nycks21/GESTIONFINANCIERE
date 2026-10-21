// ui.js — GÉNÉRALE
'use strict';
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

// ─── SPINNER ───
function forceHideSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'none'; s.style.visibility = 'hidden';
    s.style.opacity = '0'; s.setAttribute('aria-hidden', 'true');
}
function showSpinner() {
    var s = document.getElementById('spinnerOverlay');
    if (!s) return;
    s.style.display = 'flex'; s.style.visibility = 'visible';
    s.style.opacity = '1'; s.removeAttribute('aria-hidden');
}
function hideSpinner() { forceHideSpinner(); }

// ─── ESCAPE HTML ───
function escapeHtml(s) {
    if (s === null || s === undefined) return '';
    return String(s)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

// ════════════════════════════════════════════════════════════
// HUB — Sections + cartes
// ════════════════════════════════════════════════════════════
function renderHub() {
    var container = document.getElementById('hubContainer');
    if (!container) return;

    var dbSections = AppState.sections || [];
    var configSections = window.HUB_SECTIONS || [];

    // ⭐ 1. Fusion des sections de la BDD et de config.js
    var sections = [];
    var processedCodes = {};

    // Ajouter les sections venant de la BDD
    dbSections.forEach(function(sec) {
        var code = (sec.CODE || sec.code || '').toUpperCase();
        processedCodes[code] = true;
        sections.push(sec);
    });

    // Ajouter les sections de config.js qui ne sont PAS dans la BDD (ex: STOCK)
    configSections.forEach(function(sec) {
        var code = (sec.code || '').toUpperCase();
        if (!processedCodes[code]) {
            sections.push({
                CODE: sec.code,
                NOM: sec.nom,
                ICONE: sec.icone,
                ORDRE: sec.ordre || 99
            });
            processedCodes[code] = true;
        }
    });

    // ⭐ 2. Tri par ordre
    sections.sort(function (a, b) {
        return (a.ORDRE || a.ordre || 0) - (b.ORDRE || b.ordre || 0);
    });

    var html = '';
    sections.forEach(function (section) {
        var sectionCode  = section.CODE  || section.code  || '';
        var sectionNom   = section.NOM   || section.nom   || '';
        var sectionIcone = section.ICONE || section.icone || 'fas fa-folder';

        var hubSection = configSections.find(function (s) {
            return (s.code || '').toUpperCase() === sectionCode.toUpperCase();
        });
        var cards = hubSection ? (hubSection.cards || []) : [];

        // Si une section existe en BDD mais n'a pas de cartes dans config.js, on l'ignore
        if (cards.length === 0) return;

        html += '<div class="hub-section">';
        html += '  <div class="hub-section-head">';
        html += '    <i class="' + sectionIcone + '"></i>';
        html += '    <span data-i18n="generale.section.' + sectionCode.toLowerCase() + '">' + sectionNom + '</span>';
        html += '  </div>';
        html += '  <div class="hub-cards">';
        cards.forEach(function (card) { html += renderHubCard(card); });
        html += '  </div>';
        html += '</div>';
    });

    container.innerHTML = html;
    if (typeof window.applyTranslations === 'function') {
        try { window.applyTranslations(container); } catch (e) {}
    }
}

function renderHubCard(card) {
    var isDisabled = (card.action === 'disabled');
    var clickAttr  = '';
    var actionAttr = '';

    if (card.action === 'modal') {
        clickAttr = 'onclick="openPlansModal(event)"';
    } else if (card.action === 'link') {
        actionAttr = 'href="' + (card.href || '#') + '"';
    }

    var tag = (card.action === 'link') ? 'a' : 'div';

    var cardHtml = '';
    cardHtml += '<' + tag + ' class="hub-card' + (isDisabled ? ' hub-card-disabled' : '') + '" '
              + actionAttr + ' ' + clickAttr + '>';
    cardHtml += '  <div class="hub-card-icon"><i class="' + (card.icone || 'fas fa-cog') + '"></i></div>';
    cardHtml += '  <div class="hub-card-body">';
    cardHtml += '    <div class="hub-card-title" data-i18n="generale.card.' + card.code + '">' + (card.nom || '') + '</div>';
    cardHtml += '    <div class="hub-card-desc">' + (card.description || '') + '</div>';
    cardHtml += '  </div>';
    if (isDisabled) {
        cardHtml += '  <div class="hub-card-soon">' + _t('generale.soon', 'Bientôt') + '</div>';
    } else if (card.action === 'modal') {
        cardHtml += '  <div class="hub-card-arrow"><i class="fas fa-cog"></i></div>';
    } else {
        cardHtml += '  <div class="hub-card-arrow"><i class="fas fa-arrow-right"></i></div>';
    }
    cardHtml += '</' + tag + '>';

    return cardHtml;
}

// ════════════════════════════════════════════════════════════
// TABLEAU DES PLANS (10 slots) — identifiés par ORDRE
// ════════════════════════════════════════════════════════════
function renderPlansTable() {
    var tbody = document.getElementById('plansTableBody');
    if (!tbody) return;

    var plans = AppState.plans || [];
    if (!plans.length) {
        tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;padding:40px;">'
                        + _t('generale.plans.empty') + '</td></tr>';
        return;
    }

    var html = '';
    plans.forEach(function (p) {
        var ordre        = p.ORDRE;
        var isActive     = !!p.ACTIVE;
        var isPrincipal  = !!p.EST_PRINCIPAL;
        var hasContent   = !!(p.CODE || p.NOM);
        var elementCount = parseInt(p.ELEMENT_COUNT || 0, 10);
        var hasElements  = elementCount > 0;
        var canEdit      = !hasElements;

        var codeHtml = p.CODE
            ? '<span class="badge-code">' + escapeHtml(p.CODE) + '</span>'
            : '<span class="badge-empty">—</span>';

        var nomHtml = p.NOM
            ? '<span class="plan-nom">' + escapeHtml(p.NOM) + '</span>'
            : '<span class="badge-empty">' + _t('generale.plans.no_name') + '</span>';

        var niveauHtml = '<span class="badge-niveau">N' + (p.NIVEAU || 1) + '</span>';

        var typeHtml = p.TYPE_NOM
            ? '<span class="badge-type">' + escapeHtml(p.TYPE_NOM) + '</span>'
            : '<span class="badge-empty">—</span>';

        var principalHtml = isPrincipal
            ? '<span class="badge-principal"><i class="fas fa-star"></i> ' + _t('button.yes') + '</span>'
            : '<span style="color:#ccc;">—</span>';

        var activeHtml = isActive
            ? '<span class="badge-active-ok">' + _t('status.active') + '</span>'
            : '<span class="badge-active-off">' + _t('status.inactive') + '</span>';

        // Éditer
        var editTitle = hasElements
            ? _t('generale.plans.edit_locked_tooltip', 'Modification impossible : ce plan contient déjà des éléments.')
            : _t('button.edit');

        var editBtn = canEdit
            ? '<button type="button" class="btn btn-sm btn-primary" '
              + 'onclick="editPlan(' + ordre + ')" title="' + editTitle + '">'
              + '<i class="fas fa-edit"></i></button> '
            : '<button type="button" class="btn btn-sm btn-secondary btn-locked" disabled '
              + 'title="' + editTitle + '">'
              + '<i class="fas fa-lock"></i></button> ';

        // Toggle
        var toggleTitle = isActive ? _t('generale.plans.deactivate') : _t('generale.plans.activate');
        var toggleBtn = '<button type="button" class="btn btn-sm ' + (isActive ? 'btn-warning' : 'btn-success') + '" '
                      + 'onclick="togglePlan(' + ordre + ', ' + (isActive ? 'false' : 'true') + ')" '
                      + 'title="' + toggleTitle + '">'
                      + '<i class="fas ' + (isActive ? 'fa-toggle-on' : 'fa-toggle-off') + '"></i></button> ';

        // Supprimer
        var deleteBtn = '';
        if (hasElements) {
            var t1 = _t('generale.plans.delete_locked_tooltip', 'Suppression impossible.')
                     .replace('{count}', elementCount);
            deleteBtn = '<button type="button" class="btn btn-sm btn-secondary btn-locked" disabled '
                      + 'title="' + t1 + '"><i class="fas fa-trash"></i></button>';
        } else if (hasContent || isActive) {
            var t2 = _t('generale.plans.delete_tooltip', 'Supprimer ce plan');
            deleteBtn = '<button type="button" class="btn btn-sm btn-danger" '
                      + 'onclick="deletePlanConfig(' + ordre + ')" title="' + t2 + '">'
                      + '<i class="fas fa-trash"></i></button>';
        } else {
            var t3 = _t('generale.plans.delete_empty_slot', 'Slot vide — rien à supprimer');
            deleteBtn = '<button type="button" class="btn btn-sm btn-secondary btn-locked" disabled '
                      + 'title="' + t3 + '"><i class="fas fa-trash"></i></button>';
        }

        // Éléments
        var elementsBtn = '';
        if (isActive && hasContent) {
            elementsBtn = '<button type="button" class="btn btn-sm btn-info" '
                        + 'onclick="openElementsPage(' + ordre + ')" '
                        + 'title="' + _t('generale.plans.manage_elements', 'Gérer les éléments') + '">'
                        + '<i class="fas fa-sitemap"></i></button> ';
        }

        // Badge compteur
        var elementCountHtml = hasElements
            ? '<span class="badge-count" title="' + _t('generale.plans.elements_count', 'Éléments') + '">'
              + '<i class="fas fa-sitemap"></i> ' + elementCount + '</span>'
            : '';

        html += '<tr' + (isActive ? ' class="row-active"' : '') + '>'
            + '<td style="text-align:center;"><span class="slot-num">' + ordre + '</span></td>'
            + '<td>' + codeHtml + '</td>'
            + '<td>' + nomHtml + ' ' + elementCountHtml + '</td>'
            + '<td style="text-align:center;">' + niveauHtml + '</td>'
            + '<td>' + typeHtml + '</td>'
            + '<td style="text-align:center;">' + principalHtml + '</td>'
            + '<td style="text-align:center;">' + activeHtml + '</td>'
            + '<td style="text-align:right;">'
            +   elementsBtn + editBtn + toggleBtn + deleteBtn
            + '</td>'
            + '</tr>';
    });
    tbody.innerHTML = html;
}

// ─── Modales ───
function openPlansModal(e) {
    if (e) e.preventDefault();
    document.getElementById('plansModal').style.display = 'flex';
    loadPlans();
}
function closePlansModal() { document.getElementById('plansModal').style.display = 'none'; }
function openPlanEditModal() { document.getElementById('planEditModal').style.display = 'flex'; }
function closePlanEditModal() {
    document.getElementById('planEditModal').style.display = 'none';
    AppState.editingPlanOrdre = null;
    clearErrors('#planEditModal');
}

// ─── Erreurs ───
function clearErrors(scopeSelector) {
    var scope = scopeSelector ? document.querySelector(scopeSelector) : document;
    if (!scope) return;
    scope.querySelectorAll('.field-error').forEach(function (el) {
        el.textContent = ''; el.style.display = 'none';
    });
    scope.querySelectorAll('.is-invalid').forEach(function (el) {
        el.classList.remove('is-invalid');
    });
}
function showFieldError(fieldId, msg) {
    var errEl = document.getElementById('err-' + fieldId);
    if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; }
    var f = document.getElementById(fieldId);
    if (f) f.classList.add('is-invalid');
}

// ─── Exposition ───
window.showSpinner        = showSpinner;
window.hideSpinner        = hideSpinner;
window.forceHideSpinner   = forceHideSpinner;
window.renderHub          = renderHub;
window.renderPlansTable   = renderPlansTable;
window.openPlansModal     = openPlansModal;
window.closePlansModal    = closePlansModal;
window.openPlanEditModal  = openPlanEditModal;
window.closePlanEditModal = closePlanEditModal;
window.clearErrors        = clearErrors;
window.showFieldError     = showFieldError;
window.escapeHtml         = escapeHtml;
