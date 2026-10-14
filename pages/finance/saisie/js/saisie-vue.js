// saisie-vue.js — Vue 3 app pour la "Liste des écritures"
'use strict';

(function () {
    if (typeof Vue === 'undefined') {
        console.warn('[saisie-vue] Vue.js non chargé — fallback vanilla activé.');
        window._VueSaisieList = null;
        return;
    }

    const { createApp, reactive, computed, onMounted } = Vue;

    const SaisieListApp = {
        setup() {
            const vm = reactive({
                ecritures: [],
                total: 0,
                totalPages: 0,
                page: 1,
                pageSize: 20,
                loading: false,
                error: null,
                search: '',
                journalId: '',
                statut: '',
                expanded: {},
                linesCache: {}
            });

            const journaux = reactive([]);

            // ─── Helpers ───
            const t = (key) => (typeof window.t === 'function') ? window.t(key) : key;
            const fmt = (v) => (typeof formatMontant === 'function') ? formatMontant(v) : v;

            const counterText = computed(() => vm.total + ' ' + t('saisie.counter_unit'));
            const activePlans = computed(() =>
                typeof getActivePlanFields === 'function' ? getActivePlanFields() : []
            );

            const pagination = computed(() => {
                if (vm.totalPages <= 1) return [];
                const pages = [];
                const cur = vm.page;
                const total = vm.totalPages;

                pages.push({ text: '«', page: 1, disabled: cur === 1 });
                pages.push({ text: '‹', page: cur - 1, disabled: cur === 1 });

                const start = Math.max(1, cur - 2);
                const end = Math.min(total, start + 4);
                for (let i = start; i <= end; i++) {
                    pages.push({ text: String(i), page: i, active: i === cur });
                }

                pages.push({ text: '›', page: cur + 1, disabled: cur === total });
                pages.push({ text: '»', page: total, disabled: cur === total });
                return pages;
            });

            // ─── Chargement ───
            async function load() {
                vm.loading = true;
                vm.error = null;

                try {
                    const params = new URLSearchParams({
                        page: vm.page,
                        pageSize: vm.pageSize,
                        search: vm.search,
                        journalId: vm.journalId,
                        statut: vm.statut
                    });
                    const url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
                    const resp = await fetch(url);
                    const data = await resp.json();

                    if (!resp.ok) throw new Error(data.message || t('saisie.msg.load_error'));

                    if (data.success) {
                        vm.ecritures = data.ecritures || [];
                        vm.total = Number(data.total || 0);
                        vm.totalPages = Number(data.totalPages || 0);

                        if (vm.page < 1) vm.page = 1;
                        if (vm.totalPages > 0 && vm.page > vm.totalPages) vm.page = vm.totalPages;

                        vm.expanded = {};

                        // Sync AppState (rétrocompat)
                        AppState.ecritures = vm.ecritures;
                        AppState.total = vm.total;
                        AppState.totalPages = vm.totalPages;
                        AppState.page = vm.page;
                    } else {
                        vm.error = data.message || t('message.error');
                        vm.ecritures = [];
                    }
                } catch (err) {
                    vm.error = err.message;
                    vm.ecritures = [];
                } finally {
                    vm.loading = false;
                }
            }

            // ─── Recherche debounce ───
            let searchTimer = null;
            function onSearchInput() {
                clearTimeout(searchTimer);
                searchTimer = setTimeout(() => {
                    vm.page = 1;
                    AppState.filters.search = vm.search;
                    load();
                }, 350);
            }

            function onFilterChange() {
                vm.page = 1;
                AppState.filters.journalId = vm.journalId;
                AppState.filters.statut = vm.statut;
                load();
            }

            function resetFilters() {
                vm.search = '';
                vm.journalId = '';
                vm.statut = '';
                vm.page = 1;
                AppState.filters = { search: '', journalId: '', statut: '' };
                AppState.page = 1;
                load();
            }

            // ─── Expansion / réduction ───
            async function toggleLines(id) {
                if (vm.expanded[id]) {
                    vm.expanded[id] = false;
                    return;
                }

                if (!vm.linesCache[id]) {
                    try {
                        const url = API.BASE + API.HANDLERS_PATH + API.DETAIL
                                  + '?id=' + encodeURIComponent(id);
                        const resp = await fetch(url);
                        const data = await resp.json();
                        if (!data.success) throw new Error(data.message || t('saisie.msg.load_error'));
                        vm.linesCache[id] = data.lignes || [];
                    } catch (err) {
                        if (typeof showErrorToast === 'function') showErrorToast(err.message);
                        return;
                    }
                }

                vm.expanded[id] = true;
            }

            // ─── Pagination ───
            function goToPage(p) {
                if (!p || p < 1 || p > vm.totalPages || p === vm.page) return;
                vm.page = p;
                AppState.page = p;
                load();
            }

            function paginationStyle(p) {
                const isActive = p.active;
                const isDisabled = p.disabled;
                return 'padding:8px 14px;'
                    + 'border:1px solid ' + (isActive ? '#007bff' : '#dee2e6') + ';'
                    + 'background:' + (isActive ? '#007bff' : (isDisabled ? '#e9ecef' : 'white')) + ';'
                    + 'color:' + (isActive ? 'white' : (isDisabled ? '#6c757d' : '#007bff')) + ';'
                    + 'cursor:' + (isDisabled || isActive ? 'default' : 'pointer') + ';'
                    + 'border-radius:6px;'
                    + 'font-weight:' + (isActive ? '700' : '500') + ';'
                    + 'min-width:40px;';
            }

            // ─── Helpers d'affichage ───
            function statusClass(s) { return 'statut-' + (s || 'brouillon').toLowerCase(); }
            function statusLabel(s) { return t('saisie.statut.' + (s || 'BROUILLON')) || s; }
            function resolveCode(ordre, compteId) {
                return typeof resolvePlanCodeByOrdre === 'function'
                    ? resolvePlanCodeByOrdre(ordre, compteId)
                    : '';
            }
            function sumDebit(lignes) {
                return (lignes || []).reduce((s, x) => s + (parseFloat(x.DEBIT || 0) || 0), 0);
            }
            function sumCredit(lignes) {
                return (lignes || []).reduce((s, x) => s + (parseFloat(x.CREDIT || 0) || 0), 0);
            }

            // ─── Actions déléguées ───
            function editEcr(id) { if (typeof editEcriture === 'function') editEcriture(id); }
            function delEcr(id) { if (typeof deleteEcriture === 'function') deleteEcriture(id); }
            function newEcr() { if (typeof newEcriture === 'function') newEcriture(); }

            // ─── Sync journaux depuis AppState ───
            function syncJournaux() {
                journaux.length = 0;
                (AppState.journaux || []).forEach(j => journaux.push(j));
            }

            // ─── Bridge global ───
            window._VueSaisieList = {
                vm: vm,
                load: load,
                syncJournaux: syncJournaux,
                toggleLines: toggleLines,
                resetFilters: resetFilters
            };

            // ─── Lifecycle ───
            onMounted(() => {
                const check = setInterval(() => {
                    if (AppState.journaux && AppState.journaux.length) {
                        syncJournaux();
                        clearInterval(check);
                    }
                }, 100);
                setTimeout(() => clearInterval(check), 5000);
            });

            // Réagit aux changements de langue
            window.addEventListener('languagechange', () => {
                vm.page = vm.page; // Force re-render
            });

            return {
                vm: vm,
                journaux: journaux,
                t: t,
                fmt: fmt,
                counterText: counterText,
                pagination: pagination,
                activePlans: activePlans,
                statusClass: statusClass,
                statusLabel: statusLabel,
                resolveCode: resolveCode,
                sumDebit: sumDebit,
                sumCredit: sumCredit,
                onSearchInput: onSearchInput,
                onFilterChange: onFilterChange,
                resetFilters: resetFilters,
                toggleLines: toggleLines,
                goToPage: goToPage,
                paginationStyle: paginationStyle,
                editEcr: editEcr,
                delEcr: delEcr,
                newEcr: newEcr
            };
        }
    };

    // ─── Montage ───
    document.addEventListener('DOMContentLoaded', function () {
        const el = document.getElementById('saisieListApp');
        if (!el) {
            console.warn('[saisie-vue] #saisieListApp introuvable — fallback vanilla.');
            window._VueSaisieList = null;
            return;
        }
        try {
            createApp(SaisieListApp).mount('#saisieListApp');
            console.log('[saisie-vue] ✅ App montée.');
        } catch (err) {
            console.error('[saisie-vue] Erreur au montage :', err);
            window._VueSaisieList = null;
        }
    });

})();
