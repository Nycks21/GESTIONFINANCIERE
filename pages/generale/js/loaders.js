// loaders.js — GÉNÉRALE
function _t(k, p) { return (typeof window.t === 'function') ? window.t(k, p) : k; }

async function loadSections() {
    try {
        var url = API.BASE + API.HANDLERS_PATH + API.SECTIONS;
        var resp = await fetch(url);
        var data = await resp.json();
        if (data.success) AppState.sections = data.sections || [];
        else { console.warn('[loadSections] success=false:', data.message); AppState.sections = []; }
    } catch (err) {
        console.error('[loadSections] Erreur :', err);
        AppState.sections = [];
    }
    renderHub();
}

async function loadPlans() {
    try {
        showSpinner();
        var url = API.BASE + API.HANDLERS_PATH + API.PLANS_LIST;
        var resp = await fetch(url);
        var data = await resp.json();

        if (data.success) {
            AppState.plans     = data.plans || [];
            AppState.planTypes = data.types || [];
            renderPlansTable();
            populatePlanTypeSelect();
        } else {
            showErrorToast(data.message || _t('generale.plans.load_error'));
        }
    } catch (err) {
        showErrorToast(err.message);
    } finally {
        hideSpinner();
    }
}

function populatePlanTypeSelect() {
    var sel = document.getElementById('planType');
    if (!sel) return;
    sel.innerHTML = '<option value="">— ' + _t('generale.plans.type_none') + ' —</option>';
    (AppState.planTypes || []).forEach(function (t) {
        var opt = document.createElement('option');
        opt.value = t.CODE;
        opt.textContent = t.NOM;
        sel.appendChild(opt);
    });
}

window.loadSections = loadSections;
window.loadPlans    = loadPlans;
