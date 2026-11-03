// grid.js — Rendu grille + plans dynamiques + auxiliaire filtré + i18n
// ⭐ MODE A : restriction PLAN2..PLAN10 si :
//      (1) compte PLAN1 = 4xxxx + RESTREINDRE_IMPUT_TRESO=1 + journal CATEGORIE_JOURNAL=2
//      (2) compte PLAN1 = 4xxxx + journal CATEGORIE_JOURNAL=1 → INCONDITIONNEL
//      (3) compte PLAN1 = 5xxxx → INCONDITIONNEL
// ⭐ PLAN1 : seuls les comptes 2/3/4/6 sont visibles (aucune injection auto 5xxx).
// ⭐ PAS d'auto-sélection du compte banque : les champs « Détail de la ligne »
//    restent grisés via form.js (applyDetailLockByContext / setDetailLock).
"use strict";
function _t(k, p) {
  return typeof window.t === "function" ? window.t(k, p) : k;
}

window.RESTRICT_ON_TREASURY_ONLY =
  typeof window.RESTRICT_ON_TREASURY_ONLY !== "undefined"
    ? window.RESTRICT_ON_TREASURY_ONLY
    : true;

window.RESTRICT_5XX_ALWAYS =
  typeof window.RESTRICT_5XX_ALWAYS !== "undefined"
    ? window.RESTRICT_5XX_ALWAYS
    : true;

// Préfixes autorisés pour PLAN1 (filtrage du sélecteur)
window.ALLOWED_PLAN1_PREFIXES =
  window.ALLOWED_PLAN1_PREFIXES || ["2", "3", "4", "6"];

// ============================================================
// CATÉGORIE DE JOURNAL (1 = OD, 2 = TRESORERIE)
// ============================================================
function _resolveCategorieJournal(journalId) {
  if (!journalId) return null;
  var arr = AppState && AppState.journaux ? AppState.journaux : [];
  for (var i = 0; i < arr.length; i++) {
    if (arr[i].ID === journalId) {
      var cj = arr[i].CATEGORIE_JOURNAL;
      if (cj !== undefined && cj !== null) {
        var n = Number(cj);
        if (n === 1 || n === 2) return n;
      }
      var tj = String(arr[i].TYPE_JOURNAL || "").toUpperCase();
      if (tj === "BANQUE" || tj === "CAISSE") return 2;
      if (tj) return 1;
      return null;
    }
  }
  return null;
}

function _categorieJournalLabel(cat) {
  if (cat === 2) return _t("saisie.categorie.tresorerie_short", "TRESO");
  if (cat === 1) return _t("saisie.categorie.od_short", "OD");
  return "—";
}

function _categorieJournalBadgeStyle(cat) {
  var base =
    "display:inline-block;padding:2px 8px;border-radius:4px;" +
    "font-size:11px;font-weight:600;text-transform:uppercase;" +
    "letter-spacing:0.3px;";
  if (cat === 2) return base + "background:#fef3c7;color:#92400e;";
  if (cat === 1) return base + "background:#dbeafe;color:#1e40af;";
  return base + "background:#e5e7eb;color:#6b7280;";
}

function _ensureCategorieBadge() {
  var badge = document.getElementById("ecrCategorieBadge");
  if (badge) return badge;
  var jSel = document.getElementById("ecrJournal");
  if (!jSel || !jSel.parentNode) return null;
  badge = document.createElement("span");
  badge.id = "ecrCategorieBadge";
  badge.style.cssText = "display:none;vertical-align:middle;";
  jSel.parentNode.insertBefore(badge, jSel.nextSibling);
  return badge;
}

function _refreshCategorieJournalDisplay() {
  var jId = _getVal("ecrJournal");
  var cat = _resolveCategorieJournal(jId);
  var badge = _ensureCategorieBadge();
  if (!badge) return;
  if (jId && cat !== null) {
    badge.textContent = _categorieJournalLabel(cat);
    badge.style.cssText =
      _categorieJournalBadgeStyle(cat) +
      "vertical-align:middle;display:inline-block;";
  } else {
    badge.style.display = "none";
  }
}

// ============================================================
// RÉSOLUTION COMPTE PAR ID
// ============================================================
function _findCompteByPlanAndId(planOrder, compteId) {
  if (!planOrder || !compteId) return null;
  var arr =
    (AppState.comptesParPlan && AppState.comptesParPlan[planOrder]) || [];
  for (var i = 0; i < arr.length; i++) {
    if (arr[i].ID === compteId) return arr[i];
  }
  return null;
}

