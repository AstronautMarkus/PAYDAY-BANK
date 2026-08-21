"""Runtime configuration for the Flask client.

Paths into the COBOL "core" (mainframe binary and its data directory) are
resolved here so the rest of the app never hardcodes filesystem layout.
"""
import os
from pathlib import Path

CLIENT_DIR = Path(__file__).resolve().parent.parent
REPO_ROOT = CLIENT_DIR.parent
CORE_DIR = REPO_ROOT / "core"


class Config:
    SECRET_KEY = os.environ.get("BANK_SECRET_KEY", "dev-only-secret-change-me")
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = "Lax"

    # The compiled COBOL "mainframe" binary and the directory holding its
    # indexed data files. The binary is invoked with this directory as its
    # working directory, since bank_api.cbl assigns its files by bare
    # relative name (e.g. "accounts.dat").
    MAINFRAME_BIN = CORE_DIR / "bin" / "bank_api"
    MAINFRAME_DATA_DIR = CORE_DIR / "data"
    MAINFRAME_TIMEOUT = 10
