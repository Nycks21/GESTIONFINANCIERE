// od-lettrage.js — Modale de sélection des écritures OD à régler
"use strict";

(function () {
  "use strict";

  var _state = {
    isOpen: false,
    loading: false,
    lines: [],
    page: 1,
    pageSize: 50,
    total: 0,
    totalPages: 0,
    search: "",
    selected: {}, // { ecritureLigneId: { montant, ... } }
  };

  // ─── Vérifie si on est dans une opération de trésorerie ───
  function isTreasuryContext() {
    return typeof _isTreasuryJournal === "function" && _isTreasuryJournal();
  }

  // ─── Ouvre la modale après saisie compte + auxiliaire ───
  async function openOdModal() {
    if (!isTreasuryContext()) return;

    var primaire = getPrimaryPlanField();
    if (!primaire) return;
    var compteId = _getVal(primaire.selectId);
    if (!compteId) return;

    // Vérifier que le compte commence par 4 (compte de tiers)
    var compte = _findCompteByPlanAndId(primaire.ordre, compteId);
    if (!compte || String(compte.CODE || "").charAt(0) !== "4") return;

    // Auxiliaire (si présent)
    var auxSel = document.getElementById("flAux");
    var aux = auxSel && !auxSel.disabled ? auxSel.value : "";

    _state.isOpen = true;
    _state.loading = true;
    _state.search = "";
    _state.selected = {};
    _state.page = 1;
    _render();

    await _load();

    _state.loading = false;
    _render();
  }

  // ─── Ferme la modale ───
  function closeOdModal() {
    _state.isOpen = false;
    _state.selected = {};
    _render();
  }

  // ─── Charge les OD à régler ───
  async function _load() {
    var primaire = getPrimaryPlanField();
    if (!primaire) return;
    var compteId = _getVal(primaire.selectId);
    var auxSel = document.getElementById("flAux");
    var aux = auxSel && !auxSel.disabled ? auxSel.value : "";

    try {
      var params = new URLSearchParams({
        compteId: compteId,
        auxiliaire: aux || "",
        search: _state.search,
        page: _state.page,
        pageSize: _state.pageSize,
      });
      var url =
        API.BASE + API.HANDLERS_PATH + "GetEcrituresODARegler.ashx?" + params;
      var resp = await fetch(url);
      var data = await resp.json();
      if (data.success) {
        _state.lines = data.lignes || [];
        _state.total = Number(data.total || 0);
        _state.totalPages = Number(data.totalPages || 0);
      } else {
        if (typeof showErrorToast === "function") showErrorToast(data.message);
      }
    } catch (e) {
      if (typeof showErrorToast === "function") showErrorToast(e.message);
    }
  }

  // ─── Rendu ───
  function _render() {
    var modal = document.getElementById("odLettrageModal");
    if (!modal) return;
    modal.style.display = _state.isOpen ? "flex" : "none";

    if (!_state.isOpen) return;

    var tbody = document.getElementById("odLettrageBody");
    if (!tbody) return;

    if (_state.loading) {
      tbody.innerHTML =
        '<tr><td colspan="9" class="table-loading">' +
        '<i class="fas fa-spinner fa-spin"></i> Chargement...</td></tr>';
      return;
    }

    if (!_state.lines.length) {
      tbody.innerHTML =
        '<tr><td colspan="9" class="table-empty">' +
        '<i class="fas fa-inbox"></i> Aucune écriture OD à régler pour ce compte.' +
        "</td></tr>";
      return;
    }

    var html = "";
    _state.lines.forEach(function (l) {
      var checked = _state.selected[l.ECRITURE_LIGNE_ID] ? "checked" : "";
      html +=
        "<tr>" +
        '<td style="text-align:center;">' +
        '<input type="checkbox" data-id="' +
        l.ECRITURE_LIGNE_ID +
        '" ' +
        checked +
        " />" +
        "</td>" +
        "<td>" +
        _esc(l.DATE_PIECE || l.DATE_COMPTABLE) +
        "</td>" +
        '<td><span class="badge-code">' +
        _esc(l.REFERENCE || l.NUMERO) +
        "</span></td>" +
        '<td><span class="badge-journal">' +
        _esc(l.JOURNAL_CODE) +
        "</span></td>" +
        "<td>" +
        _esc(l.COMPTE_CODE) +
        "</td>" +
        "<td>" +
        _esc(l.AUXILIAIRE) +
        "</td>" +
        '<td class="text-truncate">' +
        _esc(l.LIBELLE) +
        "</td>" +
        '<td style="text-align:right;font-family:monospace;">' +
        formatMontant(l.MONTANT_INITIAL) +
        "</td>" +
        '<td style="text-align:right;font-family:monospace;color:#b45309;">' +
        formatMontant(l.MONTANT_REGLE) +
        "</td>" +
        '<td style="text-align:right;font-family:monospace;color:#B91C1C;font-weight:700;">' +
        formatMontant(l.SOLDE_RESTANT) +
        "</td>" +
        "</tr>";
    });
    tbody.innerHTML = html;

    // Bind checkbox
    tbody.querySelectorAll('input[type="checkbox"]').forEach(function (chk) {
      chk.addEventListener("change", function () {
        var id = chk.getAttribute("data-id");
        if (chk.checked) {
          var line = _state.lines.find(function (x) {
            return x.ECRITURE_LIGNE_ID === id;
          });
          if (line) _state.selected[id] = line;
        } else {
          delete _state.selected[id];
        }
        _updateSelectionState();
      });
    });

    _updateSelectionState();
  }

  function _updateSelectionState() {
    var count = Object.keys(_state.selected).length;
    var total = 0;
    Object.keys(_state.selected).forEach(function (id) {
      total += Number(_state.selected[id].SOLDE_RESTANT || 0);
    });

    var btn = document.getElementById("odBtnValidate");
    if (btn) {
      btn.disabled = count === 0;
      btn.innerHTML =
        '<i class="fas fa-check"></i> Lettrer la sélection (' +
        count +
        " — " +
        formatMontant(total) +
        ")";
    }
  }

  // ─── Valide la sélection et transfère les imputations ───
  function validateOdSelection() {
    var ids = Object.keys(_state.selected);
    if (ids.length === 0) return;

    // Vérifier qu'on a bien un compte de tiers sélectionné
    var primaire = getPrimaryPlanField();
    if (!primaire) return;
    var compteId = _getVal(primaire.selectId);
    var compte = _findCompteByPlanAndId(primaire.ordre, compteId);
    if (!compte) return;

    // ⭐ Transférer les imputations de la première OD sélectionnée
    //    vers le formulaire de ligne en cours
    var firstLine = _state.selected[ids[0]];

    // Copier les plans (PLAN1..PLAN10) sur le premier plan
    for (var k = 1; k <= 10; k++) {
      var planField = getPlanFieldByKey("P" + k);
      if (!planField) continue;
      var val = firstLine["PLAN" + k];
      if (val) {
        _setVal(planField.selectId, val);
      }
    }

    // Copier le montant (solde restant de la première ligne)
    var totalMontant = 0;
    ids.forEach(function (id) {
      totalMontant += Number(_state.selected[id].SOLDE_RESTANT || 0);
    });
    _setVal("flMontantLocal", formatMontant(totalMontant));
    _setVal("flMontantRep", formatMontant(totalMontant));

    // Copier libellé
    if (firstLine.LIBELLE) {
      _setVal("flLibelle", firstLine.LIBELLE);
    }

    // Stocker dans AppState pour l'envoi au serveur
    AppState.lettrageSources = ids.map(function (id) {
      var line = _state.selected[id];
      return {
        ecritureLigneId: line.ECRITURE_LIGNE_ID,
        ecritureId: line.ECRITURE_ID,
        compteId: compteId,
        compteCode: line.COMPTE_CODE,
        montant: line.SOLDE_RESTANT,
        sensOd: line.SENS,
      };
    });

    // Déverrouiller tous les champs de la ligne
    _unlockLineFields();

    closeOdModal();

    if (typeof showSuccessToast === "function") {
      showSuccessToast("Imputations transférées depuis " + ids.length + " OD");
    }
  }

  // ─── Déverrouille les champs de la ligne ───
  function _unlockLineFields() {
    // ⭐ Délègue au form.js — qui gère l'état de verrouillage complet
    if (typeof window.setDetailLock === "function") {
      window.setDetailLock(false);
      return;
    }

    // Fallback (si form.js n'est pas chargé)
    [
      "flAux",
      "flSub",
      "flMode",
      "flLibelle",
      "flMontantLocal",
      "flMontantRep",
      "flEcheance",
    ].forEach(function (id) {
      var el = document.getElementById(id);
      if (el) el.disabled = false;
    });

    getActivePlanFields().forEach(function (plan) {
      var el = document.getElementById(plan.selectId);
      if (el) el.disabled = false;
    });

    if (typeof refreshPlanRestrictionUI === "function") {
      refreshPlanRestrictionUI();
    }
  }

  // Après closeOdModal()
  if (typeof window.setDetailLock === "function") {
    window.setDetailLock(false);
  }

  // ─── Search debounce ───
  var _searchTimer = null;
  function _onSearchChange() {
    clearTimeout(_searchTimer);
    _searchTimer = setTimeout(async function () {
      _state.page = 1;
      _state.loading = true;
      _render();
      await _load();
      _state.loading = false;
      _render();
    }, 300);
  }

  // ─── Bindings ───
  function _bind() {
    var modal = document.getElementById("odLettrageModal");
    if (!modal) return;

    // Search
    var searchInput = document.getElementById("odSearchInput");
    if (searchInput) {
      searchInput.addEventListener("input", function () {
        _state.search = this.value;
        _onSearchChange();
      });
    }

    // Boutons
    var btnClose = document.getElementById("odBtnClose");
    if (btnClose) btnClose.addEventListener("click", closeOdModal);

    var btnValidate = document.getElementById("odBtnValidate");
    if (btnValidate) btnValidate.addEventListener("click", validateOdSelection);

    var btnRefresh = document.getElementById("odBtnRefresh");
    if (btnRefresh) {
      btnRefresh.addEventListener("click", async function () {
        _state.loading = true;
        _render();
        await _load();
        _state.loading = false;
        _render();
      });
    }

    // Pagination
    var btnPrev = document.getElementById("odBtnPrev");
    var btnNext = document.getElementById("odBtnNext");
    if (btnPrev) {
      btnPrev.addEventListener("click", async function () {
        if (_state.page <= 1) return;
        _state.page--;
        _state.loading = true;
        _render();
        await _load();
        _state.loading = false;
        _render();
      });
    }
    if (btnNext) {
      btnNext.addEventListener("click", async function () {
        if (_state.page >= _state.totalPages) return;
        _state.page++;
        _state.loading = true;
        _render();
        await _load();
        _state.loading = false;
        _render();
      });
    }
  }

  // ─── Helper ───
  function _esc(s) {
    if (s === null || s === undefined) return "";
    return String(s)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  // ─── Expositions ───
  window.openOdModal = openOdModal;
  window.closeOdModal = closeOdModal;

  document.addEventListener("DOMContentLoaded", _bind);
})();
