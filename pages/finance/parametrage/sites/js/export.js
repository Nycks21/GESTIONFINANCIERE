// export.js
'use strict';

function buildExportRowsFromSites(sites) {
    var rows = [['CODE', 'NOM', 'DESCRIPTION', 'STATUT']];
    var data = sites || (typeof AppState !== 'undefined' && AppState.sites) || [];
    data.forEach(function (s) {
        rows.push([
            s.CODE || '',
            s.NOM || '',
            s.DESCRIPTION || '',
            s.ACTIVE ? 'Actif' : 'Inactif'
        ]);
    });
    return rows;
}

function exportSitesToExcelOnly() {
    var sites = (typeof AppState !== 'undefined' && AppState.sites) || [];
    if (!sites.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var ws = XLSX.utils.aoa_to_sheet(buildExportRowsFromSites(sites));
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Sites');
    XLSX.writeFile(wb, 'sites_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

function exportSitesToCsvOnly() {
    var sites = (typeof AppState !== 'undefined' && AppState.sites) || [];
    if (!sites.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var rows = buildExportRowsFromSites(sites);
    var csvContent = rows.map(function (row) {
        return row.map(function (cell) {
            var value = String(cell).replace(/"/g, '""');
            return /[",;\n]/.test(value) ? '"' + value + '"' : value;
        }).join(';');
    }).join('\n');

    var blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
    var link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'sites_' + new Date().toISOString().slice(0, 10) + '.csv';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);
}

window.exportSitesPDF = function () {
    var sites = (typeof AppState !== 'undefined' && AppState.sites) || [];
    if (!sites.length) {
        Swal.fire('Info', 'Aucune donnée à imprimer.', 'info');
        return;
    }
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('l', 'mm', 'a4');
        const head = [['CODE', 'NOM', 'DESCRIPTION', 'STATUT']];
        const body = sites.map(function (s) {
            return [s.CODE || '', s.NOM || '', s.DESCRIPTION || '', s.ACTIVE ? 'Actif' : 'Inactif'];
        });
        doc.text('Liste des sites', 14, 12);
        doc.autoTable({
            head: head,
            body: body,
            startY: 20,
            theme: 'grid',
            headStyles: { fillColor: [0, 123, 255] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('Sites_' + new Date().toISOString().slice(0, 10) + '.pdf');
    } catch (err) {
        console.error(err);
        Swal.fire('Erreur', 'Erreur lors de la génération du PDF.', 'error');
    }
};

window.exportSitesToExcelOnly = exportSitesToExcelOnly;
window.exportSitesToCsvOnly = exportSitesToCsvOnly;
