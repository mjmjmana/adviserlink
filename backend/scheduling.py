"""
Pure functions for time and slots (no database, so easy to test).
"""
import datetime
import re

SLOT_MINUTES = 30
DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
_HHMM = re.compile(r"^([01]?\d|2[0-3]):([0-5]\d)(:[0-5]\d)?$")


def to_minutes(value) -> int:
    """Convert MySQL TIME or 'HH:MM' string to minutes since midnight."""
    if isinstance(value, datetime.timedelta):  # this is how pymysql returns TIME
        return int(value.total_seconds() // 60)
    if isinstance(value, datetime.time):
        return value.hour * 60 + value.minute
    m = _HHMM.match(str(value).strip())
    if not m:
        raise ValueError("Time must look like HH:MM (24-hour), for example 13:30.")
    return int(m.group(1)) * 60 + int(m.group(2))


def to_hhmm(minutes: int) -> str:
    return f"{minutes // 60:02d}:{minutes % 60:02d}"


def day_name(d: datetime.date) -> str:
    return DAYS[d.weekday()]


def overlaps(a_start: int, a_end: int, b_start: int, b_end: int) -> bool:
    return a_start < b_end and b_start < a_end


def build_slots(windows, booked, day: datetime.date, now: datetime.datetime):
    """
    windows: list of (start_min, end_min) open for this day
    booked : list of (start_min, end_min) with confirmed bookings
    Returns list of {"start": "HH:MM", "end": "HH:MM", "available": bool}.
    Slots in the past are excluded.
    """
    seen = {}
    for w_start, w_end in windows:
        s = w_start
        while s + SLOT_MINUTES <= w_end:
            seen[s] = s + SLOT_MINUTES
            s += SLOT_MINUTES
    out = []
    for s in sorted(seen):
        e = seen[s]
        slot_dt = datetime.datetime.combine(day, datetime.time(s // 60, s % 60))
        if slot_dt <= now:
            continue
        taken = any(overlaps(s, e, b0, b1) for b0, b1 in booked)
        out.append({"start": to_hhmm(s), "end": to_hhmm(e), "available": not taken})
    return out
