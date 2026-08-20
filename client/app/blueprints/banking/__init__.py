"""Banking operations: dashboard, deposits, withdrawals, opening new
accounts, and transfers between a customer's own accounts, all against
the mainframe core."""
from flask import Blueprint

bp = Blueprint("banking", __name__)

from . import routes  # noqa: E402,F401  (registers routes on import)
