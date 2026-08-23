// Wires up "Copy" buttons: click copies the text content of the element
// named in data-copy to the clipboard and shows a brief confirmation.
document.querySelectorAll("[data-copy]").forEach(function (btn) {
  btn.addEventListener("click", function () {
    var text = document.getElementById(btn.dataset.copy).textContent.trim();
    navigator.clipboard.writeText(text).then(function () {
      var original = btn.innerHTML;
      btn.innerHTML = '<i class="fa-solid fa-check"></i> Copied';
      btn.classList.add("copied");
      setTimeout(function () {
        btn.innerHTML = original;
        btn.classList.remove("copied");
      }, 1500);
    });
  });
});
