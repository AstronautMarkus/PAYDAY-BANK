import re

from flask import flash, g, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash

from app.mainframe import call_cobol, flash_result, generate_account, generate_customer_id

from . import bp

DOCUMENT_RE = re.compile(r"^[A-Za-z0-9-]{5,20}$")
EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
PHONE_RE = re.compile(r"^[+0-9 ()-]{7,20}$")
PASSWORD_RE = re.compile(r"^(?=.*[A-Za-z])(?=.*\d).{8,72}$")


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
    return render_template("public.html", open_modal="login")


@bp.route("/logout", methods=["POST"])
def logout():
    session.clear()
    flash("You have been signed out.", "ok")
    return redirect(url_for("auth.login"))


@bp.route("/register", methods=["GET", "POST"])
def register():
    name = request.form.get("name", "").strip()
    document = request.form.get("document", "").strip()
    email = request.form.get("email", "").strip().lower()
    phone = request.form.get("phone", "").strip()
    address = request.form.get("address", "").strip()
    occupation = request.form.get("occupation", "").strip()
    employer = request.form.get("employer", "").strip()
    password = request.form.get("password", "")
    password_confirmation = request.form.get("password_confirmation", "")

    if request.method == "GET":
        return render_template("public.html", open_modal="register")

    if not name or len(name) > 30:
        flash("Full name is required, up to 30 characters.", "error")
    elif not DOCUMENT_RE.match(document):
        flash("ID number must be 5 to 20 alphanumeric characters.", "error")
    elif not EMAIL_RE.match(email) or len(email) > 60:
        flash("Enter a valid email address.", "error")
    elif not PHONE_RE.match(phone):
        flash("Enter a valid phone number.", "error")
    elif not address or len(address) > 80:
        flash("Address is required, up to 80 characters.", "error")
    elif not occupation or len(occupation) > 40:
        flash("Occupation is required, up to 40 characters.", "error")
    elif not employer or len(employer) > 50:
        flash("Employer is required, up to 50 characters.", "error")
    elif not PASSWORD_RE.match(password):
        flash("Password must be at least 8 characters with a letter and a number.", "error")
    elif password != password_confirmation:
        flash("Passwords do not match.", "error")
    else:
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
            flash(
                "Account created. Your customer number is " + customer_id
                + " and your checking account number is " + account + ".",
                "ok",
            )
            return redirect(url_for("auth.login"))
        flash_result(line)
    return render_template("public.html", open_modal="register")