function _isComptePlan1Restrictif(compte) {
  if (!compte) return false;
  var code = String(compte.CODE || "");
  if (code.charAt(0) !== "4") return false;
  var flag = compte.RESTREINDRE_IMPUT_TRESO;
  return flag === true || flag === 1 || flag === "1";
}

function _isComptePlan1Financier(compte) {
  if (!compte) return false;
  if (!window.RESTRICT_5XX_ALWAYS) return false;
  var code = String(compte.CODE || "");
  return code.charAt(0) === "5";
}

function _isComptePlan1ODRestrictif(compte) {
  if (!compte) return false;
  var code = String(compte.CODE || "");
  if (code.charAt(0) !== "4") return false;
  return _resolveCategorieJournal(_getVal("ecrJournal")) === 1;
}

// ============================================================
// JOURNAL DE TRÉSORERIE
// ============================================================
function _isTreasuryJournal() {
  return _resolveCategorieJournal(_getVal("ecrJournal")) === 2;
}

function _getJournalCompteBanqueId() {
  var jId = _getVal("ecrJournal");
  if (!jId) return null;
  var arr = AppState && AppState.journaux ? AppState.journaux : [];
  for (var i = 0; i < arr.length; i++) {
    if (arr[i].ID === jId) {
      var cbid = arr[i].COMPTE_BANQUE_ID;
      return cbid && String(cbid).trim() ? String(cbid).trim() : null;
    }
  }
  return null;
}

function _getJournalCompteBanqueCode() {
  var cbId = _getJournalCompteBanqueId();
  if (!cbId) return "";
  var arr = AppState.comptesParPlan[1] || [];
  for (var i = 0; i < arr.length; i++) {
    if (arr[i].ID === cbId) return String(arr[i].CODE || "");
  }
  return "";
}

// ============================================================
// ÉVALUATION RESTRICTION
// ============================================================
function _getPlan1Field() {
  var a = getActivePlanFields();
  for (var i = 0; i < a.length; i++) {
    if (Number(a[i].ordre) === 1) return a[i];
  }
  return null;
}

function _getPlan1CompteFromForm() {
  var plan1 = _getPlan1Field();
  if (!plan1) return null;
  var compteId = _getVal(plan1.selectId);
  if (!compteId) return null;
  return _findCompteByPlanAndId(1, compteId);
}

function _getPlan1RestrictionReason(compte) {
  if (!compte) return null;
  if (_isComptePlan1Financier(compte)) return "5xx";
  var code = String(compte.CODE || "");
  if (code.charAt(0) !== "4") return null;
  if (_isComptePlan1ODRestrictif(compte)) return "4xx_od";
  if (_isComptePlan1Restrictif(compte)) {
    if (window.RESTRICT_ON_TREASURY_ONLY && !_isTreasuryJournal()) return null;
    return "4xx_treso";
  }
  return null;
}

function _shouldRestrictToPlan1() {
  return _getPlan1RestrictionReason(_getPlan1CompteFromForm()) !== null;
}

function _shouldRestrictLine(l) {
  if (!l) return false;
  var plan1 = _getPlan1Field();
  if (!plan1) return false;
  var compteId = l["compteId" + plan1.key];
  if (!compteId) return false;
  var compte = _findCompteByPlanAndId(1, compteId);
  return _getPlan1RestrictionReason(compte) !== null;
}

