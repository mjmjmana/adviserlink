import pytest
from fastapi import HTTPException

from main import message_window_offset, store_chat_message
from message_moderation import analyze_message, detect_message_language


class FakeResult:
    def __init__(self, *, values=None, lastrowid=None):
        self.values = values or []
        self.lastrowid = lastrowid

    def scalars(self):
        return self

    def all(self):
        return self.values


class FakeConnection:
    def __init__(self, admin_ids=(10, 11)):
        self.admin_ids = list(admin_ids)
        self.calls = []

    def execute(self, statement, params=None):
        sql = str(statement)
        self.calls.append((sql, params or {}))
        if "SELECT user_id FROM users WHERE role = 'admin'" in sql:
            return FakeResult(values=self.admin_ids)
        if "INSERT INTO messages" in sql:
            return FakeResult(lastrowid=123 if not any("INSERT INTO messages" in call[0] for call in self.calls[:-1]) else 124)
        return FakeResult()


class MessageWindowResult:
    def __init__(self, value):
        self.value = value

    def first(self):
        return self.value

    def scalar(self):
        return self.value


class MessageWindowConnection:
    def __init__(self, *, target_exists=True, newer_count=0):
        self.target_exists = target_exists
        self.newer_count = newer_count

    def execute(self, statement, params=None):
        if "SELECT 1 FROM messages" in str(statement):
            return MessageWindowResult(object() if self.target_exists else None)
        return MessageWindowResult(self.newer_count)


def test_detects_english_filipino_and_mixed_messages():
    assert detect_message_language("Please send the draft before Friday.") == "en"
    assert detect_message_language("Pakisend ang file ko, salamat po.") == "tl"
    assert detect_message_language("Please send the file po.") == "mixed"


def test_analysis_flags_categories_without_returning_matched_terms():
    language, categories = analyze_message("That was damn frustrating.")
    assert language == "en"
    assert categories == ["profanity"]


def test_flagged_message_is_allowed_and_admins_are_alerted_with_warning_posted():
    conn = FakeConnection()
    message_id = store_chat_message(
        conn,
        application_id=55,
        sender_id=2,
        message_body="That was damn frustrating.",
        notification_targets=[(3, "New message from Juan")],
    )

    inserts = [(sql, params) for sql, params in conn.calls if "INSERT INTO messages" in sql]
    alerts = [(sql, params) for sql, params in conn.calls if "INSERT INTO notifications" in sql]
    assert message_id == 123
    assert len(inserts) == 2
    assert inserts[0][1]["categories"] == "profanity"
    assert "moderation_warning" in inserts[1][0]
    assert len(alerts) == 3
    assert {params["u"] for _, params in alerts} == {3, 10, 11}
    assert all(params["related_application_id"] == 55 for _, params in alerts)
    assert all(params["related_message_id"] == 123 for _, params in alerts)


def test_flagged_message_is_rejected_if_no_active_admin_can_be_notified():
    conn = FakeConnection(admin_ids=())

    with pytest.raises(HTTPException) as error:
        store_chat_message(
            conn,
            application_id=55,
            sender_id=2,
            message_body="That was damn frustrating.",
            notification_targets=[(3, "New message from Juan")],
        )

    assert error.value.status_code == 503
    assert not any("INSERT INTO messages" in sql for sql, _ in conn.calls)


def test_message_window_centers_target_and_uses_latest_when_target_is_missing():
    assert message_window_offset(
        MessageWindowConnection(newer_count=120), 55, 50, 123
    ) == 95
    assert message_window_offset(
        MessageWindowConnection(target_exists=False), 55, 50, 123
    ) == 0
