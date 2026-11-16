import email_utils


def test_email_is_not_reported_as_sent_without_smtp(monkeypatch):
    stored = []
    monkeypatch.setattr(email_utils, "_can_send", lambda: False)
    monkeypatch.setattr(email_utils, "_store_dev_token", lambda *args: stored.append(args))

    sent = email_utils._send_or_store(
        "student@example.com",
        "Student",
        "token",
        "reset-password",
        "Reset password",
        "<p>Reset</p>",
        "Reset",
    )

    assert sent is False
    assert stored == []


def test_email_delivery_failure_is_returned_to_caller(monkeypatch):
    monkeypatch.setattr(email_utils, "_can_send", lambda: True)
    monkeypatch.setattr(email_utils, "send_email", lambda *args: False)

    sent = email_utils._send_or_store(
        "student@example.com",
        "Student",
        "token",
        "reset-password",
        "Reset password",
        "<p>Reset</p>",
        "Reset",
    )

    assert sent is False