// ============================================================
// DIAGNOSTIC
// ============================================================
function _evaluateRestrictionDiag() {
  var jId = _getVal("ecrJournal");
  var cat = _resolveCategorieJournal(jId);
  var isTreso = cat === 2;
  var isOD = cat === 1;
  var compte = _getPlan1CompteFromForm();
  var code = compte ? String(compte.CODE || "") : "";
  var firstDigit = code.charAt(0);

  var is5xx = firstDigit === "5";
  var is4xx = firstDigit === "4";
  var rawFlag = compte ? compte.RESTREINDRE_IMPUT_TRESO : undefined;
  var flag = rawFlag === true || rawFlag === 1 || rawFlag === "1";

  var cbId = isTreso ? _getJournalCompteBanqueId() : null;
  var currentVal = _getPlan1Field() ? _getVal(_getPlan1Field().selectId) : null;
  // ⭐ Plus d'auto-sélection : treasuryLock sera toujours false, mais on garde
  //    la variable pour le diagnostic (si une ancienne ligne avait ce compte).
  var treasuryLock = isTreso && cbId && currentVal === cbId;

  var reason = _getPlan1RestrictionReason(compte);
  var shouldRestrict = reason !== null;

  var motif;
  if (reason === "5xx") {
    motif = _t(
      "saisie.diag.motif_5xx",
      "Compte 5xxxx — restriction inconditionnelle",
    );
  } else if (reason === "4xx_od") {
    motif = _t(
      "saisie.diag.motif_4xx_od",
      "Compte 4xxxx sur journal OD — restriction inconditionnelle",
    );
  } else if (reason === "4xx_treso") {
    motif = _t(
      "saisie.diag.motif_4xx_treso",
      "Compte 4xxxx restreint (flag=1 + journal trésorerie)",
    );
  } else {
    motif = _t("saisie.diag.motif_none", "Aucune restriction");
  }

  var diag = {
    journalId: jId,
    categorieJournal: cat,
    condition1_journalTreso: isTreso,
    condition1b_journalOD: isOD,
    compteId: compte ? compte.ID : null,
    compteCode: compte ? compte.CODE : null,
    regle1_5xx_financier: is5xx,
    regle2_4xx_od: is4xx && isOD,
    condition2_4xx: is4xx,
    flagBrut: rawFlag,
    flagBrutType: typeof rawFlag,
    condition3_flag: flag,
    treasuryPlan1Locked: treasuryLock,
    treasuryCompteBanqueId: cbId,
    treasuryCompteBanqueCode: _getJournalCompteBanqueCode(),
    shouldRestrict: shouldRestrict,
    reason: reason,
    motif: motif,
  };
  console.log(
    "%c[Diagnostic restriction]",
    "color:#007bff;font-weight:bold",
    diag,
  );
  return diag;
}

// ============================================================
// BANDEAU + APPLICATION DOM
// ============================================================
function _ensureRestrictionBanner() {
  var banner = document.getElementById("restrictTresoBanner");
  if (banner) return banner;
  var container = document.getElementById("dynPlanFieldsRow");
  if (!container || !container.parentNode) return null;
  banner = document.createElement("div");
  banner.id = "restrictTresoBanner";
  banner.style.cssText =
    "display:none;margin:8px 0;padding:8px 12px;" +
    "background:#fff3cd;border:1px solid #ffc107;border-radius:6px;" +
    "color:#856404;font-size:13px;";
  container.parentNode.insertBefore(banner, container);
  return banner;
}

