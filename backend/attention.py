"""
"Needs your attention": a short list of things to do now, so users don't have to check every page.
Content differs for students and advisers. Each item includes an action (link, rate, book, or nudge).
"""
import datetime

from sqlalchemy import text

from analytics import build_report

STALL_DAYS = 14


def _pretty(d, minutes):
    h, m = divmod(minutes, 60)
    return f"{d.strftime('%b')} {d.day}, {h % 12 or 12}:{m:02d} {'AM' if h < 12 else 'PM'}"


def _mins(v):
    if isinstance(v, datetime.timedelta):
        return int(v.total_seconds() // 60)
    return v.hour * 60 + v.minute


def build_attention(conn, user: dict) -> list:
    items = []
    now = datetime.datetime.now()
    today = now.date()

    def add(id_, level, msg, action=None):
        items.append({"id": id_, "level": level, "text": msg, "action": action})

    if user["role"] == "student":
        row = conn.execute(
            text(
                "SELECT a.application_id, a.adviser_id, v.name AS adviser_name FROM applications a "
                "JOIN users v ON v.user_id = a.adviser_id WHERE a.student_id = :u AND a.status = 'approved' LIMIT 1"
            ),
            {"u": user["user_id"]},
        ).mappings().first()
        if row is None:
            return items
        app_id, adviser = row["application_id"], row["adviser_name"]
        bookings = conn.execute(
            text(
                "SELECT b.booking_id, b.slot_date, b.start_time, b.status, b.meeting_type, r.stars FROM bookings b "
                "LEFT JOIN consultation_ratings r ON r.booking_id = b.booking_id WHERE b.student_id = :u ORDER BY b.slot_date, b.start_time"
            ),
            {"u": user["user_id"]},
        ).mappings().all()
        upcoming = []
        for b in bookings:
            start = datetime.datetime.combine(b["slot_date"], datetime.time(*divmod(_mins(b["start_time"]), 60)))
            if b["status"] == "confirmed" and start > now:
                upcoming.append((start, b))
        if upcoming:
            start, b = upcoming[0]
            hours = (start - now).total_seconds() / 3600
            if hours <= 48:
                add("next", "info", f"Next consultation: {_pretty(b['slot_date'], _mins(b['start_time']))} with {adviser}.", {"type": "link", "label": "Open schedule", "to": "/schedule"})
            for _, b2 in upcoming:
                if b2["meeting_type"] is None:
                    add("details", "info", f"Waiting for {adviser} to set if {_pretty(b2['slot_date'], _mins(b2['start_time']))} is online or in person.")
                    break
        else:
            add("book", "info", "You have no upcoming consultation.", {"type": "book", "label": "Book now"})
        unrated = [b for b in bookings if b["status"] == "completed" and b["stars"] is None and (today - b["slot_date"]).days <= 30]
        for b in unrated[-2:]:
            add(f"rate{b['booking_id']}", "info", f"How was your consultation on {_pretty(b['slot_date'], _mins(b['start_time']))}?", {"type": "rate", "label": "Rate it", "booking_id": b["booking_id"]})
        tasks = conn.execute(
            text("SELECT status, created_at, updated_at FROM kanban_tasks WHERE application_id = :a"), {"a": app_id}
        ).mappings().all()
        if not tasks:
            add("firsttask", "info", "Add your first task to your progress board.", {"type": "link", "label": "Open board", "to": "/board"})
        else:
            open_tasks = [t for t in tasks if t["status"] != "done"]
            last = max((t["updated_at"] or t["created_at"]) for t in tasks)
            days = (now - last).days
            if open_tasks and days >= STALL_DAYS:
                add("stalled", "warn", f"Your board hasn't been updated in {days} days.", {"type": "link", "label": "Open board", "to": "/board"})
            review = sum(1 for t in tasks if t["status"] == "review")
            if review:
                add("review", "info", f"{review} task(s) are waiting for {adviser} to review.")
    elif user["role"] == "adviser":
        uid = user["user_id"]
        pending = conn.execute(
            text("SELECT COUNT(*), MIN(date_submitted) FROM applications WHERE adviser_id = :u AND status = 'pending'"), {"u": uid}
        ).first()
        if pending[0]:
            old = pending[1] is not None and (now - pending[1]).days >= 3
            add("pending", "warn" if old else "info", f"{pending[0]} student(s) are waiting for your reply.", {"type": "link", "label": "Open requests", "to": "/applications"})
        rows = conn.execute(
            text("SELECT slot_date, start_time, status, meeting_type FROM bookings WHERE adviser_id = :u AND status = 'confirmed'"), {"u": uid}
        ).mappings().all()
        todays = [r for r in rows if r["slot_date"] == today]
        no_details = [r for r in rows if r["meeting_type"] is None and datetime.datetime.combine(r["slot_date"], datetime.time(*divmod(_mins(r["start_time"]), 60))) > now]
        unmarked = [r for r in rows if datetime.datetime.combine(r["slot_date"], datetime.time(*divmod(_mins(r["start_time"]), 60))) < now - datetime.timedelta(hours=1)]
        if todays:
            add("today", "info", f"You have {len(todays)} consultation(s) today.", {"type": "link", "label": "Open schedule", "to": "/schedule"})
        if no_details:
            add("details", "warn", f"{len(no_details)} upcoming consultation(s) need online or in-person details.", {"type": "link", "label": "Set details", "to": "/schedule"})
        if unmarked:
            add("unmarked", "info", f"{len(unmarked)} past consultation(s) are not marked completed yet.", {"type": "link", "label": "Open schedule", "to": "/schedule"})
        review = conn.execute(
            text("SELECT COUNT(*) FROM kanban_tasks t JOIN applications a ON a.application_id = t.application_id WHERE a.adviser_id = :u AND t.status = 'review'"),
            {"u": uid},
        ).scalar()
        if review:
            add("review", "info", f"{review} task(s) are waiting for your review.", {"type": "link", "label": "Open board", "to": "/board"})
        windows = conn.execute(text("SELECT COUNT(*) FROM availability WHERE adviser_id = :u"), {"u": uid}).scalar()
        if not windows:
            add("hours", "warn", "You haven't set open times, so students can't book you.", {"type": "link", "label": "Set open times", "to": "/settings"})
        # advisees with no activity: one-click nudge
        report = build_report(conn, uid)
        for a in [x for x in report["predictive"]["advisees"] if x["risk"] == "Stalled"][:3]:
            add(f"nudge{a['application_id']}", "warn", f"{a['student']} has had no activity for {a['days_inactive']} days.", {"type": "nudge", "label": "Send reminder", "application_id": a["application_id"]})
    order = {"warn": 0, "info": 1}
    items.sort(key=lambda i: order.get(i["level"], 2))
    return items
