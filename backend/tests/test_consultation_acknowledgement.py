import datetime

import pytest
from fastapi import HTTPException

import main


class Result:
    def __init__(self, row=None, rowcount=0):
        self.row = row
        self.rowcount = rowcount

    def mappings(self):
        return self

    def first(self):
        return self.row

    def all(self):
        return self.row or []


class Connection:
    def __init__(self, booking, leader_membership=None):
        self.booking = booking
        self.leader_membership = leader_membership
        self.updated = False

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def execute(self, statement, params=None):
        query = str(statement)
        if "FROM bookings WHERE booking_id = :id FOR UPDATE" in query:
            return Result(self.booking)
        if "SELECT 1 FROM application_groups" in query:
            return Result(self.leader_membership)
        if "UPDATE bookings SET leader_accepted = 1" in query:
            self.updated = True
            return Result(rowcount=1)
        raise AssertionError(f"Unexpected query: {query}")


class Engine:
    def __init__(self, connection):
        self.connection = connection

    def begin(self):
        return self.connection


def booking_row():
    return {
        "booking_id": 41,
        "application_id": 8,
        "student_id": 10,
        "adviser_id": 20,
        "slot_date": datetime.date.today() + datetime.timedelta(days=1),
        "start_time": datetime.time(10, 0),
        "status": "confirmed",
        "meeting_type": "online",
        "leader_accepted": 0,
    }


def test_group_leader_can_accept_meeting_details(monkeypatch):
    connection = Connection(booking_row())
    notifications = []
    monkeypatch.setattr(main, "engine", Engine(connection))
    monkeypatch.setattr(main, "notify", lambda *args, **kwargs: notifications.append(args))

    result = main.accept_meeting(41, {"user_id": 10, "role": "student", "name": "Leader"})

    assert result["message"] == "Meeting details accepted."
    assert connection.updated
    assert len(notifications) == 1


def test_group_member_cannot_accept_meeting_details(monkeypatch):
    monkeypatch.setattr(main, "engine", Engine(Connection(booking_row())))

    with pytest.raises(HTTPException) as error:
        main.accept_meeting(41, {"user_id": 11, "role": "student", "name": "Member"})

    assert error.value.status_code == 403


def test_unaccepted_past_booking_is_cancelled_and_both_parties_are_notified(monkeypatch):
    rows = [{
        "booking_id": 41,
        "slot_date": datetime.date(2026, 11, 14),
        "start_time": datetime.time(10, 0),
        "student_id": 10,
        "adviser_id": 20,
        "student_name": "Leader",
        "adviser_name": "Adviser",
    }]
    statements = []

    class CancellationConnection:
        def execute(self, statement, params=None):
            query = str(statement)
            statements.append(query)
            if query.startswith("SELECT b.booking_id"):
                return Result(rows)
            if query.startswith("UPDATE bookings SET status = 'cancelled'"):
                return Result(rowcount=1)
            raise AssertionError(f"Unexpected query: {query}")

    notifications = []
    monkeypatch.setattr(main, "notify", lambda *args, **kwargs: notifications.append(args))

    main.cancel_unaccepted_bookings(CancellationConnection(), datetime.datetime(2026, 11, 14, 10, 1))

    assert any("leader_accepted = 0" in query for query in statements)
    assert len(notifications) == 2


def test_accepted_booking_is_completed_after_its_end_time(monkeypatch):
    executed = []
    notifications = []
    rows = [{
        "booking_id": 41,
        "student_id": 10,
        "adviser_id": 20,
        "slot_date": datetime.date(2026, 11, 15),
        "start_time": datetime.time(10, 0),
        "end_time": datetime.time(10, 30),
        "adviser_name": "Adviser",
    }]

    class CompletionConnection:
        def execute(self, statement, params=None):
            query = str(statement)
            executed.append((query, params))
            if query.startswith("SELECT b.booking_id"):
                return Result(rows)
            if query.startswith("UPDATE bookings SET status = 'completed'"):
                return Result(rowcount=1)
            raise AssertionError(f"Unexpected query: {query}")

    now = datetime.datetime(2026, 11, 15, 10, 30)
    monkeypatch.setattr(main, "notify", lambda *args, **kwargs: notifications.append((args, kwargs)))
    main.complete_accepted_bookings(CompletionConnection(), now)

    query, params = executed[0]
    assert "status = 'confirmed' AND b.leader_accepted = 1" in query
    assert "b.end_time <= :time" in query
    assert params == {"today": now.date(), "time": now.time()}
    assert executed[1][1] == {"id": 41}
    assert len(notifications) == 1
    assert "You can now rate your adviser." in notifications[0][0][2]
