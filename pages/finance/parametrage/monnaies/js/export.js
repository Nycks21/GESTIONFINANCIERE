// export.js – Module MONNAIES
'use strict';

function buildExportRowsFromMonnaies(monnaies) {
    var rows = [['CODE', 'NOM', 'SYMBOLE', 'DECIMALES', 'TAUX REF', 'REFERENCE', 'STATUT']];
    var data = monnaies || (typeof AppState !== 'undefined' && AppState.monnaies) || [];
    data.forEach(function (m) {
        rows.push([
            m.CODE || '',
            m.NOM || '',
            m.SYMBOLE || '',
            m.DECIMALES != null ? m.DECIMALES : 2,
            m.TAUX_REFERENCE != null ? m.TAUX_REFERENCE : '',
            m.EST_REFERENCE ? 'Oui' : 'Non',
            m.ACTIVE ? 'Actif' : 'Inactif'
        ]);
    });
    return rows;
}

function exportMonnaiesToExcelOnly() {
    var monnaies = (typeof AppState !== 'undefined' && AppState.monnaies) || [];
    if (!monnaies.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var ws = XLSX.utils.aoa_to_sheet(buildExportRowsFromMonnaies(monnaies));
    var wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Monnaies');
    XLSX.writeFile(wb, 'monnaies_' + new Date().toISOString().slice(0, 10) + '.xlsx');
}

function exportMonnaiesToCsvOnly() {
    var monnaies = (typeof AppState !== 'undefined' && AppState.monnaies) || [];
    if (!monnaies.length) {
        Swal.fire('Info', 'Aucune donnée à exporter.', 'info');
        return;
    }
    var rows = buildExportRowsFromMonnaies(monnaies);
    var csvContent = rows.map(function (row) {
        return row.map(function (cell) {
            var value = String(cell).replace(/"/g, '""');
            return /[",;\n]/.test(value) ? '"' + value + '"' : value;
        }).join(';');
    }).join('\n');

    var blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' });
    var link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.download = 'monnaies_' + new Date().toISOString().slice(0, 10) + '.csv';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(link.href);
}

window.exportMonnaiesPDF = function () {
    var monnaies = (typeof AppState !== 'undefined' && AppState.monnaies) || [];
    if (!monnaies.length) {
        Swal.fire('Info', 'Aucune donnée à imprimer.', 'info');
        return;
    }
    try {
        const { jsPDF } = window.jspdf;
        const doc = new jsPDF('l', 'mm', 'a4');
        const head = [['CODE', 'NOM', 'SYMBOLE', 'DEC.', 'TAUX REF', 'REF.', 'STATUT']];
        const body = monnaies.map(function (m) {
            return [
                m.CODE || '',
                m.NOM || '',
                m.SYMBOLE || '',
                (m.DECIMALES != null ? m.DECIMALES : 2),
                (m.TAUX_REFERENCE != null ? m.TAUX_REFERENCE : ''),
                m.EST_REFERENCE ? 'Oui' : 'Non',
                m.ACTIVE ? 'Actif' : 'Inactif'
            ];
        });
        doc.text('Liste des monnaies', 14, 12);
        doc.autoTable({
            head: head,
            body: body,
            startY: 20,
            theme: 'grid',
            headStyles: { fillColor: [243, 156, 18] },
            styles: { fontSize: 8, cellPadding: 2 }
        });
        doc.save('Monnaies_' + new Date().toISOString().slice(0, 10) + '.pdf');
    } catch (err) {
        console.error(err);
        Swal.fire('Erreur', 'Erreur lors de la génération du PDF.', 'error');
    }
};

window.exportMonnaiesToExcelOnly = exportMonnaiesToExcelOnly;
window.exportMonnaiesToCsvOnly = exportMonnaiesToCsvOnly;
