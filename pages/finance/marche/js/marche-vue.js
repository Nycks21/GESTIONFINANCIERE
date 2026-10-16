// marche-vue.js — Vue 3 app pour la "Liste des marchés"
'use strict';

(function () {
    if (typeof Vue === 'undefined') {
        console.warn('[marche-vue] Vue.js non chargé — fallback vanilla.');
        window._VueMarcheList = null;
        return;
    }

    const { createApp, reactive, computed, onMounted } = Vue;

    const MarcheListApp = {
        setup() {
            const vm = reactive({
                marches: [],
                total: 0,
                totalPages: 0,
                page: 1,
                pageSize: 20,
                loading: false,
                error: null,
                search: '',
                statut: '',
                typeMarche: '',
                expanded: {},
                linesCache: {}
            });

            const t = (key) => (typeof window.t === 'function') ? window.t(key) : key;
            const fmt = (v) => (typeof formatMontant === 'function') ? formatMontant(v) : v;

            const counterText = computed(() => vm.total + ' ' + t('marche.counter_unit'));

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

            async function load() {
                vm.loading = true;
                vm.error = null;
                try {
                    const params = new URLSearchParams({
                        page: vm.page,
                        pageSize: vm.pageSize,
                        search: vm.search,
                        statut: vm.statut,
                        typeMarche: vm.typeMarche
                    });
                    const url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
                    const resp = await fetch(url);
                    const data = await resp.json();
                    if (!resp.ok) throw new Error(data.message || t('marche.msg.load_error'));

                    if (data.success) {
                        vm.marches = data.marches || [];
                        vm.total = Number(data.total || 0);
                        vm.totalPages = Number(data.totalPages || 0);
                        vm.expanded = {};

                        AppState.marches = vm.marches;
                        AppState.total = vm.total;
                        AppState.totalPages = vm.totalPages;
                    } else {
                        vm.error = data.message || t('message.error');
                        vm.marches = [];
                    }
                } catch (err) {
                    vm.error = err.message;
                    vm.marches = [];
                } finally {
                    vm.loading = false;
                }
            }

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
                AppState.filters.statut = vm.statut;
                AppState.filters.typeMarche = vm.typeMarche;
                load();
            }

            function resetFilters() {
                vm.search = '';
                vm.statut = '';
                vm.typeMarche = '';
                vm.page = 1;
                AppState.filters = { search: '', statut: '', typeMarche: '' };
                load();
            }

            async function toggleLines(id) {
                if (vm.expanded[id]) {
                    vm.expanded[id] = false;
                    return;
                }
                if (!vm.linesCache[id]) {
                    try {
                        const url = API.BASE + API.HANDLERS_PATH + API.DETAIL + '?id=' + encodeURIComponent(id);
                        const resp = await fetch(url);
                        const data = await resp.json();
                        if (!data.success) throw new Error(data.message || t('marche.msg.load_error'));
                        vm.linesCache[id] = data.lignes || [];
                    } catch (err) {
                        if (typeof showErrorToast === 'function') showErrorToast(err.message);
                        return;
                    }
                }
                vm.expanded[id] = true;
            }

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
                    + 'border-radius:6px;font-weight:' + (isActive ? '700' : '500') + ';min-width:40px;';
            }

            function statusClass(s) { return 'statut-' + (s || 'attribue').toLowerCase(); }
            function statusLabel(s) { return t('marche.statut.' + (s || 'ATTRIBUE')) || s; }
            function typeLabel(tp) { return t('marche.type.' + (tp || 'AUTRE')) || tp; }

            // ⭐ NOUVEAU : bridge vers les fonctions GLOBALES (pas de shadowing)
            function _callGlobal(name, arg) {
                if (typeof window[name] === 'function') {
                    return arg !== undefined ? window[name](arg) : window[name]();
                }
            }
            function editMarcheBridge(id) { _callGlobal('editMarche', id); }
            function delMarcheBridge(id)  { _callGlobal('deleteMarche', id); }
            function newMarcheBridge()    { _callGlobal('newMarche'); }

            window._VueMarcheList = {
                vm: vm, load: load, toggleLines: toggleLines, resetFilters: resetFilters
            };

            onMounted(() => { /* rien */ });

            window.addEventListener('languagechange', () => { vm.page = vm.page; });

            return {
                vm, t, fmt, counterText, pagination,
                statusClass, statusLabel, typeLabel,
                onSearchInput, onFilterChange, resetFilters,
                toggleLines, goToPage, paginationStyle,
                editMarche: editMarcheBridge,
                delMarche:  delMarcheBridge,
                newMarche:  newMarcheBridge
            };
        }
    };

    document.addEventListener('DOMContentLoaded', function () {
        const el = document.getElementById('marcheListApp');
        if (!el) { window._VueMarcheList = null; return; }
        try {
            createApp(MarcheListApp).mount('#marcheListApp');
            console.log('[marche-vue] ✅ App montée.');
        } catch (err) {
            console.error('[marche-vue] Erreur au montage :', err);
            window._VueMarcheList = null;
        }
    });
})();
