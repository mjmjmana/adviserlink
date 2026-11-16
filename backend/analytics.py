"""
AdviserLink Analytics: Descriptive, Diagnostic, Predictive, Prescriptive.

  Descriptive: What happened? (counts, distribution, load per adviser)
  Diagnostic: Why did it happen? (cancellations: who cancelled, which day)
  Predictive: What will happen? (linear regression for next week's consultation demand,
              projected completion and risk level per advisee)
  Prescriptive: What should we do? (rule-based recommendations from above results)

`analyze()` is pure Python (no database) for easy testing; `load_data()` fetches from MySQL.
No numpy/pandas needed: simple loops and least-squares formula only.
"""
import datetime
from collections import Counter, defaultdict
from typing import Optional

from sqlalchemy import text

WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
ACTIVE = ("confirmed", "completed")
HISTORY_WEEKS = 8
FORECAST_WEEKS = 4
STALLED_DAYS = 14


# ---------------------------------------------------------------- mga pure na formula
def week_start(d: datetime.date) -> datetime.date:
    return d - datetime.timedelta(days=d.weekday())


def linear_regression(values):
    """Least squares: y = a + b*x, x = 0..n-1. Nagbabalik ng (a, b, r2)."""
    n = len(values)
    if n == 0:
        return 0.0, 0.0, 0.0
    if n == 1:
        return float(values[0]), 0.0, 0.0
    xs = list(range(n))
    mx, my = sum(xs) / n, sum(values) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    sxy = sum((x - mx) * (y - my) for x, y in zip(xs, values))
    b = sxy / sxx if sxx else 0.0
    a = my - b * mx
    ss_tot = sum((y - my) ** 2 for y in values)
    ss_res = sum((y - (a + b * x)) ** 2 for x, y in zip(xs, values))
    r2 = 1 - ss_res / ss_tot if ss_tot else 0.0
    return a, b, max(0.0, min(1.0, r2))


def forecast(values, horizon):
    """Hulaan ang susunod na `horizon` na halaga gamit ang linear regression (hindi bumababa sa 0)."""
    a, b, r2 = linear_regression(values)
    n = len(values)
    preds = [max(0.0, round(a + b * (n + i), 1)) for i in range(horizon)]
    return preds, b, r2


def backtest_mae(values, min_train=4):
    """Gaano katumpak ang model? Walk-forward backtest: sa bawat linggo, i-fit sa mga nauna at hulaan ang susunod.
    Nagbabalik ng (MAE ng regression, MAE ng simpleng "kapareho ng nakaraang linggo", bilang ng hinulaan)."""
    model_err, naive_err = [], []
    for i in range(min_train, len(values)):
        a, b, _ = linear_regression(values[:i])
        model_err.append(abs(values[i] - max(0.0, a + b * i)))
        naive_err.append(abs(values[i] - values[i - 1]))
    if not model_err:
        return None, None, 0
    return round(sum(model_err) / len(model_err), 2), round(sum(naive_err) / len(naive_err), 2), len(model_err)


def risk_for(total, done, days_inactive, velocity_per_week):
    """Rule-based na risk ng isang advisee: Complete / No tasks yet / Stalled / At risk / On track."""
    if total == 0:
        return "No tasks yet"
    if done == total:
        return "Complete"
    if days_inactive is not None and days_inactive >= STALLED_DAYS:
        return "Stalled"
    remaining = total - done
    if velocity_per_week <= 0:
        return "At risk"
    return "At risk" if remaining / velocity_per_week > 6 else "On track"


