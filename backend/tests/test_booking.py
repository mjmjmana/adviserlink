import datetime

import main


class MappingResult:
    def __init__(self, row):
        self.row = row

    def first(self):
        return self.row


class ApplicationResult:
    def __init__(self, row):
        self.row = row

    def mappings(self):
        return MappingResult(self.row)

    def first(self):
        return tuple(self.row.values())


class BookingConnection:
    def __init__(self, application):
        self.application = application
        self.inserted = None

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def execute(self, statement, params=None):
        query = str(statement)
        if "FROM adviser_profiles" in query and "FOR UPDATE" in query:
            return ApplicationResult({})
        if "SELECT a.application_id, a.student_id" in query:
            return ApplicationResult(self.application)
        if "INSERT INTO bookings" in query:
            self.inserted = params
            return type("InsertResult", (), {"lastrowid": 73})()
        raise AssertionError(f"Unexpected query: {query}")


class BookingEngine:
    def __init__(self, connection):
        self.connection = connection

    def begin(self):
        return self.connection


def test_group_leader_can_book_available_slot(monkeypatch):
    slot_date = datetime.date.today() + datetime.timedelta(days=1)
    connection = BookingConnection({
        "application_id": 8,
        "student_id": 10,
        "is_group_leader": 1,
    })
    notifications = []
    monkeypatch.setattr(main, "engine", BookingEngine(connection))
    monkeypatch.setattr(main, "fetch_slots", lambda *args: [
        {"start": "09:00", "available": True, "reason": None},
    ])
    monkeypatch.setattr(main, "notify", lambda *args, **kwargs: notifications.append(args))

    result = main.create_booking(
        main.BookingIn(adviser_id=20, slot_date=slot_date, start_time="09:00", notes="Chapter 1 revision"),
        {"user_id": 10, "role": "student", "name": "Leader"},
    )

    assert result == {"booking_id": 73, "message": "Consultation booked."}
    assert connection.inserted["ap"] == 8
    assert connection.inserted["s"] == 10
    assert connection.inserted["st"] == "09:00:00"
    assert len(notifications) == 1
