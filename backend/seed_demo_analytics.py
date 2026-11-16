"""
Creates DEMO data (students, applications, bookings, tasks) so Analytics charts have content.

  python seed_demo_analytics.py            -> creates if none exists
  python seed_demo_analytics.py --reset    -> deletes old demo data first, then recreates

All demo students have email "demo.*@demo.isu.edu.ph" (password: test1234), making them easy to remove.
You must have run `python seed_demo_users.py` first (to create Maria and Jose).
"""
import datetime
import random
import sys

from sqlalchemy import bindparam, text

from db_setup import ensure_schema
from main import engine, hash_password

RESET = "--reset" in sys.argv
rnd = random.Random(2026)
today = datetime.date.today()
this_monday = today - datetime.timedelta(days=today.weekday())
NAMES = ["Angelo Cruz", "Bea Villanueva", "Carlo Mendoza", "Dana Ramos", "Eli Navarro",
         "Faith Domingo", "Gio Bautista", "Hazel Aquino", "Ian Soriano", "Jam Garcia"]


def adviser_id(conn, email):
    row = conn.execute(text("SELECT user_id FROM users WHERE email = :e"), {"e": email}).first()
    return row[0] if row else None


with engine.begin() as conn:
    ensure_schema(engine)
    maria = adviser_id(conn, "maria.santos@isu.edu.ph")
    jose = adviser_id(conn, "jose.reyes@isu.edu.ph")
    if not maria or not jose:
        sys.exit("Patakbuhin muna ang: python seed_demo_users.py")

    demo_ids = [r[0] for r in conn.execute(text("SELECT user_id FROM users WHERE email LIKE 'demo.%@demo.isu.edu.ph'"))]
    if demo_ids and not RESET:
        sys.exit("May demo data na. Gamitin ang --reset kung gusto mong gawin ulit.")
    if demo_ids:
        for tbl, col in (("bookings", "student_id"), ("applications", "student_id")):
            conn.execute(text(f"DELETE FROM {tbl} WHERE {col} IN :ids").bindparams(bindparam("ids", expanding=True)), {"ids": demo_ids})
        conn.execute(text("DELETE FROM users WHERE user_id IN :ids").bindparams(bindparam("ids", expanding=True)), {"ids": demo_ids})
        print("Nabura ang lumang demo data.")

    conn.execute(text("UPDATE adviser_profiles SET max_capacity = GREATEST(COALESCE(max_capacity, 0), 12) WHERE adviser_id IN (:a, :b)"), {"a": maria, "b": jose})

    pw = hash_password("test1234")
    students = []
    for i, name in enumerate(NAMES):
        res = conn.execute(
            text("INSERT INTO users (name, email, password, role, created_at) VALUES (:n, :e, :p, 'student', :c)"),
            {"n": name, "e": f"demo.{i + 1}@demo.isu.edu.ph", "p": pw, "c": datetime.datetime.now() - datetime.timedelta(days=70)},
        )
        students.append((res.lastrowid, name))

    # 7 approved for Maria and Jose, 1 pending (old), 1 declined, 1 pending (new)
    plan = [(maria, "approved")] * 4 + [(jose, "approved")] * 3 + [(jose, "pending"), (jose, "declined"), (maria, "pending")]
    topics = ["Online enrollment system", "IoT-based classroom monitoring", "Barangay records web portal",
              "Mobile app for campus navigation", "Library management system", "Sales analytics dashboard",
              "Attendance tracker with QR codes", "Student clearance system", "E-commerce for local products",
              "Learning management system"]
    apps = {}
    for idx, ((sid, name), (aid, status)) in enumerate(zip(students, plan)):
        days_ago = 55 - idx * 3 if status == "approved" else (6 if idx == 7 else 1 if idx == 9 else 20)
        res = conn.execute(
            text("INSERT INTO applications (student_id, adviser_id, topic_brief, status, date_submitted) VALUES (:s, :a, :t, :st, :d)"),
            {"s": sid, "a": aid, "t": topics[idx], "st": status, "d": datetime.datetime.now() - datetime.timedelta(days=days_ago)},
        )
        if status == "approved":
            apps[res.lastrowid] = (sid, aid)

    for aid in (maria, jose):
        conn.execute(
            text("UPDATE adviser_profiles SET current_advisee_count = (SELECT COUNT(*) FROM applications WHERE adviser_id = :a AND status = 'approved') WHERE adviser_id = :a"),
            {"a": aid},
        )

    # ---- bookings: demand rises each week (8 complete weeks + this week + 2 future)
    days = {maria: [1, 2, 3], jose: [0, 4]}          # Tue/Wed/Thu and Mon/Fri
    starts = {maria: [9 * 60 + 30 * k for k in range(6)], jose: [13 * 60 + 30 * k for k in range(5)]}
    weekly = [3, 4, 3, 5, 6, 6, 8, 9]
    used = set()
    app_ids = list(apps)
    made = 0

    def add_booking(week_monday, future):
        global made
        app_id = rnd.choice(app_ids)
        sid, aid = apps[app_id]
        for _ in range(30):
            d = week_monday + datetime.timedelta(days=rnd.choice(days[aid]))
            m = rnd.choice(starts[aid])
            if (aid, d, m) not in used:
                break
        else:
            return
        used.add((aid, d, m))
        if future or d >= today:
            status, by, reason = "confirmed", None, None
        else:
            r = rnd.random()
            if r < 0.78:
                status, by, reason = "completed", None, None
            elif r < 0.93:
                status = "cancelled"
                by = aid if rnd.random() < 0.6 else sid
                reason = rnd.choice(["Schedule conflict", "Not feeling well", "Class suspension", "Need more time to prepare"])
            else:
                status, by, reason = "confirmed", None, None   # not yet marked as completed
        mtype = rnd.choice(["online", "in-person"])
        conn.execute(
            text(
                "INSERT INTO bookings (application_id, student_id, adviser_id, slot_date, start_time, end_time, status, "
                "meeting_type, location, cancel_reason, cancelled_by, reminded) VALUES (:ap, :s, :a, :d, :st, :en, :stat, :mt, :loc, :cr, :cb, 1)"
            ),
            {"ap": app_id, "s": sid, "a": aid, "d": d, "st": f"{m // 60:02d}:{m % 60:02d}:00", "en": f"{(m + 30) // 60:02d}:{(m + 30) % 60:02d}:00",
             "stat": status, "mt": mtype, "loc": "Google Meet" if mtype == "online" else "Faculty Room", "cr": reason, "cb": by},
        )
        made += 1

    for i, n in enumerate(weekly):
        monday = this_monday - datetime.timedelta(weeks=len(weekly) - i)
        for _ in range(n):
            add_booking(monday, False)
    for w, n in ((0, 3), (1, 2), (2, 1)):
        for _ in range(n):
            add_booking(this_monday + datetime.timedelta(weeks=w), True)

    # ---- kanban tasks: iba-ibang kalagayan (stalled, tapos na, wala pang task, on track, at risk)
    titles = ["Chapter 1 draft", "Review of related literature", "Survey questionnaire", "System design diagrams",
              "Prototype v1", "Chapter 3 methodology", "Data gathering", "Testing plan"]
    profile_by_idx = ["stalled", "complete", "none", "ontrack", "ontrack", "atrisk", "ontrack"]
    for idx, (app_id, (sid, aid)) in enumerate(apps.items()):
        kind = profile_by_idx[idx % len(profile_by_idx)]
        if kind == "none":
            continue
        n = rnd.randint(5, 8)
        for k in range(n):
            if kind == "complete":
                st = "done"
            elif kind == "stalled":
                st = "done" if k < 2 else "todo"
            elif kind == "atrisk":
                st = "done" if k < 1 else rnd.choice(["todo", "in_progress"])
            else:
                st = "done" if k < n // 2 else rnd.choice(["in_progress", "review", "todo"])
            last = 25 if kind == "stalled" else rnd.randint(1, 8)
            ts = datetime.datetime.now() - datetime.timedelta(days=last + (n - k))
            res = conn.execute(
                text("INSERT INTO kanban_tasks (application_id, title, description, status, created_by, created_at, updated_at) VALUES (:a, :t, NULL, :s, :u, :c, :c)"),
                {"a": app_id, "t": titles[k % len(titles)], "s": st, "u": sid, "c": ts},
            )
            if st in ("review", "done") and rnd.random() < 0.6:
                conn.execute(
                    text("INSERT INTO task_comments (task_id, author_id, body, created_at) VALUES (:t, :a, :b, :c)"),
                    {"t": res.lastrowid, "a": aid, "b": rnd.choice(["Good progress, please polish the formatting.", "Add more references.", "Looks good, approved."]), "c": ts},
                )
    # ---- ratings (Sprint 3): karamihan ay 4-5 stars
    done = conn.execute(
        text("SELECT booking_id, student_id, adviser_id FROM bookings WHERE status = 'completed' AND student_id IN (SELECT user_id FROM users WHERE email LIKE 'demo.%@demo.isu.edu.ph')")
    ).fetchall()
    for bid, sid, aid in done:
        if rnd.random() < 0.7:
            conn.execute(
                text("INSERT INTO consultation_ratings (booking_id, student_id, adviser_id, stars, comment) VALUES (:b, :s, :a, :st, :c)"),
                {"b": bid, "s": sid, "a": aid, "st": rnd.choice([3, 4, 4, 5, 5, 5]), "c": rnd.choice([None, "Very helpful!", "Clear feedback, thank you.", "Needed more time."])},
            )
print(f"Done: {len(students)} demo students, {len(apps)} approved, {made} bookings. Log in as admin@isu.edu.ph to see Analytics.")