# ---------------------------------------------------------------- ang pangunahing pagsusuri
def analyze(data: dict, today: datetime.date, adviser_id: Optional[int] = None) -> dict:
    users = data["users"]
    apps = data["applications"]
    bookings = data["bookings"]
    tasks = data["tasks"]
    profiles = data["profiles"]
    ratings = data.get("ratings", [])
    names = {u["user_id"]: u["name"] for u in users}

    # ---------- DESCRIPTIVE
    role_count = Counter(u["role"] for u in users)
    app_status = Counter(a["status"] for a in apps)
    booking_status = Counter(b["status"] for b in bookings)
    task_status = Counter(t["status"] for t in tasks)
    active = [b for b in bookings if b["status"] in ACTIVE]
    by_weekday = [sum(1 for b in active if b["slot_date"].weekday() == i) for i in range(7)]
    by_hour = Counter(b["start_hour"] for b in active)
    decided = app_status.get("approved", 0) + app_status.get("declined", 0)

    per_adviser = []
    adviser_ids = [adviser_id] if adviser_id else [u["user_id"] for u in users if u["role"] == "adviser"]
    for aid in adviser_ids:
        prof = profiles.get(aid, {"capacity": 0, "advisees": 0})
        mine = [b for b in bookings if b["adviser_id"] == aid]
        cap = prof["capacity"] or 0
        per_adviser.append({
            "adviser_id": aid,
            "name": names.get(aid, f"Adviser {aid}"),
            "advisees": prof["advisees"],
            "capacity": cap,
            "utilization": round(100 * prof["advisees"] / cap) if cap else 0,
            "consultations": sum(1 for b in mine if b["status"] in ACTIVE),
            "completed": sum(1 for b in mine if b["status"] == "completed"),
            "cancelled": sum(1 for b in mine if b["status"] == "cancelled"),
            "avg_rating": (lambda rs: round(sum(rs) / len(rs), 1) if rs else None)([r["stars"] for r in ratings if r["adviser_id"] == aid]),
            "rating_count": sum(1 for r in ratings if r["adviser_id"] == aid),
        })
    per_adviser.sort(key=lambda r: (-r["utilization"], r["name"]))

    descriptive = {
        "totals": {
            "students": role_count.get("student", 0),
            "advisers": role_count.get("adviser", 0),
            "applications": len(apps),
            "pending": app_status.get("pending", 0),
            "consultations": len(active),
            "completed": booking_status.get("completed", 0),
            "tasks": len(tasks),
            "tasks_done": task_status.get("done", 0),
        },
        "application_status": [{"name": k, "value": app_status.get(k, 0)} for k in ("pending", "approved", "declined")],
        "booking_status": [{"name": k, "value": booking_status.get(k, 0)} for k in ("confirmed", "completed", "cancelled")],
        "task_status": [
            {"name": label, "value": task_status.get(k, 0)}
            for k, label in (("todo", "To Do"), ("in_progress", "In Progress"), ("review", "For Review"), ("done", "Done"))
        ],
        "by_weekday": [{"name": WEEKDAYS[i], "value": by_weekday[i]} for i in range(7)],
        "by_hour": [{"name": f"{h:02d}:00", "value": by_hour[h]} for h in sorted(by_hour)],
        "avg_rating": round(sum(r["stars"] for r in ratings) / len(ratings), 1) if ratings else None,
        "rating_count": len(ratings),
        "rating_distribution": [{"name": f"{s}★", "value": sum(1 for r in ratings if r["stars"] == s)} for s in range(1, 6)],
        "acceptance_rate": round(100 * app_status.get("approved", 0) / decided) if decided else None,
        "cancellation_rate": round(100 * booking_status.get("cancelled", 0) / len(bookings)) if bookings else None,
        "advisers": per_adviser,
    }

    # ---------- DIAGNOSTIC (bakit nagka-cancel?)
    cancelled = [b for b in bookings if b["status"] == "cancelled"]
    by_who = Counter()
    for b in cancelled:
        if b["cancelled_by"] == b["adviser_id"]:
            by_who["Adviser"] += 1
        elif b["cancelled_by"] == b["student_id"]:
            by_who["Student"] += 1
        else:
            by_who["Unknown"] += 1
    cancel_by_day = []
    for i in range(7):
        total_day = sum(1 for b in bookings if b["slot_date"].weekday() == i)
        canc_day = sum(1 for b in cancelled if b["slot_date"].weekday() == i)
        cancel_by_day.append({"name": WEEKDAYS[i], "total": total_day, "cancelled": canc_day,
                              "rate": round(100 * canc_day / total_day) if total_day else 0})
    unmarked = [b for b in bookings if b["status"] == "confirmed" and b["slot_date"] < today]
    diagnostic = {
        "cancelled_by": [{"name": k, "value": v} for k, v in by_who.items()],
        "cancel_by_weekday": cancel_by_day,
        "unmarked_past": len(unmarked),
    }
    notes = []
    if cancelled:
        top_who, top_n = by_who.most_common(1)[0]
        notes.append(f"{round(100 * top_n / len(cancelled))}% ng mga na-cancel na consultation ay galing sa {top_who.lower()}.")
        worst = max(cancel_by_day, key=lambda r: (r["rate"], r["total"]))
        if worst["total"] >= 3 and worst["rate"] > 0:
            notes.append(f"Pinakamataas ang cancellation rate tuwing {worst['name']} ({worst['rate']}%).")
    if unmarked:
        notes.append(f"{len(unmarked)} na lumipas na consultation ang hindi pa naka-mark na completed.")
    diagnostic["notes"] = notes

    # ---------- PREDICTIVE 1: demand forecast (linear regression sa lingguhang bilang)
    this_week = week_start(today)
    weeks = [this_week - datetime.timedelta(weeks=i) for i in range(HISTORY_WEEKS, 0, -1)]  # kumpletong linggo lang
    counts = {w: 0 for w in weeks}
    for b in active:
        w = week_start(b["slot_date"])
        if w in counts:
            counts[w] += 1
    history = [counts[w] for w in weeks]
    preds, slope, r2 = forecast(history, FORECAST_WEEKS)
    mae, naive_mae, tested = backtest_mae(history)
    series = [{"week": w.strftime("%b %d"), "actual": counts[w], "forecast": None} for w in weeks]
    if series:
        series[-1]["forecast"] = series[-1]["actual"]  # para magdugtong ang linya sa chart
    for i, p in enumerate(preds):
        w = this_week + datetime.timedelta(weeks=i)
        series.append({"week": w.strftime("%b %d"), "actual": None, "forecast": p})
    trend = "rising" if slope > 0.25 else "falling" if slope < -0.25 else "steady"

    # ---------- PREDICTIVE 2: progress at risk level ng bawat advisee
    app_by_id = {a["application_id"]: a for a in apps if a["status"] == "approved"}
    last_booking = defaultdict(lambda: None)
    for b in bookings:
        if b["status"] in ACTIVE and b["slot_date"] <= today:
            cur = last_booking[b["application_id"]]
            if cur is None or b["slot_date"] > cur:
                last_booking[b["application_id"]] = b["slot_date"]
    advisees = []
    for aid, a in app_by_id.items():
        mine = [t for t in tasks if t["application_id"] == aid]
        total, done = len(mine), sum(1 for t in mine if t["status"] == "done")
        dates = [t["updated_at"].date() for t in mine if t.get("updated_at")]
        for t in mine:
            if t.get("created_at"):
                dates.append(t["created_at"].date())
        if last_booking[aid]:
            dates.append(last_booking[aid])
        last_activity = max(dates) if dates else None
        days_inactive = (today - last_activity).days if last_activity else None
        start = a["date_submitted"].date() if hasattr(a["date_submitted"], "date") else a["date_submitted"]
        weeks_active = max((today - start).days / 7, 1.0)
        velocity = done / weeks_active
        eta = None
        if total and done < total and velocity > 0:
            eta = (today + datetime.timedelta(weeks=(total - done) / velocity)).isoformat()
        advisees.append({
            "application_id": aid,
            "student": a["student_name"],
            "adviser": a["adviser_name"],
            "total": total, "done": done,
            "progress": round(100 * done / total) if total else 0,
            "days_inactive": days_inactive,
            "velocity": round(velocity, 2),
            "eta": eta,
            "risk": risk_for(total, done, days_inactive, velocity),
        })
    order = {"Stalled": 0, "At risk": 1, "No tasks yet": 2, "On track": 3, "Complete": 4}
    advisees.sort(key=lambda r: (order[r["risk"]], r["student"]))

    predictive = {
        "demand": {
            "series": series, "slope": round(slope, 2), "r2": round(r2, 2), "trend": trend,
            "next_week": preds[0] if preds else 0,
            "mae": mae, "naive_mae": naive_mae, "tested_weeks": tested,
            "method": "Linear regression (least squares) sa bilang ng consultation kada linggo, huling %d na linggo" % HISTORY_WEEKS,
        },
        "advisees": advisees,
        "risk_counts": dict(Counter(a["risk"] for a in advisees)),
    }

    # ---------- PRESCRIPTIVE (ano ang dapat gawin?) rule-based
    recs = []
    if trend == "rising":
        recs.append({"level": "info", "text": f"Consultation demand is rising (+{round(slope, 1)} consultations per week). Open more time slots next week (about {preds[0]} are expected)."})
    elif trend == "falling":
        recs.append({"level": "info", "text": "Consultation demand is falling. Remind your advisees to book a consultation."})
    if any(by_weekday):
        top_day = WEEKDAYS[max(range(7), key=lambda i: by_weekday[i])]
        recs.append({"level": "info", "text": f"Most consultations happen on {top_day}. Make sure you have enough open time slots that day."})
    for a in advisees:
        if a["risk"] == "Stalled":
            recs.append({"level": "warn", "text": f"{a['student']} has had no activity for {a['days_inactive']} days. Follow up or schedule a consultation."})
        elif a["risk"] == "At risk":
            recs.append({"level": "warn", "text": f"{a['student']}'s progress is slow ({a['done']}/{a['total']} tasks complete). Break the work into smaller tasks and set deadlines."})
    for p in per_adviser:
        if p["capacity"] and p["utilization"] >= 90:
            recs.append({"level": "warn", "text": f"{p['name']} is at {p['utilization']}% capacity. Increase their capacity or direct new applicants to another adviser."})
    for p in per_adviser:
        if p["rating_count"] >= 3 and p["avg_rating"] is not None and p["avg_rating"] < 3.5:
            recs.append({"level": "warn", "text": f"{p['name']} has a low average rating ({p['avg_rating']}/5). Review the feedback and check in with them."})
    pending_old = [a for a in apps if a["status"] == "pending" and (today - (a["date_submitted"].date() if hasattr(a["date_submitted"], "date") else a["date_submitted"])).days >= 3]
    if pending_old:
        recs.append({"level": "warn", "text": f"{len(pending_old)} application(s) have been waiting for at least 3 days. Approve or decline them."})
    if unmarked:
        recs.append({"level": "info", "text": f"Mark {len(unmarked)} past consultation(s) as completed to keep records accurate."})
    if not recs:
        recs.append({"level": "ok", "text": "Everything is on track. No action is needed right now."})

    return {
        "scope": "adviser" if adviser_id else "system",
        "generated": today.isoformat(),
        "descriptive": descriptive,
        "diagnostic": diagnostic,
        "predictive": predictive,
        "prescriptive": recs,
    }


