"""Development entrypoint. In production, point a WSGI server (gunicorn,
uwsgi, ...) at the `app` object created here, e.g.:

    gunicorn -w 2 -b 0.0.0.0:5005 wsgi:app
"""
from app import create_app
from app.config import Config

app = create_app()

if __name__ == "__main__":
    if not Config.MAINFRAME_BIN.exists():
        raise SystemExit(
            "Mainframe binary not found. Compile the core first with:\n"
            "  make -C ../core build\n"
            "(or `make build-core` from the repository root)"
        )
    app.run(debug=True, port=5005)
