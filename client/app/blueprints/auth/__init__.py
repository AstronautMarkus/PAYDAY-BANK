"""Authentication: login, logout, onboarding, and the logged-in-user hooks
shared by every blueprint (login_required, g.user, current_user).
"""
from functools import wraps

from flask import Blueprint, flash, g, redirect, session, url_for

from app.extensions import db
from app.models import User

bp = Blueprint("auth", __name__)


def login_required(view):
    @wraps(view)
    def wrapped_view(*args, **kwargs):
        if "user_id" not in session:
            flash("Inicia sesión para entrar al banco.", "error")
            return redirect(url_for("auth.login"))
        return view(*args, **kwargs)

    return wrapped_view


@bp.before_app_request
def load_logged_in_user():
    user_id = session.get("user_id")
    g.user = None if user_id is None else db.session.get(User, user_id)
    if user_id is not None and g.user is None:
        session.clear()


@bp.app_context_processor
def inject_user():
    return {"current_user": g.get("user")}


from . import routes  # noqa: E402,F401  (registers routes on import)
