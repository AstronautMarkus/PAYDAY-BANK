import re

from flask import flash, g, redirect, render_template, request, url_for

from app.blueprints.auth import login_required
from app.formatting import format_usd
from app.mainframe import call_cobol, flash_result, generate_account, list_customer_accounts

from . import bp

# USD amounts are whole dollars: a positive integer, no leading zero, no
# decimal point, sized to fit the core's PIC 9(12) COMP-3 balance field.
AMOUNT_RE = re.compile(r"^[1-9]\d{0,11}$")

# FD-ACCOUNT-TYPE values (core/src/copybooks/account-record.cpy) -> label.
ACCOUNT_TYPES = {"CHECKING": "Checking Account", "SAVINGS": "Savings Account"}


@bp.route("/")
def index():
    if g.user:
        return redirect(url_for("banking.dashboard"))
    return render_template("public/landing.html")


@bp.route("/dashboard")
@login_required
def dashboard():
    accounts = list_customer_accounts(g.user.customer_id)
    total_balance = sum(int(item["balance"]) for item in accounts)
    type_counts = {}
    for item in accounts:
        type_counts[item["type"]] = type_counts.get(item["type"], 0) + 1
    type_summary = ", ".join(
        f"{count} {ACCOUNT_TYPES.get(acct_type, acct_type)}{'s' if count != 1 else ''}"
        for acct_type, count in type_counts.items()
    )
    return render_template(
        "banking/dashboard.html", accounts=accounts, account_types=ACCOUNT_TYPES,
        total_balance=total_balance, type_summary=type_summary,
    )


@bp.route("/deposit", methods=["POST"])
@login_required
def deposit():
    return move_money("DEPOSIT")


@bp.route("/withdraw", methods=["POST"])
@login_required
def withdraw():
    return move_money("WITHDRAW")


def move_money(operation: str):
    account = request.form.get("account", "").strip()
    amount = request.form.get("amount", "").strip()
    owned_accounts = {item["account"] for item in list_customer_accounts(g.user.customer_id)}

    if account not in owned_accounts:
        # The dashboard only ever offers the customer's own accounts in the
        # <select>, so this only fires on a tampered request -- the COBOL
        # core enforces the same ownership check regardless (see
        # core/src/ops/op_deposit.cbl / op_withdraw.cbl).
        flash("Invalid account.", "error")
    elif not AMOUNT_RE.match(amount):
        flash("Invalid amount. Enter a whole dollar amount, no decimals.", "error")
    else:
        line = call_cobol(operation, g.user.customer_id, account, amount)
        flash_result(line, prefix="New balance: $", formatter=format_usd)
    return redirect(url_for("banking.dashboard"))


@bp.route("/accounts/open", methods=["GET", "POST"])
@login_required
def open_account():
    if request.method == "POST":
        account_type = request.form.get("account_type", "").strip().upper()

        if account_type not in ACCOUNT_TYPES:
            flash("Invalid account type.", "error")
        else:
            try:
                account = generate_account()
                line = call_cobol(
                    "OPENACCT", g.user.customer_id, account, g.user.name, account_type
                )
            except RuntimeError:
                line = []
            if line and line[0].startswith("OK|"):
                flash_result(line)
                return redirect(url_for("banking.dashboard"))
            flash_result(line)
    return render_template("banking/open_account.html", account_types=ACCOUNT_TYPES)


@bp.route("/transfer", methods=["GET", "POST"])
@login_required
def transfer():
    accounts = list_customer_accounts(g.user.customer_id)

    if request.method == "POST":
        from_account = request.form.get("from_account", "").strip()
        to_account = request.form.get("to_account", "").strip()
        amount = request.form.get("amount", "").strip()
        owned_accounts = {item["account"] for item in accounts}

        if from_account not in owned_accounts or to_account not in owned_accounts:
            # Same reasoning as move_money(): a UI-only guard, the COBOL
            # core re-checks ownership of both accounts (op_transfer.cbl).
            flash("Invalid account.", "error")
        elif from_account == to_account:
            flash("Source and destination accounts must be different.", "error")
        elif not AMOUNT_RE.match(amount):
            flash("Invalid amount. Enter a whole dollar amount, no decimals.", "error")
        else:
            line = call_cobol("TRANSFER", g.user.customer_id, from_account, to_account, amount)
            flash_result(line, prefix="New balances: $", formatter=format_transfer_balances)
            if line and line[0].startswith("OK|"):
                return redirect(url_for("banking.dashboard"))

    return render_template("banking/transfer.html", accounts=accounts, account_types=ACCOUNT_TYPES)


def format_transfer_balances(rest: str) -> str:
    """TRANSFER's OK payload is "<from-balance>|<to-balance>" -- flash_result
    only splits the leading OK|/ERR| marker, so this formats both halves.
    """
    return " / ".join(format_usd(part) for part in rest.split("|"))
