"""Legacy bank frontend web app (Flask).

All business logic and data live in COBOL (bank_api.cbl, compiled as the
`bank_api` binary). This app only renders HTML and translates HTTP requests
into calls to the binary via subprocess, parsing the output line printed by
the COBOL program.
"""
import re
import secrets
import sqlite3
import subprocess
import os
from functools import wraps
from pathlib import Path

from flask import Flask, flash, g, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash

BASE_DIR = Path(__file__).resolve().parent
BANK_API = BASE_DIR / "bank_api"
USERS_DB = BASE_DIR / "bank_users.sqlite3"

app = Flask(__name__)
app.secret_key = os.environ.get("BANK_SECRET_KEY", "dev-only-secret-change-me")
app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax")

AMOUNT_RE = re.compile(r"^\d+(\.\d{1,2})?$")
DOCUMENT_RE = re.compile(r"^[A-Za-z0-9-]{5,20}$")
EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
PHONE_RE = re.compile(r"^[+0-9 ()-]{7,20}$")
PASSWORD_RE = re.compile(r"^(?=.*[A-Za-z])(?=.*\d).{8,72}$")


def call_cobol(*args: str) -> list[str]:
    """Run the COBOL binary and return its stdout lines."""
    result = subprocess.run(
        [str(BANK_API), *args],
        cwd=BASE_DIR,
        capture_output=True,
        text=True,
        timeout=10,
        check=False,
    )
    return result.stdout.splitlines()


