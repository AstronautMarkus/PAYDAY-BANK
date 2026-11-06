"""Presentation helpers for USD amounts and display names.

Every amount coming out of the core is a whole number of dollars (no minor
currency unit tracked), formatted here with "," as the thousands separator
(1234567 -> "1,234,567").
"""


def format_usd(amount) -> str:
    try:
        value = int(str(amount).strip())
    except (TypeError, ValueError):
        return str(amount)
    return f"{value:,}"


def initials(name: str) -> str:
    parts = name.split()
    if not parts:
        return ""
    if len(parts) == 1:
        return parts[0][:2].upper()
    return (parts[0][0] + parts[-1][0]).upper()


def format_datetime(stamp: str) -> str:
    """Ledger TX-DATETIME "YYYYMMDDHHMMSS" -> "YYYY-MM-DD HH:MM"."""
    if len(stamp) != 14 or not stamp.isdigit():
        return stamp
    return f"{stamp[:4]}-{stamp[4:6]}-{stamp[6:8]} {stamp[8:10]}:{stamp[10:12]}"
