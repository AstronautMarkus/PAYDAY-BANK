"""Presentation helpers for Chilean peso (CLP) amounts.

CLP has no minor currency unit in everyday use, so every amount coming out
of the core is a whole number of pesos. This formats it with "." as the
thousands separator, matching the Chilean convention (1234567 -> "1.234.567").
"""


def format_clp(amount) -> str:
    try:
        value = int(str(amount).strip())
    except (TypeError, ValueError):
        return str(amount)
    return f"{value:,}".replace(",", ".")
