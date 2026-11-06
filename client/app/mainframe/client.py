"""Thin subprocess client around the compiled bank_api binary.

The COBOL core owns every banking decision (customer/account IDs,
balances, profiles, ownership). This module only knows how to invoke it
and parse its line-oriented stdout contract:

    OK|...      successful operation
    ERR|message failed operation
    ROW|...     one row per item (ACCOUNTS, STATEMENT, CARDS)
    END          marks the end of a ROW listing
"""
import secrets
import subprocess
from datetime import date

from flask import current_app, flash


def call_cobol(*args: str) -> list[str]:
    """Run the mainframe binary and return its stdout lines."""
    config = current_app.config
    result = subprocess.run(
        [str(config["MAINFRAME_BIN"]), *args],
        cwd=config["MAINFRAME_DATA_DIR"],
        capture_output=True,
        text=True,
        timeout=config["MAINFRAME_TIMEOUT"],
        check=False,
    )
    return result.stdout.splitlines()


def account_digit(body: str) -> str:
    """Luhn check digit used for generated account numbers."""
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
    raise RuntimeError("No account numbers available")


def customer_exists(customer_id: str) -> bool:
    lines = call_cobol("CUSTEXISTS", customer_id)
    return bool(lines and lines[0].startswith("OK|"))


def generate_customer_id() -> str:
    """Same Luhn-checked generation scheme as generate_account(), with a
    distinct "77" entity prefix so customer IDs and account numbers are
    visually distinguishable even though they live in separate keyspaces.
    """
    for _ in range(50):
        body = f"77{secrets.randbelow(1000):03d}"
        candidate = body + account_digit(body)
        if not customer_exists(candidate):
            return candidate
    raise RuntimeError("No customer numbers available")


def flash_result(lines: list[str], prefix: str = "", formatter=None) -> None:
    """Turn a call_cobol() response into a Spanish flash message.

    `formatter`, if given, is applied to the OK payload before it is shown
    (e.g. to render a raw peso amount with thousands separators).
    """
    if not lines:
        flash("The COBOL backend did not respond.", "error")
        return
    status, _, rest = lines[0].partition("|")
    if status == "OK":
        text = formatter(rest) if formatter and rest else rest
        flash(f"{prefix}{text}" if prefix else text or "Operation successful.", "ok")
    else:
        flash(rest or "Unknown error.", "error")


def list_rows(fields: tuple[str, ...], *args: str) -> list[dict[str, str]]:
    """Run a ROW-listing operation and map each ROW line onto `fields`.
    Lines of the wrong width (and ERR/END) are skipped.
    """
    rows = []
    for line in call_cobol(*args):
        parts = line.split("|")
        if parts[0] == "ROW" and len(parts) == len(fields) + 1:
            rows.append(dict(zip(fields, parts[1:])))
    return rows


def list_customer_accounts(customer_id: str) -> list[dict[str, str]]:
    """List every account owned by one customer (dashboard "my accounts"),
    with its lifecycle status (ACTIVE/FROZEN/CLOSED).

    Profile fields (name, document, etc.) aren't part of this response --
    the caller already has them from the logged-in User row.
    """
    return list_rows(("account", "type", "balance", "status"), "ACCOUNTS", customer_id)


def list_statement(customer_id: str, account: str) -> list[dict[str, str]]:
    """Ledger rows of one account, oldest first (see op_statement.cbl)."""
    fields = ("id", "type", "amount", "balance", "counterparty", "description", "datetime")
    return list_rows(fields, "STATEMENT", customer_id, account)


def list_customer_cards(customer_id: str) -> list[dict[str, str]]:
    """Cards owned by one customer; CARDS never returns CVV or limit."""
    return list_rows(("number", "account", "type", "status", "expiry"), "CARDS", customer_id)


def generate_card() -> tuple[str, str, str]:
    """New (card number, CVV, expiry YYMM) for ISSUECARD. The core enforces
    card-number uniqueness; a 1-in-10^14 collision just fails the issue.
    """
    body = "4" + "".join(str(secrets.randbelow(10)) for _ in range(14))
    today = date.today()
    expiry = f"{(today.year + 4) % 100:02d}{today.month:02d}"
    return body + account_digit(body), f"{secrets.randbelow(1000):03d}", expiry
