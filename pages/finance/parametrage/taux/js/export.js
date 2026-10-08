// export.js — TAUX
'use strict';

function buildExportRowsFromTaux(taux) {
    var rows = [['SOURCE', 'CIBLE', 'TAUX', 'DATE EFFET', 'SOURCE INFO', 'STATUT']];
    var data = taux || (typeof AppState !== 'undefined' && AppState.taux) || [];
    data.forEach(function (t) {
        rows.push([
            t.SOURCE_CODE || '',
            t.CIBLE_CODE || '',
            formatTaux(t.TAUX),
            formatDateFr(t.DATE_EFFET),
            t.SOURCE || '',
            t.ACTIVE ? 'Actif' : 'Inactif'
        ]);
    });
    return rows;
}

function exportTauxToExcelOnly() {
    var taux = (typeof AppState !== 'undefined' && AppState.taux) || [];
    if (!taux.length) { Swal.fire('Info', 'Aucune donnée à exporter.', 'info'); return; }
    var ws = XLSX.utils.aoa_to_sheet(buildExportRowsFromTaux(taux));
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Taux');
    XLSX.writeFile(wb, 'taux_change_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

function exportTauxToCsvOnly() {
    var taux = (typeof AppState !== 'undefined' && AppState.taux) || [];
    if (!taux.length) { Swal.fire('Info', 'Aucune donnée à exporter.', 'info'); return; }
    var rows = buildExportRowsFromTaux(taux);
    var csvContent = rows.map(function (row) {
        return row.map(function (cell) {
            var value = String(cell).replace(/"/g, '""');
            return /[",;\n]/.test(value) ? '"' + value + '"' : value;
        }).join(';');
    }).join('\n');
    var blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
    var link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'taux_change_' + new Date().toISOString().slice(0, 10) + '.csv';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);
}

window.exportTauxPDF = function () {
    var taux = (typeof AppState !== 'undefined' && AppState.taux) || [];
    if (!taux.length) { Swal.fire('Info', 'Aucune donnée à imprimer.', 'info'); return; }
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('l', 'mm', 'a4');
        const head = [['SOURCE', 'CIBLE', 'TAUX', 'DATE EFFET', 'SOURCE INFO', 'STATUT']];
        const body = taux.map(function (t) {
            return [
                t.SOURCE_CODE || '',
                t.CIBLE_CODE || '',
                formatTaux(t.TAUX),
                formatDateFr(t.DATE_EFFET),
                t.SOURCE || '',
                t.ACTIVE ? 'Actif' : 'Inactif'
            ];
        });
        doc.text('Taux de change', 14, 12);
        doc.autoTable({
            head: head,
            body: body,
            startY: 20,
            theme: 'grid',
            headStyles: { fillColor: [0, 123, 255] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('Taux_change_' + new Date().toISOString().slice(0, 10) + '.pdf');
    } catch (err) {
        console.error(err);
        Swal.fire('Erreur', 'Erreur lors de la génération du PDF.', 'error');
    }
};

window.exportTauxToExcelOnly = exportTauxToExcelOnly;
window.exportTauxToCsvOnly = exportTauxToCsvOnly;
