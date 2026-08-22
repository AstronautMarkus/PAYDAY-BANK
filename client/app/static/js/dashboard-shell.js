// User dropdown + sign-out confirmation modal, shared by every logged-in
// page (layouts/dashboard.html).
document.addEventListener("DOMContentLoaded", () => {
  const dropdown = document.getElementById("user-dropdown");
  const dropdownTrigger = dropdown.querySelector(".user-dropdown-trigger");

  dropdownTrigger.addEventListener("click", (event) => {
    event.stopPropagation();
    dropdown.classList.toggle("open");
  });

  document.addEventListener("click", (event) => {
    if (!dropdown.contains(event.target)) {
      dropdown.classList.remove("open");
    }
  });

  const logoutModal = document.getElementById("modal-logout");
  document.querySelectorAll(".btn-trigger-logout").forEach((trigger) => {
    trigger.addEventListener("click", () => {
      dropdown.classList.remove("open");
      logoutModal.classList.add("active");
    });
  });

  document.querySelectorAll("[data-close-modal]").forEach((btn) => {
    btn.addEventListener("click", () => btn.closest(".ui-modal-overlay").classList.remove("active"));
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      logoutModal.classList.remove("active");
      dropdown.classList.remove("open");
    }
  });
});
