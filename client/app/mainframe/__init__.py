"""Client for the COBOL "mainframe" core (see core/src/bank_api.cbl)."""
from .client import (
    account_exists,
    call_cobol,
    customer_exists,
    flash_result,
    generate_account,
    generate_customer_id,
    list_customer_accounts,
)

__all__ = [
    "account_exists",
    "call_cobol",
    "customer_exists",
    "flash_result",
    "generate_account",
    "generate_customer_id",
    "list_customer_accounts",
]
