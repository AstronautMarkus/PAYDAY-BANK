"""Client for the COBOL "mainframe" core (see core/src/bank_api.cbl)."""
from .client import (
    account_exists,
    call_cobol,
    customer_exists,
    flash_result,
    generate_account,
    generate_card,
    generate_customer_id,
    list_customer_accounts,
    list_customer_cards,
    list_statement,
)

__all__ = [
    "account_exists",
    "call_cobol",
    "customer_exists",
    "flash_result",
    "generate_account",
    "generate_card",
    "generate_customer_id",
    "list_customer_accounts",
    "list_customer_cards",
    "list_statement",
]
