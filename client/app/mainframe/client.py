"""Thin subprocess client around the compiled bank_api binary.

The COBOL core owns every banking decision (customer/account IDs,
balances, profiles, ownership). This module only knows how to invoke it
and parse its line-oriented stdout contract:

    OK|...      successful operation
    ERR|message failed operation
    ROW|...     one row per item (ACCOUNTS only, in this client)
    END          marks the end of a ROW listing
"""
import secrets
import subprocess

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


def list_customer_accounts(customer_id: str) -> list[dict[str, str]]:
    """List every account owned by one customer (dashboard "my accounts").

    Profile fields (name, document, etc.) aren't part of this response --
    the caller already has them from the logged-in User row.
    """
    accounts = []
    for line in call_cobol("ACCOUNTS", customer_id):
        parts = line.split("|")
        if parts[0] == "ROW" and len(parts) == 4:
            accounts.append({"account": parts[1], "type": parts[2], "balance": parts[3]})
    return accounts
