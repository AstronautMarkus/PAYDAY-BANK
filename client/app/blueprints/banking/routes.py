import re

from flask import abort, flash, g, redirect, render_template, request, session, url_for

from app.blueprints.auth import login_required
from app.formatting import format_usd
from app.mainframe import (
    call_cobol,
    flash_result,
    generate_account,
    generate_card,
    list_customer_accounts,
    list_customer_cards,
    list_statement,
)

from . import bp

# USD amounts are whole dollars: a positive integer, no leading zero, no
# decimal point, sized to fit the core's PIC 9(12) COMP-3 balance field.
AMOUNT_RE = re.compile(r"^[1-9]\d{0,11}$")
ACCOUNT_RE = re.compile(r"^\d{6}$")
CARD_RE = re.compile(r"^\d{16}$")
CVV_RE = re.compile(r"^\d{3}$")
# Merchant ends up in the ledger's 40-char description, which STATEMENT
# prints "|"-separated -- so no "|" (or anything exotic) allowed.
MERCHANT_RE = re.compile(r"^[A-Za-z0-9 .,&'-]{1,40}$")

# FD-ACCOUNT-TYPE values (core/src/copybooks/account-record.cpy) -> label.
ACCOUNT_TYPES = {"CHECKING": "Checking Account", "SAVINGS": "Savings Account"}
# CD-CARD-TYPE values (core/src/copybooks/card-record.cpy) -> label.
CARD_TYPES = {"DEBIT": "Debit Card", "CREDIT": "Credit Card"}
# Per-payment card limits offered when issuing (CD-TX-LIMIT).
CARD_LIMITS = ("500", "1000", "5000", "10000")

ACCOUNT_ACTIONS = {"freeze": "BLOCKACCT", "unfreeze": "UNBLOCKACCT", "close": "CLOSEACCT"}
CARD_ACTIONS = {"block": "BLOCKCARD", "unblock": "UNBLOCKCARD"}

# TX-TYPE (core/src/copybooks/transaction-record.cpy) -> (label, sign).
TX_TYPES = {
    "OPEN": ("Account opened", 0),
    "DEPOSIT": ("Deposit", 1),
    "WITHDRAW": ("Withdrawal", -1),
    "TRANSFER-OUT": ("Transfer to own account", -1),
    "TRANSFER-IN": ("Transfer from own account", 1),
    "P2P-OUT": ("Sent to", -1),
    "P2P-IN": ("Received from", 1),
    "CARD-PAY": ("Card payment", -1),
}


@bp.route("/")
def index():
    if g.user:
        return redirect(url_for("banking.dashboard"))
    return render_template("public/landing.html")


@bp.route("/<any(products, security, help):page>")
def info(page):
    """Static public pages (public/products.html, security.html, help.html)."""
    return render_template(f"public/{page}.html", account_types=ACCOUNT_TYPES, card_types=CARD_TYPES)


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


@bp.route("/accounts")
@login_required
def accounts():
    return render_template(
        "banking/accounts.html", accounts=list_customer_accounts(g.user.customer_id),
        account_types=ACCOUNT_TYPES,
    )


@bp.route("/accounts/open", methods=["POST"])
@login_required
def open_account():
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
        flash_result(line)
    return redirect(url_for("banking.accounts"))


@bp.route("/accounts/<account>/<any(freeze, unfreeze, close):action>", methods=["POST"])
@login_required
def account_action(account, action):
    # Ownership, current status and the zero-balance rule for closing are
    # all enforced by the core (op_blockacct/op_unblockacct/op_closeacct).
    if not ACCOUNT_RE.match(account):
        abort(404)
    flash_result(call_cobol(ACCOUNT_ACTIONS[action], g.user.customer_id, account))
    return redirect(url_for("banking.accounts"))


@bp.route("/accounts/<account>/statement")
@login_required
def statement(account):
    accounts = list_customer_accounts(g.user.customer_id)
    current = next((item for item in accounts if item["account"] == account), None)
    if current is None:
        abort(404)
    rows = list_statement(g.user.customer_id, account)
    rows.reverse()  # newest first
    return render_template(
        "banking/statement.html", account=current, accounts=accounts, rows=rows,
        account_types=ACCOUNT_TYPES, tx_types=TX_TYPES,
    )


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


