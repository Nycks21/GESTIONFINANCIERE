// export.js — EXERCICES
'use strict';

function buildExportRows() {
    var rows = [['CODE', 'LIBELLE', 'DATE DEBUT', 'DATE FIN', 'DUREE', 'STATUT', 'ACTIF']];
    var data = (typeof AppState !== 'undefined' && AppState.exercices) || [];
    data.forEach(function (e) {
        rows.push([
            e.CODE || '',
            e.LIBELLE || '',
            formatDateFr(e.DATE_DEBUT),
            formatDateFr(e.DATE_FIN),
            formatDureeMois(e.DATE_DEBUT, e.DATE_FIN),
            e.STATUT || '',
            e.ACTIVE ? 'Oui' : 'Non'
        ]);
    });
    return rows;
}

function exportExercicesToExcelOnly() {
    var list = (typeof AppState !== 'undefined' && AppState.exercices) || [];
    if (!list.length) { Swal.fire('Info', 'Aucune donnée à exporter.', 'info'); return; }
    var ws = XLSX.utils.aoa_to_sheet(buildExportRows());
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Exercices');
    XLSX.writeFile(wb, 'exercices_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

function exportExercicesToCsvOnly() {
    var list = (typeof AppState !== 'undefined' && AppState.exercices) || [];
    if (!list.length) { Swal.fire('Info', 'Aucune donnée à exporter.', 'info'); return; }
    var rows = buildExportRows();
    var csvContent = rows.map(function (row) {
        return row.map(function (cell) {
            var v = String(cell).replace(/"/g, '""');
            return /[",;\n]/.test(v) ? '"' + v + '"' : v;
        }).join(';');
    }).join('\n');
    var blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
    var link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'exercices_' + new Date().toISOString().slice(0, 10) + '.csv';
    document.body.appendChild(link); link.click();
    document.body.removeChild(link); URL.revokeObjectURL(link.href);
}

window.exportExercicesPDF = function () {
    var list = (typeof AppState !== 'undefined' && AppState.exercices) || [];
    if (!list.length) { Swal.fire('Info', 'Aucune donnée à imprimer.', 'info'); return; }
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('l', 'mm', 'a4');
        doc.text('Liste des exercices', 14, 12);
        doc.autoTable({
            head: [['CODE', 'LIBELLE', 'DATE DEBUT', 'DATE FIN', 'DUREE', 'STATUT', 'ACTIF']],
            body: buildExportRows().slice(1),
            startY: 20, theme: 'grid',
            headStyles: { fillColor: [0, 123, 255] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('Exercices_' + new Date().toISOString().slice(0, 10) + '.pdf');
    } catch (err) { console.error(err); Swal.fire('Erreur', 'Erreur PDF.', 'error'); }
};

window.exportExercicesToExcelOnly = exportExercicesToExcelOnly;
window.exportExercicesToCsvOnly   = exportExercicesToCsvOnly;
