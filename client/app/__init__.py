"""Legacy bank frontend web app (Flask).

All business logic and data live in the COBOL core (core/src/bank_api.cbl,
compiled to core/bin/bank_api). This app has no persistence of its own --
it only renders HTML, keeps the logged-in customer-id in the session
cookie, and translates HTTP requests into calls to the mainframe binary
via the app.mainframe client.
"""
from flask import Flask

from .config import Config
from .formatting import format_clp


def create_app() -> Flask:
    app = Flask(__name__)
    app.config.from_object(Config)
    app.jinja_env.filters["clp"] = format_clp

    from .blueprints.auth import bp as auth_bp
    from .blueprints.banking import bp as banking_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(banking_bp)

    return app
