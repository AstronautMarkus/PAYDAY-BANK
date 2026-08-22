// Client-side companion to the registration wizard. Mirrors the field
// rules enforced server-side in app/blueprints/auth/routes.py
// (validate_registration) so users get instant feedback -- the server
// re-validates everything on submit and remains the source of truth.
(function () {
  var RULES = {
    name: { re: /^.{1,30}$/, message: "Full name is required, up to 30 characters." },
    document: { re: /^[A-Za-z0-9-]{5,20}$/, message: "ID number must be 5 to 20 alphanumeric characters." },
    email: { re: /^[^\s@]+@[^\s@]+\.[^\s@]+$/, maxLength: 60, message: "Enter a valid email address." },
    phone: { re: /^[+0-9 ()-]{7,20}$/, message: "Enter a valid phone number." },
    address: { re: /^.{1,80}$/, message: "Address is required, up to 80 characters." },
    occupation: { re: /^.{1,40}$/, message: "Occupation is required, up to 40 characters." },
    employer: { re: /^.{1,50}$/, message: "Employer is required, up to 50 characters." },
    password: {
      re: /^(?=.*[A-Za-z])(?=.*\d).{8,72}$/,
      message: "Password must be at least 8 characters with a letter and a number.",
    },
    password_confirmation: { message: "Passwords do not match." },
  };

  var form = document.getElementById("register-form");
  if (!form) return;

  var steps = Array.prototype.slice.call(form.querySelectorAll(".wizard-step"));
  var stepperItems = Array.prototype.slice.call(document.querySelectorAll("#wizard-stepper .stepper-item"));
  var btnPrev = document.getElementById("btn-prev");
  var btnNext = document.getElementById("btn-next");
  var btnSubmit = document.getElementById("btn-submit");
  var current = steps.findIndex(function (step) { return step.hasAttribute("data-has-error"); });
  if (current < 0) current = 0;

  function fieldsIn(step) {
    return Array.prototype.slice.call(step.querySelectorAll("[data-validate]"));
  }

  function validateField(input) {
    var name = input.dataset.validate;
    var rule = RULES[name];
    var wrapper = input.closest(".ui-input-wrapper");
    var msg = form.querySelector('[data-msg-for="' + name + '"]');
    var value = input.value.trim();
    var ok = true;
    var text = "";

    if (name === "password_confirmation") {
      var password = document.getElementById("reg-password").value;
      ok = value.length > 0 && value === password;
      text = ok ? "" : rule.message;
    } else if (!value) {
      ok = false;
      text = rule.message;
    } else if (rule.re && !rule.re.test(value)) {
      ok = false;
      text = rule.message;
    } else if (rule.maxLength && value.length > rule.maxLength) {
      ok = false;
      text = rule.message;
    }

    if (wrapper) {
      wrapper.classList.toggle("has-error", !ok);
      wrapper.classList.toggle("has-ok", ok);
    }
    if (msg) {
      msg.textContent = text;
      msg.className = "field-msg" + (ok ? "" : " error");
    }
    return ok;
  }

  function validateStep(index) {
    return fieldsIn(steps[index]).map(validateField).every(Boolean);
  }

  function updateReviewSummary() {
    var box = document.getElementById("review-summary");
    if (!box) return;
    var rows = [
      ["Name", "reg-name"],
      ["ID Number", "reg-document"],
      ["Email", "reg-email"],
      ["Phone", "reg-phone"],
      ["Address", "reg-address"],
      ["Occupation", "reg-occupation"],
      ["Employer", "reg-employer"],
    ];
    box.innerHTML = rows
      .map(function (row) {
        var el = document.getElementById(row[1]);
        var value = el && el.value.trim() ? el.value.trim() : "—";
        return '<div class="review-row"><span>' + row[0] + "</span><span>" +
          value.replace(/</g, "&lt;") + "</span></div>";
      })
      .join("");
  }

  function showStep(index) {
    steps.forEach(function (step, i) { step.classList.toggle("active", i === index); });
    stepperItems.forEach(function (item, i) {
      item.classList.toggle("active", i === index);
      item.classList.toggle("done", i < index);
    });
    btnPrev.style.visibility = index === 0 ? "hidden" : "visible";
    btnNext.style.display = index === steps.length - 1 ? "none" : "inline-flex";
    btnSubmit.style.display = index === steps.length - 1 ? "inline-flex" : "none";
    if (index === steps.length - 1) updateReviewSummary();
    current = index;
  }

  btnNext.addEventListener("click", function () {
    if (!validateStep(current)) {
      var firstInvalid = fieldsIn(steps[current]).find(function (input) {
        return input.closest(".ui-input-wrapper").classList.contains("has-error");
      });
      if (firstInvalid) firstInvalid.focus();
      return;
    }
    if (current < steps.length - 1) showStep(current + 1);
  });

  btnPrev.addEventListener("click", function () {
    if (current > 0) showStep(current - 1);
  });

  steps.forEach(function (step) {
    fieldsIn(step).forEach(function (input) {
      input.addEventListener("blur", function () { validateField(input); });
      input.addEventListener("input", function () {
        if (input.closest(".ui-input-wrapper").classList.contains("has-error")) validateField(input);
        if (input.id === "reg-password") {
          updateStrength(input.value);
          var confirmation = document.getElementById("reg-password-confirmation");
          if (confirmation.value) validateField(confirmation);
        }
      });
    });
  });

  form.addEventListener("submit", function (event) {
    var allValid = steps.every(function (_, i) { return validateStep(i); });
    if (!allValid) {
      event.preventDefault();
      var firstBadStep = steps.findIndex(function (step) {
        return fieldsIn(step).some(function (input) {
          return input.closest(".ui-input-wrapper").classList.contains("has-error");
        });
      });
      if (firstBadStep >= 0) showStep(firstBadStep);
    }
  });

  document.querySelectorAll(".toggle-visibility").forEach(function (btn) {
    btn.addEventListener("click", function () {
      var input = document.getElementById(btn.dataset.toggleFor);
      var showing = input.type === "text";
      input.type = showing ? "password" : "text";
      btn.querySelector("i").className = showing ? "fa-solid fa-eye" : "fa-solid fa-eye-slash";
    });
  });

  function updateStrength(value) {
    var fill = document.getElementById("strength-fill");
    var label = document.getElementById("strength-label");
    if (!fill || !label) return;

    var score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (/[a-z]/.test(value) && /[A-Z]/.test(value)) score++;
    if (/\d/.test(value)) score++;
    if (/[^A-Za-z0-9]/.test(value)) score++;

    var levels = [
      { pct: 0, color: "#dee2e6", text: " " },
      { pct: 25, color: "#c0392b", text: "Weak" },
      { pct: 50, color: "#e67e22", text: "Fair" },
      { pct: 75, color: "#f1c40f", text: "Good" },
      { pct: 100, color: "#27ae60", text: "Strong" },
    ];
    var level = levels[Math.min(score, 4)];
    fill.style.width = level.pct + "%";
    fill.style.backgroundColor = level.color;
    label.textContent = value ? level.text : " ";
  }

  showStep(current);
})();