function _applyPlanRestrictionToDom() {
  // ⭐ Pas d'auto-sélection ni de verrouillage PLAN1 sur compte banque.
  //    Le compte 5xxx est simplement exclu du <select> PLAN1.
  //    Les champs « Détail de la ligne » restent grisés via form.js.

  var compte = _getPlan1CompteFromForm();
  var code = compte ? String(compte.CODE || "") : "";
  var reason = _getPlan1RestrictionReason(compte);
  var restrict = reason !== null;

  // ⭐ Message pour tooltip + bandeau selon la raison
  var tooltip = "";
  if (reason === "5xx") {
    tooltip = _t(
      "saisie.hint.restrict_5xx_short",
      "Compte financier 5xxxx : imputations analytiques interdites.",
    );
  } else if (reason === "4xx_od") {
    tooltip = _t(
      "saisie.hint.restrict_4xx_od_short",
      "Compte tiers 4xxxx sur journal OD : imputations analytiques interdites.",
    );
  } else if (reason === "4xx_treso") {
    tooltip = _t(
      "saisie.hint.restrict_treso_short",
      "Compte tiers 4xxxx soumis à restriction trésorerie : seul PLAN1 reste accessible.",
    );
  }

  var active = getActivePlanFields();
  active.forEach(function (plan) {
    var sel = document.getElementById(plan.selectId);
    if (!sel) return;

    if (Number(plan.ordre) === 1) {
      // ⭐ PLAN1 n'est plus jamais verrouillé par le contexte trésorerie.
      //    C'est form.js (applyDetailLockByContext) qui gère son état.
      sel.disabled = false;
      sel.classList.remove(
        "is-disabled",
        "plan-select-restricted",
        "plan-select-locked-treso",
      );
      sel.style.backgroundColor = "";
      sel.style.cursor = "";
      sel.removeAttribute("title");
      return;
    }

    if (restrict) {
      sel.disabled = true;
      sel.classList.add("is-disabled", "plan-select-restricted");
      sel.style.backgroundColor = "#e9ecef";
      sel.style.cursor = "not-allowed";
      sel.setAttribute("title", tooltip);
    } else {
      sel.disabled = false;
      sel.classList.remove("is-disabled", "plan-select-restricted");
      sel.style.backgroundColor = "";
      sel.style.cursor = "";
      sel.removeAttribute("title");
    }
  });

  // Bandeau contextuel (sans cas « compte imposé »)
  var banner = _ensureRestrictionBanner();
  if (banner) {
    if (reason === "5xx") {
      banner.innerHTML =
        '<i class="fas fa-lock"></i> ' +
        _t(
          "saisie.hint.restrict_5xx_banner",
          "Compte financier <strong>{code}</strong> : les imputations analytiques (PLAN2 à PLAN10) sont interdites.",
        ).replace("{code}", escapeHtml(code));
      banner.style.display = "block";
    } else if (reason === "4xx_od") {
      banner.innerHTML =
        '<i class="fas fa-lock"></i> ' +
        _t(
          "saisie.hint.restrict_4xx_od_banner",
          "Compte tiers <strong>{code}</strong> sur journal OD : les imputations analytiques (PLAN2 à PLAN10) sont interdites.",
        ).replace("{code}", escapeHtml(code));
      banner.style.display = "block";
    } else if (reason === "4xx_treso") {
      banner.innerHTML =
        '<i class="fas fa-lock"></i> ' +
        _t(
          "saisie.hint.restrict_treso_banner",
          "Journal de trésorerie + compte 4xx soumis à restriction : seul PLAN1 reste accessible pour cette ligne.",
        );
      banner.style.display = "block";
    } else {
      banner.style.display = "none";
    }
  }
  return restrict;
}

function refreshPlanRestrictionUI() {
  _applyPlanRestrictionToDom();

  // ⭐ NOUVEAU : après chaque refresh, réapplique le déverrouillage conditionnel
  //    par préfixe de compte (2/3/6 → sauf aux ; 4 → seul aux).
  //    C'est le point de passage unique pour tous les change listeners.
  if (typeof window._applyLockByComptePrefix === "function") {
    try {
      window._applyLockByComptePrefix();
    } catch (e) {
      console.warn("[grid] _applyLockByComptePrefix erreur :", e);
    }
  }

  if (typeof renderGrid === "function") {
    try {
      renderGrid();
    } catch (e) {
      /* ignore */
    }
  }
}

// ============================================================
// AUXILIAIRE
// ============================================================
function refreshAuxiliaireField(options) {
  options = options || {};
  var preserveValue = options.preserveValue === true;
  var auxSel = document.getElementById("flAux");
  if (!auxSel) return;

  var primaire = getPrimaryPlanField();
  if (!primaire) {
    _disableAuxField(
      auxSel,
      _t("saisie.hint.aux_no_primary", "Aucun plan comptable actif."),
      preserveValue,
    );
    return;
  }
  var compteId = _getVal(primaire.selectId);
  if (!compteId) {
    _disableAuxField(
      auxSel,
      _t("saisie.hint.aux_initial", "Sélectionnez d'abord un compte PCG."),
      preserveValue,
    );
    return;
  }
  var comptes = AppState.comptesParPlan[primaire.ordre] || [];
  var compte = null;
  for (var i = 0; i < comptes.length; i++) {
    if (comptes[i].ID === compteId) {
      compte = comptes[i];
      break;
    }
  }
  if (!compte) {
    _disableAuxField(
      auxSel,
      _t("saisie.hint.aux_not_found", "Compte introuvable."),
      preserveValue,
    );
    return;
  }
  if (!compte.EST_AUXILIAIRE) {
    _disableAuxField(
      auxSel,
      _t("saisie.hint.aux_no_auth", "Ce compte n'autorise pas d'auxiliaire."),
      preserveValue,
    );
    return;
  }
  populateAuxiliaireOptions(compte.ID, preserveValue);
  _enableAuxField(auxSel);

  var count = parseInt(auxSel.getAttribute("data-count") || "0", 10);
  var isFiltered = auxSel.getAttribute("data-filtered") === "1";
  var hint = document.getElementById("flAuxHint");
  if (hint) {
    if (isFiltered) {
      hint.textContent = _t(
        "saisie.hint.aux_filtered",
        "{n} tiers liés au compte {code}",
      )
        .replace("{n}", count)
        .replace("{code}", compte.CODE);
      hint.style.color = "#047857";
    } else {
      hint.textContent = _t(
        "saisie.hint.aux_all",
        "Aucun tiers spécifique lié — {n} tiers disponibles.",
      ).replace("{n}", count);
      hint.style.color = "#6c757d";
    }
    hint.style.display = "block";
  }
}

