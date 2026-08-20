import re

from flask import flash, g, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash

from app.extensions import db
from app.mainframe import call_cobol, flash_result, generate_account, generate_customer_id
from app.models import User

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
        user = db.session.execute(
            db.select(User).filter_by(email=email)
        ).scalar_one_or_none()
        if user is None or not check_password_hash(user.password_hash, password):
            flash("Correo o contraseña incorrectos.", "error")
        else:
            session.clear()
            session["user_id"] = user.id
            return redirect(url_for("banking.dashboard"))
    return render_template("login.html")


@bp.route("/logout", methods=["POST"])
def logout():
    session.clear()
    flash("Sesión cerrada correctamente.", "ok")
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
        return render_template("register.html")

    if not name or len(name) > 30:
        flash("El nombre del titular es obligatorio y admite hasta 30 caracteres.", "error")
    elif not DOCUMENT_RE.match(document):
        flash("El documento debe tener entre 5 y 20 caracteres alfanuméricos.", "error")
    elif not EMAIL_RE.match(email) or len(email) > 60:
        flash("Introduce un correo electrónico válido.", "error")
    elif not PHONE_RE.match(phone):
        flash("Introduce un teléfono válido.", "error")
    elif not address or len(address) > 80:
        flash("El domicilio es obligatorio y admite hasta 80 caracteres.", "error")
    elif not occupation or len(occupation) > 40:
        flash("La ocupación es obligatoria y admite hasta 40 caracteres.", "error")
    elif not employer or len(employer) > 50:
        flash("La empresa o actividad es obligatoria y admite hasta 50 caracteres.", "error")
    elif not PASSWORD_RE.match(password):
        flash("La contraseña debe tener 8 caracteres, una letra y un número.", "error")
    elif password != password_confirmation:
        flash("Las contraseñas no coinciden.", "error")
    else:
        duplicate = db.session.execute(
            db.select(User).where((User.email == email) | (User.document == document))
        ).scalar_one_or_none()
        if duplicate:
            flash("Ya existe un cliente con ese correo o documento.", "error")
        else:
            try:
                customer_id = generate_customer_id()
                account = generate_account()
                line = call_cobol(
                    "REGISTER", customer_id, account, name, document, email, phone,
                    address, occupation, employer,
                )
            except (OSError, RuntimeError):
                line = []
            if line and line[0].startswith("OK|"):
                db.session.add(
                    User(
                        name=name, document=document, email=email, phone=phone,
                        address=address, occupation=occupation, employer=employer,
                        customer_id=customer_id, password_hash=generate_password_hash(password),
                    )
                )
                db.session.commit()
                flash(
                    "Cliente creado. Tu número de cliente es " + customer_id
                    + " y tu cuenta corriente es " + account + ".",
                    "ok",
                )
                return redirect(url_for("auth.login"))
            flash_result(line)
    return render_template("register.html")
