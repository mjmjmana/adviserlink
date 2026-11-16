"""
Mga automated test para sa mga mahalagang logic: oras at slots, matching, analytics, at seguridad.
Patakbuhin sa folder na `backend`:   pip install -r requirements-dev.txt   tapos   pytest
"""
import datetime

import pytest
from fastapi import HTTPException

from analytics import analyze, backtest_mae, forecast, linear_regression, risk_for
from matching import match_score, tokenize
from scheduling import build_slots, overlaps, to_hhmm, to_minutes
from security import LoginThrottle, file_matches_type
from main import AvailabilityIn, BookingIn, MeetingIn, can_access_application, can_manage_group_members, ensure_availability_has_no_overlap, is_public_profile_photo
from pydantic import ValidationError


# ---------------------------------------------------------------- scheduling
def test_to_minutes_handles_formats():
    assert to_minutes("09:30") == 570
    assert to_minutes(datetime.timedelta(hours=13, minutes=30)) == 810
    assert to_hhmm(570) == "09:30"


def test_overlaps():
    assert overlaps(540, 570, 560, 600)
    assert not overlaps(540, 570, 570, 600)  # magkadikit pero hindi magkapatong


def test_slots_skip_past_and_mark_booked():
    day = datetime.date(2026, 10, 19)
    now = datetime.datetime(2026, 10, 19, 9, 10)
    slots = build_slots([(540, 660)], [(600, 630)], day, now)
    starts = [s["start"] for s in slots]
    assert "09:00" not in starts  # lumipas na
    assert next(s for s in slots if s["start"] == "10:00")["available"] is False
    assert next(s for s in slots if s["start"] == "10:30")["available"] is True


def test_slots_keep_adviser_selected_minute_start_times():
    day = datetime.date(2026, 10, 20)
    slots = build_slots([(623, 653)], [], day, datetime.datetime(2026, 10, 1))
    assert slots == [{"start": "10:23", "end": "10:53", "available": True}]


def test_overlapping_windows_do_not_duplicate_slots():
    day = datetime.date(2026, 10, 20)
    slots = build_slots([(540, 660), (600, 720)], [], day, datetime.datetime(2026, 10, 1))
    starts = [s["start"] for s in slots]
    assert len(starts) == len(set(starts))


def test_booking_requires_nonblank_discussion_notes():
    with pytest.raises(ValidationError):
        BookingIn(adviser_id=1, slot_date=datetime.date(2026, 10, 20), start_time="09:00")
    with pytest.raises(ValidationError):
        BookingIn(
            adviser_id=1,
            slot_date=datetime.date(2026, 10, 20),
            start_time="09:00",
            notes="   ",
        )
    booking = BookingIn(
        adviser_id=1,
        slot_date=datetime.date(2026, 10, 20),
        start_time="09:00",
        notes="  Discuss chapter 1  ",
    )
    assert booking.notes == "Discuss chapter 1"


def test_online_meeting_links_are_normalized_and_validated():
    assert MeetingIn(meeting_type="online", location="meet.google.com/abc-defg-hij").location == (
        "https://meet.google.com/abc-defg-hij"
    )
    assert MeetingIn(meeting_type="online", location=" https://zoom.us/j/123 ").location == (
        "https://zoom.us/j/123"
    )
    assert MeetingIn(meeting_type="in-person", location="CCSICT Faculty Room").location == (
        "CCSICT Faculty Room"
    )
    with pytest.raises(ValidationError, match="valid online meeting link"):
        MeetingIn(meeting_type="online", location="https://")


def test_availability_is_one_separate_half_hour_slot():
    slot = AvailabilityIn(day_of_week="Mon", start_time="09:00", end_time="09:30")
    assert slot.start_time == "09:00"
    flexible_slot = AvailabilityIn(day_of_week="Mon", start_time="10:23", end_time="10:53")
    assert flexible_slot.end_time == "10:53"
    with pytest.raises(ValidationError, match="exactly 30 minutes"):
        AvailabilityIn(day_of_week="Mon", start_time="10:23", end_time="10:52")


def test_availability_edit_ignores_its_own_slot_but_rejects_other_overlaps():
    rows = [
        {
            "availability_id": 1,
            "day_of_week": "Mon",
            "specific_date": None,
            "start_time": "09:00",
            "end_time": "09:30",
        },
        {
            "availability_id": 2,
            "day_of_week": "Mon",
            "specific_date": None,
            "start_time": "10:00",
            "end_time": "10:30",
        },
    ]
    same_slot = AvailabilityIn(day_of_week="Mon", start_time="09:00", end_time="09:30")
    ensure_availability_has_no_overlap(rows, same_slot, exclude_id=1)

    overlapping_slot = AvailabilityIn(day_of_week="Mon", start_time="10:00", end_time="10:30")
    with pytest.raises(HTTPException) as error:
        ensure_availability_has_no_overlap(rows, overlapping_slot, exclude_id=1)
    assert error.value.status_code == 409


