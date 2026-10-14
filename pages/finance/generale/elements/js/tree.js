// tree.js — Rendu hiérarchique des éléments
'use strict';

function getMaxLevel() {
    if (AppState.plan && AppState.plan.NIVEAU) return AppState.plan.NIVEAU;
    return 4;
}

function renderLevelTabs() {
    var container = document.getElementById('levelTabs');
    if (!container) return;
    var max = getMaxLevel();
    var html = '';
    for (var i = 1; i <= max; i++) {
        var active = (i === AppState.currentLevel) ? 'active' : '';
        var count = getLevelCount(i);
        html += '<button type="button" class="level-tab ' + active + '" onclick="switchLevel(' + i + ')">'
              + '<i class="fas fa-layer-group"></i> <span>N' + i + '</span>'
              + (count > 0 ? ' <span class="level-count">' + count + '</span>' : '')
              + '</button>';
    }
    container.innerHTML = html;
}

function getLevelCount(level) {
    return (AppState.elements || []).filter(function (e) { return e.NIVEAU === level; }).length;
}

function switchLevel(level) {
    AppState.currentLevel = level;
    renderLevelTabs();
    renderElementsTable();
}

function renderElementsTable() {
    var tbody = document.getElementById('elementsTableBody');
    if (!tbody) return;

    var level = AppState.currentLevel;
    var search = (AppState.filters.search || '').toLowerCase();
    var activeFilter = AppState.filters.active;

    var list = (AppState.elements || []).filter(function (e) {
        if (e.NIVEAU !== level) return false;
        if (search) {
            var hay = ((e.CODE || '') + ' ' + (e.LIBELLE || '')).toLowerCase();
            if (hay.indexOf(search) === -1) return false;
        }
        if (activeFilter !== '') {
            var isAct = !!e.ACTIVE;
            if (activeFilter === '1' && !isAct) return false;
            if (activeFilter === '0' && isAct) return false;
        }
        return true;
    });

    list.sort(function (a, b) {
        var oa = a.ORDRE || 0, ob = b.ORDRE || 0;
        if (oa !== ob) return oa - ob;
        return (a.CODE || '').localeCompare(b.CODE || '');
    });

    if (!list.length) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;padding:60px;color:#94A3B8;">'
                        + '<i class="fas fa-sitemap" style="font-size:38px;opacity:.3;display:block;margin-bottom:10px;"></i>'
                        + _t('elements.msg.no_data') + '</td></tr>';
        updateCounter(0);
        return;
    }

    var html = '';
    list.forEach(function (e) {
        var indent = (e.NIVEAU - 1) * 22;
        var codeHtml = '<span class="tree-indent" style="margin-left:' + indent + 'px;"></span>'
                     + (e.NIVEAU > 1 ? '<i class="fas fa-level-up-alt tree-arrow"></i>' : '')
                     + '<span class="badge-code">' + _esc(e.CODE) + '</span>';

        var auxBadge = e.EST_AUXILIAIRE
            ? ' <span class="badge-auxiliaire" title="' + _t('elements.badge.auxiliaire') + '">'
              + '<i class="fas fa-users"></i> AUX</span>'
            : '';
        var libelleHtml = '<span class="plan-nom">' + _esc(e.LIBELLE) + '</span>' + auxBadge;

        var niveauHtml = '<span class="badge-niveau">N' + e.NIVEAU + '</span>';

        var typeHtml = (e.TYPE_ELEMENT === 'RUBRIQUE')
            ? '<span class="badge-type-rub">RUBRIQUE</span>'
            : '<span class="badge-type-det">DÉTAIL</span>';

        var activeHtml = e.ACTIVE
            ? '<span class="badge-active-ok">' + _t('status.active') + '</span>'
            : '<span class="badge-active-off">' + _t('status.inactive') + '</span>';

        html += '<tr>'
            + '<td>' + codeHtml + '</td>'
            + '<td>' + libelleHtml + '</td>'
            + '<td style="text-align:center;">' + niveauHtml + '</td>'
            + '<td>' + typeHtml + '</td>'
            + '<td style="text-align:center;">' + activeHtml + '</td>'
            + '<td style="text-align:right;">'
            +   '<button type="button" class="btn btn-sm btn-primary" onclick="editElement(\'' + e.ID + '\')" title="' + _t('button.edit') + '"><i class="fas fa-edit"></i></button> '
            +   '<button type="button" class="btn btn-sm btn-danger" onclick="deleteElement(\'' + e.ID + '\')" title="' + _t('button.delete') + '"><i class="fas fa-trash"></i></button>'
            + '</td>'
            + '</tr>';
    });
    tbody.innerHTML = html;
    updateCounter(list.length);
}

function updateCounter(n) {
    var el = document.getElementById('resultsCounter');
    if (el) el.textContent = _t('elements.counter').replace('{n}', n);
}

function _esc(s) {
    if (s === null || s === undefined) return '';
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function resetFilters() {
    AppState.filters.search = '';
    AppState.filters.active = '';
    var s = document.getElementById('search-filter');
    var a = document.getElementById('active-filter');
    if (s) s.value = '';
    if (a) a.value = '';
    renderElementsTable();
}

window.renderLevelTabs     = renderLevelTabs;
window.renderElementsTable = renderElementsTable;
window.switchLevel         = switchLevel;
window.resetFilters        = resetFilters;
