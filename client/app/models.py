"""Client-side persistence: login credentials and the profile snapshot used
to prefill the dashboard. The COBOL core remains the source of truth for
account balances and profile data; this table only owns authentication.
"""
from datetime import datetime, timezone

from sqlalchemy import DateTime
from sqlalchemy.orm import Mapped, mapped_column

from .extensions import db


class User(db.Model):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(db.String(30))
    document: Mapped[str] = mapped_column(db.String(20), unique=True)
    email: Mapped[str] = mapped_column(db.String(60), unique=True)
    phone: Mapped[str] = mapped_column(db.String(20))
    address: Mapped[str] = mapped_column(db.String(80))
    occupation: Mapped[str] = mapped_column(db.String(40))
    employer: Mapped[str] = mapped_column(db.String(50))
    account: Mapped[str] = mapped_column(db.String(10), unique=True)
    password_hash: Mapped[str] = mapped_column(db.String(255))
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=lambda: datetime.now(timezone.utc)
    )