function _disableAuxField(sel, reason, preserveValue) {
  sel.disabled = true;
  sel.style.backgroundColor = "#e9ecef";
  sel.style.cursor = "not-allowed";
  if (typeof populateAuxiliaireOptions === "function") {
    populateAuxiliaireOptions(null, preserveValue);
  }
  if (!preserveValue) sel.value = "";
  var hint = document.getElementById("flAuxHint");
  if (hint) {
    hint.textContent = reason || "";
    hint.style.color = "#6c757d";
    hint.style.display = reason ? "block" : "none";
  }
}

function _enableAuxField(sel) {
  sel.disabled = false;
  sel.style.backgroundColor = "";
  sel.style.cursor = "";
}

// ============================================================
// GÉNÉRATION DU FORMULAIRE
// ============================================================
function renderFormPlanFields() {
  var container = document.getElementById("dynPlanFieldsRow");
  if (!container) return;
  var active = getActivePlanFields();
  if (!active.length) {
    container.innerHTML =
      '<div class="eb-field eb-w-full" ' +
      'style="color:#B91C1C;font-style:italic;text-align:center;padding:12px;">' +
      escapeHtml(_t("saisie.msg.no_plans", "Aucun plan comptable actif")) +
      "</div>";
    return;
  }
  var html = "";
  active.forEach(function (plan) {
    var widthClass = plan.isPrimary ? "eb-w-2" : "eb-w-1";
    html +=
      '<div class="eb-field ' +
      widthClass +
      '" ' +
      'id="' +
      plan.wrapperId +
      '" ' +
      'data-plan-key="' +
      plan.key +
      '" ' +
      'data-plan-order="' +
      plan.ordre +
      '" ' +
      'data-plan-type="' +
      plan.typeCode +
      '">' +
      "<label>" +
      escapeHtml(plan.label) +
      "</label>" +
      '<select id="' +
      plan.selectId +
      '" class="form-control"></select>' +
      "</div>";
  });
  container.innerHTML = html;

  if (!container._restrictionBound) {
    container._restrictionBound = true;
    container.addEventListener("change", function (ev) {
      var tgt = ev.target;
      if (!tgt || tgt.tagName !== "SELECT") return;
      if (!/^flP\d+$/.test(tgt.id)) return;
      if (typeof refreshAuxiliaireField === "function") {
        refreshAuxiliaireField({ preserveValue: true });
      }
      refreshPlanRestrictionUI();
    });
  }

  var plan1 = _getPlan1Field();
  if (plan1) {
    var p1Sel = document.getElementById(plan1.selectId);
    if (p1Sel && !p1Sel._restrictionBound) {
      p1Sel._restrictionBound = true;
      p1Sel.addEventListener("change", function () {
        refreshPlanRestrictionUI();
      });
    }
  }

  refreshPlanRestrictionUI();
  _refreshCategorieJournalDisplay();
  console.log(
    "[grid] Formulaire plans généré :",
    active
      .map(function (p) {
        return p.label;
      })
      .join(", "),
  );
}