@bp.route("/transfer/external", methods=["POST"])
@login_required
def transfer_p2p():
    from_account = request.form.get("from_account", "").strip()
    to_account = request.form.get("to_account", "").strip()
    amount = request.form.get("amount", "").strip()
    owned_accounts = {item["account"] for item in list_customer_accounts(g.user.customer_id)}

    if from_account not in owned_accounts:
        flash("Invalid account.", "error")
    elif not ACCOUNT_RE.match(to_account):
        flash("Destination must be a 6-digit account number.", "error")
    elif not AMOUNT_RE.match(amount):
        flash("Invalid amount. Enter a whole dollar amount, no decimals.", "error")
    else:
        # The core never reveals the destination's balance (it may belong
        # to someone else), so OK carries only the source balance.
        line = call_cobol("TRANSFER-P2P", g.user.customer_id, from_account, to_account, amount)
        flash_result(line, prefix="Sent. New balance: $", formatter=format_usd)
        if line and line[0].startswith("OK|"):
            return redirect(url_for("banking.dashboard"))
    return redirect(url_for("banking.transfer"))


def format_transfer_balances(rest: str) -> str:
    """TRANSFER's OK payload is "<from-balance>|<to-balance>" -- flash_result
    only splits the leading OK|/ERR| marker, so this formats both halves.
    """
    return " / ".join(format_usd(part) for part in rest.split("|"))


@bp.route("/cards")
@login_required
def cards():
    return render_template(
        "banking/cards.html", cards=list_customer_cards(g.user.customer_id),
        accounts=list_customer_accounts(g.user.customer_id), account_types=ACCOUNT_TYPES,
        card_types=CARD_TYPES, card_limits=CARD_LIMITS,
        # Set by issue_card() for exactly one render: the CVV is never
        # retrievable again (CARDS doesn't return it).
        new_card=session.pop("new_card", None),
    )


@bp.route("/cards/issue", methods=["POST"])
@login_required
def issue_card():
    account = request.form.get("account", "").strip()
    card_type = request.form.get("card_type", "").strip().upper()
    limit = request.form.get("limit", "").strip()
    owned_accounts = {item["account"] for item in list_customer_accounts(g.user.customer_id)}

    if account not in owned_accounts:
        flash("Invalid account.", "error")
    elif card_type not in CARD_TYPES:
        flash("Invalid card type.", "error")
    elif limit not in CARD_LIMITS:
        flash("Invalid spending limit.", "error")
    else:
        number, cvv, expiry = generate_card()
        line = call_cobol("ISSUECARD", g.user.customer_id, account, number, card_type, cvv, expiry, limit)
        if line and line[0].startswith("OK|"):
            # shortcut: the signed (not encrypted) session cookie carries
            # the CVV for one redirect; move to server-side storage if this
            # ever handles real cards.
            session["new_card"] = {"number": number, "cvv": cvv}
        flash_result(line)
    return redirect(url_for("banking.cards"))


@bp.route("/cards/<card>/<any(block, unblock):action>", methods=["POST"])
@login_required
def card_action(card, action):
    # Ownership and current status are enforced by op_blockcard/op_unblockcard.
    if not CARD_RE.match(card):
        abort(404)
    flash_result(call_cobol(CARD_ACTIONS[action], g.user.customer_id, card))
    return redirect(url_for("banking.cards"))


@bp.route("/cards/pay", methods=["GET", "POST"])
@login_required
def card_payment():
    cards = list_customer_cards(g.user.customer_id)

    if request.method == "POST":
        card = request.form.get("card", "").strip()
        cvv = request.form.get("cvv", "").strip()
        merchant = request.form.get("merchant", "").strip()
        amount = request.form.get("amount", "").strip()

        if card not in {item["number"] for item in cards}:
            flash("Invalid card.", "error")
        elif not CVV_RE.match(cvv):
            flash("The CVV is the 3-digit code shown when the card was issued.", "error")
        elif not MERCHANT_RE.match(merchant):
            flash("Merchant: up to 40 letters, numbers, spaces and . , & ' -", "error")
        elif not AMOUNT_RE.match(amount):
            flash("Invalid amount. Enter a whole dollar amount, no decimals.", "error")
        else:
            # CARDPAYMENT authenticates by card + CVV only, like a real
            # checkout; the core checks status, expiry, CVV, limit and funds.
            line = call_cobol("CARDPAYMENT", card, cvv, merchant, amount)
            flash_result(line, prefix="Payment approved. Account balance: $", formatter=format_usd)
            if line and line[0].startswith("OK|"):
                return redirect(url_for("banking.cards"))

    return render_template("banking/card_payment.html", cards=cards, card_types=CARD_TYPES)
