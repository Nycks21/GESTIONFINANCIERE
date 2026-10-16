// export.js — TIERS
'use strict';

function buildExportRows() {
    var rows = [['CODE', 'NOM', 'TYPE', 'COMPTE', 'EMAIL', 'TELEPHONE', 'STATUT']];
    var data = (typeof AppState !== 'undefined' && AppState.tiers) || [];
    data.forEach(function (t) {
        rows.push([
            t.CODE || '',
            t.NOM || '',
            t.TYPE_TIERS || '',
            (t.COMPTE_CODE || '') + (t.COMPTE_LIBELLE ? ' - ' + t.COMPTE_LIBELLE : ''),
            t.EMAIL || '',
            t.TELEPHONE || '',
            t.ACTIVE ? 'Actif' : 'Inactif'
        ]);
    });
    return rows;
}

function exportTiersToExcelOnly() {
    var list = (typeof AppState !== 'undefined' && AppState.tiers) || [];
    if (!list.length) { Swal.fire('Info', 'Aucune donnée à exporter.', 'info'); return; }
    var ws = XLSX.utils.aoa_to_sheet(buildExportRows());
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Tiers');
    XLSX.writeFile(wb, 'tiers_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

window.exportTiersPDF = function () {
    var list = (typeof AppState !== 'undefined' && AppState.tiers) || [];
    if (!list.length) { Swal.fire('Info', 'Aucune donnée à imprimer.', 'info'); return; }
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('l', 'mm', 'a4');
        doc.text('Liste des tiers', 14, 12);
        doc.autoTable({
            head: [buildExportRows()[0]],
            body: buildExportRows().slice(1),
            startY: 20, theme: 'grid',
            headStyles: { fillColor: [0, 123, 255] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('Tiers_' + new Date().toISOString().slice(0, 10) + '.pdf');
    } catch (err) { console.error(err); Swal.fire('Erreur', 'Erreur PDF.', 'error'); }
};

window.exportTiersToExcelOnly = exportTiersToExcelOnly;