// ============================================================
// EN-TÊTE DE GRILLE
// ============================================================
function renderGridHead() {
  var row = document.getElementById("ecrGridHeadRow");
  if (!row) return;
  var active = getActivePlanFields();
  var hasPrimary = active.some(function (p) {
    return p.isPrimary;
  });

  var html =
    '<th style="width:40px;" data-i18n="saisie.col.line_number">' +
    escapeHtml(_t("saisie.col.line_number", "#")) +
    "</th>";
  html +=
    '<th style="width:110px; text-align:center;" ' +
    'data-i18n="saisie.col.categorie_journal">' +
    escapeHtml(_t("saisie.col.categorie_journal", "Catégorie")) +
    "</th>";

  active.forEach(function (plan) {
    var w = plan.isPrimary ? 110 : 100;
    html +=
      '<th style="width:' + w + 'px;">' + escapeHtml(plan.label) + "</th>";
    if (plan.isPrimary) {
      html +=
        '<th style="width:90px;" data-i18n="saisie.col.auxiliaire">' +
        escapeHtml(_t("saisie.col.auxiliaire", "Auxiliaire")) +
        "</th>";
    }
  });
  if (!hasPrimary) {
    html +=
      '<th style="width:90px;" data-i18n="saisie.col.auxiliaire">' +
      escapeHtml(_t("saisie.col.auxiliaire", "Auxiliaire")) +
      "</th>";
  }
  html +=
    '<th style="width:100px;" data-i18n="saisie.col.subvention">' +
    escapeHtml(_t("saisie.col.subvention", "Subvention")) +
    "</th>";
  html +=
    '<th data-i18n="saisie.col.libelle">' +
    escapeHtml(_t("saisie.col.libelle", "Libellé")) +
    "</th>";
  html +=
    '<th style="width:110px; text-align:right;" data-i18n="saisie.col.debit">' +
    escapeHtml(_t("saisie.col.debit", "Débit")) +
    "</th>";
  html +=
    '<th style="width:110px; text-align:right;" data-i18n="saisie.col.credit">' +
    escapeHtml(_t("saisie.col.credit", "Crédit")) +
    "</th>";
  html +=
    '<th style="width:110px; text-align:right;" data-i18n="saisie.col.debit_rep">' +
    escapeHtml(_t("saisie.col.debit_rep", "Débit (Réf.)")) +
    "</th>";
  html +=
    '<th style="width:110px; text-align:right;" data-i18n="saisie.col.credit_rep">' +
    escapeHtml(_t("saisie.col.credit_rep", "Crédit (Réf.)")) +
    "</th>";
  html +=
    '<th style="width:110px;" data-i18n="saisie.col.echeance">' +
    escapeHtml(_t("saisie.col.echeance", "Échéance")) +
    "</th>";
  row.innerHTML = html;
}

// ============================================================
// RENDU CORPS DE GRILLE
// ============================================================
function renderGrid() {
  var tb = document.getElementById("ecrLignesBody");
  if (!tb) return;
  var active = getActivePlanFields();
  var hasPrimary = active.some(function (p) {
    return p.isPrimary;
  });
  var totalCols = 1 + 1 + active.length + 1 + 7;
  var cat = _resolveCategorieJournal(_getVal("ecrJournal"));

  if (!AppState.lignes.length) {
    tb.innerHTML =
      '<tr><td colspan="' +
      totalCols +
      '" class="table-empty">' +
      '<i class="fas fa-inbox"></i>' +
      "<span>" +
      escapeHtml(_t("saisie.msg.no_lignes", "Aucune ligne.")) +
      "</span></td></tr>";
    return;
  }

  var html = "";
  AppState.lignes.forEach(function (l, idx) {
    var lineRestricted = _shouldRestrictLine(l);
    var selCls = idx === AppState.selectedLigneIndex ? " selected" : "";
    var restrictCls = lineRestricted ? " row-restricted" : "";

    html +=
      '<tr class="ecr-ligne' +
      selCls +
      restrictCls +
      '" ' +
      'data-index="' +
      idx +
      '" ' +
      'onclick="selectLigne(' +
      idx +
      ')" ' +
      (lineRestricted
        ? 'title="' +
          escapeHtml(
            _t(
              "saisie.hint.restrict_treso_row",
              "Ligne soumise à restriction (seul PLAN1 est autorisé)",
            ),
          ) +
          '"'
        : "") +
      ">";

    html += '<td><span class="cell-num">' + (idx + 1) + "</span></td>";
    html +=
      '<td style="text-align:center;">' +
      '<span style="' +
      _categorieJournalBadgeStyle(cat) +
      '">' +
      escapeHtml(_categorieJournalLabel(cat)) +
      "</span></td>";

    active.forEach(function (plan) {
      var cellRestricted = lineRestricted && Number(plan.ordre) !== 1;
      html += _cellPlan(l["code" + plan.key] || "", cellRestricted);
      if (plan.isPrimary) {
        html += "<td>" + escapeHtml(l.auxiliaire || "") + "</td>";
      }
    });
    if (!hasPrimary) {
      html += "<td>" + escapeHtml(l.auxiliaire || "") + "</td>";
    }
    html += _cellPlan(l.codeSUB || l.sourceFinancement || l.compteIdSUB || "", false);
    html +=
      '<td title="' +
      escapeHtml(l.libelle || "") +
      '">' +
      escapeHtml(l.libelle || "") +
      "</td>";
    html +=
      '<td class="cell-montant debit">' +
      (l.debit > 0 ? formatMontant(l.debit) : "") +
      "</td>";
    html +=
      '<td class="cell-montant credit">' +
      (l.credit > 0 ? formatMontant(l.credit) : "") +
      "</td>";
    html +=
      '<td class="cell-montant debit">' +
      (l.montantRep > 0 && l.sens === "D" ? formatMontant(l.montantRep) : "") +
      "</td>";
    html +=
      '<td class="cell-montant credit">' +
      (l.montantRep > 0 && l.sens === "C" ? formatMontant(l.montantRep) : "") +
      "</td>";
    html += "<td>" + escapeHtml(l.echeance || "") + "</td>";
    html += "</tr>";
  });
  tb.innerHTML = html;
  if (typeof _refreshLinesCounter === "function") _refreshLinesCounter();
}

