// Live-formats Chilean peso (CLP) amount inputs: as the user types, the
// visible field shows "$1.250.000" while a paired hidden input keeps the
// plain digit string ("1250000") that actually gets submitted to the
// server, matching the AMOUNT_RE contract in app/blueprints/banking/routes.py.
(function () {
  function toDigits(value) {
    return value.replace(/\D/g, "").replace(/^0+(?=\d)/, "");
  }

  function toDisplay(digits) {
    if (!digits) return "";
    return "$" + digits.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  }

  function wire(display) {
    var target = document.getElementById(display.dataset.clpTarget);
    if (!target) return;

    function sync() {
      var digits = toDigits(display.value);
      display.value = toDisplay(digits);
      target.value = digits;
    }

    display.addEventListener("input", sync);
    sync();
  }

  document.querySelectorAll("[data-clp-amount]").forEach(wire);
})();
