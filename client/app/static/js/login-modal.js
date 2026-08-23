// Generic modal open/close, used on public-facing pages. A trigger opens
// its target via data-open-modal="<modal id>"; data-close-modal or Escape
// closes whichever modal is open.
document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-open-modal]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const modal = document.getElementById(btn.dataset.openModal);
      if (modal) modal.classList.add("active");
    });
  });

  document.querySelectorAll("[data-close-modal]").forEach((btn) => {
    btn.addEventListener("click", () => btn.closest(".ui-modal-overlay").classList.remove("active"));
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      document.querySelectorAll(".ui-modal-overlay.active").forEach((modal) => modal.classList.remove("active"));
    }
  });
});
