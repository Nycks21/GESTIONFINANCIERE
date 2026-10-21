// liste-ecritures-vue.js — Liste des écritures (Grand Livre)
(function () {
    if (typeof Vue === 'undefined') return;
    const { createApp, reactive, computed, onMounted, ref } = Vue;

    createApp({
        setup() {
            const vm = reactive({
                loading: false, error: null,
                search: '', journalId: '', statut: '',
                exerciceId: '', dateDebut: '', dateFin: '',
                datePieceDebut: '', datePieceFin: '',
                numeroPiece: '', compte: '', tiers: '', marche: '',
                ecritures: [], expanded: {}, linesCache: {},
                page: 1, pageSize: 50, total: 0
            });
            const exercices   = ref([]);
            const journaux    = ref([]);
            const activePlans = ref([]);

            // ── Lookups (exercices, journaux, plans) ──
            async function loadLookups() {
                try {
                    const url = API.BASE + API.HANDLERS_PATH + API.LOOKUPS;
                    const resp = await fetch(url);
                    const data = await resp.json();
                    if (data.success) {
                        exercices.value = data.exercices || [];
                        journaux.value  = data.journaux  || [];
                        activePlans.value = (data.plans || []).map((p, i) => ({
                            key: 'p' + i,
                            ordre: p.ORDRE || i + 1,
                            label: p.LABEL || 'PLAN' + (i + 1)
                        }));
                    }
                } catch (err) { console.error('[liste-vue] loadLookups', err); }
            }

            // ── Chargement des écritures ──
            async function loadEcritures() {
                vm.loading = true; vm.error = null;
                try {
                    if (!API.LIST) {
                        throw new Error("API.LIST n'est pas défini dans config.js");
                    }
                    const params = new URLSearchParams({
                        search:         vm.search        || '',
                        journalId:      vm.journalId     || '',
                        statut:         vm.statut        || '',
                        exerciceId:     vm.exerciceId    || '',
                        dateDebut:      vm.dateDebut     || '',
                        dateFin:        vm.dateFin       || '',
                        datePieceDebut: vm.datePieceDebut|| '',
                        datePieceFin:   vm.datePieceFin  || '',
                        numeroPiece:    vm.numeroPiece   || '',
                        compte:         vm.compte        || '',
                        tiers:          vm.tiers         || '',
                        marche:         vm.marche        || '',
                        page:           vm.page,
                        pageSize:       vm.pageSize
                    });
                    const url = API.BASE + API.HANDLERS_PATH + API.LIST + '?' + params;
                    console.log('[liste-vue] GET', url);

                    const resp = await fetch(url);
                    if (!resp.ok) {
                        const raw = await resp.text();
                        console.error('[liste-vue] HTTP', resp.status, '| Body:', raw.substring(0, 500));
                        throw new Error('HTTP ' + resp.status + ' — handler ' + API.LIST);
                    }
                    const text = await resp.text();
                    if (text.trim().charAt(0) === '<') {
                        console.error('[liste-vue] Réponse HTML reçue:', text.substring(0, 500));
                        throw new Error('Réponse non-JSON (voir console)');
                    }
                    const data = JSON.parse(text);
                    if (!data.success) throw new Error(data.message || 'Erreur serveur');
                    vm.ecritures = data.ecritures || [];
                    vm.total     = data.total || vm.ecritures.length;
                } catch (err) {
                    vm.error = err.message;
                    console.error('[liste-vue] ❌', err);
                } finally { vm.loading = false; }
            }

            let searchTimer = null;
            function onSearchInput() {
                clearTimeout(searchTimer);
                searchTimer = setTimeout(() => { vm.page = 1; loadEcritures(); }, 350);
            }
            function onFilterChange() { vm.page = 1; loadEcritures(); }

            function resetFilters() {
                Object.assign(vm, {
                    search: '', journalId: '', statut: '',
                    exerciceId: '', dateDebut: '', dateFin: '',
                    datePieceDebut: '', datePieceFin: '',
                    numeroPiece: '', compte: '', tiers: '', marche: '',
                    page: 1
                });
                loadEcritures();
            }

            function editEcr(id)    { window.location.href = 'saisie.aspx?editId=' + encodeURIComponent(id); }
            function navigateToNew(){ window.location.href = 'saisie.aspx'; }

            // ── Lignes via GetEcritureDetail.ashx ──
            async function toggleLines(id) {
                if (vm.expanded[id]) { vm.expanded[id] = false; return; }
                vm.expanded[id] = true;
                if (!vm.linesCache[id]) {
                    try {
                        const url = API.BASE + API.HANDLERS_PATH + API.ECRITURES_DETAIL + '?id=' + encodeURIComponent(id);
                        const resp = await fetch(url);
                        const data = await resp.json();
                        vm.linesCache[id] = data.lignes || [];
                    } catch (err) {
                        console.error('[liste-vue] toggleLines', err);
                        vm.linesCache[id] = [];
                    }
                }
            }

            function goToPage(p) { if (!p || p === vm.page) return; vm.page = p; loadEcritures(); }

            // ── Helpers ──
            function fmt(v) {
                if (v == null) return '0,00';
                const n = parseFloat(v); if (isNaN(n)) return '0,00';
                const s = n.toFixed(2); const parts = s.split('.');
                return parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + ',' + parts[1];
            }
            function resolveCode(ordre, planId) { return planId || ''; }
            function statusClass(s) { return 'statut-' + String(s || '').toLowerCase(); }
            function statusLabel(s) { return t('saisie.statut.' + s) || s; }
            function t(key) { return (window.i18n && window.i18n.t) ? window.i18n.t(key) : key; }

            const totalPages = computed(() => Math.max(1, Math.ceil(vm.total / vm.pageSize)));
            const pagination = computed(() => {
                const pages = [];
                for (let i = 1; i <= totalPages.value; i++) pages.push({ page: i, text: i, disabled: i === vm.page });
                return pages;
            });
            const counterText = computed(() => `${vm.total} ${t('liste_ecritures.count_unit')}`);
            const paginationStyle = (p) => p.disabled
                ? 'background:#007bff;color:#fff;border:1px solid #007bff;padding:5px 10px;border-radius:4px;'
                : 'background:#fff;color:#007bff;border:1px solid #007bff;padding:5px 10px;border-radius:4px;cursor:pointer;';

            onMounted(async () => { await loadLookups(); await loadEcritures(); });

            return {
                vm, exercices, journaux, activePlans,
                onSearchInput, onFilterChange, resetFilters,
                editEcr, navigateToNew, toggleLines, goToPage,
                fmt, resolveCode, statusClass, statusLabel, t,
                pagination, counterText, paginationStyle
            };
        }
    }).mount('#listeEcrituresApp');
})();
