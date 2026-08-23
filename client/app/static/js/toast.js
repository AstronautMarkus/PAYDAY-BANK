// Wires up interactivity for the server-rendered toast stack
// (partials/_toast_stack.html): auto-dismiss, pause-on-hover, and the
// manual close button. Flask's flash()/get_flashed_messages() are untouched
// -- this only changes how the messages already in the DOM behave.
(function () {
  var AUTO_DISMISS_MS = 5000;

  function dismiss(toast) {
    if (toast.dataset.leaving) return;
    toast.dataset.leaving = "1";
    toast.classList.add("leaving");
    setTimeout(function () {
      if (toast.parentNode) toast.parentNode.removeChild(toast);
    }, 180);
  }

  function wire(toast) {
    var timer = setTimeout(function () { dismiss(toast); }, AUTO_DISMISS_MS);

    toast.addEventListener("mouseenter", function () {
      clearTimeout(timer);
      toast.classList.add("paused");
    });
    toast.addEventListener("mouseleave", function () {
      toast.classList.remove("paused");
      timer = setTimeout(function () { dismiss(toast); }, AUTO_DISMISS_MS);
    });

    var closeBtn = toast.querySelector(".toast-close");
    if (closeBtn) {
      closeBtn.addEventListener("click", function () {
        clearTimeout(timer);
        dismiss(toast);
      });
    }
  }

  document.querySelectorAll("#toast-stack .toast").forEach(wire);
})();