function _cellPlan(code, restricted) {
  var safe = escapeHtml(code || "");
  var inner =
    (safe || "—") +
    (restricted
      ? ' <i class="fas fa-lock" style="color:#b45309;font-size:10px;"></i>'
      : "");
  return (
    "<td" +
    (restricted ? ' class="plan-cell-restricted"' : "") +
    ">" +
    '<span class="cell-badge" title="' +
    safe +
    '">' +
    inner +
    "</span></td>"
  );
}

// ============================================================
// SÉLECTION LIGNE
// ============================================================
function selectLigne(idx) {
  AppState.selectedLigneIndex = idx;
  renderGrid();
  loadLigneIntoForm(idx);
}

function loadLigneIntoForm(idx) {
  var l = AppState.lignes[idx];
  if (!l) return;
  getActivePlanFields().forEach(function (plan) {
    _setVal(plan.selectId, l["compteId" + plan.key] || "");
  });
  _setVal("flSub", l.sourceFinancement || l.compteIdSUB || "");
  _setVal("flMode", l.mode || "");
  _setVal("flLibelle", l.libelle || "");
  _setVal("flMontantLocal", l.debit > 0 ? l.debit : l.credit);
  _setVal("flMontantRep", l.montantRep || 0);
  _setVal("flEcheance", l.echeance || "");

  var sensRadios = document.querySelectorAll('input[name="flSens"]');
  sensRadios.forEach(function (r) {
    r.checked = r.value === (l.sens || "D");
  });

  refreshAuxiliaireField({ preserveValue: true });
  refreshPlanRestrictionUI();

  var auxSel = document.getElementById("flAux");
  if (auxSel && l.auxiliaire) {
    auxSel.value = l.auxiliaire;
    var selectedOption = auxSel.options[auxSel.selectedIndex];
    if (selectedOption && l.tiersId) {
      selectedOption.setAttribute("data-tiers-id", l.tiersId);
    }
    if (auxSel.value !== l.auxiliaire) {
      var opt = document.createElement("option");
      opt.value = l.auxiliaire;
      opt.textContent =
        l.auxiliaire +
        " (" +
        _t("saisie.hint.out_of_filter", "hors filtre") +
        ")";
      if (l.tiersId) opt.setAttribute("data-tiers-id", l.tiersId);
      auxSel.appendChild(opt);
      auxSel.value = l.auxiliaire;
    }
  }
}

