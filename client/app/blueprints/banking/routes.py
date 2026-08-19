import re

from flask import flash, g, redirect, render_template, request, url_for

from app.blueprints.auth import login_required
from app.mainframe import call_cobol, flash_result, list_accounts

from . import bp

AMOUNT_RE = re.compile(r"^\d+(\.\d{1,2})?$")


@bp.route("/")
def index():
    return redirect(url_for("banking.dashboard" if g.user else "auth.login"))


@bp.route("/dashboard")
@login_required
def dashboard():
    account = next(
        (item for item in list_accounts() if item["account"] == g.user.account),
        {
            "account": g.user.account,
            "name": g.user.name,
            "balance": "000000000.00",
            "document": g.user.document,
            "email": g.user.email,
            "phone": g.user.phone,
            "address": g.user.address,
            "occupation": g.user.occupation,
            "employer": g.user.employer,
        },
    )
    return render_template("dashboard.html", account=account)


@bp.route("/deposit", methods=["POST"])
@login_required
def deposit():
    return move_money("DEPOSIT")


@bp.route("/withdraw", methods=["POST"])
@login_required
def withdraw():
    return move_money("WITHDRAW")


def move_money(operation: str):
    account = g.user.account
    amount = request.form.get("amount", "").strip()

    if not AMOUNT_RE.match(amount):
        flash("Monto inválido.", "error")
    else:
        line = call_cobol(operation, account, amount)
        flash_result(line, prefix="Nuevo saldo: ")
    return redirect(url_for("banking.dashboard"))
