"""Thin subprocess client around the compiled bank_api binary.

The COBOL core owns every banking decision (account numbers, balances,
profiles). This module only knows how to invoke it and parse its
line-oriented stdout contract:

    OK|...      successful operation
    ERR|message failed operation
    ROW|account|name|balance|profile-data  (LIST only)
    END          marks the end of the LIST output
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
    raise RuntimeError("No hay números de cuenta disponibles")


def flash_result(lines: list[str], prefix: str = "") -> None:
    """Turn a call_cobol() response into a Spanish flash message."""
    if not lines:
        flash("El backend COBOL no respondió.", "error")
        return
    status, _, rest = lines[0].partition("|")
    if status == "OK":
        flash(f"{prefix}{rest}" if prefix else rest or "Operación exitosa.", "ok")
    else:
        flash(rest or "Error desconocido.", "error")


def list_accounts() -> list[dict[str, str]]:
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