# ---------------------------------------------------------------- matching
def test_tokenize_removes_stopwords_and_stems():
    assert tokenize("I want a Web development system for my thesis") == ["web", "development"]
    assert tokenize("Websites and Databases") == ["website", "database"]
    assert tokenize("campus") == ["campus"]


def test_match_prefers_exact_tag():
    q = tokenize("flutter mobile app")
    mobile = match_score(q, "Jose", ["mobile development", "Flutter"], "")
    web = match_score(q, "Maria", ["web development", "PHP"], "")
    assert mobile[0] > web[0]
    assert mobile[1] >= 60 and web[1] == 0


def test_no_match_returns_zero():
    assert match_score(tokenize("blockchain"), "Maria", ["web development"], "")[0] == 0


# ---------------------------------------------------------------- analytics
def test_linear_regression_perfect_line():
    a, b, r2 = linear_regression([2, 4, 6, 8])
    assert abs(a - 2) < 1e-9 and abs(b - 2) < 1e-9 and abs(r2 - 1) < 1e-9


def test_forecast_never_negative_and_continues_trend():
    assert forecast([2, 4, 6, 8], 2)[0] == [10.0, 12.0]
    assert forecast([5, 3, 1], 3)[0] == [0.0, 0.0, 0.0]


def test_backtest_mae_needs_enough_data():
    assert backtest_mae([1, 2, 3]) == (None, None, 0)
    mae, naive, n = backtest_mae([3, 4, 3, 5, 6, 6, 8, 9])
    assert n == 4 and mae is not None and naive is not None


def test_risk_rules():
    assert risk_for(0, 0, None, 0) == "No tasks yet"
    assert risk_for(4, 4, 2, 1) == "Complete"
    assert risk_for(4, 1, 20, 1) == "Stalled"
    assert risk_for(10, 1, 2, 0.1) == "At risk"
    assert risk_for(4, 2, 2, 1) == "On track"


def test_analyze_output_shape_and_ratings():
    data = {
        "users": [{"user_id": 1, "name": "Maria", "role": "adviser"}, {"user_id": 2, "name": "Juan", "role": "student"}],
        "profiles": {1: {"capacity": 5, "advisees": 1}},
        "applications": [{"application_id": 1, "student_id": 2, "adviser_id": 1, "status": "approved",
                          "date_submitted": datetime.datetime(2026, 9, 1), "student_name": "Juan", "adviser_name": "Maria"}],
        "bookings": [], "tasks": [],
        "ratings": [{"stars": 5, "adviser_id": 1}, {"stars": 3, "adviser_id": 1}],
    }
    r = analyze(data, datetime.date(2026, 10, 19))
    assert set(r) >= {"descriptive", "diagnostic", "predictive", "prescriptive"}
    assert r["descriptive"]["avg_rating"] == 4.0
    assert r["predictive"]["advisees"][0]["risk"] == "No tasks yet"


# ---------------------------------------------------------------- security
def test_login_throttle_locks_then_releases():
    t = LoginThrottle(max_attempts=3, window=600, lock=300)
    for i in range(3):
        assert t.retry_after("a", now=1000 + i) == 0
        t.fail("a", now=1000 + i)
    assert t.retry_after("a", now=1010) > 0           # naka-lock na
    assert t.retry_after("b", now=1010) == 0          # ibang user, hindi apektado
    assert t.retry_after("a", now=1010 + 400) == 0    # lumipas na ang lock


def test_login_throttle_reset_on_success():
    t = LoginThrottle(max_attempts=2)
    t.fail("x", now=1); t.fail("x", now=2)
    t.reset("x")
    assert t.retry_after("x", now=3) == 0


def test_file_signature_checks():
    assert file_matches_type("pdf", b"%PDF-1.7 ....")
    assert not file_matches_type("pdf", b"MZ\x90\x00 (exe)")           # exe na pinalitan ng pangalan
    assert file_matches_type("docx", b"PK\x03\x04....")
    assert file_matches_type("png", b"\x89PNG\r\n\x1a\n....")
    assert file_matches_type("txt", b"hello world")
    assert not file_matches_type("txt", b"\x00\x01\x02binary")
    assert not file_matches_type("exe", b"MZ")                         # hindi kilalang uri


def test_only_student_group_leaders_can_manage_members():
    assert can_manage_group_members({"role": "student"}, True)
    assert not can_manage_group_members({"role": "student"}, False)
    assert not can_manage_group_members({"role": "adviser"}, True)
    assert not can_manage_group_members({"role": "admin"}, True)


def test_application_access_includes_group_members_not_unrelated_users():
    assert can_access_application(1, 1, 2, False)
    assert can_access_application(2, 1, 2, False)
    assert can_access_application(3, 1, 2, True)
    assert not can_access_application(4, 1, 2, False)


def test_public_uploads_are_limited_to_profile_photo_names():
    assert is_public_profile_photo("photo_42_0123456789abcdef.jpg")
    assert not is_public_profile_photo("d8f78a49c3774e30af39.pdf")
    assert not is_public_profile_photo("..\\private.jpg")
