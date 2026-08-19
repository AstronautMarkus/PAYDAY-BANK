"""Legacy bank frontend web app (Flask).

All business logic and data live in COBOL (bank_api.cbl, compiled as the
`bank_api` binary). This app only renders HTML and translates HTTP requests
into calls to the binary via subprocess, parsing the output line printed by
the COBOL program.
"""
import re
import subprocess
from pathlib import Path

from flask import Flask, flash, redirect, render_template, request, url_for

BASE_DIR = Path(__file__).resolve().parent
BANK_API = BASE_DIR / "bank_api"

app = Flask(__name__)
app.secret_key = "dev-only-secret-change-me"

ACCOUNT_RE = re.compile(r"^\d{1,6}$")
AMOUNT_RE = re.compile(r"^\d+(\.\d{1,2})?$")


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


def list_accounts():
    accounts = []
    for line in call_cobol("LIST"):
        parts = line.split("|")
        if parts[0] == "ROW" and len(parts) == 4:
            accounts.append(
                {"account": parts[1], "name": parts[2], "balance": parts[3]}
            )
    return accounts


@app.route("/")
def index():
    return render_template("index.html", accounts=list_accounts())


@app.route("/register", methods=["POST"])
def register():
    account = request.form.get("account", "").strip()
    name = request.form.get("name", "").strip()

    if not ACCOUNT_RE.match(account):
        flash("Numero de cuenta invalido (hasta 6 digitos).", "error")
    elif not name:
        flash("El nombre del titular es obligatorio.", "error")
    else:
        line = call_cobol("REGISTER", account, name)
        report(line)
    return redirect(url_for("index"))


@app.route("/deposit", methods=["POST"])
def deposit():
    return move_money("DEPOSIT")


@app.route("/withdraw", methods=["POST"])
def withdraw():
    return move_money("WITHDRAW")


def move_money(operation: str):
    account = request.form.get("account", "").strip()
    amount = request.form.get("amount", "").strip()

    if not ACCOUNT_RE.match(account):
        flash("Numero de cuenta invalido.", "error")
    elif not AMOUNT_RE.match(amount):
        flash("Monto invalido.", "error")
    else:
        line = call_cobol(operation, account, amount)
        report(line, prefix="Nuevo saldo: ")
    return redirect(url_for("index"))


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
            "  cobc -x bank_api.cbl -o bank_api"
        )
    app.run(debug=True, port=5005)
