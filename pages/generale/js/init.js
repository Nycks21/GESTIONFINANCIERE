// init.js — GÉNÉRALE
$(document).ready(function () {
    loadSections();

    document.addEventListener('keydown', function (e) {
        if (e.key !== 'Escape') return;
        var planEdit = document.getElementById('planEditModal');
        var plans    = document.getElementById('plansModal');
        if (planEdit && planEdit.style.display === 'flex') closePlanEditModal();
        else if (plans && plans.style.display === 'flex') closePlansModal();
    });

    document.querySelectorAll('.modal').forEach(function (modal) {
        modal.addEventListener('click', function (e) {
            if (e.target !== modal) return;
            if (modal.id === 'planEditModal') closePlanEditModal();
            else if (modal.id === 'plansModal') {
                var child = document.getElementById('planEditModal');
                if (child && child.style.display === 'flex') closePlanEditModal();
                closePlansModal();
            }
        });
    });
});
