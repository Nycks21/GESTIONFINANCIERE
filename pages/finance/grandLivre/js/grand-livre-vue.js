// grand-livre-vue.js — Gestion de la page Grand Livre Général
'use strict';

(function () {
    if (typeof Vue === 'undefined') {
        console.error('[GrandLivre] Vue.js n’est pas chargé.');
        return;
    }

    const { createApp, reactive, computed, ref, onMounted } = Vue;
    const API_BASE = window.API.BASE + window.API.HANDLERS_PATH;

    function emptyFilters() {
        return {
            siteId: '',
            journalId: '',
            statut: '',
            compte: '', // ⭐ Nouveau filtre
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

    const GrandLivreApp = {
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
                push('compte', 'Compte', appliedFilters.compte); // ⭐ Chip compte
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
                    vm.filterError = 'Erreur de chargement des référentiels : ' + error.message;
                    console.error('[GrandLivre] Erreur de chargement des référentiels', error);
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
                        compte: appliedFilters.compte, // ⭐ Ajout au payload
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
                            html: `Vous êtes sur le point d'afficher <b>${data.total}</b> écritures.<br><br>Que souhaitez-vous faire ?`,
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
                    vm.error = error.message || 'Erreur de chargement.';
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
                        else console.error('[GrandLivre] Erreur de chargement du détail', error);
                        return;
                    }
                }
                vm.expanded[id] = true;
            }

            function validateFilters() {
                if (filters.dateDebut && filters.dateFin && filters.dateDebut > filters.dateFin) {
                    vm.filterError = 'La date de début ne peut pas être supérieure à la date de fin.';
                    return false;
                }
                const min = filters.montantMin === '' ? null : Number(filters.montantMin);
                const max = filters.montantMax === '' ? null : Number(filters.montantMax);
                if ((min !== null && (!Number.isFinite(min) || min < 0))
                    || (max !== null && (!Number.isFinite(max) || max < 0))
                    || (min !== null && max !== null && min > max)) {
                    vm.filterError = 'Plage de montants invalide.';
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

            // Grand Livre = Consultation seule
            function viewEcriture(id) {
                // Vous pouvez soit ouvrir la modale de détail, soit rediriger vers une vue figée
                // Ici on toggle simplement l'affichage des lignes
                toggleLines(id);
            }

            onMounted(loadLookups);

            return {
                vm, filters, lookup, activePlans, activeFilters, t,
                fmt, formatDate, statusClass, statusLabel, resolveCode,
                applyFilters, openFilterModal, closeFilterModal, resetFilters,
                clearAppliedFilters, removeFilter, loadData, toggleLines,
                changePageSize, goToPage, viewEcriture
            };
        }
    };

    createApp(GrandLivreApp).mount('#grandLivreApp');
})();