def get_db():
    if "db" not in g:
        g.db = sqlite3.connect(USERS_DB)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(_error=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    db = sqlite3.connect(USERS_DB)
    db.execute(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            document TEXT NOT NULL UNIQUE,
            email TEXT NOT NULL UNIQUE,
            phone TEXT NOT NULL,
            address TEXT NOT NULL,
            occupation TEXT NOT NULL,
            employer TEXT NOT NULL,
            account TEXT NOT NULL UNIQUE,
            password_hash TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    db.commit()
    db.close()


init_db()


def login_required(view):
    @wraps(view)
    def wrapped_view(*args, **kwargs):
        if "user_id" not in session:
            flash("Inicia sesion para entrar al banco.", "error")
            return redirect(url_for("login"))
        return view(*args, **kwargs)

    return wrapped_view


@app.before_request
def load_logged_in_user():
    user_id = session.get("user_id")
    g.user = None if user_id is None else get_db().execute(
        "SELECT * FROM users WHERE id = ?", (user_id,)
    ).fetchone()
    if user_id is not None and g.user is None:
        session.clear()


@app.context_processor
def inject_user():
    return {"current_user": g.get("user")}


def account_digit(body: str) -> str:
    total = 0
    for index, digit in enumerate(reversed(body)):
        value = int(digit) * (2 if index % 2 == 0 else 1)
        total += value // 10 + value % 10
    return str((10 - total % 10) % 10)


def account_exists(account: str) -> bool:
    lines = call_cobol("BALANCE", account)
    return bool(lines and lines[0].startswith("OK|"))


def generate_account() -> str:
    for _ in range(50):
        body = f"42{secrets.randbelow(1000):03d}"
        candidate = body + account_digit(body)
        if not account_exists(candidate):
            return candidate
    raise RuntimeError("No hay numeros de cuenta disponibles")


def list_accounts():
    accounts = []
    for line in call_cobol("LIST"):
        parts = line.split("|")
        if parts[0] == "ROW" and len(parts) in (4, 10):
            profile = parts[4:] if len(parts) == 10 else ["", "", "", "", "", ""]
            accounts.append(
                {
                    "account": parts[1],
                    "name": parts[2],
                    "balance": parts[3],
                    "document": profile[0],
                    "email": profile[1],
                    "phone": profile[2],
                    "address": profile[3],
                    "occupation": profile[4],
                    "employer": profile[5],
                }
            )
    return accounts


@app.route("/")
def index():
    return redirect(url_for("dashboard" if g.user else "login"))


@app.route("/login", methods=["GET", "POST"])
def login():
    if g.user:
        return redirect(url_for("dashboard"))
    if request.method == "POST":
        email = request.form.get("email", "").strip().lower()
        password = request.form.get("password", "")
        user = get_db().execute(
            "SELECT * FROM users WHERE email = ?", (email,)
        ).fetchone()
        if user is None or not check_password_hash(user["password_hash"], password):
            flash("Correo o contrasena incorrectos.", "error")
        else:
            session.clear()
            session["user_id"] = user["id"]
            return redirect(url_for("dashboard"))
    return render_template("login.html")


@app.route("/logout", methods=["POST"])
def logout():
    session.clear()
    flash("Sesion cerrada correctamente.", "ok")
    return redirect(url_for("login"))


@app.route("/register", methods=["GET", "POST"])
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
        flash("El documento debe tener entre 5 y 20 caracteres alfanumericos.", "error")
    elif not EMAIL_RE.match(email) or len(email) > 60:
        flash("Introduce un correo electronico valido.", "error")
    elif not PHONE_RE.match(phone):
        flash("Introduce un telefono valido.", "error")
    elif not address or len(address) > 80:
        flash("El domicilio es obligatorio y admite hasta 80 caracteres.", "error")
    elif not occupation or len(occupation) > 40:
        flash("La ocupacion es obligatoria y admite hasta 40 caracteres.", "error")
    elif not employer or len(employer) > 50:
        flash("La empresa o actividad es obligatoria y admite hasta 50 caracteres.", "error")
    elif not PASSWORD_RE.match(password):
        flash("La contrasena debe tener 8 caracteres, una letra y un numero.", "error")
    elif password != password_confirmation:
        flash("Las contrasenas no coinciden.", "error")
    else:
        db = get_db()
        duplicate = db.execute(
            "SELECT 1 FROM users WHERE email = ? OR document = ?",
            (email, document),
        ).fetchone()
        if duplicate:
            flash("Ya existe un cliente con ese correo o documento.", "error")
        else:
            try:
                account = generate_account()
                line = call_cobol(
                    "REGISTER", account, name, document, email, phone, address,
                    occupation, employer,
                )
            except (OSError, RuntimeError):
                line = []
            if line and line[0].startswith("OK|"):
                db.execute(
                    """INSERT INTO users
                    (name, document, email, phone, address, occupation, employer,
                     account, password_hash)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    (
                        name, document, email, phone, address, occupation, employer,
                        account, generate_password_hash(password),
                    ),
                )
                db.commit()
                flash("Cliente creado. Tu numero de cuenta es " + account + ".", "ok")
                return redirect(url_for("login"))
            report(line)
    return render_template("register.html")


@app.route("/dashboard")
@login_required
def dashboard():
    account = next(
        (item for item in list_accounts() if item["account"] == g.user["account"]),
        {
            "account": g.user["account"],
            "name": g.user["name"],
            "balance": "000000000.00",
            "document": g.user["document"],
            "email": g.user["email"],
            "phone": g.user["phone"],
            "address": g.user["address"],
            "occupation": g.user["occupation"],
            "employer": g.user["employer"],
        },
    )
    return render_template("dashboard.html", account=account)


@app.route("/deposit", methods=["POST"])
@login_required
def deposit():
    return move_money("DEPOSIT")


@app.route("/withdraw", methods=["POST"])
@login_required
def withdraw():
    return move_money("WITHDRAW")


def move_money(operation: str):
    account = g.user["account"]
    amount = request.form.get("amount", "").strip()

    if not AMOUNT_RE.match(amount):
        flash("Monto invalido.", "error")
    else:
        line = call_cobol(operation, account, amount)
        report(line, prefix="Nuevo saldo: ")
    return redirect(url_for("dashboard"))


def report(lines: list[str], prefix: str = "") -> None:
    if not lines:
        flash("El backend COBOL no respondio.", "error")
        return
    status, _, rest = lines[0].partition("|")
    if status == "OK":
        flash(f"{prefix}{rest}" if prefix else rest or "Operacion exitosa.", "ok")
    else:
        flash(rest or "Error desconocido.", "error")


if __name__ == "__main__":
    if not BANK_API.exists():
        raise SystemExit(
            "bank_api not found. Compile it first with:\n"
            "  cobc -x -free bank_api.cbl -o bank_api"
        )
    app.run(debug=True, port=5005)
