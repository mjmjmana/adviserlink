"""Para tumakbo ang mga test kahit walang SQLAlchemy/MySQL (purong logic lang ang sinusuri)."""
import os
import sys
import types

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
try:
    import sqlalchemy  # noqa: F401
except ImportError:  # pragma: no cover
    sys.modules["sqlalchemy"] = types.SimpleNamespace(text=lambda s: s)
