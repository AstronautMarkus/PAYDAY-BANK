import re

from flask import flash, g, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash

from app.mainframe import call_cobol, flash_result, generate_account, generate_customer_id

from . import bp

# Kept in sync by hand with static/js/register-validate.js, which mirrors
# these same rules on the client for instant feedback. This module stays
# the source of truth -- the client-side copy never replaces this check.
DOCUMENT_RE = re.compile(r"^[A-Za-z0-9-]{5,20}$")
EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
PHONE_RE = re.compile(r"^[+0-9 ()-]{7,20}$")
PASSWORD_RE = re.compile(r"^(?=.*[A-Za-z])(?=.*\d).{8,72}$")
NUMERIC_ID_RE = re.compile(r"^\d{6}$")


def validate_registration(form) -> dict[str, str]:
    """Validate every registration field and return one error per invalid
    field, keyed by input name, instead of stopping at the first problem.
    """
    errors: dict[str, str] = {}

    if not form.get("name", "").strip() or len(form["name"].strip()) > 30:
        errors["name"] = "Full name is required, up to 30 characters."
    if not DOCUMENT_RE.match(form.get("document", "").strip()):
        errors["document"] = "ID number must be 5 to 20 alphanumeric characters."
    if not EMAIL_RE.match(form.get("email", "").strip().lower()) or len(form.get("email", "")) > 60:
        errors["email"] = "Enter a valid email address."
    if not PHONE_RE.match(form.get("phone", "").strip()):
        errors["phone"] = "Enter a valid phone number."
    if not form.get("address", "").strip() or len(form["address"].strip()) > 80:
        errors["address"] = "Address is required, up to 80 characters."
    if not form.get("occupation", "").strip() or len(form["occupation"].strip()) > 40:
        errors["occupation"] = "Occupation is required, up to 40 characters."
    if not form.get("employer", "").strip() or len(form["employer"].strip()) > 50:
        errors["employer"] = "Employer is required, up to 50 characters."
    if not PASSWORD_RE.match(form.get("password", "")):
        errors["password"] = "Password must be at least 8 characters with a letter and a number."
    elif form.get("password", "") != form.get("password_confirmation", ""):
        errors["password_confirmation"] = "Passwords do not match."

    return errors


@bp.route("/login", methods=["GET", "POST"])
def login():
    if g.user:
        return redirect(url_for("banking.dashboard"))
    if request.method == "POST":
        email = request.form.get("email", "").strip().lower()
        password = request.form.get("password", "")
        lines = call_cobol("LOGIN", email)
        parts = lines[0].split("|") if lines else []
        if len(parts) != 3 or parts[0] != "OK" or not check_password_hash(parts[2], password):
            flash("Incorrect email or password.", "error")
        else:
            session.clear()
            session["customer_id"] = parts[1]
            return redirect(url_for("banking.dashboard"))
    return render_template("public/landing.html", open_modal="login")


@bp.route("/logout", methods=["POST"])
def logout():
    session.clear()
    flash("You have been signed out.", "ok")
    return redirect(url_for("auth.login"))


@bp.route("/register", methods=["GET", "POST"])
def register():
    if g.user:
        return redirect(url_for("banking.dashboard"))

    if request.method == "GET":
        return render_template("auth/register.html", values={}, errors={})

    errors = validate_registration(request.form)
    if not errors:
        name = request.form["name"].strip()
        document = request.form["document"].strip()
        email = request.form["email"].strip().lower()
        phone = request.form["phone"].strip()
        address = request.form["address"].strip()
        occupation = request.form["occupation"].strip()
        employer = request.form["employer"].strip()
        password = request.form["password"]

        try:
            customer_id = generate_customer_id()
            account = generate_account()
            line = call_cobol(
                "REGISTER", customer_id, account, name, document, email, phone,
                address, occupation, employer, generate_password_hash(password),
            )
        except (OSError, RuntimeError):
            line = []
        if line and line[0].startswith("OK|"):
            return redirect(url_for("auth.register_success", customer=customer_id, account=account))
        flash_result(line)
        return render_template("auth/register.html", values=request.form, errors={})

    flash("Please fix the highlighted fields and try again.", "error")
    return render_template("auth/register.html", values=request.form, errors=errors)


@bp.route("/register/success")
def register_success():
    customer_id = request.args.get("customer", "")
    account = request.args.get("account", "")
    if not NUMERIC_ID_RE.match(customer_id) or not NUMERIC_ID_RE.match(account):
        return redirect(url_for("auth.register"))
    return render_template("auth/register_success.html", customer_id=customer_id, account=account)
