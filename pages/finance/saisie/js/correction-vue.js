// correction-vue.js — Gestion de la page Correction
'use strict';

(function () {
    if (typeof Vue === 'undefined') {
        console.error('[Correction] Vue.js n’est pas chargé.');
        return;
    }

    const { createApp, reactive, computed, ref, onMounted } = Vue;
    const API_BASE = window.API.BASE + window.API.HANDLERS_PATH;

    function emptyFilters() {
        return {
            siteId: '',
            journalId: '',
            statut: '',
            search: '',
            referenceDebut: '',
            referenceFin: '',
            dateDebut: '',
            dateFin: '',
            montantMin: '',
            montantMax: '',
            marcheId: ''
        };
    }

    const CorrectionApp = {
        setup() {
            const vm = reactive({
                loading: false,
                error: '',
                filterError: '',
                ecritures: [],
                total: 0,
                totalPages: 0,
                page: 1,
                pageSize: 50,
                expanded: {},
                linesCache: {},
                showFilterModal: true,
                hasAppliedFilters: false,
                hasConfirmedLargeData: false
            });
            const filters = reactive(emptyFilters());
            const appliedFilters = reactive(emptyFilters());
            const lookup = reactive({ sites: [], journaux: [], marches: [] });
            const plans = ref([]);
            let currentRequest = 0;

            const t = (key, params) => window.t ? window.t(key, params) : key;
            const activePlans = computed(() => plans.value);
            const fmt = (value) => (typeof formatMontant === 'function' ? formatMontant(value) : value);
            const formatDate = (value) => {
                if (!value) return '—';
                const date = new Date(value + 'T00:00:00');
                return Number.isNaN(date.getTime()) ? value : date.toLocaleDateString('fr-FR');
            };
            const statusClass = (status) => {
                const classes = {
                    BROUILLON: 'statut-brouillon',
                    A_VALIDER: 'statut-a_valider',
                    VALIDEE: 'statut-validee',
                    COMPTABILISEE: 'statut-comptabilisee',
                    ANNULEE: 'statut-annulee'
                };
                return classes[status] || '';
            };
            const statusLabel = (status) => {
                const key = 'saisie.statut.' + status;
                const label = t(key);
                return label === key ? status : label;
            };
            const resolveCode = (ordre, compteId) => {
                if (!compteId || !window.AppState) return '';
                const accounts = window.AppState.comptesParPlan[ordre] || [];
                const account = accounts.find((item) => item.ID === compteId);
                return account ? account.CODE : '';
            };

            const activeFilters = computed(() => {
                const chips = [];
                const push = (key, label, value) => {
                    if (value !== '' && value !== null && value !== undefined) {
                        chips.push({ key, label, value: String(value) });
                    }
                };
                const site = lookup.sites.find((item) => item.ID === appliedFilters.siteId);
                const journal = lookup.journaux.find((item) => item.ID === appliedFilters.journalId);
                const market = lookup.marches.find((item) => item.ID === appliedFilters.marcheId);
                push('siteId', t('correction.site'), site ? site.CODE + ' — ' + site.NOM : appliedFilters.siteId);
                push('journalId', t('correction.journal'), journal ? journal.CODE : appliedFilters.journalId);
                push('statut', t('correction.status'), appliedFilters.statut ? statusLabel(appliedFilters.statut) : '');
                push('search', t('correction.search'), appliedFilters.search);
                if (appliedFilters.referenceDebut) push('referenceDebut', 'Réf. de', appliedFilters.referenceDebut);
                if (appliedFilters.referenceFin) push('referenceFin', 'Réf. à', appliedFilters.referenceFin);
                push('dateDebut', t('correction.date_from'), appliedFilters.dateDebut);
                push('dateFin', t('correction.date_to'), appliedFilters.dateFin);
                push('montantMin', t('correction.minimum'), appliedFilters.montantMin);
                push('montantMax', t('correction.maximum'), appliedFilters.montantMax);
                push('marcheId', t('correction.market'), market ? market.NUMERO : appliedFilters.marcheId);
                return chips;
            });

            async function readJson(response) {
                const text = await response.text();
                let data;
                try {
                    data = JSON.parse(text);
                } catch (error) {
                    throw new Error(response.ok ? t('correction.invalid_response') : 'HTTP ' + response.status);
                }
                if (!response.ok || !data.success) {
                    throw new Error(data.message || 'HTTP ' + response.status);
                }
                return data;
            }

            async function loadLookups() {
                try {
                    const response = await fetch(API_BASE + window.API.LOOKUPS);
                    const data = await readJson(response);
                    lookup.sites = data.sites || [];
                    lookup.journaux = data.journaux || [];
                    if (window.AppState && data.plansActifs) {
                        window.AppState.plansActifs = data.plansActifs;
                    }
                    plans.value = typeof getActivePlanFields === 'function'
                        ? getActivePlanFields()
                        : (data.plansActifs || []).map((plan, index) => ({
                            key: 'P' + (plan.ORDRE || index + 1),
                            ordre: plan.ORDRE || index + 1,
                            label: plan.CODE || plan.NOM || 'Plan ' + (index + 1)
                        }));

                    const lookupRequests = [
                        fetch(API_BASE + window.API.MARCHES)
                            .then(readJson)
                            .then((marketData) => { lookup.marches = marketData.marches || []; })
                    ];
                    if (window.AppState) {
                        plans.value.forEach((plan) => {
                            const url = API_BASE + window.API.COMPTES_BY_PLAN
                                + '?planOrder=' + encodeURIComponent(plan.ordre);
                            lookupRequests.push(
                                fetch(url)
                                    .then(readJson)
                                    .then((accountData) => {
                                        window.AppState.comptesParPlan[plan.ordre] = accountData.comptes || [];
                                    })
                            );
                        });
                    }
                    await Promise.all(lookupRequests);
                } catch (error) {
                    vm.filterError = t('correction.lookup_error') + ' ' + error.message;
                    console.error('[Correction] Erreur de chargement des référentiels', error);
                }
            }

            async function loadData() {
                if (!vm.hasAppliedFilters) return;
                const requestId = ++currentRequest;
                vm.loading = true;
                vm.error = '';

                try {
                    const params = new URLSearchParams({
                        page: vm.page,
                        pageSize: vm.pageSize,
                        siteId: appliedFilters.siteId,
                        journalId: appliedFilters.journalId,
                        statut: appliedFilters.statut,
                        search: appliedFilters.search,
                        referenceDebut: appliedFilters.referenceDebut,
                        referenceFin: appliedFilters.referenceFin,
                        dateDebut: appliedFilters.dateDebut,
                        dateFin: appliedFilters.dateFin,
                        montantMin: appliedFilters.montantMin,
                        montantMax: appliedFilters.montantMax,
                        marche: appliedFilters.marcheId
                    });
                    const response = await fetch(API_BASE + window.API.LIST + '?' + params);
                    const data = await readJson(response);

                    if (requestId !== currentRequest) return;

                    if (data.total > 1000 && !vm.hasConfirmedLargeData) {
                        vm.loading = false;
                        const result = await Swal.fire({
                            title: 'Volume de données important',
                            html: `Vous êtes sur le point d'afficher <b>${data.total}</b> écritures.<br><br>Cela peut impacter les performances de votre navigateur.<br>Que souhaitez-vous faire ?`,
                            icon: 'warning',
                            showCancelButton: true,
                            confirmButtonColor: '#2563EB',
                            cancelButtonColor: '#6c757d',
                            confirmButtonText: '<i class="fas fa-check"></i> OK, continuer',
                            cancelButtonText: '<i class="fas fa-filter"></i> Changer les filtres',
                            allowOutsideClick: false
                        });

                        if (result.isConfirmed) {
                            vm.hasConfirmedLargeData = true;
                        } else {
                            vm.hasAppliedFilters = false;
                            vm.ecritures = [];
                            vm.total = 0;
                            vm.totalPages = 0;
                            vm.showFilterModal = true;
                            return;
                        }
                    }

                    vm.ecritures = data.ecritures || [];
                    vm.total = Number(data.total || 0);
                    vm.totalPages = Number(data.totalPages || 0);
                    if (vm.totalPages > 0 && vm.page > vm.totalPages) {
                        vm.page = vm.totalPages;
                        await loadData();
                        return;
                    }
                    if (vm.totalPages === 0) vm.page = 1;
                    vm.expanded = {};
                } catch (error) {
                    if (requestId !== currentRequest) return;
                    vm.ecritures = [];
                    vm.total = 0;
                    vm.totalPages = 0;
                    vm.error = error.message || t('correction.load_error');
                } finally {
                    if (requestId === currentRequest) vm.loading = false;
                }
            }

            async function toggleLines(id) {
                if (vm.expanded[id]) {
                    vm.expanded[id] = false;
                    return;
                }
                if (!vm.linesCache[id]) {
                    try {
                        const response = await fetch(API_BASE + window.API.DETAIL + '?id=' + encodeURIComponent(id));
                        const data = await readJson(response);
                        vm.linesCache[id] = data.lignes || [];
                    } catch (error) {
                        if (typeof showErrorToast === 'function') showErrorToast(error.message);
                        else console.error('[Correction] Erreur de chargement du détail', error);
                        return;
                    }
                }
                vm.expanded[id] = true;
            }

            function validateFilters() {
                if (filters.referenceDebut && filters.referenceFin && filters.referenceDebut > filters.referenceFin) {
                    vm.filterError = 'La référence de début ne peut pas être supérieure à la référence de fin.';
                    return false;
                }
                if (filters.dateDebut && filters.dateFin && filters.dateDebut > filters.dateFin) {
                    vm.filterError = t('correction.date_range_error');
                    return false;
                }
                const min = filters.montantMin === '' ? null : Number(filters.montantMin);
                const max = filters.montantMax === '' ? null : Number(filters.montantMax);
                if ((min !== null && (!Number.isFinite(min) || min < 0))
                    || (max !== null && (!Number.isFinite(max) || max < 0))
                    || (min !== null && max !== null && min > max)) {
                    vm.filterError = t('correction.amount_range_error');
                    return false;
                }
                return true;
            }

            async function applyFilters() {
                vm.filterError = '';
                if (!validateFilters()) return;
                Object.assign(appliedFilters, filters);
                vm.hasAppliedFilters = true;
                vm.showFilterModal = false;
                vm.page = 1;
                vm.hasConfirmedLargeData = false;
                await loadData();
            }

            function openFilterModal() {
                Object.assign(filters, appliedFilters);
                vm.filterError = '';
                vm.showFilterModal = true;
            }

            function closeFilterModal() {
                if (vm.loading) return;
                Object.assign(filters, appliedFilters);
                vm.filterError = '';
                vm.showFilterModal = false;
            }

            function resetFilters() {
                Object.assign(filters, emptyFilters());
                vm.filterError = '';
            }

            function removeFilter(key) {
                appliedFilters[key] = '';
                Object.assign(filters, appliedFilters);
                vm.page = 1;
                vm.hasConfirmedLargeData = false;
                loadData();
            }

            function clearAppliedFilters() {
                Object.assign(filters, emptyFilters());
                Object.assign(appliedFilters, emptyFilters());
                vm.page = 1;
                vm.hasConfirmedLargeData = false;
                loadData();
            }

            function goToPage(page) {
                if (page < 1 || page > vm.totalPages || page === vm.page || vm.loading) return;
                vm.page = page;
                loadData();
            }

            function changePageSize() {
                vm.page = 1;
                loadData();
            }

            function editEcriture(id) {
                window.location.href = 'saisie.aspx?editId=' + encodeURIComponent(id);
            }

            async function validateEcriture(id) {
                const confirmation = await Swal.fire({
                    title: t('correction.confirm_validate'),
                    text: t('correction.confirm_validate_text'),
                    icon: 'warning',
                    showCancelButton: true,
                    confirmButtonText: t('correction.validate'),
                    cancelButtonText: t('correction.cancel')
                });
                if (!confirmation.isConfirmed) return;

                try {
                    const response = await fetch(API_BASE + window.API.VALIDER, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ id })
                    });
                    await readJson(response);
                    await Swal.fire(t('correction.success'), t('correction.validated'), 'success');
                    await loadData();
                } catch (error) {
                    await Swal.fire(t('correction.error'), error.message, 'error');
                }
            }

            async function deleteEcriture(id) {
                const confirmation = await Swal.fire({
                    title: t('correction.confirm_delete'),
                    text: t('correction.confirm_delete_text'),
                    icon: 'warning',
                    showCancelButton: true,
                    confirmButtonText: t('correction.delete'),
                    cancelButtonText: t('correction.cancel')
                });
                if (!confirmation.isConfirmed) return;

                try {
                    const response = await fetch(API_BASE + window.API.DELETE, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ id })
                    });
                    await readJson(response);
                    await Swal.fire(t('correction.success'), t('correction.deleted'), 'success');
                    await loadData();
                } catch (error) {
                    await Swal.fire(t('correction.error'), error.message, 'error');
                }
            }

            onMounted(loadLookups);

            return {
                vm, filters, lookup, activePlans, activeFilters, t,
                fmt, formatDate, statusClass, statusLabel, resolveCode,
                applyFilters, openFilterModal, closeFilterModal, resetFilters,
                clearAppliedFilters, removeFilter, loadData, toggleLines,
                changePageSize, goToPage, editEcriture, validateEcriture, deleteEcriture
            };
        }
    };

    createApp(CorrectionApp).mount('#correctionApp');
})();
