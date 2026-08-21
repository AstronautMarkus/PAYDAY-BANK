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