# ---------------------------------------------------------------- kumukuha ng data sa MySQL
def load_data(conn, adviser_id: Optional[int] = None) -> dict:
    scope_a = "WHERE a.adviser_id = :aid" if adviser_id else ""
    scope_b = "WHERE b.adviser_id = :aid" if adviser_id else ""
    p = {"aid": adviser_id} if adviser_id else {}

    users = [dict(r) for r in conn.execute(text("SELECT user_id, name, role FROM users")).mappings()]
    if adviser_id:  # adviser: sarili at mga advisee lang ang bilang
        ids = {adviser_id} | {r[0] for r in conn.execute(text("SELECT student_id FROM applications WHERE adviser_id = :aid"), p)}
        users = [u for u in users if u["user_id"] in ids]
    profiles = {
        r["adviser_id"]: {"capacity": r["max_capacity"] or 0, "advisees": r["current_advisee_count"] or 0}
        for r in conn.execute(text("SELECT adviser_id, max_capacity, current_advisee_count FROM adviser_profiles")).mappings()
    }
    apps = [dict(r) for r in conn.execute(
        text(
            "SELECT a.application_id, a.student_id, a.adviser_id, a.status, a.date_submitted, "
            "s.name AS student_name, v.name AS adviser_name FROM applications a "
            "JOIN users s ON s.user_id = a.student_id JOIN users v ON v.user_id = a.adviser_id " + scope_a
        ), p).mappings()]
    bookings = []
    for r in conn.execute(
        text("SELECT b.application_id, b.slot_date, b.start_time, b.status, b.adviser_id, b.student_id, b.cancelled_by FROM bookings b " + scope_b), p
    ).mappings():
        d = dict(r)
        st = d.pop("start_time")
        d["start_hour"] = int(st.total_seconds() // 3600) if isinstance(st, datetime.timedelta) else st.hour
        bookings.append(d)
    tasks = [dict(r) for r in conn.execute(
        text(
            "SELECT t.application_id, t.status, t.created_at, t.updated_at FROM kanban_tasks t "
            "JOIN applications a ON a.application_id = t.application_id " + scope_a
        ), p).mappings()]
    ratings = [dict(r) for r in conn.execute(
        text("SELECT r.stars, r.adviser_id FROM consultation_ratings r " + ("WHERE r.adviser_id = :aid" if adviser_id else "")), p
    ).mappings()]
    return {"users": users, "profiles": profiles, "applications": apps, "bookings": bookings, "tasks": tasks, "ratings": ratings}


def build_report(conn, adviser_id: Optional[int] = None) -> dict:
    return analyze(load_data(conn, adviser_id), datetime.date.today(), adviser_id)
