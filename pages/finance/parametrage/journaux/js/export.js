// export.js — JOURNAUX
'use strict';

function buildExportRows() {
    var rows = [['CODE', 'LIBELLE', 'TYPE', 'SITE', 'MONNAIE', 'PREFIXE', 'STATUT']];
    var data = (typeof AppState !== 'undefined' && AppState.journaux) || [];
    data.forEach(function (j) {
        rows.push([
            j.CODE || '',
            j.LIBELLE || '',
            j.TYPE_JOURNAL || '',
            j.SITE_NOM || '',
            j.MONNAIE_CODE || '',
            j.PREFIXE_NUMERO || '',
            j.ACTIVE ? 'Actif' : 'Inactif'
        ]);
    });
    return rows;
}

function exportJournauxToExcelOnly() {
    var list = (typeof AppState !== 'undefined' && AppState.journaux) || [];
    if (!list.length) { Swal.fire('Info', 'Aucune donnée à exporter.', 'info'); return; }
    var ws = XLSX.utils.aoa_to_sheet(buildExportRows());
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Journaux');
    XLSX.writeFile(wb, 'journaux_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

window.exportJournauxPDF = function () {
    var list = (typeof AppState !== 'undefined' && AppState.journaux) || [];
    if (!list.length) { Swal.fire('Info', 'Aucune donnée à imprimer.', 'info'); return; }
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('l', 'mm', 'a4');
        doc.text('Liste des journaux', 14, 12);
        doc.autoTable({
            head: [buildExportRows()[0]],
            body: buildExportRows().slice(1),
            startY: 20, theme: 'grid',
            headStyles: { fillColor: [0, 123, 255] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('Journaux_' + new Date().toISOString().slice(0, 10) + '.pdf');
    } catch (err) { console.error(err); Swal.fire('Erreur', 'Erreur PDF.', 'error'); }
};

window.exportJournauxToExcelOnly = exportJournauxToExcelOnly;