// ============================================================
// PEUPLEMENT DES SELECTS DE COMPTES
// ============================================================
function populatePlanSelectsForm() {
  var active = getActivePlanFields();
  active.forEach(function (plan) {
    var sel = document.getElementById(plan.selectId);
    if (!sel) return;
    sel.innerHTML = '<option value="">—</option>';
    var comptes = AppState.comptesParPlan[plan.ordre] || [];

    // ⭐ Filtrage PLAN1 : seuls les préfixes 2, 3, 4, 6 sont autorisés.
    //    Aucune injection du compte banque (5xxx) : il est exclu définitivement.
    var isPrimary = Number(plan.ordre) === 1;
    var allowedPrefixes = window.ALLOWED_PLAN1_PREFIXES || ["2", "3", "4", "6"];

    comptes.forEach(function (c) {
      var code = String(c.CODE || "");

      if (isPrimary) {
        var prefix = code.charAt(0);
        if (allowedPrefixes.indexOf(prefix) === -1) return;
      }

      var o = document.createElement("option");
      o.value = c.ID;
      o.textContent = c.CODE + " — " + c.LIBELLE;
      o.setAttribute("data-code", c.CODE);
      o.setAttribute("data-aux", c.EST_AUXILIAIRE ? "1" : "0");
      o.setAttribute("data-restrict", c.RESTREINDRE_IMPUT_TRESO ? "1" : "0");
      sel.appendChild(o);
    });
  });
  refreshPlanRestrictionUI();
  console.log("[grid] Selects de comptes peuplés :", active.length);
}

// ============================================================
// HELPERS
// ============================================================
function findCodeCompteByKey(key, compteId) {
  if (!compteId) return "";
  var plan = getPlanFieldByKey(key);
  if (!plan) return "";
  var arr = AppState.comptesParPlan[plan.ordre] || [];
  var c = arr.find(function (x) {
    return x.ID === compteId;
  });
  return c ? c.CODE : "";
}

function findCodeCompte(planOrder, compteId) {
  if (!planOrder || !compteId) return "";
  var arr = AppState.comptesParPlan[planOrder] || [];
  var c = arr.find(function (x) {
    return x.ID === compteId;
  });
  return c ? c.CODE : "";
}

// ============================================================
// BINDING JOURNAL → Catégorie + Restriction
// ============================================================
function _bindJournalCategoryListener() {
  var jSel = document.getElementById("ecrJournal");
  if (!jSel || jSel._catBound) return;
  jSel._catBound = true;
  jSel.addEventListener("change", function () {
    _refreshCategorieJournalDisplay();
    refreshPlanRestrictionUI();
    if (typeof applyDetailLockByContext === "function") {
      applyDetailLockByContext();
    }
  });
  _refreshCategorieJournalDisplay();
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", _bindJournalCategoryListener);
} else {
  _bindJournalCategoryListener();
}
setTimeout(_bindJournalCategoryListener, 300);

window.addEventListener("languagechange", function () {
  _refreshCategorieJournalDisplay();
  if (typeof renderGridHead === "function") renderGridHead();
  if (typeof renderGrid === "function") renderGrid();
});

// ============================================================
// HOOK — après chargement des lookups
// ============================================================
function afterLookupsLoaded() {
  _refreshCategorieJournalDisplay();
  refreshPlanRestrictionUI();
  if (typeof populatePlanSelectsForm === "function") populatePlanSelectsForm();
  if (typeof renderGrid === "function") renderGrid();
}

// ============================================================
// EXPOSITIONS
// ============================================================
window.renderFormPlanFields = renderFormPlanFields;
window.renderGridHead = renderGridHead;
window.renderGrid = renderGrid;
window.selectLigne = selectLigne;
window.loadLigneIntoForm = loadLigneIntoForm;
window.populatePlanSelectsForm = populatePlanSelectsForm;
window.refreshAuxiliaireField = refreshAuxiliaireField;
window.findCodeCompte = findCodeCompte;
window.findCodeCompteByKey = findCodeCompteByKey;

window.refreshPlanRestrictionUI = refreshPlanRestrictionUI;
window.afterLookupsLoaded = afterLookupsLoaded;
window._isTreasuryJournal = _isTreasuryJournal;
window._shouldRestrictToPlan1 = _shouldRestrictToPlan1;
window._shouldRestrictLine = _shouldRestrictLine;
window._resolveCategorieJournal = _resolveCategorieJournal;
window._categorieJournalLabel = _categorieJournalLabel;
window._refreshCategorieJournalDisplay = _refreshCategorieJournalDisplay;
window._evaluateRestrictionDiag = _evaluateRestrictionDiag;
window._getJournalCompteBanqueId = _getJournalCompteBanqueId;
window._getJournalCompteBanqueCode = _getJournalCompteBanqueCode;
window._getPlan1RestrictionReason = _getPlan1RestrictionReason;
window._isComptePlan1ODRestrictif = _isComptePlan1ODRestrictif;
// ⭐ plus d'export de _ensureCompteBanqueInSelect (fonction supprimée)
