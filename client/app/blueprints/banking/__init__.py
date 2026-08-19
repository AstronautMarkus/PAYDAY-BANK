"""Banking operations: dashboard, deposits, and withdrawals against the
mainframe core."""
from flask import Blueprint

bp = Blueprint("banking", __name__)

from . import routes  # noqa: E402,F401  (registers routes on import)
