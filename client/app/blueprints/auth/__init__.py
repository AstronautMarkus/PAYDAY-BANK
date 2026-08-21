"""Authentication: login, logout, onboarding, and the logged-in-user hooks
shared by every blueprint (login_required, g.user, current_user).
"""
from functools import wraps
from types import SimpleNamespace

from flask import Blueprint, flash, g, redirect, session, url_for

from app.mainframe import call_cobol

bp = Blueprint("auth", __name__)

# PROFILE's OK payload, in order (see core/src/ops/op_profile.cbl).
PROFILE_FIELDS = (
    "customer_id", "name", "document", "email", "phone", "address",
    "occupation", "employer",
)


def login_required(view):
    @wraps(view)
    def wrapped_view(*args, **kwargs):
        if "customer_id" not in session:
            flash("Please sign in to access PAYDAY BANK.", "error")
            return redirect(url_for("auth.login"))
        return view(*args, **kwargs)

    return wrapped_view


@bp.before_app_request
def load_logged_in_user():
    customer_id = session.get("customer_id")
    g.user = None
    if customer_id is not None:
        lines = call_cobol("PROFILE", customer_id)
        if lines and lines[0].startswith("OK|"):
            values = lines[0].split("|")[1:]
            g.user = SimpleNamespace(**dict(zip(PROFILE_FIELDS, values)))
        else:
            session.clear()


@bp.app_context_processor
def inject_user():
    return {"current_user": g.get("user")}


from . import routes  # noqa: E402,F401  (registers routes on import)
