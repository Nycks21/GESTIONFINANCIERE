// delletrage-vue.js — Gestion de la page Délettrage
'use strict';

(function () {
    if (typeof Vue === 'undefined') return;
    if (!window.API) {
        console.error('[Délettrage] window.API non défini.');
        return;
    }

    const { createApp, reactive, computed, onMounted } = Vue;
    const API_LETTRAGE = window.API.BASE + window.API.HANDLERS_PATH;
    const API_SHARED   = window.API.BASE + window.API.SHARED_HANDLERS_PATH;

    const DelletrageApp = {
        setup() {
            const vm = reactive({
                loading: false,
                lines: [],
                total: 0,
                totalPages: 0,
                page: 1,
                pageSize: window.DEFAULTS ? window.DEFAULTS.PAGE_SIZE : 50,
                showFilterModal: true,
                hasAppliedFilters: false,
                selectedLines: [],
                totalDebitSelected: 0,
                totalCreditSelected: 0,
                difference: 0,
                currentAccountCode: '',
                currentAccountName: ''
            });

            // ⭐ Nouveaux filtres
            const filters = reactive({
                compteId: '',
                auxiliaire: '',
                dateDebut: '',
                dateFin: ''
            });
            const appliedFilters = reactive({
                compteId: '',
                auxiliaire: '',
                dateDebut: '',
                dateFin: ''
            });
            const lookup = reactive({ comptes: [], tiers: [] });

            const fmt = (value) => (typeof formatMontant === 'function' ? formatMontant(value) : value);
            const formatDate = (value) => {
                if (!value) return '—';
                const date = new Date(value + 'T00:00:00');
                return Number.isNaN(date.getTime()) ? value : date.toLocaleDateString('fr-FR');
            };

            // ⭐ Auxiliaires filtrés selon le compte sélectionné
            const filteredAuxiliaires = computed(() => {
                if (!filters.compteId) return [];
                return (lookup.tiers || []).filter(t => t.PLAN_ELEMENT_ID === filters.compteId);
            });

            const canDelletrage = computed(() => {
                return vm.selectedLines.length >= 2
                    && vm.difference <= 0.01
                    && selectedLinesHaveSameCode.value
                    && !vm.loading;
            });

            const selectedLinesHaveSameCode = computed(() => {
                if (vm.selectedLines.length === 0) return false;

                const selectedLines = vm.lines.filter(l => vm.selectedLines.includes(l.ID));
                if (selectedLines.length !== vm.selectedLines.length) return false;

                const codes = selectedLines.map(l => String(l.LETTRAGE_CODE || '').trim());
                return codes[0] !== '' && codes.every(code => code === codes[0]);
            });

            const delletrageDisabledReason = computed(() => {
                if (vm.loading) return 'Enregistrement en cours...';
                if (vm.selectedLines.length < 2)
                    return 'Sélectionnez au moins 2 lignes (débit et crédit).';
                if (vm.difference > 0.01)
                    return 'Écart de ' + fmt(vm.difference) + ' — le débit et le crédit doivent être équilibrés.';
                if (!selectedLinesHaveSameCode.value)
                    return 'Sélectionnez uniquement des lignes ayant le même code de lettrage.';
                return '';
            });

            function onCompteChange() {
                filters.auxiliaire = '';
            }

            function resetFilterModal() {
                filters.compteId = '';
                filters.auxiliaire = '';
                filters.dateDebut = '';
                filters.dateFin = '';
            }

            // ⭐ Chargement des lookups (comptes + tiers)
            async function loadLookups() {
                try {
                    // Comptes de tiers 4xxxx
                    const urlComptes = API_SHARED + window.API.COMPTES_BY_PLAN
                                     + '?planOrder=1&onlyAuxiliaire=0';
                    const resComptes = await fetch(urlComptes);
                    const dataComptes = await resComptes.json();
                    if (dataComptes.success) {
                        lookup.comptes = (dataComptes.comptes || []).filter(c =>
                            String(c.CODE || '').charAt(0) === '4'
                        );
                    }

                    // Tiers (auxiliaires)
                    const resTiers = await fetch(API_SHARED + window.API.LOOKUPS);
                    const dataTiers = await resTiers.json();
                    if (dataTiers.success) {
                        lookup.tiers = dataTiers.tiers || [];
                    }

                    console.log('[Délettrage] Comptes chargés :', lookup.comptes.length,
                                '— Tiers :', lookup.tiers.length);
                } catch (e) {
                    console.error('[Délettrage] Erreur lookups :', e);
                }
            }

            // ⭐ Chargement des lignes lettrées
            async function loadData() {
                if (!vm.hasAppliedFilters) return;
                vm.loading = true;
                vm.selectedLines = [];
                computeSelection();

                try {
                    const params = new URLSearchParams({
                        compteId:   appliedFilters.compteId,
                        auxiliaire: appliedFilters.auxiliaire || '',
                        dateDebut:  appliedFilters.dateDebut || '',
                        dateFin:    appliedFilters.dateFin || '',
                        page:       vm.page,
                        pageSize:   vm.pageSize
                    });
                    const res = await fetch(API_LETTRAGE + window.API.LIGNES_DELETTRAGE + '?' + params);
                    const data = await res.json();

                    if (data.success) {
                        vm.lines = data.lignes || [];
                        vm.total = Number(data.total || 0);
                        vm.totalPages = Number(data.totalPages || 0);

                        const cpt = lookup.comptes.find(c => c.ID === appliedFilters.compteId);
                        if (cpt) {
                            vm.currentAccountCode = cpt.CODE;
                            vm.currentAccountName = cpt.LIBELLE;
                        }
                    } else {
                        Swal.fire('Erreur', data.message || 'Erreur serveur', 'error');
                    }
                } catch (e) {
                    Swal.fire('Erreur', e.message, 'error');
                } finally {
                    vm.loading = false;
                }
            }

            // ⭐ Sélection
            const isAllSelected = computed(() => {
                return vm.lines.length > 0 && vm.selectedLines.length === vm.lines.length;
            });

            function toggleAll(e) {
                vm.selectedLines = e.target.checked ? vm.lines.map(l => l.ID) : [];
                computeSelection();
            }

            function computeSelection() {
                vm.totalDebitSelected = 0;
                vm.totalCreditSelected = 0;

                vm.lines.forEach(l => {
                    if (vm.selectedLines.includes(l.ID)) {
                        vm.totalDebitSelected += parseFloat(l.DEBIT || 0);
                        vm.totalCreditSelected += parseFloat(l.CREDIT || 0);
                    }
                });

                vm.difference = Math.abs(vm.totalDebitSelected - vm.totalCreditSelected);
            }

            function clearSelection() {
                vm.selectedLines = [];
                computeSelection();
            }

            // ⭐ Exécution du délettrage
            async function performDelletrage() {
                if (!canDelletrage.value) {
                    Swal.fire({
                        icon: 'warning',
                        title: 'Délettrage impossible',
                        text: delletrageDisabledReason.value
                    });
                    return;
                }

                const conf = await Swal.fire({
                    title: 'Confirmer le délettrage',
                    html: `Vous allez délettrer <b>${vm.selectedLines.length}</b> ligne(s).<br><br>Si ces lignes faisaient partie d'un groupe de lettrage complet, le groupe sera rompu.`,
                    icon: 'warning',
                    showCancelButton: true,
                    confirmButtonColor: '#DC2626',
                    confirmButtonText: '<i class="fas fa-unlink"></i> Oui, délettrer',
                    cancelButtonText: 'Annuler'
                });

                if (!conf.isConfirmed) return;

                vm.loading = true;
                try {
                    const res = await fetch(API_LETTRAGE + window.API.SAVE_DELETTRAGE, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ lineIds: vm.selectedLines })
                    });
                    const data = await res.json();

                    if (data.success) {
                        Swal.fire('Succès', data.message || 'Délettrage effectué.', 'success');
                        clearSelection();
                        await loadData();
                    } else {
                        Swal.fire('Erreur', data.message, 'error');
                    }
                } catch (e) {
                    Swal.fire('Erreur', e.message, 'error');
                } finally {
                    vm.loading = false;
                }
            }

            // ⭐ Appliquer filtres
            function applyFilters() {
                if (!filters.compteId) {
                    Swal.fire('Attention', 'Sélectionnez un compte.', 'warning');
                    return;
                }
                Object.assign(appliedFilters, filters);
                vm.hasAppliedFilters = true;
                vm.showFilterModal = false;
                vm.page = 1;
                vm.selectedLines = [];
                loadData();
            }

            function openFilterModal() {
                Object.assign(filters, appliedFilters);
                vm.showFilterModal = true;
            }

            function closeFilterModal() {
                vm.showFilterModal = false;
            }

            async function goToPage(page) {
                if (page < 1 || page > vm.totalPages || page === vm.page || vm.loading) return;
                if (vm.selectedLines.length > 0) {
                    const res = await Swal.fire({
                        title: 'Changer de page ?',
                        text: 'La sélection actuelle sera perdue.',
                        icon: 'question',
                        showCancelButton: true,
                        confirmButtonText: 'Oui, changer',
                        cancelButtonText: 'Annuler'
                    });
                    if (!res.isConfirmed) return;
                    clearSelection();
                }
                vm.page = page;
                await loadData();
            }

            onMounted(loadLookups);

            return {
                vm, filters, lookup, isAllSelected, filteredAuxiliaires,
                canDelletrage, delletrageDisabledReason,
                fmt, formatDate,
                onCompteChange, resetFilterModal,
                applyFilters, openFilterModal, closeFilterModal,
                toggleAll, computeSelection, clearSelection, performDelletrage, goToPage
            };
        }
    };

    createApp(DelletrageApp).mount('#delletrageApp');
})();
