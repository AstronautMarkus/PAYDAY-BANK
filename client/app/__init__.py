"""Legacy bank frontend web app (Flask).

All business logic and data live in the COBOL core (core/src/bank_api.cbl,
compiled to core/bin/bank_api). This app only renders HTML, stores login
credentials in its own SQLite database, and translates HTTP requests into
calls to the mainframe binary via the app.mainframe client.
"""
import os

from flask import Flask

from .config import Config
from .extensions import db


def create_app() -> Flask:
    app = Flask(__name__, instance_relative_config=True)
    app.config.from_object(Config)
    os.makedirs(app.instance_path, exist_ok=True)
    app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///" + os.path.join(
        app.instance_path, "bank_users.sqlite3"
    )

    db.init_app(app)

    from .blueprints.auth import bp as auth_bp
    from .blueprints.banking import bp as banking_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(banking_bp)

    with app.app_context():
        db.create_all()

    return app
