"""
AdviserLink API (Python / FastAPI) — Sprint 2

React web app and Flutter mobile app both communicate with this API.
Only the API directly accesses the MySQL database.

Sprint 1: register, login, /me, health
Sprint 2:
  - adviser profile + keyword search
  - application (apply, approve/decline, withdraw) + capacity check
  - adviser availability and consultation booking (online / in-person)
    with conflict detection, cancel (with reason), and mark as completed
  - Kanban/Agile board per advisee (only adviser can comment)
  - student document upload (visible to adviser)
  - notifications (in-app + reminder before consultation starts)
"""
import datetime
import base64
import logging
import mimetypes
import os
import re
import secrets
import threading
import uuid
from typing import Literal, Optional
from urllib.parse import urlsplit

import bcrypt
import jwt
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator
from sqlalchemy import create_engine, text

from analytics import build_report
from attention import build_attention
from matching import match_score, tokenize
from db_setup import ensure_schema
from message_moderation import analyze_message
from board_workflow import can_comment_on_task, can_manage_application, can_transition_task
from security import LoginThrottle, file_matches_type
from scheduling import (
    DAYS, SLOT_MINUTES, build_slots, day_name, overlaps, to_hhmm, to_minutes,
)
load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env"))
from email_utils import send_verification_email, send_password_reset_email, get_dev_token

APP_ENV = os.getenv("APP_ENV", "development").strip().lower()
DATABASE_URL = os.getenv("DATABASE_URL", "mysql+pymysql://root:@localhost:3306/adviserlink_db")
RUN_SCHEMA_MIGRATIONS = os.getenv("RUN_SCHEMA_MIGRATIONS", "false" if APP_ENV == "production" else "true").lower() == "true"
def _load_secret() -> str:
    """Loads JWT secret from .env or generates a persistent random one.
    If no valid secret in .env, creates one and saves to backend/.jwt_secret
    so users stay logged in across restarts."""
    value = os.getenv("JWT_SECRET", "").strip()
    if value and not value.lower().startswith("palitan") and value != "dev-only-secret-palitan-sa-env" and len(value) >= 16:
        return value
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".jwt_secret")
    if os.path.exists(path):
        with open(path) as f:
            saved = f.read().strip()
        if len(saved) >= 32:
            return saved
    saved = secrets.token_hex(32)
    with open(path, "w") as f:
        f.write(saved)
    print("[AdviserLink] No secure JWT_SECRET in .env, generated random secret in backend/.jwt_secret. "
          "Set a long random JWT_SECRET in .env for production.")
    return saved


JWT_SECRET = _load_secret()
CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173,http://localhost:8080,http://127.0.0.1:8080,http://localhost:5001,http://127.0.0.1:5001").split(",") if o.strip()]
# For development, allow all origins if CORS_ORIGINS contains "*"
if "*" in CORS_ORIGINS:
    CORS_ORIGINS = ["*"]
ALLOWED_EMAIL_DOMAIN = os.getenv("ALLOWED_EMAIL_DOMAIN", "").strip().lower().lstrip("@")  # hal. isu.edu.ph (opsyonal)
SKIP_EMAIL_VERIFICATION = os.getenv("SKIP_EMAIL_VERIFICATION", "false").lower() == "true"
throttle = LoginThrottle()
JWT_HOURS = int(os.getenv("JWT_HOURS", "8"))
UPLOAD_DIR = os.getenv("UPLOAD_DIR", "").strip() or os.path.join(os.path.dirname(os.path.abspath(__file__)), "uploads")
MAX_UPLOAD_BYTES = 10 * 1024 * 1024
ALLOWED_EXT = {"pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "txt", "png", "jpg", "jpeg", "zip"}
REMINDER_MINUTES = 15
BOOKING_WATCHDOG_SECONDS = 5

os.makedirs(UPLOAD_DIR, exist_ok=True)
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
_booking_watchdog_stop = threading.Event()
_booking_watchdog_thread = None
app = FastAPI(
    title="AdviserLink API",
    version="0.2.0",
    docs_url=None if APP_ENV == "production" else "/docs",
    openapi_url=None if APP_ENV == "production" else "/openapi.json",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_methods=["*"],
    allow_headers=["*"],
)
bearer = HTTPBearer(auto_error=False)


@app.on_event("startup")
def startup() -> None:
    global _booking_watchdog_thread
    if APP_ENV == "production":
        configured_secret = os.getenv("JWT_SECRET", "").strip()
        if (len(configured_secret) < 32 or configured_secret.lower().startswith("palitan")
                or configured_secret == "dev-only-secret-palitan-sa-env"):
            raise RuntimeError("Production requires a configured JWT_SECRET with at least 32 characters.")
        if not os.getenv("APP_BASE_URL", "").startswith("https://"):
            raise RuntimeError("Production requires APP_BASE_URL to use HTTPS.")
        if not CORS_ORIGINS or any(not origin.startswith("https://") for origin in CORS_ORIGINS) or "*" in CORS_ORIGINS:
            raise RuntimeError("Production CORS_ORIGINS must contain only explicit HTTPS origins.")
        if not all(os.getenv(key, "").strip() for key in ("SMTP_HOST", "SMTP_USER", "SMTP_PASS", "SMTP_FROM")):
            raise RuntimeError("Production requires SMTP_HOST, SMTP_USER, SMTP_PASS, and SMTP_FROM.")
        if SKIP_EMAIL_VERIFICATION:
            raise RuntimeError("SKIP_EMAIL_VERIFICATION must be false in production.")
        if not os.getenv("UPLOAD_DIR", "").strip():
            raise RuntimeError("Production requires UPLOAD_DIR to point to persistent file storage.")
        if (engine.url.username or "").lower() == "root":
            raise RuntimeError("Production must use a least-privilege application database user, not root.")
        if RUN_SCHEMA_MIGRATIONS:
            raise RuntimeError("Production schema migrations must run separately with a migration account.")
    if RUN_SCHEMA_MIGRATIONS:
        ensure_schema(engine)
    if _booking_watchdog_thread is None or not _booking_watchdog_thread.is_alive():
        _booking_watchdog_stop.clear()
        _booking_watchdog_thread = threading.Thread(target=_booking_watchdog, daemon=True)
        _booking_watchdog_thread.start()


@app.on_event("shutdown")
def shutdown() -> None:
    _booking_watchdog_stop.set()
    if _booking_watchdog_thread and _booking_watchdog_thread.is_alive():
        _booking_watchdog_thread.join(timeout=BOOKING_WATCHDOG_SECONDS + 1)


# =====================================================================
# request models (server-side validation happens here)
# =====================================================================
ADVISER_DEPARTMENTS = (
    "Information Technology",
    "Computer Science",
    "Information Systems",
    "Data Science and Analytics",
    "Library and Information Science",
)


class RegisterIn(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    email: EmailStr
    password: str = Field(min_length=8)
    confirm_password: str
    role: Literal["student", "adviser"]
    student_group_role: Literal["leader", "member"] = "leader"
    department: Optional[Literal[
        "Information Technology",
        "Computer Science",
        "Information Systems",
        "Data Science and Analytics",
        "Library and Information Science",
    ]] = None
    profile_photo: Optional[str] = Field(default=None, max_length=2_800_000)

    @field_validator("name")
    @classmethod
    def clean_name(cls, v: str) -> str:
        return v.strip()

    @field_validator("password")
    @classmethod
    def password_size(cls, v: str) -> str:
        if len(v.encode("utf-8")) > 72:
            raise ValueError("Password is too long (72 bytes max).")
        return v

    @model_validator(mode="after")
    def passwords_match(self):
        if self.password != self.confirm_password:
            raise ValueError("The two passwords do not match.")
        if self.role == "adviser" and not self.department:
            raise ValueError("Choose your department.")
        return self


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class ChangePasswordIn(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8)
    confirm_password: str

    @field_validator("new_password")
    @classmethod
    def new_size(cls, v: str) -> str:
        if len(v.encode("utf-8")) > 72:
            raise ValueError("Password is too long (72 bytes max).")
        return v

    @model_validator(mode="after")
    def match(self):
        if self.new_password != self.confirm_password:
            raise ValueError("The two new passwords do not match.")
        return self


class StatusIn(BaseModel):
    status: Literal["active", "disabled"]


class MeIn(BaseModel):
    name: str = Field(min_length=2, max_length=100)
    contact_number: Optional[str] = Field(default=None, max_length=20)
    research_interests: Optional[str] = Field(default=None, max_length=500)
    thesis_title: Optional[str] = Field(default=None, min_length=10, max_length=500)


class ProfileIn(BaseModel):
    department: Literal[
        "Information Technology",
        "Computer Science",
        "Information Systems",
        "Data Science and Analytics",
        "Library and Information Science",
    ]
    specialization_tags: str = Field(default="", max_length=500)
    certifications: Optional[str] = Field(default=None, max_length=500)
    max_capacity: int = Field(ge=1, le=50)


class AvailabilityIn(BaseModel):
    day_of_week: Optional[Literal["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]] = None
    specific_date: Optional[datetime.date] = None
    start_time: str
    end_time: str

    @model_validator(mode="after")
    def check(self):
        if (self.day_of_week is None) == (self.specific_date is None):
            raise ValueError("Choose either a weekday or a specific date.")
        try:
            s, e = to_minutes(self.start_time), to_minutes(self.end_time)
        except ValueError as err:
            raise ValueError(str(err))
        if e - s != SLOT_MINUTES:
            raise ValueError(f"Each open time must be exactly {SLOT_MINUTES} minutes.")
        return self


class ApplicationIn(BaseModel):
    adviser_id: int
    topic_brief: str = Field(min_length=10, max_length=2000)


class AppStatusIn(BaseModel):
    status: Literal["approved", "declined"]


class BookingIn(BaseModel):
    # Ang student ay pumipili lang ng petsa/oras. Ang adviser ang magse-set ng online/in-person at location.
    adviser_id: int
    slot_date: datetime.date
    start_time: str
    notes: str = Field(min_length=1, max_length=1000)

    @field_validator("notes")
    @classmethod
    def clean_notes(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Please tell us what you will discuss.")
        return cleaned


class MeetingIn(BaseModel):
    meeting_type: Literal["online", "in-person"]
    location: Optional[str] = Field(default=None, max_length=255)

    @model_validator(mode="after")
    def normalize_online_link(self):
        if self.meeting_type != "online" or not self.location:
            return self

        location = self.location.strip()
        if not location:
            self.location = None
            return self

        candidate = location if re.match(r"^https?://", location, re.IGNORECASE) else f"https://{location}"
        try:
            parsed = urlsplit(candidate)
            hostname = (parsed.hostname or "").rstrip(".")
            valid = (
                parsed.scheme.lower() in ("http", "https")
                and hostname
                and (hostname.lower() == "localhost" or "." in hostname or ":" in hostname)
                and parsed.username is None
                and parsed.password is None
                and not any(char.isspace() for char in candidate)
            )
            if parsed.port is not None and not 1 <= parsed.port <= 65535:
                valid = False
        except ValueError:
            valid = False
        if not valid:
            raise ValueError("Enter a valid online meeting link beginning with http:// or https://.")
        self.location = candidate
        return self


class RescheduleIn(BaseModel):
    slot_date: datetime.date
    start_time: str


class RatingIn(BaseModel):
    stars: int = Field(ge=1, le=5)
    comment: Optional[str] = Field(default=None, max_length=500)


class CancelIn(BaseModel):
    reason: Optional[str] = Field(default=None, max_length=500)


class CompleteIn(BaseModel):
    stage_status: Optional[str] = Field(default=None, max_length=100)
    remarks: Optional[str] = Field(default=None, max_length=2000)


class TaskIn(BaseModel):
    title: str = Field(min_length=1, max_length=150)
    description: Optional[str] = Field(default=None, max_length=2000)
    due_date: Optional[datetime.date] = None


class TaskPatch(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=150)
    description: Optional[str] = Field(default=None, max_length=2000)
    status: Optional[Literal["todo", "in_progress", "review", "done"]] = None
    due_date: Optional[datetime.date] = None


# ---- Email verification & password reset ----
class VerifyEmailIn(BaseModel):
    token: str


class ResendVerificationIn(BaseModel):
    email: EmailStr


class ForgotPasswordIn(BaseModel):
    email: EmailStr


class ResetPasswordIn(BaseModel):
    token: str
    new_password: str = Field(min_length=8)
    confirm_password: str

    @field_validator("new_password")
    @classmethod
    def new_size(cls, v: str) -> str:
        if len(v.encode("utf-8")) > 72:
            raise ValueError("Password is too long (72 bytes max).")
        return v

    @model_validator(mode="after")
    def match(self):
        if self.new_password != self.confirm_password:
            raise ValueError("The two passwords do not match.")
        return self


class PhotoUploadIn(BaseModel):
    # Base64 encoded image (data URL or raw base64)
    image: str = Field(max_length=2_800_000)


# ---- Phase B: New request models ----
class MessageIn(BaseModel):
    body: str = Field(min_length=1, max_length=5000)


class MilestoneIn(BaseModel):
    title: str = Field(min_length=1, max_length=150)
    description: Optional[str] = Field(default=None, max_length=2000)
    stage: Literal["title_defense", "chapters_1_3", "proposal_defense", "final_defense", "custom"]
    due_date: Optional[datetime.date] = None


class MilestonePatch(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=150)
    description: Optional[str] = Field(default=None, max_length=2000)
    stage: Optional[Literal["title_defense", "chapters_1_3", "proposal_defense", "final_defense", "custom"]] = None
    due_date: Optional[datetime.date] = None
    status: Optional[Literal["pending", "in_progress", "completed", "overdue"]] = None


class DocumentVersionIn(BaseModel):
    file: UploadFile = File(...)
    comment: Optional[str] = Field(default=None, max_length=500)


class AvailabilityExceptionIn(BaseModel):
    specific_date: datetime.date
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    reason: Optional[str] = Field(default=None, max_length=255)
    is_all_day: bool = False

    @model_validator(mode="after")
    def check_times(self):
        if not self.is_all_day and (self.start_time is None or self.end_time is None):
            raise ValueError("Start and end time required unless all-day.")
        if self.start_time and self.end_time:
            s, e = to_minutes(self.start_time), to_minutes(self.end_time)
            if e - s < SLOT_MINUTES:
                raise ValueError(f"The window must be at least {SLOT_MINUTES} minutes long.")
        return self


class WaitlistIn(BaseModel):
    adviser_id: int
    topic_brief: str = Field(min_length=10, max_length=2000)


class GroupInvitationIn(BaseModel):
    student_email: EmailStr


class StudentGroupRequestIn(BaseModel):
    user_id: int = Field(gt=0)


class StudentGroupRequestDecisionIn(BaseModel):
    status: Literal["approved", "declined"]


class GroupJoinDecisionIn(BaseModel):
    status: Literal["approved", "declined"]


class AdminActionIn(BaseModel):
    action: str
    target_type: str
    target_id: int
    details: Optional[str] = None


# =====================================================================
# helpers
# =====================================================================
def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(password: str, stored: str) -> bool:
    # PHP password_hash() produces "$2y$..." bcrypt. Same as Python's "$2b$"
    # so accounts created in PHP version still work.
    if not stored.startswith("$2"):
        return False  # plain-text content (dummy data), reject
    try:
        return bcrypt.checkpw(password.encode("utf-8"), stored.replace("$2y$", "$2b$", 1).encode("utf-8"))
    except ValueError:
        return False


def make_token(user: dict) -> str:
    payload = {
        "sub": str(user["user_id"]),
        "role": user["role"],
        "exp": datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=JWT_HOURS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


def public_user(row) -> dict:
    return {
        "user_id": row["user_id"],
        "name": row["name"],
        "email": row["email"],
        "role": row["role"],
        "contact_number": row.get("contact_number") if hasattr(row, "get") else None,
        "profile_photo": row.get("profile_photo") if hasattr(row, "get") else None,
        "student_group_role": row.get("student_group_role") if hasattr(row, "get") else None,
        "research_interests": row.get("research_interests") if hasattr(row, "get") else None,
        "thesis_title": row.get("thesis_title") if hasattr(row, "get") else None,
        "title_setup_required": bool(row.get("title_setup_required")) if hasattr(row, "get") else False,
    }


def clean(row) -> dict:
    """Converts row to JSON-friendly format (TIME -> 'HH:MM', DATE/DATETIME -> text)."""
    out = {}
    for k, v in dict(row).items():
        if isinstance(v, datetime.timedelta):
            out[k] = to_hhmm(to_minutes(v))
        elif isinstance(v, datetime.datetime):
            out[k] = v.strftime("%Y-%m-%d %H:%M:%S")
        elif isinstance(v, datetime.date):
            out[k] = v.isoformat()
        elif isinstance(v, datetime.time):
            out[k] = v.strftime("%H:%M")
        else:
            out[k] = v
    return out


def current_user(creds: HTTPAuthorizationCredentials = Depends(bearer)) -> dict:
    if creds is None:
        raise HTTPException(401, "Not logged in.")
    try:
        data = jwt.decode(creds.credentials, JWT_SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        raise HTTPException(401, "Session expired. Please log in again.")
    with engine.connect() as conn:
        row = conn.execute(
            text("SELECT user_id, name, email, role, contact_number, profile_photo, account_status, student_group_role, research_interests, thesis_title, title_setup_required FROM users WHERE user_id = :id"),
            {"id": int(data["sub"])},
        ).mappings().first()
    if row is None:
        raise HTTPException(401, "Account no longer exists.")
    if row["account_status"] != "active":
        raise HTTPException(403, "Your account is not active. Please contact the admin.")
    return public_user(row)


def need_role(role: str):
    def dep(user: dict = Depends(current_user)) -> dict:
        if user["role"] != role:
            raise HTTPException(403, f"Only {role}s can do this.")
        return user
    return dep


student_only = need_role("student")
adviser_only = need_role("adviser")
admin_only = need_role("admin")


def notify(
    conn,
    user_id: int,
    message: str,
    related_user_id: int = None,
    related_application_id: int = None,
    related_message_id: int = None,
) -> None:
    conn.execute(
        text(
            "INSERT INTO notifications "
            "(user_id, message, type, related_user_id, related_application_id, related_message_id) "
            "VALUES (:u, :m, 'in-app', :related_user_id, :related_application_id, :related_message_id)"
        ),
        {
            "u": user_id,
            "m": message,
            "related_user_id": related_user_id,
            "related_application_id": related_application_id,
            "related_message_id": related_message_id,
        },
    )


AUTOMATED_MODERATION_WARNING = (
    "Automated moderation warning: Please keep this conversation respectful. "
    "An administrator has been notified and may review the message."
)


def store_chat_message(
    conn,
    application_id: int,
    sender_id: int,
    message_body: str,
    notification_targets: list[tuple[int, str]],
) -> int:
    language_code, categories = analyze_message(message_body)
    category_text = ", ".join(categories) if categories else None
    active_admin_ids = []
    if categories:
        active_admin_ids = conn.execute(
            text("SELECT user_id FROM users WHERE role = 'admin' AND account_status = 'active' ORDER BY user_id")
        ).scalars().all()
        if not active_admin_ids:
            raise HTTPException(503, "Message moderation is unavailable because no active administrator is configured.")

    result = conn.execute(
        text(
            "INSERT INTO messages "
            "(application_id, sender_id, body, message_kind, language_code, moderation_categories) "
            "VALUES (:a, :u, :b, 'user', :language, :categories)"
        ),
        {
            "a": application_id,
            "u": sender_id,
            "b": message_body,
            "language": language_code,
            "categories": category_text,
        },
    )
    for recipient_id, notification in notification_targets:
        notify(
            conn,
            recipient_id,
            notification,
            related_user_id=sender_id,
            related_application_id=application_id,
            related_message_id=result.lastrowid,
        )

    if categories:
        conn.execute(
            text(
                "INSERT INTO messages "
                "(application_id, sender_id, body, message_kind, language_code, moderation_categories) "
                "VALUES (:a, :u, :b, 'moderation_warning', 'unknown', NULL)"
            ),
            {
                "a": application_id,
                "u": active_admin_ids[0],
                "b": AUTOMATED_MODERATION_WARNING,
            },
        )
        for admin_id in active_admin_ids:
            notify(
                conn,
                admin_id,
                f"Chat moderation alert for application {application_id}: flagged for "
                f"{category_text}. An automated warning was posted.",
                related_user_id=sender_id,
                related_application_id=application_id,
                related_message_id=result.lastrowid,
            )

    return result.lastrowid


def log_login_attempt(conn, email: str, ip: str, user_agent: str, success: bool, user_id: int = None, failure_reason: str = None) -> None:
    """Log login attempt to login_history table."""
    conn.execute(
        text("""
            INSERT INTO login_history (user_id, email_attempted, ip_address, user_agent, success, failure_reason)
            VALUES (:uid, :email, :ip, :ua, :success, :reason)
        """),
        {"uid": user_id, "email": email, "ip": ip, "ua": user_agent, "success": 1 if success else 0, "reason": failure_reason},
    )


def log_audit(conn, user_id: int, action: str, target_type: str, target_id: int = None,
              old_values: dict = None, new_values: dict = None, request: Request = None) -> None:
    """Log audit trail to audit_logs table."""
    ip = request.client.host if request and request.client else None
    ua = request.headers.get("user-agent") if request else None
    conn.execute(
        text("""
            INSERT INTO audit_logs (user_id, action, target_type, target_id, old_values, new_values, ip_address, user_agent)
            VALUES (:uid, :action, :ttype, :tid, :old, :new, :ip, :ua)
        """),
        {
            "uid": user_id,
            "action": action,
            "ttype": target_type,
            "tid": target_id,
            "old": json.dumps(old_values) if old_values else None,
            "new": json.dumps(new_values) if new_values else None,
            "ip": ip,
            "ua": ua,
        },
    )


import json


def pretty_slot(d: datetime.date, start_min: int) -> str:
    h, m = divmod(start_min, 60)
    suffix = "AM" if h < 12 else "PM"
    h12 = h % 12 or 12
    return f"{d.strftime('%b')} {d.day}, {h12}:{m:02d} {suffix}"


def fetch_slots(conn, adviser_id: int, start: datetime.date, end: datetime.date, student_id: Optional[int] = None):
    """Generates 30-minute slots from adviser availability, marks as unavailable
    slots with confirmed bookings (or if student already has a booking at that time)."""
    windows = conn.execute(
        text("SELECT day_of_week, specific_date, start_time, end_time FROM availability WHERE adviser_id = :a"),
        {"a": adviser_id},
    ).mappings().all()
    booked_rows = conn.execute(
        text(
            "SELECT slot_date, start_time, end_time, student_id FROM bookings "
            "WHERE adviser_id = :a AND status = 'confirmed' AND slot_date BETWEEN :s AND :e"
        ),
        {"a": adviser_id, "s": start, "e": end},
    ).mappings().all()
    mine = []
    if student_id is not None:
        mine = conn.execute(
            text(
                "SELECT slot_date, start_time, end_time FROM bookings "
                "WHERE student_id = :st AND status = 'confirmed' AND slot_date BETWEEN :s AND :e"
            ),
            {"st": student_id, "s": start, "e": end},
        ).mappings().all()
    now = datetime.datetime.now()
    result = []
    day = start
    while day <= end:
        todays = [
            (to_minutes(w["start_time"]), to_minutes(w["end_time"]))
            for w in windows
            if (w["specific_date"] is not None and w["specific_date"] == day)
            or (w["specific_date"] is None and w["day_of_week"] == day_name(day))
        ]
        booked = [(to_minutes(b["start_time"]), to_minutes(b["end_time"])) for b in booked_rows if b["slot_date"] == day]
        my_busy = [(to_minutes(b["start_time"]), to_minutes(b["end_time"])) for b in mine if b["slot_date"] == day]
        for slot in build_slots(todays, booked, day, now):
            s0, s1 = to_minutes(slot["start"]), to_minutes(slot["end"])
            busy = any(overlaps(s0, s1, m0, m1) for m0, m1 in my_busy)
            result.append({
                "date": day.isoformat(),
                "start": slot["start"],
                "end": slot["end"],
                "available": slot["available"] and not busy,
                "reason": None if slot["available"] and not busy else ("You already have a booking at this time." if busy else "Already booked."),
            })
        day += datetime.timedelta(days=1)
    return result


def get_application(conn, application_id: int, user: dict) -> dict:
    row = conn.execute(
        text(
            "SELECT a.application_id, a.student_id, a.adviser_id, a.topic_brief, a.status, "
            "s.name AS student_name, s.profile_photo AS student_profile_photo, "
            "v.name AS adviser_name, v.profile_photo AS adviser_profile_photo "
            "FROM applications a JOIN users s ON s.user_id = a.student_id "
            "JOIN users v ON v.user_id = a.adviser_id WHERE a.application_id = :id"
        ),
        {"id": application_id},
    ).mappings().first()
    if row is None:
        raise HTTPException(404, "Application not found.")
    is_group_member = conn.execute(
        text("SELECT 1 FROM application_groups WHERE application_id = :a AND student_id = :u"),
        {"a": application_id, "u": user["user_id"]},
    ).first()
    if not can_access_application(user["user_id"], row["student_id"], row["adviser_id"], bool(is_group_member)):
        raise HTTPException(403, "This is not your application.")
    return dict(row)


def can_access_application(user_id: int, student_id: int, adviser_id: int, is_group_member: bool) -> bool:
    return user_id in (student_id, adviser_id) or is_group_member


def can_manage_group_members(user: dict, is_leader: bool) -> bool:
    return user["role"] == "student" and is_leader


def is_public_profile_photo(filename: str) -> bool:
    return bool(re.fullmatch(r"photo_[0-9]+_[a-f0-9]{16}\.(?:png|jpg|jpeg|webp)", filename))


def get_approved_application(conn, application_id: int, user: dict) -> dict:
    row = get_application(conn, application_id, user)
    if row["status"] != "approved":
        raise HTTPException(409, "This is available once the adviser approves the application.")
    return row


def is_application_leader(conn, app_row: dict, user: dict) -> bool:
    if user["role"] != "student":
        return False
    if user["user_id"] == app_row["student_id"]:
        return True
    return conn.execute(
        text(
            "SELECT 1 FROM application_groups "
            "WHERE application_id = :a AND student_id = :u AND is_leader = 1"
        ),
        {"a": app_row["application_id"], "u": user["user_id"]},
    ).first() is not None


def other_party(app_row: dict, user: dict) -> int:
    return app_row["adviser_id"] if user["user_id"] == app_row["student_id"] else app_row["student_id"]


def cancel_unaccepted_bookings(conn, now: datetime.datetime) -> None:
    rows = conn.execute(
        text(
            "SELECT b.booking_id, b.application_id, b.student_id, b.adviser_id, b.slot_date, b.start_time, "
            "s.name AS student_name, v.name AS adviser_name FROM bookings b "
            "JOIN users s ON s.user_id = b.student_id JOIN users v ON v.user_id = b.adviser_id "
            "WHERE b.status = 'confirmed' AND b.leader_accepted = 0 "
            "AND (b.slot_date < :today OR (b.slot_date = :today AND b.start_time <= :time))"
        ),
        {"today": now.date(), "time": now.time()},
    ).mappings().all()
    reason = "Automatically cancelled because the group leader did not accept the meeting details before the consultation started."
    for row in rows:
        updated = conn.execute(
            text(
                "UPDATE bookings SET status = 'cancelled', cancel_reason = :reason "
                "WHERE booking_id = :id AND status = 'confirmed' AND leader_accepted = 0"
            ),
            {"reason": reason, "id": row["booking_id"]},
        )
        if updated.rowcount:
            when = pretty_slot(row["slot_date"], to_minutes(row["start_time"]))
            message = f"Consultation on {when} was automatically cancelled because the group leader did not accept the meeting details before it started."
            notify(conn, row["student_id"], message, related_user_id=row["adviser_id"])
            notify(conn, row["adviser_id"], message, related_user_id=row["student_id"])


def complete_accepted_bookings(conn, now: datetime.datetime) -> None:
    params = {"today": now.date(), "time": now.time()}
    rows = conn.execute(
        text(
            "SELECT b.booking_id, b.student_id, b.adviser_id, b.slot_date, b.start_time, v.name AS adviser_name "
            "FROM bookings b JOIN users v ON v.user_id = b.adviser_id "
            "WHERE b.status = 'confirmed' AND b.leader_accepted = 1 "
            "AND (b.slot_date < :today OR (b.slot_date = :today AND b.end_time <= :time))"
            " FOR UPDATE"
        ),
        params,
    ).mappings().all()
    for row in rows:
        updated = conn.execute(
            text(
                "UPDATE bookings SET status = 'completed' "
                "WHERE booking_id = :id AND status = 'confirmed' AND leader_accepted = 1"
            ),
            {"id": row["booking_id"]},
        )
        if updated.rowcount:
            when = pretty_slot(row["slot_date"], to_minutes(row["start_time"]))
            notify(
                conn,
                row["student_id"],
                f"Your consultation with {row['adviser_name']} on {when} has been marked completed. You can now rate your adviser.",
                related_user_id=row["adviser_id"],
            )


def run_reminders(conn) -> None:
    """Create one-time reminders for upcoming consultations and project deadlines."""
    now = datetime.datetime.now()
    cancel_unaccepted_bookings(conn, now)
    rows = conn.execute(
        text(
            "SELECT b.booking_id, b.slot_date, b.start_time, b.student_id, b.adviser_id, "
            "s.name AS student_name, v.name AS adviser_name FROM bookings b "
            "JOIN users s ON s.user_id = b.student_id JOIN users v ON v.user_id = b.adviser_id "
            "WHERE b.status = 'confirmed' AND b.reminded = 0 AND b.slot_date BETWEEN :d0 AND :d1"
        ),
        {"d0": now.date(), "d1": now.date() + datetime.timedelta(days=1)},
    ).mappings().all()
    for r in rows:
        start_min = to_minutes(r["start_time"])
        start_dt = datetime.datetime.combine(r["slot_date"], datetime.time(start_min // 60, start_min % 60))
        left = (start_dt - now).total_seconds() / 60
        if 0 <= left <= REMINDER_MINUTES:
            when = pretty_slot(r["slot_date"], start_min)
            notify(
                conn,
                r["student_id"],
                f"Reminder: your consultation with {r['adviser_name']} starts soon ({when}).",
                related_user_id=r["adviser_id"],
            )
            notify(
                conn,
                r["adviser_id"],
                f"Reminder: your consultation with {r['student_name']} starts soon ({when}).",
                related_user_id=r["student_id"],
            )
            conn.execute(text("UPDATE bookings SET reminded = 1 WHERE booking_id = :id"), {"id": r["booking_id"]})
    deadlines = conn.execute(
        text(
            "SELECT 'task' AS kind, t.task_id AS item_id, t.application_id, t.title, t.due_date, "
            "a.adviser_id FROM kanban_tasks t JOIN applications a ON a.application_id = t.application_id "
            "WHERE t.due_date = CURDATE() + INTERVAL 1 DAY AND t.status != 'done' AND t.reminder_sent_at IS NULL "
            "AND a.status = 'approved' "
            "UNION ALL "
            "SELECT 'milestone' AS kind, m.milestone_id AS item_id, m.application_id, m.title, m.due_date, "
            "a.adviser_id FROM milestones m JOIN applications a ON a.application_id = m.application_id "
            "WHERE m.due_date = CURDATE() + INTERVAL 1 DAY AND m.status != 'completed' AND m.reminder_sent_at IS NULL "
            "AND a.status = 'approved'"
        )
    ).mappings().all()
    for deadline in deadlines:
        students = conn.execute(
            text("SELECT student_id FROM application_groups WHERE application_id = :a"),
            {"a": deadline["application_id"]},
        ).scalars().all()
        label = "Task" if deadline["kind"] == "task" else "Milestone"
        message = f"{label} due tomorrow: {deadline['title']}."
        for student_id in students:
            notify(conn, student_id, message)
        notify(conn, deadline["adviser_id"], message)
        table = "kanban_tasks" if deadline["kind"] == "task" else "milestones"
        id_column = "task_id" if deadline["kind"] == "task" else "milestone_id"
        conn.execute(
            text(f"UPDATE {table} SET reminder_sent_at = NOW() WHERE {id_column} = :id"),
            {"id": deadline["item_id"]},
        )


def _booking_watchdog() -> None:
    while not _booking_watchdog_stop.is_set():
        try:
            with engine.begin() as conn:
                now = datetime.datetime.now()
                cancel_unaccepted_bookings(conn, now)
                complete_accepted_bookings(conn, now)
        except Exception:
            logging.exception("Consultation status auto-update failed.")
        if _booking_watchdog_stop.wait(BOOKING_WATCHDOG_SECONDS):
            break


def decode_profile_photo(image_data: str) -> tuple[str, bytes]:
    match = re.fullmatch(r"data:(image/(?:png|jpeg|jpg|webp));base64,([A-Za-z0-9+/=]+)", image_data)
    if image_data.startswith("data:") and not match:
        raise HTTPException(400, "Choose a valid PNG, JPEG, or WebP image.")
    if match:
        mime_type, encoded = match.groups()
        ext = {"image/png": "png", "image/jpeg": "jpg", "image/jpg": "jpg", "image/webp": "webp"}[mime_type]
    else:
        ext, encoded = "png", image_data

    try:
        binary_data = base64.b64decode(encoded, validate=True)
    except Exception:
        raise HTTPException(400, "Invalid image data.")

    if not binary_data or len(binary_data) > 2 * 1024 * 1024:
        raise HTTPException(413, "Profile photos must be smaller than 2 MB.")

    is_webp = ext == "webp" and binary_data.startswith(b"RIFF") and binary_data[8:12] == b"WEBP"
    if not (is_webp or (ext != "webp" and file_matches_type(ext, binary_data[:16]))):
        raise HTTPException(400, "The image content does not match its file type.")
    return ext, binary_data


def store_profile_photo(user_id: int, decoded_photo: tuple[str, bytes]) -> tuple[str, str]:
    ext, binary_data = decoded_photo
    stored = f"photo_{user_id}_{secrets.token_hex(8)}.{ext}"
    path = os.path.join(UPLOAD_DIR, stored)
    with open(path, "wb") as photo_file:
        photo_file.write(binary_data)
    return f"/api/uploads/{stored}", path


def remove_profile_photo_file(photo_url: str | None, user_id: int) -> None:
    if not photo_url:
        return
    match = re.fullmatch(rf"/api/uploads/(photo_{user_id}_[a-f0-9]{{16}}\.(?:png|jpg|jpeg|webp))", photo_url)
    if not match:
        return
    path = os.path.join(UPLOAD_DIR, match.group(1))
    try:
        os.remove(path)
    except FileNotFoundError:
        pass


# =====================================================================
# Sprint 1 endpoints
# =====================================================================
@app.get("/api/health")
def health():
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return {"status": "ok", "database": "connected"}


@app.post("/api/register", status_code=201)
def register(body: RegisterIn, request: Request):
    email = body.email.lower()
    if ALLOWED_EMAIL_DOMAIN and not email.endswith("@" + ALLOWED_EMAIL_DOMAIN):
        raise HTTPException(400, f"Please register with your @{ALLOWED_EMAIL_DOMAIN} email address.")
    account_status = "pending" if body.role == "adviser" else "active"
    verify_token = secrets.token_urlsafe(32)
    verify_expires = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=24)
    email_verified = 1 if SKIP_EMAIL_VERIFICATION else 0
    decoded_photo = decode_profile_photo(body.profile_photo) if body.profile_photo else None
    stored_photo_path = None
    profile_photo_url = None
    try:
        with engine.begin() as conn:
            taken = conn.execute(text("SELECT 1 FROM users WHERE LOWER(email) = :e"), {"e": email}).first()
            if taken:
                raise HTTPException(409, "That email is already registered. Log in instead.")
            result = conn.execute(
                text("""INSERT INTO users (name, email, password, role, student_group_role, account_status, email_verified, password_reset_token, password_reset_expires, title_setup_required)
                        VALUES (:n, :e, :p, :r, :gr, :s, :ev, :vt, :ve, :title_required)"""),
                {"n": body.name, "e": email, "p": hash_password(body.password), "r": body.role, "s": account_status,
                 "gr": body.student_group_role if body.role == "student" else None,
                 "ev": email_verified, "vt": verify_token, "ve": verify_expires,
                 "title_required": 1 if body.role == "student" else 0},
            )
            user_id = result.lastrowid
            if decoded_photo:
                profile_photo_url, stored_photo_path = store_profile_photo(user_id, decoded_photo)
                conn.execute(text("UPDATE users SET profile_photo = :photo WHERE user_id = :id"), {"photo": profile_photo_url, "id": user_id})
            if body.role == "adviser":
                conn.execute(
                    text(
                        "INSERT INTO adviser_profiles (adviser_id, department, specialization_tags) "
                        "VALUES (:id, :department, :tags)"
                    ),
                    {
                        "id": user_id,
                        "department": body.department,
                        "tags": f"Department: {body.department}",
                    },
                )
                for (admin_id,) in conn.execute(text("SELECT user_id FROM users WHERE role = 'admin'")).fetchall():
                    notify(
                        conn,
                        admin_id,
                        f"New adviser registration: {body.name} is waiting for your approval.",
                        related_user_id=user_id,
                    )
            log_audit(conn, user_id, "REGISTER", "user", user_id,
                      new_values={"name": body.name, "email": email, "role": body.role, "student_group_role": body.student_group_role if body.role == "student" else None, "profile_photo": bool(profile_photo_url), "account_status": account_status},
                      request=request)
    except Exception:
        if stored_photo_path and os.path.exists(stored_photo_path):
            os.remove(stored_photo_path)
        raise
    if not SKIP_EMAIL_VERIFICATION:
        if not send_verification_email(email, body.name, verify_token):
            raise HTTPException(
                503,
                "Your account was created, but the verification email could not be sent. "
                "Check the SMTP configuration or ask an administrator to resend it.",
            )
    else:
        # Store token for dev mode access
        from email_utils import _store_dev_token
        _store_dev_token(email, verify_token, "verify-email")
    if SKIP_EMAIL_VERIFICATION:
        message = "Account created. An admin must approve your adviser account before you can log in." if body.role == "adviser" else "Account created. You can now log in."
    else:
        message = "Account created. Please check your email to verify your address. An admin must approve your adviser account before you can log in." if body.role == "adviser" else "Account created. Please check your email to verify your address before logging in."
    return {"message": message, "user_id": user_id, "status": account_status, "profile_photo": profile_photo_url}


@app.post("/api/login")
def login(body: LoginIn, request: Request):
    key = f"{body.email.lower()}|{request.client.host if request.client else '-'}"
    wait = throttle.retry_after(key)
    if wait:
        with engine.begin() as conn:
            log_login_attempt(conn, body.email.lower(), request.client.host if request.client else "unknown",
                             request.headers.get("user-agent", ""), False, failure_reason="rate_limited")
        raise HTTPException(429, f"Too many failed attempts. Try again in {max(1, round(wait / 60))} minute(s).")
    with engine.connect() as conn:
        row = conn.execute(
            text("SELECT user_id, name, email, role, contact_number, profile_photo, password, account_status, email_verified, student_group_role, research_interests, thesis_title, title_setup_required FROM users WHERE LOWER(email) = :e"),
            {"e": body.email.lower()},
        ).mappings().first()
    if row is None or not verify_password(body.password, row["password"]):
        throttle.fail(key)
        with engine.begin() as conn:
            log_login_attempt(conn, body.email.lower(), request.client.host if request.client else "unknown",
                             request.headers.get("user-agent", ""), False, failure_reason="invalid_password")
        # parehong mensahe sa dalawang kaso para hindi mahulaan kung aling email ang may account
        raise HTTPException(401, "Incorrect email or password.")
    throttle.reset(key)
    if row["account_status"] == "pending":
        with engine.begin() as conn:
            log_login_attempt(conn, body.email.lower(), request.client.host if request.client else "unknown",
                             request.headers.get("user-agent", ""), False, row["user_id"], "account_pending")
        raise HTTPException(403, "Your adviser account is waiting for admin approval.")
    if row["account_status"] != "active":
        with engine.begin() as conn:
            log_login_attempt(conn, body.email.lower(), request.client.host if request.client else "unknown",
                             request.headers.get("user-agent", ""), False, row["user_id"], "account_inactive")
        raise HTTPException(403, "This account is deactivated. Please contact the admin.")
    if not row["email_verified"]:
        with engine.begin() as conn:
            log_login_attempt(conn, body.email.lower(), request.client.host if request.client else "unknown",
                             request.headers.get("user-agent", ""), False, row["user_id"], "email_not_verified")
        raise HTTPException(403, "Please verify your email address before logging in. Check your inbox or request a new verification link.")
    with engine.begin() as conn:
        log_login_attempt(conn, body.email.lower(), request.client.host if request.client else "unknown",
                         request.headers.get("user-agent", ""), True, row["user_id"])
    return {"token": make_token(row), "user": public_user(row)}


@app.post("/api/me/password")
def change_password(body: ChangePasswordIn, user: dict = Depends(current_user)):
    with engine.begin() as conn:
        stored = conn.execute(text("SELECT password FROM users WHERE user_id = :id"), {"id": user["user_id"]}).scalar()
        if not stored or not verify_password(body.current_password, stored):
            raise HTTPException(400, "Your current password is incorrect.")
        conn.execute(text("UPDATE users SET password = :p WHERE user_id = :id"), {"p": hash_password(body.new_password), "id": user["user_id"]})
    return {"message": "Password changed."}


# =====================================================================
# Email verification & password reset (public endpoints)
# =====================================================================
@app.post("/api/auth/verify-email")
def verify_email(body: VerifyEmailIn):
    """Verify user's email with token from email link."""
    with engine.begin() as conn:
        row = conn.execute(
            text("SELECT user_id, email_verified FROM users WHERE password_reset_token = :t AND password_reset_expires > NOW()"),
            {"t": body.token},
        ).mappings().first()
        if not row:
            raise HTTPException(400, "Invalid or expired verification link.")
        if row["email_verified"]:
            return {"message": "Email already verified. You can log in."}
        conn.execute(
            text("UPDATE users SET email_verified = 1, password_reset_token = NULL, password_reset_expires = NULL WHERE user_id = :id"),
            {"id": row["user_id"]},
        )
    return {"message": "Email verified successfully. You can now log in."}


@app.post("/api/auth/resend-verification")
def resend_verification(body: ResendVerificationIn):
    """Resend verification email."""
    email = body.email.lower()
    with engine.begin() as conn:
        row = conn.execute(
            text("SELECT user_id, name, email_verified FROM users WHERE LOWER(email) = :e"),
            {"e": email},
        ).mappings().first()
        if not row:
            # Don't reveal if email exists
            return {"message": "If the account exists, a verification email has been sent."}
        if row["email_verified"]:
            return {"message": "Email already verified."}
        # Generate new token
        token = secrets.token_urlsafe(32)
        expires = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=24)
        conn.execute(
            text("UPDATE users SET password_reset_token = :t, password_reset_expires = :exp WHERE user_id = :id"),
            {"t": token, "exp": expires, "id": row["user_id"]},
        )
        if SKIP_EMAIL_VERIFICATION:
            from email_utils import _store_dev_token
            _store_dev_token(row["email"], token, "verify-email")
        elif not send_verification_email(row["email"], row["name"], token):
            raise HTTPException(503, "The verification email could not be sent. Check the SMTP configuration and try again.")
    return {"message": "If the account exists, a verification email has been sent."}


@app.get("/api/auth/dev-token")
def get_dev_token_endpoint(email: str, purpose: str = "verify-email"):
    """Get dev token for testing (only works when SMTP not configured)."""
    if not os.getenv("SKIP_EMAIL_VERIFICATION", "false").lower() == "true":
        raise HTTPException(403, "Dev token endpoint only available in dev mode.")
    token = get_dev_token(email, purpose)
    if not token:
        raise HTTPException(404, "No dev token found for this email.")
    return {"token": token, "url": f"{os.getenv('APP_BASE_URL', 'http://localhost:5173')}/{purpose}?token={token}"}


@app.post("/api/auth/forgot-password")
def forgot_password(body: ForgotPasswordIn):
    """Request password reset - sends email with reset link."""
    email = body.email.lower()
    with engine.begin() as conn:
        row = conn.execute(
            text("SELECT user_id, email, name, email_verified FROM users WHERE LOWER(email) = :e"),
            {"e": email},
        ).mappings().first()
        if not row:
            # Don't reveal if email exists
            if SKIP_EMAIL_VERIFICATION:
                return {
                    "delivery_mode": "development",
                    "message": "No email was sent: email delivery is disabled in local demo mode. "
                    "If the account exists, use “Get reset link (dev mode)” below.",
                }
            return {"message": "If the account exists, a password reset email has been sent."}
        if not row["email_verified"]:
            raise HTTPException(400, "Please verify your email before resetting your password.")
        # Generate reset token
        token = secrets.token_urlsafe(32)
        expires = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(hours=1)
        conn.execute(
            text("UPDATE users SET password_reset_token = :t, password_reset_expires = :exp WHERE user_id = :id"),
            {"t": token, "exp": expires, "id": row["user_id"]},
        )
        if SKIP_EMAIL_VERIFICATION:
            from email_utils import _store_dev_token
            _store_dev_token(row["email"], token, "reset-password")
            return {
                "delivery_mode": "development",
                "message": "No email was sent: email delivery is disabled in local demo mode. "
                "Use “Get reset link (dev mode)” below to continue.",
            }
        if not send_password_reset_email(row["email"], row["name"], token):
            raise HTTPException(
                503,
                "The reset link could not be emailed. Check the Gmail SMTP settings and try again.",
            )
    return {"message": "If the account exists, a password reset email has been sent."}


@app.post("/api/auth/reset-password")
def reset_password(body: ResetPasswordIn):
    """Reset password using token from email link."""
    with engine.begin() as conn:
        row = conn.execute(
            text("SELECT user_id FROM users WHERE password_reset_token = :t AND password_reset_expires > UTC_TIMESTAMP()"),
            {"t": body.token},
        ).mappings().first()
        if not row:
            raise HTTPException(400, "Invalid or expired reset link.")
        conn.execute(
            text("UPDATE users SET password = :p, password_reset_token = NULL, password_reset_expires = NULL WHERE user_id = :id"),
            {"p": hash_password(body.new_password), "id": row["user_id"]},
        )
    return {"message": "Password has been reset. You can now log in."}


# Profile photo upload
@app.post("/api/me/photo")
async def upload_photo(body: PhotoUploadIn, user: dict = Depends(current_user)):
    decoded_photo = decode_profile_photo(body.image)
    photo_url, stored_path = store_profile_photo(user["user_id"], decoded_photo)
    with engine.begin() as conn:
        old_photo = conn.execute(
            text("SELECT profile_photo FROM users WHERE user_id = :id"),
            {"id": user["user_id"]},
        ).scalar_one_or_none()
        conn.execute(text("UPDATE users SET profile_photo = :p WHERE user_id = :id"), {"p": photo_url, "id": user["user_id"]})
    remove_profile_photo_file(old_photo, user["user_id"])

    return {"message": "Profile photo updated.", "photo_url": photo_url}


@app.delete("/api/me/photo")
def delete_photo(user: dict = Depends(current_user)):
    with engine.begin() as conn:
        old_photo = conn.execute(
            text("SELECT profile_photo FROM users WHERE user_id = :id"),
            {"id": user["user_id"]},
        ).scalar_one_or_none()
        conn.execute(
            text("UPDATE users SET profile_photo = NULL WHERE user_id = :id"),
            {"id": user["user_id"]},
        )
    remove_profile_photo_file(old_photo, user["user_id"])
    return {"message": "Profile photo removed."}


@app.get("/api/uploads/{filename}")
def serve_upload(filename: str):
    """Serve uploaded files (profile photos, documents)."""
    if not is_public_profile_photo(filename):
        raise HTTPException(404, "File not found.")
    path = os.path.join(UPLOAD_DIR, filename)
    if not os.path.exists(path):
        raise HTTPException(404, "File not found.")
    return FileResponse(path)


@app.get("/api/me")
def me(user: dict = Depends(current_user)):
    return user


@app.put("/api/me")
def update_me(body: MeIn, user: dict = Depends(current_user)):
    interests = (body.research_interests or "").strip() or None
    thesis_title = (body.thesis_title or "").strip() or None
    update_interests = user["role"] == "student" and "research_interests" in body.model_fields_set
    update_title = user["role"] == "student" and "thesis_title" in body.model_fields_set
    if update_title and thesis_title is None:
        raise HTTPException(422, "Enter your complete thesis or capstone title.")
    query = "UPDATE users SET name = :n, contact_number = :c"
    params = {
        "n": body.name.strip(),
        "c": (body.contact_number or "").strip() or None,
        "id": user["user_id"],
    }
    if update_interests:
        query += ", research_interests = :i"
        params["i"] = interests
    if update_title:
        query += ", thesis_title = :t, title_setup_required = 0"
        params["t"] = thesis_title
    query += " WHERE user_id = :id"
    with engine.begin() as conn:
        conn.execute(text(query), params)
    return {
        **user,
        "name": body.name.strip(),
        "contact_number": (body.contact_number or "").strip() or None,
        "research_interests": interests if update_interests else user.get("research_interests"),
        "thesis_title": thesis_title if update_title else user.get("thesis_title"),
        "title_setup_required": False if update_title else user.get("title_setup_required", False),
    }


# =====================================================================
# Advisers: profile, keyword search, availability, slots
# =====================================================================
def adviser_card(row: dict) -> dict:
    tags = [t.strip() for t in (row["specialization_tags"] or "").split(",") if t.strip()]
    department = row.get("department") or next(
        (tag.split(":", 1)[1].strip() for tag in tags if tag.lower().startswith("department:")),
        "",
    )
    cap = row["max_capacity"] or 0
    cur = row["current_advisee_count"] or 0
    return {
        "adviser_id": row["adviser_id"],
        "name": row["name"],
        "email": row["email"],
        "profile_photo": row.get("profile_photo"),
        "department": department,
        "tags": tags,
        "certifications": row["certifications"] or "",
        "max_capacity": cap,
        "current_advisee_count": cur,
        "slots_left": max(cap - cur, 0),
    }


@app.get("/api/advisers")
def list_advisers(q: str = "", user: dict = Depends(current_user)):
    """Smart search: inaalis ang stopwords at pinaikli ang mga salita, tapos binibigyan ng puntos ang bawat adviser
    (tags > pangalan/certs). May match %, at kapag magkapareho ang puntos, mas mataas ang rating at mas maraming bakante ang mauuna."""
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT p.adviser_id, u.name, u.email, u.profile_photo, p.department, p.specialization_tags, p.certifications, "
                "p.max_capacity, p.current_advisee_count FROM adviser_profiles p "
                "JOIN users u ON u.user_id = p.adviser_id WHERE u.role = 'adviser' AND u.account_status = 'active' ORDER BY u.name"
            )
        ).mappings().all()
        ratings = {
            r[0]: (float(r[1]), int(r[2]))
            for r in conn.execute(text("SELECT adviser_id, AVG(stars), COUNT(*) FROM consultation_ratings GROUP BY adviser_id"))
        }
        mine = {}
        if user["role"] == "student":
            for a in conn.execute(
                text("SELECT application_id, adviser_id, status FROM applications WHERE student_id = :s ORDER BY application_id"),
                {"s": user["user_id"]},
            ).mappings():
                mine[a["adviser_id"]] = a  # huling application ang mananaig
    words = tokenize(q)
    out = []
    for r in rows:
        card = adviser_card(dict(r))
        score, percent, matched = match_score(words, card["name"], card["tags"], card["certifications"])
        if words and score == 0:
            continue
        avg, count = ratings.get(card["adviser_id"], (None, 0))
        card.update({
            "score": score,
            "match": percent if words else None,
            "matched": matched,
            "avg_rating": round(avg, 1) if avg is not None else None,
            "rating_count": count,
        })
        app_row = mine.get(card["adviser_id"])
        card["my_application"] = (
            {"application_id": app_row["application_id"], "status": app_row["status"]} if app_row else None
        )
        out.append(card)
    out.sort(key=lambda c: (-c["score"], -(c["avg_rating"] or 0), -c["slots_left"], c["name"]))
    if words and out and out[0]["match"] >= 50:
        out[0]["best_match"] = True
    return out


@app.get("/api/status")
def my_status(user: dict = Depends(current_user)):
    """Maliit na buod para malaman ng UI kung ano ang dapat ipakita (hal. walang Schedule kung wala pang adviser)."""
    if user["role"] == "admin":
        with engine.connect() as conn:
            pending = conn.execute(text("SELECT COUNT(*) FROM users WHERE role = 'adviser' AND account_status = 'pending'")).scalar()
            unread_messages = conn.execute(
                text("SELECT COUNT(*) FROM messages WHERE sender_id != :u AND is_read = 0"),
                {"u": user["user_id"]},
            ).scalar()
            unread_notifications = conn.execute(
                text("SELECT COUNT(*) FROM notifications WHERE user_id = :u AND is_read = 0"),
                {"u": user["user_id"]},
            ).scalar()
        return {
            "role": "admin",
            "pending_advisers": int(pending or 0),
            "unread_messages": int(unread_messages or 0),
            "unread_count": int(unread_notifications or 0),
        }
    with engine.connect() as conn:
        if user["role"] == "student":
            row = conn.execute(
                text(
                    "SELECT a.application_id, a.status, a.adviser_id, v.name AS adviser_name, "
                    "v.profile_photo AS adviser_profile_photo, a.topic_brief "
                    "FROM applications a JOIN users v ON v.user_id = a.adviser_id "
                    "LEFT JOIN application_groups g ON g.application_id = a.application_id AND g.student_id = :u "
                    "WHERE a.student_id = :u OR g.student_id = :u "
                    "ORDER BY (a.status = 'approved') DESC, (a.status = 'pending') DESC, a.application_id DESC LIMIT 1"
                ),
                {"u": user["user_id"]},
            ).mappings().first()
            has_group = conn.execute(
                text(
                    "SELECT EXISTS(SELECT 1 FROM application_groups WHERE student_id = :u) "
                    "OR EXISTS(SELECT 1 FROM student_group_requests "
                    "WHERE member_id = :u AND status = 'approved')"
                ),
                {"u": user["user_id"]},
            ).scalar()
            return {
                "role": "student",
                "application": clean(row) if row else None,
                "has_adviser": bool(row and row["status"] == "approved"),
                "has_group": bool(has_group),
            }
        counts = conn.execute(
            text(
                "SELECT SUM(status = 'approved') AS advisees, SUM(status = 'pending') AS pending "
                "FROM applications WHERE adviser_id = :u"
            ),
            {"u": user["user_id"]},
        ).mappings().first()
        tags = conn.execute(
            text("SELECT specialization_tags FROM adviser_profiles WHERE adviser_id = :u"), {"u": user["user_id"]}
        ).scalar()
        windows = conn.execute(text("SELECT COUNT(*) FROM availability WHERE adviser_id = :u"), {"u": user["user_id"]}).scalar()
    return {
        "role": "adviser",
        "advisee_count": int(counts["advisees"] or 0),
        "pending_requests": int(counts["pending"] or 0),
        "profile_ready": any(
            tag.strip() and not tag.strip().lower().startswith("department:")
            for tag in (tags or "").split(",")
        ),
        "has_availability": int(windows or 0) > 0,
    }


@app.get("/api/adviser/profile")
def my_profile(user: dict = Depends(adviser_only)):
    with engine.begin() as conn:
        if conn.execute(text("SELECT 1 FROM adviser_profiles WHERE adviser_id = :id"), {"id": user["user_id"]}).first() is None:
            conn.execute(text("INSERT INTO adviser_profiles (adviser_id) VALUES (:id)"), {"id": user["user_id"]})
        row = conn.execute(
            text(
                "SELECT p.adviser_id, u.name, u.email, u.profile_photo, p.department, p.specialization_tags, p.certifications, "
                "p.max_capacity, p.current_advisee_count FROM adviser_profiles p "
                "JOIN users u ON u.user_id = p.adviser_id WHERE p.adviser_id = :id"
            ),
            {"id": user["user_id"]},
        ).mappings().first()
    card = adviser_card(dict(row))
    card["specialization_tags_text"] = ", ".join(
        tag.strip() for tag in (row["specialization_tags"] or "").split(",")
        if tag.strip() and not tag.strip().lower().startswith("department:")
    )
    return card


@app.put("/api/adviser/profile")
def save_profile(body: ProfileIn, user: dict = Depends(adviser_only)):
    specialties = [
        tag.strip() for tag in body.specialization_tags.split(",")
        if tag.strip() and not tag.strip().lower().startswith("department:")
    ]
    tags = ", ".join([f"Department: {body.department}", *specialties])
    with engine.begin() as conn:
        cur = conn.execute(
            text("SELECT current_advisee_count FROM adviser_profiles WHERE adviser_id = :id FOR UPDATE"),
            {"id": user["user_id"]},
        ).first()
        if cur is None:
            conn.execute(text("INSERT INTO adviser_profiles (adviser_id) VALUES (:id)"), {"id": user["user_id"]})
            cur = (0,)
        if body.max_capacity < (cur[0] or 0):
            raise HTTPException(400, f"Capacity cannot be lower than your current advisees ({cur[0]}).")
        conn.execute(
            text("UPDATE adviser_profiles SET department = :d, specialization_tags = :t, certifications = :c, max_capacity = :m WHERE adviser_id = :id"),
            {"d": body.department, "t": tags, "c": (body.certifications or "").strip() or None, "m": body.max_capacity, "id": user["user_id"]},
        )
    return {"message": "Profile saved."}


@app.get("/api/availability")
def my_availability(user: dict = Depends(adviser_only)):
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT availability_id, day_of_week, specific_date, start_time, end_time "
                "FROM availability WHERE adviser_id = :a ORDER BY specific_date IS NULL DESC, specific_date, day_of_week, start_time"
            ),
            {"a": user["user_id"]},
        ).mappings().all()
    items = [clean(r) for r in rows]
    items.sort(key=lambda r: (r["specific_date"] is not None, DAYS.index(r["day_of_week"]) if r["day_of_week"] else 0, r["specific_date"] or "", r["start_time"]))
    return items


def ensure_availability_has_no_overlap(
    rows,
    body: AvailabilityIn,
    exclude_id: Optional[int] = None,
) -> None:
    start, end = to_minutes(body.start_time), to_minutes(body.end_time)
    for row in rows:
        if row["availability_id"] == exclude_id:
            continue
        same_day = (
            (body.day_of_week and row["specific_date"] is None and row["day_of_week"] == body.day_of_week)
            or (body.specific_date and row["specific_date"] == body.specific_date)
        )
        if same_day and overlaps(start, end, to_minutes(row["start_time"]), to_minutes(row["end_time"])):
            raise HTTPException(409, "That overlaps with a window you already opened.")


@app.post("/api/availability", status_code=201)
def add_availability(body: AvailabilityIn, user: dict = Depends(adviser_only)):
    s, e = to_minutes(body.start_time), to_minutes(body.end_time)
    with engine.begin() as conn:
        rows = conn.execute(
            text(
                "SELECT availability_id, day_of_week, specific_date, start_time, end_time "
                "FROM availability WHERE adviser_id = :a FOR UPDATE"
            ),
            {"a": user["user_id"]},
        ).mappings().all()
        ensure_availability_has_no_overlap(rows, body)
        res = conn.execute(
            text(
                "INSERT INTO availability (adviser_id, day_of_week, specific_date, start_time, end_time) "
                "VALUES (:a, :d, :sd, :st, :en)"
            ),
            {"a": user["user_id"], "d": body.day_of_week, "sd": body.specific_date, "st": to_hhmm(s) + ":00", "en": to_hhmm(e) + ":00"},
        )
    return {"availability_id": res.lastrowid}


@app.put("/api/availability/{availability_id}")
def update_availability(
    availability_id: int,
    body: AvailabilityIn,
    user: dict = Depends(adviser_only),
):
    start, end = to_minutes(body.start_time), to_minutes(body.end_time)
    with engine.begin() as conn:
        current = conn.execute(
            text(
                "SELECT availability_id FROM availability "
                "WHERE availability_id = :id AND adviser_id = :a FOR UPDATE"
            ),
            {"id": availability_id, "a": user["user_id"]},
        ).first()
        if current is None:
            raise HTTPException(404, "Availability window not found.")
        rows = conn.execute(
            text(
                "SELECT availability_id, day_of_week, specific_date, start_time, end_time "
                "FROM availability WHERE adviser_id = :a FOR UPDATE"
            ),
            {"a": user["user_id"]},
        ).mappings().all()
        ensure_availability_has_no_overlap(rows, body, exclude_id=availability_id)
        conn.execute(
            text(
                "UPDATE availability SET day_of_week = :d, specific_date = :sd, "
                "start_time = :st, end_time = :en "
                "WHERE availability_id = :id AND adviser_id = :a"
            ),
            {
                "d": body.day_of_week,
                "sd": body.specific_date,
                "st": to_hhmm(start) + ":00",
                "en": to_hhmm(end) + ":00",
                "id": availability_id,
                "a": user["user_id"],
            },
        )
    return {"message": "Availability updated."}


@app.delete("/api/availability/{availability_id}")
def delete_availability(availability_id: int, user: dict = Depends(adviser_only)):
    with engine.begin() as conn:
        res = conn.execute(
            text("DELETE FROM availability WHERE availability_id = :id AND adviser_id = :a"),
            {"id": availability_id, "a": user["user_id"]},
        )
    if res.rowcount == 0:
        raise HTTPException(404, "Availability window not found.")
    return {"message": "Removed."}


@app.get("/api/advisers/{adviser_id}/slots")
def adviser_slots(adviser_id: int, start: datetime.date, end: datetime.date, user: dict = Depends(current_user)):
    if end < start or (end - start).days > 62:
        raise HTTPException(400, "Choose a date range of up to 62 days.")
    with engine.connect() as conn:
        exists = conn.execute(text("SELECT 1 FROM adviser_profiles WHERE adviser_id = :a"), {"a": adviser_id}).first()
        if not exists:
            raise HTTPException(404, "Adviser not found.")
        if user["role"] == "student":
            approved = conn.execute(
                text(
                    "SELECT 1 FROM applications a "
                    "LEFT JOIN application_groups g ON g.application_id = a.application_id AND g.student_id = :s "
                    "WHERE a.adviser_id = :a AND a.status = 'approved' "
                    "AND (a.student_id = :s OR g.student_id = :s) LIMIT 1"
                ),
                {"s": user["user_id"], "a": adviser_id},
            ).first()
            if approved is None:
                raise HTTPException(403, "You can only see the open times of your approved adviser.")
        return fetch_slots(conn, adviser_id, start, end, user["user_id"] if user["role"] == "student" else None)


# =====================================================================
# Applications
# =====================================================================
@app.post("/api/applications", status_code=201)
def apply(body: ApplicationIn, user: dict = Depends(student_only)):
    if user.get("student_group_role") == "member":
        raise HTTPException(403, "Only student group leaders can apply to an adviser.")
    require_student_project_title(user)
    with engine.begin() as conn:
        prof = conn.execute(
            text("SELECT max_capacity, current_advisee_count FROM adviser_profiles WHERE adviser_id = :a"),
            {"a": body.adviser_id},
        ).first()
        if prof is None:
            raise HTTPException(404, "Adviser not found.")
        active = conn.execute(
            text("SELECT status FROM applications WHERE student_id = :s AND status IN ('pending','approved') LIMIT 1"),
            {"s": user["user_id"]},
        ).first()
        if active:
            raise HTTPException(
                409,
                "You already have an approved adviser." if active[0] == "approved"
                else "You already have a pending application. Withdraw it first if you want to apply to someone else.",
            )
        if (prof[1] or 0) >= (prof[0] or 0):
            raise HTTPException(409, "This adviser has no open slots left.")
        res = conn.execute(
            text("INSERT INTO applications (student_id, adviser_id, topic_brief) VALUES (:s, :a, :t)"),
            {"s": user["user_id"], "a": body.adviser_id, "t": body.topic_brief.strip()},
        )
        notify(conn, body.adviser_id, f"{user['name']} applied to you as their adviser.")
    return {"application_id": res.lastrowid, "message": "Application sent."}


@app.get("/api/applications")
def my_applications(user: dict = Depends(current_user)):
    col = "student_id" if user["role"] == "student" else "adviser_id"
    group_filter = (
        " OR EXISTS (SELECT 1 FROM application_groups g "
        "WHERE g.application_id = a.application_id AND g.student_id = :u)"
        if user["role"] == "student"
        else ""
    )
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT a.application_id, a.student_id, a.adviser_id, a.topic_brief, a.status, a.date_submitted, "
                "s.name AS student_name, s.email AS student_email, s.profile_photo AS student_profile_photo, "
                "v.name AS adviser_name, v.profile_photo AS adviser_profile_photo "
                "FROM applications a JOIN users s ON s.user_id = a.student_id JOIN users v ON v.user_id = a.adviser_id "
                f"WHERE a.{col} = :u{group_filter} ORDER BY a.date_submitted DESC, a.application_id DESC"
            ),
            {"u": user["user_id"]},
        ).mappings().all()
    return [clean(r) for r in rows]


@app.patch("/api/applications/{application_id}")
def decide_application(application_id: int, body: AppStatusIn, user: dict = Depends(adviser_only)):
    with engine.begin() as conn:
        # i-lock ang profile row para hindi sabay na lumampas sa capacity
        prof = conn.execute(
            text("SELECT max_capacity, current_advisee_count FROM adviser_profiles WHERE adviser_id = :a FOR UPDATE"),
            {"a": user["user_id"]},
        ).first()
        row = conn.execute(
            text(
                "SELECT a.student_id, a.status, u.student_group_role "
                "FROM applications a JOIN users u ON u.user_id = a.student_id "
                "WHERE a.application_id = :id AND a.adviser_id = :a"
            ),
            {"id": application_id, "a": user["user_id"]},
        ).first()
        if row is None:
            raise HTTPException(404, "Application not found.")
        if row[1] != "pending":
            raise HTTPException(409, f"This application is already {row[1]}.")
        if body.status == "approved":
            if prof is None or (prof[1] or 0) >= (prof[0] or 0):
                raise HTTPException(409, "You are at full capacity. Raise your capacity in your profile first.")
            conn.execute(
                text("UPDATE adviser_profiles SET current_advisee_count = current_advisee_count + 1 WHERE adviser_id = :a"),
                {"a": user["user_id"]},
            )
        conn.execute(text("UPDATE applications SET status = :s WHERE application_id = :id"), {"s": body.status, "id": application_id})
        if body.status == "approved" and row[2] == "leader":
            conn.execute(
                text(
                    "INSERT IGNORE INTO application_groups (application_id, student_id, is_leader) "
                    "VALUES (:a, :s, 1)"
                ),
                {"a": application_id, "s": row[0]},
            )
            conn.execute(
                text(
                    "INSERT IGNORE INTO application_groups (application_id, student_id, is_leader) "
                    "SELECT :a, member_id, 0 FROM student_group_requests "
                    "WHERE leader_id = :s AND status = 'approved'"
                ),
                {"a": application_id, "s": row[0]},
            )
        notify(conn, row[0], f"{user['name']} {body.status} your application." + (" You can now book a consultation." if body.status == "approved" else ""))
    return {"message": f"Application {body.status}."}


@app.delete("/api/applications/{application_id}")
def withdraw_application(application_id: int, user: dict = Depends(student_only)):
    with engine.begin() as conn:
        res = conn.execute(
            text("DELETE FROM applications WHERE application_id = :id AND student_id = :s AND status = 'pending'"),
            {"id": application_id, "s": user["user_id"]},
        )
    if res.rowcount == 0:
        raise HTTPException(404, "Only your pending applications can be withdrawn.")
    return {"message": "Application withdrawn."}


# =====================================================================
# Bookings
# =====================================================================
BOOKING_SELECT = (
    "SELECT b.booking_id, b.application_id, b.student_id, b.adviser_id, b.slot_date, b.start_time, b.end_time, "
    "b.status, b.meeting_type, b.location, b.notes, b.cancel_reason, b.cancelled_by, b.leader_accepted, "
    "s.name AS student_name, s.profile_photo AS student_profile_photo, "
    "v.name AS adviser_name, v.profile_photo AS adviser_profile_photo, a.topic_brief, r.stars AS rating, "
    "(SELECT pl.stage_status FROM progress_logs pl WHERE pl.booking_id = b.booking_id ORDER BY pl.log_id DESC LIMIT 1) AS stage_status, "
    "(SELECT pl.remarks FROM progress_logs pl WHERE pl.booking_id = b.booking_id ORDER BY pl.log_id DESC LIMIT 1) AS remarks "
    "FROM bookings b JOIN users s ON s.user_id = b.student_id JOIN users v ON v.user_id = b.adviser_id "
    "JOIN applications a ON a.application_id = b.application_id "
    "LEFT JOIN consultation_ratings r ON r.booking_id = b.booking_id "
)


@app.post("/api/bookings", status_code=201)
def create_booking(body: BookingIn, user: dict = Depends(student_only)):
    try:
        start = to_minutes(body.start_time)
    except ValueError as err:
        raise HTTPException(400, str(err))
    end = start + SLOT_MINUTES
    with engine.begin() as conn:
        conn.execute(text("SELECT adviser_id FROM adviser_profiles WHERE adviser_id = :a FOR UPDATE"), {"a": body.adviser_id})
        app_row = conn.execute(
            text(
                "SELECT a.application_id, a.student_id, COALESCE(g.is_leader, 0) AS is_group_leader FROM applications a "
                "LEFT JOIN application_groups g ON g.application_id = a.application_id AND g.student_id = :s "
                "WHERE a.adviser_id = :a AND a.status = 'approved' "
                "AND (a.student_id = :s OR g.student_id = :s) LIMIT 1"
            ),
            {"s": user["user_id"], "a": body.adviser_id},
        ).mappings().first()
        if app_row is None:
            raise HTTPException(403, "You can only book an adviser who approved your application.")
        if not can_manage_application(
            user["role"], user["user_id"], app_row["student_id"], bool(app_row["is_group_leader"])
        ):
            raise HTTPException(403, "Only the group leader can book consultations for this project.")
        slots = fetch_slots(conn, body.adviser_id, body.slot_date, body.slot_date, user["user_id"])
        match = next((s for s in slots if s["start"] == to_hhmm(start)), None)
        if match is None:
            raise HTTPException(409, "That time is not open for consultation (or it already passed).")
        if not match["available"]:
            raise HTTPException(409, match["reason"] or "That slot is no longer available.")
        res = conn.execute(
            text(
                "INSERT INTO bookings (application_id, student_id, adviser_id, slot_date, start_time, end_time, "
                "status, notes) VALUES (:ap, :s, :a, :d, :st, :en, 'confirmed', :n)"
            ),
            {
                "ap": app_row["application_id"], "s": user["user_id"], "a": body.adviser_id, "d": body.slot_date,
                "st": to_hhmm(start) + ":00", "en": to_hhmm(end) + ":00",
                "n": (body.notes or "").strip() or None,
            },
        )
        notify(
            conn,
            body.adviser_id,
            f"{user['name']} booked a consultation on {pretty_slot(body.slot_date, start)}. It is automatically confirmed; please set if it will be online or in person.",
            related_user_id=user["user_id"],
        )
    return {"booking_id": res.lastrowid, "message": "Consultation booked."}


@app.get("/api/bookings")
def my_bookings(start: Optional[datetime.date] = None, end: Optional[datetime.date] = None, user: dict = Depends(current_user)):
    if user["role"] == "student":
        where = (
            "WHERE (b.student_id = :u OR EXISTS ("
            "SELECT 1 FROM application_groups g "
            "WHERE g.application_id = b.application_id AND g.student_id = :u)) "
        )
    else:
        where = "WHERE b.adviser_id = :u "
    booking_select = BOOKING_SELECT.replace(
        "FROM bookings b",
        ", CASE WHEN EXISTS ("
        "SELECT 1 FROM notifications n WHERE n.user_id = :u AND n.is_read = 0 "
        "AND n.related_user_id = CASE WHEN :role = 'adviser' THEN b.student_id ELSE b.adviser_id END "
        "AND n.message LIKE '%consultation%'"
        ") THEN 1 ELSE 0 END AS has_new_activity, CASE WHEN :role != 'student' OR b.student_id = :u OR EXISTS ("
        "SELECT 1 FROM application_groups g "
        "WHERE g.application_id = b.application_id AND g.student_id = :u AND g.is_leader = 1"
        ") THEN 1 ELSE 0 END AS can_manage FROM bookings b",
    )
    sql = booking_select + where
    params: dict = {"u": user["user_id"], "role": user["role"]}
    if start:
        sql += "AND b.slot_date >= :s "
        params["s"] = start
    if end:
        sql += "AND b.slot_date <= :e "
        params["e"] = end
    sql += "ORDER BY b.slot_date, b.start_time"
    with engine.connect() as conn:
        rows = conn.execute(text(sql), params).mappings().all()
    return [clean(row) for row in rows]


@app.patch("/api/bookings/{booking_id}/meeting")
def set_meeting(booking_id: int, body: MeetingIn, user: dict = Depends(adviser_only)):
    """Ang adviser ang nagpapasya kung online o in-person ang consultation, at kung saan."""
    with engine.begin() as conn:
        b = conn.execute(
            text(
                "SELECT student_id, slot_date, start_time, status, meeting_type, location "
                "FROM bookings WHERE booking_id = :id AND adviser_id = :a FOR UPDATE"
            ),
            {"id": booking_id, "a": user["user_id"]},
        ).mappings().first()
        if b is None:
            raise HTTPException(404, "Booking not found.")
        if b["status"] != "confirmed":
            raise HTTPException(409, f"This booking is already {b['status']}.")
        start = to_minutes(b["start_time"])
        starts_at = datetime.datetime.combine(
            b["slot_date"], datetime.time(start // 60, start % 60)
        )
        if starts_at <= datetime.datetime.now():
            raise HTTPException(409, "The consultation has already started.")
        loc = (body.location or "").strip() or None
        changed = b["meeting_type"] != body.meeting_type or (b["location"] or "") != (loc or "")
        conn.execute(
            text(
                "UPDATE bookings SET meeting_type = :t, location = :l, "
                "leader_accepted = CASE WHEN :changed THEN 0 ELSE leader_accepted END "
                "WHERE booking_id = :id"
            ),
            {"t": body.meeting_type, "l": loc, "changed": changed, "id": booking_id},
        )
        kind = "online" if body.meeting_type == "online" else "in person"
        notify(
            conn,
            b["student_id"],
            f"{user['name']} set your consultation on {pretty_slot(b['slot_date'], to_minutes(b['start_time']))} as {kind}" + (f": {loc}" if loc else "."),
            related_user_id=user["user_id"],
        )
    return {"message": "Meeting details saved."}


@app.post("/api/bookings/{booking_id}/accept-meeting")
def accept_meeting(booking_id: int, user: dict = Depends(current_user)):
    if user["role"] != "student":
        raise HTTPException(403, "Only the group leader can accept meeting details.")
    with engine.begin() as conn:
        booking = conn.execute(
            text(
                "SELECT booking_id, application_id, student_id, adviser_id, slot_date, start_time, "
                "status, meeting_type, leader_accepted FROM bookings WHERE booking_id = :id FOR UPDATE"
            ),
            {"id": booking_id},
        ).mappings().first()
        if booking is None:
            raise HTTPException(404, "Booking not found.")
        if not is_application_leader(
            conn,
            {"application_id": booking["application_id"], "student_id": booking["student_id"]},
            user,
        ):
            raise HTTPException(403, "Only the group leader can accept meeting details.")
        if booking["status"] != "confirmed":
            raise HTTPException(409, f"This consultation is already {booking['status']}.")
        if booking["meeting_type"] is None:
            raise HTTPException(409, "Wait for the adviser to set whether this meeting is online or in person.")
        start = to_minutes(booking["start_time"])
        starts_at = datetime.datetime.combine(
            booking["slot_date"], datetime.time(start // 60, start % 60)
        )
        if starts_at <= datetime.datetime.now():
            raise HTTPException(409, "The consultation has already started and can no longer be accepted.")
        if booking["leader_accepted"]:
            return {"message": "Meeting details have already been accepted."}
        updated = conn.execute(
            text(
                "UPDATE bookings SET leader_accepted = 1 "
                "WHERE booking_id = :id AND status = 'confirmed' AND leader_accepted = 0"
            ),
            {"id": booking_id},
        )
        if updated.rowcount == 0:
            latest = conn.execute(
                text("SELECT status, leader_accepted FROM bookings WHERE booking_id = :id"),
                {"id": booking_id},
            ).mappings().first()
            if latest and latest["status"] == "confirmed" and latest["leader_accepted"]:
                return {"message": "Meeting details have already been accepted."}
            raise HTTPException(409, "The consultation changed or was cancelled before it could be accepted.")
        notify(
            conn,
            booking["adviser_id"],
            f"{user['name']} accepted the meeting details for {pretty_slot(booking['slot_date'], start)}.",
            related_user_id=user["user_id"],
        )
    return {"message": "Meeting details accepted."}


@app.get("/api/advisers/{adviser_id}/next-slots")
def next_slots(adviser_id: int, limit: int = 6, user: dict = Depends(student_only)):
    """Pinakamaagang bakanteng oras ng adviser sa susunod na 4 na linggo, para makapag-book nang mabilis."""
    limit = max(1, min(limit, 12))
    today = datetime.date.today()
    with engine.connect() as conn:
        ok = conn.execute(
            text(
                "SELECT 1 FROM applications a "
                "LEFT JOIN application_groups g ON g.application_id = a.application_id AND g.student_id = :s "
                "WHERE a.adviser_id = :a AND a.status = 'approved' "
                "AND (a.student_id = :s OR g.student_id = :s)"
            ),
            {"s": user["user_id"], "a": adviser_id},
        ).first()
        if ok is None:
            raise HTTPException(403, "You can only see the open times of your approved adviser.")
        slots = fetch_slots(conn, adviser_id, today, today + datetime.timedelta(days=28), user["user_id"])
    return [s for s in slots if s["available"]][:limit]


@app.post("/api/bookings/{booking_id}/reschedule")
def reschedule_booking(booking_id: int, body: RescheduleIn, user: dict = Depends(current_user)):
    """Ilipat sa ibang oras sa isang hakbang (hindi na kailangang mag-cancel at mag-book ulit). Pwede ang student o adviser."""
    try:
        start = to_minutes(body.start_time)
    except ValueError as err:
        raise HTTPException(400, str(err))
    end = start + SLOT_MINUTES
    with engine.begin() as conn:
        b = conn.execute(
            text(
                "SELECT booking_id, application_id, student_id, adviser_id, slot_date, start_time, status "
                "FROM bookings WHERE booking_id = :id"
            ),
            {"id": booking_id},
        ).mappings().first()
        if b is None or user["user_id"] not in (b["student_id"], b["adviser_id"]):
            if b is None or user["role"] != "student":
                raise HTTPException(404, "Booking not found.")
            is_leader = is_application_leader(
                conn,
                {"application_id": b["application_id"], "student_id": b["student_id"]},
                user,
            )
            if not is_leader:
                raise HTTPException(404, "Booking not found.")
        if b["status"] != "confirmed":
            raise HTTPException(409, f"This booking is already {b['status']}.")
        old_start = to_minutes(b["start_time"])
        if b["slot_date"] == body.slot_date and old_start == start:
            raise HTTPException(400, "That is already the current time. Pick a different one.")
        conn.execute(text("SELECT adviser_id FROM adviser_profiles WHERE adviser_id = :a FOR UPDATE"), {"a": b["adviser_id"]})
        slots = fetch_slots(conn, b["adviser_id"], body.slot_date, body.slot_date, b["student_id"])
        match = next((s for s in slots if s["start"] == to_hhmm(start)), None)
        if match is None:
            raise HTTPException(409, "That time is not open for consultation (or it already passed).")
        if not match["available"]:
            raise HTTPException(409, match["reason"] or "That slot is no longer available.")
        conn.execute(
            text(
                "UPDATE bookings SET slot_date = :d, start_time = :st, end_time = :en, "
                "reminded = 0, leader_accepted = 0 WHERE booking_id = :id"
            ),
            {"d": body.slot_date, "st": to_hhmm(start) + ":00", "en": to_hhmm(end) + ":00", "id": booking_id},
        )
        other = b["adviser_id"] if user["user_id"] == b["student_id"] else b["student_id"]
        notify(
            conn,
            other,
            f"{user['name']} moved the consultation from {pretty_slot(b['slot_date'], old_start)} to {pretty_slot(body.slot_date, start)}.",
            related_user_id=user["user_id"],
        )
    return {"message": "Consultation moved."}


def _ics_escape(v: str) -> str:
    return (v or "").replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\n", "\\n")


@app.get("/api/bookings/{booking_id}/calendar.ics")
def booking_ics(booking_id: int, user: dict = Depends(current_user)):
    """I-download ang consultation bilang .ics para maidagdag sa Google Calendar, Outlook, o Apple Calendar."""
    with engine.connect() as conn:
        b = conn.execute(
            text(BOOKING_SELECT + "WHERE b.booking_id = :id AND (b.student_id = :u OR b.adviser_id = :u)"),
            {"id": booking_id, "u": user["user_id"]},
        ).mappings().first()
    if b is None:
        raise HTTPException(404, "Booking not found.")
    s0, s1 = to_minutes(b["start_time"]), to_minutes(b["end_time"])
    fmt = lambda m: f"{b['slot_date'].strftime('%Y%m%d')}T{m // 60:02d}{m % 60:02d}00"
    who = b["adviser_name"] if user["user_id"] == b["student_id"] else b["student_name"]
    kind = {"online": "Online", "in-person": "In person"}.get(b["meeting_type"], "")
    lines = [
        "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//AdviserLink//EN", "BEGIN:VEVENT",
        f"UID:booking-{b['booking_id']}@adviserlink",
        f"DTSTAMP:{datetime.datetime.utcnow().strftime('%Y%m%dT%H%M%SZ')}",
        f"DTSTART:{fmt(s0)}", f"DTEND:{fmt(s1)}",
        f"SUMMARY:{_ics_escape('Consultation with ' + who)}",
        f"DESCRIPTION:{_ics_escape((kind + '. ' if kind else '') + (b['topic_brief'] or ''))}",
    ]
    if b["location"]:
        lines.append(f"LOCATION:{_ics_escape(b['location'])}")
    lines += ["BEGIN:VALARM", "TRIGGER:-PT15M", "ACTION:DISPLAY", "DESCRIPTION:Consultation soon", "END:VALARM", "END:VEVENT", "END:VCALENDAR"]
    return Response("\r\n".join(lines) + "\r\n", media_type="text/calendar", headers={"Content-Disposition": 'attachment; filename="consultation.ics"'})


@app.post("/api/bookings/{booking_id}/rating", status_code=201)
def rate_booking(booking_id: int, body: RatingIn, user: dict = Depends(student_only)):
    with engine.begin() as conn:
        b = conn.execute(
            text("SELECT adviser_id, status FROM bookings WHERE booking_id = :id AND student_id = :u"),
            {"id": booking_id, "u": user["user_id"]},
        ).first()
        if b is None:
            raise HTTPException(404, "Booking not found.")
        if b[1] != "completed":
            raise HTTPException(409, "You can rate a consultation after it is marked completed.")
        if conn.execute(text("SELECT 1 FROM consultation_ratings WHERE booking_id = :id"), {"id": booking_id}).first():
            raise HTTPException(409, "You already rated this consultation.")
        conn.execute(
            text("INSERT INTO consultation_ratings (booking_id, student_id, adviser_id, stars, comment) VALUES (:b, :s, :a, :st, :c)"),
            {"b": booking_id, "s": user["user_id"], "a": b[0], "st": body.stars, "c": (body.comment or "").strip() or None},
        )
        notify(conn, b[0], f"{user['name']} rated your consultation {body.stars} out of 5.")
    return {"message": "Thanks for your feedback."}


@app.post("/api/bookings/{booking_id}/cancel")
def cancel_booking(booking_id: int, body: CancelIn, user: dict = Depends(current_user)):
    reason = (body.reason or "").strip()
    if user["role"] == "adviser" and len(reason) < 3:
        raise HTTPException(400, "Please give the student a reason for cancelling.")
    with engine.begin() as conn:
        b = conn.execute(
            text("SELECT booking_id, student_id, adviser_id, slot_date, start_time, status FROM bookings WHERE booking_id = :id"),
            {"id": booking_id},
        ).mappings().first()
        if b is None or user["user_id"] not in (b["student_id"], b["adviser_id"]):
            raise HTTPException(404, "Booking not found.")
        if b["status"] != "confirmed":
            raise HTTPException(409, f"This booking is already {b['status']}.")
        conn.execute(
            text("UPDATE bookings SET status = 'cancelled', cancel_reason = :r, cancelled_by = :u WHERE booking_id = :id"),
            {"r": reason or None, "u": user["user_id"], "id": booking_id},
        )
        target = b["adviser_id"] if user["role"] == "student" else b["student_id"]
        when = pretty_slot(b["slot_date"], to_minutes(b["start_time"]))
        notify(
            conn,
            target,
            f"{user['name']} cancelled the consultation on {when}." + (f" Reason: {reason}" if reason else ""),
            related_user_id=user["user_id"],
        )
    return {"message": "Booking cancelled."}


@app.post("/api/bookings/{booking_id}/complete")
def complete_booking(booking_id: int, body: CompleteIn, user: dict = Depends(adviser_only)):
    with engine.begin() as conn:
        b = conn.execute(
            text("SELECT student_id, slot_date, start_time, status FROM bookings WHERE booking_id = :id AND adviser_id = :a"),
            {"id": booking_id, "a": user["user_id"]},
        ).mappings().first()
        if b is None:
            raise HTTPException(404, "Booking not found.")
        if b["status"] != "confirmed":
            raise HTTPException(409, f"This booking is already {b['status']}.")
        conn.execute(text("UPDATE bookings SET status = 'completed' WHERE booking_id = :id"), {"id": booking_id})
        if (body.stage_status or "").strip() or (body.remarks or "").strip():
            conn.execute(
                text("INSERT INTO progress_logs (booking_id, stage_status, remarks) VALUES (:b, :s, :r)"),
                {"b": booking_id, "s": (body.stage_status or "").strip() or None, "r": (body.remarks or "").strip() or None},
            )
        notify(
            conn,
            b["student_id"],
            f"{user['name']} marked your consultation on {pretty_slot(b['slot_date'], to_minutes(b['start_time']))} as completed.",
            related_user_id=user["user_id"],
        )
    return {"message": "Marked as completed."}


# =====================================================================
# Kanban / Agile board (kada approved application)
# =====================================================================
async def store_uploaded_file(file: UploadFile) -> tuple[str, str, int, str]:
    name = os.path.basename(file.filename or "file")
    ext = name.rsplit(".", 1)[-1].lower() if "." in name else ""
    if ext not in ALLOWED_EXT:
        raise HTTPException(400, "That file type is not allowed. Use: " + ", ".join(sorted(ALLOWED_EXT)) + ".")

    stored = f"{uuid.uuid4().hex}.{ext}"
    path = os.path.join(UPLOAD_DIR, stored)
    size = 0
    complete = False
    try:
        with open(path, "wb") as out:
            while True:
                chunk = await file.read(1024 * 256)
                if not chunk:
                    break
                if size == 0 and not file_matches_type(ext, chunk[:16]):
                    raise HTTPException(400, f"The file content does not look like a real .{ext} file.")
                size += len(chunk)
                if size > MAX_UPLOAD_BYTES:
                    raise HTTPException(413, "File is too large (10 MB max).")
                out.write(chunk)
        complete = True
    finally:
        if not complete and os.path.exists(path):
            os.remove(path)

    return name, stored, size, path


@app.get("/api/applications/{application_id}/board")
def get_board(application_id: int, user: dict = Depends(current_user)):
    with engine.connect() as conn:
        app_row = get_approved_application(conn, application_id, user)
        tasks = conn.execute(
            text(
                "SELECT t.task_id, t.title, t.description, t.status, t.due_date, t.created_by, t.created_at, u.name AS created_by_name, "
                "EXISTS (SELECT 1 FROM documents d WHERE d.task_id = t.task_id) AS has_documents "
                "FROM kanban_tasks t JOIN users u ON u.user_id = t.created_by "
                "WHERE t.application_id = :a ORDER BY t.task_id"
            ),
            {"a": application_id},
        ).mappings().all()
        comments = conn.execute(
            text(
                "SELECT c.comment_id, c.task_id, c.body, c.created_at, u.name AS author_name, "
                "d.document_id AS attachment_document_id, d.filename AS attachment_filename, "
                "d.size_bytes AS attachment_size_bytes, d.uploaded_by AS attachment_uploaded_by, "
                "d.uploaded_at AS attachment_uploaded_at, uploader.name AS attachment_uploaded_by_name "
                "FROM task_comments c "
                "JOIN users u ON u.user_id = c.author_id JOIN kanban_tasks t ON t.task_id = c.task_id "
                "LEFT JOIN documents d ON d.task_comment_id = c.comment_id "
                "LEFT JOIN users uploader ON uploader.user_id = d.uploaded_by "
                "WHERE t.application_id = :a ORDER BY c.comment_id"
            ),
            {"a": application_id},
        ).mappings().all()
        task_documents = conn.execute(
            text(
                "SELECT d.document_id, d.task_id, d.task_comment_id, d.filename, d.size_bytes, d.uploaded_by, d.uploaded_at, u.name AS uploaded_by_name "
                "FROM documents d JOIN users u ON u.user_id = d.uploaded_by "
                "WHERE d.application_id = :a AND d.task_id IS NOT NULL AND d.task_comment_id IS NULL ORDER BY d.document_id DESC"
            ),
            {"a": application_id},
        ).mappings().all()
        is_leader = is_application_leader(conn, app_row, user)
        can_manage = can_manage_application(user["role"], user["user_id"], app_row["student_id"], is_leader)
        can_comment = can_comment_on_task(user["role"], is_leader)
    by_task: dict = {}
    for row in comments:
        comment = clean(row)
        attachment_id = comment.pop("attachment_document_id")
        attachment = None
        if attachment_id is not None:
            attachment = {
                "document_id": attachment_id,
                "filename": comment["attachment_filename"],
                "size_bytes": comment["attachment_size_bytes"],
                "uploaded_by": comment["attachment_uploaded_by"],
                "uploaded_at": comment["attachment_uploaded_at"],
                "uploaded_by_name": comment["attachment_uploaded_by_name"],
            }
        for field in (
            "attachment_filename",
            "attachment_size_bytes",
            "attachment_uploaded_by",
            "attachment_uploaded_at",
            "attachment_uploaded_by_name",
        ):
            comment.pop(field)
        comment["attachment"] = attachment
        by_task.setdefault(comment["task_id"], []).append(comment)
    docs_by_task: dict = {}
    for document in task_documents:
        docs_by_task.setdefault(document["task_id"], []).append(clean(document))
    items = []
    total = done = 0
    for t in tasks:
        d = clean(t)
        d["comments"] = by_task.get(t["task_id"], [])
        d["documents"] = docs_by_task.get(t["task_id"], [])
        items.append(d)
        total += 1
        done += 1 if t["status"] == "done" else 0
    return {
        "application": {
            k: app_row[k]
            for k in (
                "application_id",
                "student_name",
                "student_profile_photo",
                "adviser_name",
                "adviser_profile_photo",
                "topic_brief",
            )
        },
        "tasks": items,
        "can_comment": can_comment,
        "can_manage": can_manage,
        "progress": {"done": done, "total": total},
    }


@app.post("/api/applications/{application_id}/tasks", status_code=201)
def add_task(application_id: int, body: TaskIn, user: dict = Depends(current_user)):
    if user["role"] != "adviser":
        raise HTTPException(403, "Only your adviser can assign board tasks.")
    with engine.begin() as conn:
        get_approved_application(conn, application_id, user)
        res = conn.execute(
            text("INSERT INTO kanban_tasks (application_id, title, description, due_date, created_by) VALUES (:a, :t, :d, :dd, :u)"),
            {"a": application_id, "t": body.title.strip(), "d": (body.description or "").strip() or None,
             "dd": body.due_date, "u": user["user_id"]},
        )
    return {"task_id": res.lastrowid}


def load_task(conn, task_id: int, user: dict):
    t = conn.execute(
        text("SELECT task_id, application_id, title, status FROM kanban_tasks WHERE task_id = :id"), {"id": task_id}
    ).mappings().first()
    if t is None:
        raise HTTPException(404, "Task not found.")
    app_row = get_approved_application(conn, t["application_id"], user)
    return dict(t), app_row


STATUS_LABEL = {"todo": "To Do", "in_progress": "In Progress", "review": "For Review", "done": "Done"}


@app.patch("/api/tasks/{task_id}")
def update_task(task_id: int, body: TaskPatch, user: dict = Depends(current_user)):
    with engine.begin() as conn:
        t, app_row = load_task(conn, task_id, user)
        if body.status and user["role"] == "student" and not is_application_leader(conn, app_row, user):
            raise HTTPException(403, "Only the group leader can move tasks on the board.")
        if user["role"] != "adviser" and any(
            field in body.model_fields_set for field in ("title", "description", "due_date")
        ):
            raise HTTPException(403, "Only your adviser can edit task details.")
        if body.status and body.status != t["status"]:
            if not can_transition_task(user["role"], t["status"], body.status):
                message = (
                    "Advisers can only mark a submitted task Done or return it for revision."
                    if user["role"] == "adviser"
                    else "Students can move tasks from To Do to In Progress, then submit them For Review."
                )
                raise HTTPException(403, message)
            if user["role"] != "adviser" and body.status == "review":
                attached = conn.execute(
                    text("SELECT 1 FROM documents WHERE task_id = :task_id LIMIT 1"),
                    {"task_id": task_id},
                ).first()
                if not attached:
                    raise HTTPException(409, "Attach your completed work to this task before submitting it for review.")
        sets, params = [], {"id": task_id}
        for field in ("title", "description", "status", "due_date"):
            value = getattr(body, field)
            if field == "due_date":
                if field in body.model_fields_set:
                    sets.append("due_date = :due_date")
                    params["due_date"] = value
                    sets.append("reminder_sent_at = NULL")
                continue
            if value is not None:
                sets.append(f"{field} = :{field}")
                params[field] = value.strip() if isinstance(value, str) else value
        if not sets:
            raise HTTPException(400, "Nothing to update.")
        conn.execute(text(f"UPDATE kanban_tasks SET {', '.join(sets)} WHERE task_id = :id"), params)
        if body.status and body.status != t["status"]:
            notify(conn, other_party(app_row, user), f"{user['name']} moved \"{t['title']}\" to {STATUS_LABEL[body.status]}.")
    return {"message": "Task updated."}


@app.delete("/api/tasks/{task_id}")
def delete_task(task_id: int, user: dict = Depends(current_user)):
    if user["role"] != "adviser":
        raise HTTPException(403, "Only your adviser can delete board tasks.")
    with engine.begin() as conn:
        load_task(conn, task_id, user)
        conn.execute(text("UPDATE documents SET task_id = NULL WHERE task_id = :id"), {"id": task_id})
        conn.execute(text("DELETE FROM kanban_tasks WHERE task_id = :id"), {"id": task_id})
    return {"message": "Task deleted."}


@app.post("/api/tasks/{task_id}/comments", status_code=201)
async def add_comment(
    task_id: int,
    body: str = Form(..., min_length=1, max_length=2000),
    file: Optional[UploadFile] = File(default=None),
    user: dict = Depends(current_user),
):
    comment_body = body.strip()
    if not comment_body:
        raise HTTPException(400, "Comment cannot be empty.")

    with engine.connect() as conn:
        task, app_row = load_task(conn, task_id, user)
        if not can_comment_on_task(user["role"], is_application_leader(conn, app_row, user)):
            raise HTTPException(403, "Only the adviser or group leader can reply to task comments.")

    uploaded_file = await store_uploaded_file(file) if file else None
    file_saved = uploaded_file is None
    try:
        with engine.begin() as conn:
            task, app_row = load_task(conn, task_id, user)
            if not can_comment_on_task(user["role"], is_application_leader(conn, app_row, user)):
                raise HTTPException(403, "Only the adviser or group leader can reply to task comments.")
            comment_result = conn.execute(
                text("INSERT INTO task_comments (task_id, author_id, body) VALUES (:t, :a, :b)"),
                {"t": task_id, "a": user["user_id"], "b": comment_body},
            )
            document_id = None
            if uploaded_file is not None:
                name, stored, size, _ = uploaded_file
                document_result = conn.execute(
                    text(
                        "INSERT INTO documents "
                        "(application_id, booking_id, uploaded_by, filename, stored_name, size_bytes, "
                        "category, task_id, task_comment_id) "
                        "VALUES (:a, NULL, :u, :f, :s, :z, :c, :task_id, :comment_id)"
                    ),
                    {
                        "a": app_row["application_id"],
                        "u": user["user_id"],
                        "f": name[:255],
                        "s": stored,
                        "z": size,
                        "c": task["status"],
                        "task_id": task_id,
                        "comment_id": comment_result.lastrowid,
                    },
                )
                document_id = document_result.lastrowid
            recipient_id = app_row["adviser_id"] if user["role"] == "student" else app_row["student_id"]
            action = "replied to" if user["role"] == "student" else "commented on"
            attachment_note = " with an attachment" if uploaded_file is not None else ""
            notify(
                conn,
                recipient_id,
                f"{user['name']} {action} \"{task['title']}\"{attachment_note}.",
                related_user_id=user["user_id"],
            )
        file_saved = True
    finally:
        if uploaded_file is not None and not file_saved and os.path.exists(uploaded_file[3]):
            os.remove(uploaded_file[3])

    return {
        "comment_id": comment_result.lastrowid,
        "document_id": document_id,
        "message": "Comment added.",
    }


# =====================================================================
# Documents (student ang nag-a-upload, makikita ng adviser)
# =====================================================================
@app.post("/api/applications/{application_id}/documents", status_code=201)
async def upload_document(
    application_id: int,
    file: UploadFile = File(...),
    booking_id: Optional[int] = Form(default=None),
    category: str = Form(default="todo"),
    task_id: Optional[int] = Form(default=None),
    user: dict = Depends(student_only),
):
    # Ang file ay nakakabit sa kategorya (column) ng board kung saan ito in-upload: To Do, In Progress, o For Review.
    if category not in ("todo", "in_progress", "review"):
        raise HTTPException(400, "Files can be uploaded to To Do, In Progress, or For Review.")
    if task_id is None and booking_id is None:
        raise HTTPException(400, "Choose a task before uploading board work.")
    with engine.connect() as conn:
        app_row = get_approved_application(conn, application_id, user)
        if not is_application_leader(conn, app_row, user):
            raise HTTPException(403, "Only the group leader can upload board files.")
        if task_id is not None:
            task = conn.execute(
                text("SELECT title, status FROM kanban_tasks WHERE task_id = :task_id AND application_id = :application_id"),
                {"task_id": task_id, "application_id": application_id},
            ).mappings().first()
            if task is None:
                raise HTTPException(404, "Task not found.")
            if task["status"] != "in_progress":
                raise HTTPException(409, "Start the task before attaching your work.")
        if booking_id is not None:
            ok = conn.execute(
                text("SELECT 1 FROM bookings WHERE booking_id = :b AND application_id = :a"),
                {"b": booking_id, "a": application_id},
            ).first()
            if not ok:
                raise HTTPException(404, "That booking does not belong to your application.")
    name, stored, size, path = await store_uploaded_file(file)
    persisted = False
    try:
        with engine.begin() as conn:
            res = conn.execute(
                text(
                    "INSERT INTO documents (application_id, booking_id, uploaded_by, filename, stored_name, size_bytes, category, task_id) "
                    "VALUES (:a, :b, :u, :f, :s, :z, :c, :task_id)"
                ),
                {"a": application_id, "b": booking_id, "u": user["user_id"], "f": name[:255], "s": stored, "z": size, "c": category, "task_id": task_id},
            )
            if task_id is not None:
                notify(conn, app_row["adviser_id"], f"{user['name']} attached {name[:80]} as work for \"{task['title']}\".")
            else:
                label = {"todo": "To Do", "in_progress": "In Progress", "review": "For Review"}[category]
                notify(conn, app_row["adviser_id"], f"{user['name']} uploaded {name[:80]} to {label}.")
        persisted = True
    finally:
        if not persisted and os.path.exists(path):
            os.remove(path)
    return {"document_id": res.lastrowid, "message": "Uploaded."}


@app.get("/api/applications/{application_id}/documents")
def list_documents(application_id: int, user: dict = Depends(current_user)):
    with engine.connect() as conn:
        get_approved_application(conn, application_id, user)
        rows = conn.execute(
            text(
                "SELECT d.document_id, d.booking_id, d.task_id, d.category, d.filename, d.size_bytes, d.uploaded_at, d.uploaded_by, u.name AS uploaded_by_name "
                "FROM documents d JOIN users u ON u.user_id = d.uploaded_by WHERE d.application_id = :a ORDER BY d.document_id DESC"
            ),
            {"a": application_id},
        ).mappings().all()
    return [clean(r) for r in rows]


@app.get("/api/documents/{document_id}/download")
def download_document(document_id: int, preview: bool = False, user: dict = Depends(current_user)):
    with engine.connect() as conn:
        d = conn.execute(
            text("SELECT application_id, filename, stored_name FROM documents WHERE document_id = :id"), {"id": document_id}
        ).mappings().first()
        if d is None:
            raise HTTPException(404, "Document not found.")
        get_approved_application(conn, d["application_id"], user)
    path = os.path.join(UPLOAD_DIR, d["stored_name"])
    if not os.path.exists(path):
        raise HTTPException(404, "The file is missing on the server.")
    media_type, _ = mimetypes.guess_type(d["filename"])
    inline = preview and (media_type == "application/pdf" or media_type == "text/plain" or (media_type or "").startswith("image/"))
    return FileResponse(
        path,
        media_type=media_type if inline else "application/octet-stream",
        filename=None if inline else d["filename"],
        headers={"Content-Disposition": "inline", "X-Content-Type-Options": "nosniff"} if inline else None,
    )


@app.delete("/api/documents/{document_id}")
def delete_document(document_id: int, user: dict = Depends(student_only)):
    with engine.begin() as conn:
        d = conn.execute(
            text(
                "SELECT application_id, stored_name, task_id, uploaded_by FROM documents WHERE document_id = :id"
            ),
            {"id": document_id},
        ).mappings().first()
        if d is None:
            raise HTTPException(404, "Document not found.")
        app_row = get_approved_application(conn, d["application_id"], user)
        if not is_application_leader(conn, app_row, user):
            raise HTTPException(403, "Only the group leader can delete board files.")
        if d["uploaded_by"] != user["user_id"]:
            raise HTTPException(403, "You can only delete files you uploaded.")
        if d["task_id"] is not None:
            task = conn.execute(
                text("SELECT status FROM kanban_tasks WHERE task_id = :id"), {"id": d["task_id"]}
            ).mappings().first()
            if task and task["status"] in ("review", "done"):
                raise HTTPException(409, "Submitted task attachments cannot be deleted.")
        log_audit(conn, user["user_id"], "DOCUMENT_DELETE", "document", document_id,
                  new_values={"application_id": d["application_id"]})
        conn.execute(text("DELETE FROM documents WHERE document_id = :id"), {"id": document_id})
    path = os.path.join(UPLOAD_DIR, d["stored_name"])
    if os.path.exists(path):
        os.remove(path)
    return {"message": "Deleted."}


# =====================================================================
# Notifications
# =====================================================================
@app.get("/api/notifications")
def notifications(limit: int = 30, user: dict = Depends(current_user)):
    limit = max(1, min(limit, 200))
    with engine.begin() as conn:
        run_reminders(conn)  # tuwing magpo-poll ang app, sinisilip kung may malapit nang consultation
        rows = conn.execute(
            text(
                "SELECT notification_id, message, is_read, related_user_id, related_application_id, "
                "related_message_id, date_sent FROM notifications "
                "WHERE user_id = :u ORDER BY notification_id DESC LIMIT :lim"
            ),
            {"u": user["user_id"], "lim": limit},
        ).mappings().all()
        unread = conn.execute(
            text("SELECT COUNT(*) FROM notifications WHERE user_id = :u AND is_read = 0"), {"u": user["user_id"]}
        ).scalar()
        items = []
        for row in rows:
            item = dict(row)
            if (
                item["related_application_id"] is None
                and item["related_user_id"] is not None
                and item["message"].lower().startswith("new message from ")
            ):
                preview = item["message"].partition(": ")[2]
                if preview:
                    target = conn.execute(
                        text(
                            "SELECT m.application_id, m.message_id "
                            "FROM messages m JOIN applications a ON a.application_id = m.application_id "
                            "WHERE m.sender_id = :sender AND a.status = 'approved' "
                            "AND (a.student_id = :recipient OR a.adviser_id = :recipient) "
                            "AND m.created_at BETWEEN DATE_SUB(:sent_at, INTERVAL 2 MINUTE) "
                            "AND DATE_ADD(:sent_at, INTERVAL 2 MINUTE) "
                            "AND LEFT(m.body, CHAR_LENGTH(:preview)) = :preview "
                            "ORDER BY ABS(TIMESTAMPDIFF(SECOND, m.created_at, :sent_at)), "
                            "m.message_id DESC LIMIT 1"
                        ),
                        {
                            "sender": item["related_user_id"],
                            "recipient": user["user_id"],
                            "sent_at": item["date_sent"],
                            "preview": preview,
                        },
                    ).mappings().first()
                    if target:
                        item["related_application_id"] = target["application_id"]
                        item["related_message_id"] = target["message_id"]
            item.pop("related_user_id", None)
            items.append(clean(item))
    return {"items": items, "unread": int(unread or 0)}


@app.post("/api/notifications/read-all")
def read_all(user: dict = Depends(current_user)):
    with engine.begin() as conn:
        conn.execute(text("UPDATE notifications SET is_read = 1 WHERE user_id = :u"), {"u": user["user_id"]})
    return {"message": "All read."}


@app.post("/api/notifications/{notification_id}/read")
def read_one(notification_id: int, user: dict = Depends(current_user)):
    with engine.begin() as conn:
        res = conn.execute(
            text("UPDATE notifications SET is_read = 1 WHERE notification_id = :id AND user_id = :u"),
            {"id": notification_id, "u": user["user_id"]},
        )
    if res.rowcount == 0:
        # rowcount ay 0 rin kapag nabasa na; tiyakin kung sa kaniya nga ang notification
        with engine.connect() as conn:
            mine = conn.execute(
                text("SELECT 1 FROM notifications WHERE notification_id = :id AND user_id = :u"),
                {"id": notification_id, "u": user["user_id"]},
            ).first()
        if mine is None:
            raise HTTPException(404, "Notification not found.")
    return {"message": "Read."}


# =====================================================================
# Admin at Analytics (Descriptive / Diagnostic / Predictive / Prescriptive)
# =====================================================================
@app.get("/api/analytics")
def analytics(user: dict = Depends(current_user)):
    """Admin: buong sistema. Adviser: sarili at mga advisee lang. Student: bawal."""
    if user["role"] == "student":
        raise HTTPException(403, "Analytics are for advisers and the admin.")
    with engine.connect() as conn:
        return build_report(conn, user["user_id"] if user["role"] == "adviser" else None)


@app.get("/api/analytics/details/{category}")
def analytics_details(category: str, user: dict = Depends(current_user)):
    """Return records behind an analytics category, scoped to the signed-in adviser."""
    if user["role"] == "student":
        raise HTTPException(403, "Analytics are for advisers and the admin.")

    adviser_id = user["user_id"] if user["role"] == "adviser" else None
    params = {}
    if adviser_id:
        params["aid"] = adviser_id

    user_filters = {
        "students": "u.role = 'student'",
        "advisers": "u.role = 'adviser'",
    }
    if category in user_filters:
        sql = (
            "SELECT u.user_id, u.name, u.email, u.role, u.account_status, u.created_at "
            "FROM users u WHERE " + user_filters[category] + " "
        )
        if adviser_id:
            if category == "advisers":
                sql += "AND u.user_id = :aid "
            else:
                sql += (
                    "AND EXISTS (SELECT 1 FROM applications a WHERE a.student_id = u.user_id "
                    "AND a.adviser_id = :aid) "
                )
        sql += "ORDER BY u.name"
    elif category in ("applications", "pending", "acceptance", "advisees"):
        sql = (
            "SELECT a.application_id, s.name AS student, s.email AS student_email, "
            "v.name AS adviser, v.email AS adviser_email, a.topic_brief, a.status, a.date_submitted "
            "FROM applications a JOIN users s ON s.user_id = a.student_id "
            "JOIN users v ON v.user_id = a.adviser_id WHERE 1 = 1 "
        )
        if category == "pending":
            sql += "AND a.status = 'pending' "
        elif category == "acceptance":
            sql += "AND a.status IN ('approved', 'declined') "
        elif category == "advisees":
            sql += "AND a.status = 'approved' "
        if adviser_id:
            sql += "AND a.adviser_id = :aid "
        sql += "ORDER BY a.date_submitted DESC, a.application_id DESC"
    elif category in ("consultations", "bookings", "cancellations", "weekday", "hour", "cancelled_by", "cancel_weekday"):
        sql = (
            "SELECT b.booking_id, s.name AS student, v.name AS adviser, a.topic_brief, "
            "b.slot_date, b.start_time, b.end_time, b.status, b.meeting_type, b.location, "
            "b.cancel_reason, c.name AS cancelled_by "
            "FROM bookings b JOIN users s ON s.user_id = b.student_id "
            "JOIN users v ON v.user_id = b.adviser_id "
            "JOIN applications a ON a.application_id = b.application_id "
            "LEFT JOIN users c ON c.user_id = b.cancelled_by WHERE 1 = 1 "
        )
        if category in ("consultations", "weekday", "hour"):
            sql += "AND b.status IN ('confirmed', 'completed') "
        elif category in ("cancellations", "cancelled_by", "cancel_weekday"):
            sql += "AND b.status = 'cancelled' "
        if adviser_id:
            sql += "AND b.adviser_id = :aid "
        sql += "ORDER BY b.slot_date DESC, b.start_time DESC"
    elif category == "ratings":
        sql = (
            "SELECT r.rating_id, s.name AS student, v.name AS adviser, r.stars, r.comment, "
            "r.created_at, b.slot_date, b.start_time "
            "FROM consultation_ratings r JOIN users s ON s.user_id = r.student_id "
            "JOIN users v ON v.user_id = r.adviser_id "
            "JOIN bookings b ON b.booking_id = r.booking_id WHERE 1 = 1 "
        )
        if adviser_id:
            sql += "AND r.adviser_id = :aid "
        sql += "ORDER BY r.created_at DESC"
    elif category == "tasks":
        sql = (
            "SELECT t.task_id, t.title, t.status, t.points, s.name AS student, "
            "v.name AS adviser, t.created_at, t.updated_at "
            "FROM kanban_tasks t JOIN applications a ON a.application_id = t.application_id "
            "JOIN users s ON s.user_id = a.student_id JOIN users v ON v.user_id = a.adviser_id "
            "WHERE 1 = 1 "
        )
        if adviser_id:
            sql += "AND a.adviser_id = :aid "
        sql += "ORDER BY t.updated_at DESC, t.task_id DESC"
    elif category == "workload":
        with engine.connect() as conn:
            report = build_report(conn, adviser_id)
        return report["descriptive"]["advisers"]
    else:
        raise HTTPException(404, "Analytics category not found.")

    with engine.connect() as conn:
        rows = conn.execute(text(sql), params).mappings().all()
    return [clean(row) for row in rows]


@app.get("/api/admin/users")
def admin_users(
    q: str = "",
    role: str = "",
    status: str = "",
    limit: int = 50,
    offset: int = 0,
    user: dict = Depends(admin_only),
):
    sql = (
        "SELECT u.user_id, u.name, u.email, u.role, u.contact_number, u.profile_photo, u.created_at, u.account_status, "
        "(SELECT COUNT(*) FROM applications a WHERE a.adviser_id = u.user_id AND a.status = 'approved') AS advisees, "
        "(SELECT v.name FROM applications a JOIN users v ON v.user_id = a.adviser_id "
        " WHERE a.student_id = u.user_id AND a.status = 'approved' LIMIT 1) AS adviser_name, "
        "(SELECT v.profile_photo FROM applications a JOIN users v ON v.user_id = a.adviser_id "
        " WHERE a.student_id = u.user_id AND a.status = 'approved' LIMIT 1) AS adviser_profile_photo "
        "FROM users u WHERE 1 = 1 "
    )
    count_sql = "SELECT COUNT(*) FROM users u WHERE 1 = 1 "
    params: dict = {}
    if role in ("student", "adviser", "admin"):
        sql += "AND u.role = :r "
        count_sql += "AND u.role = :r "
        params["r"] = role
    if status in ("active", "pending", "disabled"):
        sql += "AND u.account_status = :s "
        count_sql += "AND u.account_status = :s "
        params["s"] = status
    if q.strip():
        sql += "AND (u.name LIKE :q OR u.email LIKE :q) "
        count_sql += "AND (u.name LIKE :q OR u.email LIKE :q) "
        params["q"] = f"%{q.strip()}%"
    limit = max(1, min(limit, 200))
    offset = max(0, offset)
    count_params = params.copy()
    params.update({"lim": limit, "off": offset})
    sql += "ORDER BY u.role, u.name LIMIT :lim OFFSET :off"
    with engine.connect() as conn:
        total = conn.execute(text(count_sql), count_params).scalar_one()
        rows = conn.execute(text(sql), params).mappings().all()
    return {"items": [clean(r) for r in rows], "total": total, "limit": limit, "offset": offset}


@app.patch("/api/admin/users/{user_id}/status")
def admin_set_status(user_id: int, body: StatusIn, user: dict = Depends(admin_only), request: Request = None):
    """Admin: i-approve ang bagong adviser, o i-deactivate/i-reactivate ang account (hindi pwede ang admin)."""
    if user_id == user["user_id"]:
        raise HTTPException(400, "You cannot change your own account.")
    with engine.begin() as conn:
        row = conn.execute(text("SELECT role, account_status, name FROM users WHERE user_id = :id"), {"id": user_id}).first()
        if row is None:
            raise HTTPException(404, "User not found.")
        if row[0] == "admin":
            raise HTTPException(400, "Admin accounts cannot be changed here.")
        old_status = row[1]
        conn.execute(text("UPDATE users SET account_status = :s WHERE user_id = :id"), {"s": body.status, "id": user_id})
        if row[0] == "adviser" and old_status == "pending" and body.status == "active":
            conn.execute(
                text(
                    "DELETE FROM notifications WHERE user_id IN (SELECT user_id FROM users WHERE role = 'admin') "
                    "AND (related_user_id = :id OR (related_user_id IS NULL AND message = :message))"
                ),
                {
                    "id": user_id,
                    "message": f"New adviser registration: {row[2]} is waiting for your approval.",
                },
            )
        log_audit(conn, user["user_id"], "STATUS_CHANGE", "user", user_id,
                  old_values={"account_status": old_status},
                  new_values={"account_status": body.status},
                  request=request)
    return {"message": "Account activated." if body.status == "active" else "Account deactivated."}


# ---- Login History (Admin) ----
@app.get("/api/admin/login-history")
def admin_login_history(limit: int = 100, user_id: int = None, success: bool = None, user: dict = Depends(admin_only)):
    """Get login history with optional filters."""
    limit = max(1, min(limit, 500))
    sql = """
        SELECT l.login_id, l.user_id, l.email_attempted, l.ip_address, l.user_agent,
               l.success, l.failure_reason, l.created_at, u.name AS user_name
        FROM login_history l
        LEFT JOIN users u ON u.user_id = l.user_id
        WHERE 1=1
    """
    params: dict = {}
    if user_id is not None:
        sql += " AND l.user_id = :uid "
        params["uid"] = user_id
    if success is not None:
        sql += " AND l.success = :success "
        params["success"] = 1 if success else 0
    sql += " ORDER BY l.created_at DESC LIMIT :lim"
    params["lim"] = limit
    with engine.connect() as conn:
        rows = conn.execute(text(sql), params).mappings().all()
    return [clean(r) for r in rows]


# ---- Audit Logs (Admin) ----
@app.get("/api/admin/audit-logs")
def admin_audit_logs(limit: int = 100, user_id: int = None, action: str = None, target_type: str = None, user: dict = Depends(admin_only)):
    """Get audit logs with optional filters."""
    limit = max(1, min(limit, 500))
    sql = """
        SELECT a.audit_id, a.user_id, a.action, a.target_type, a.target_id,
               a.old_values, a.new_values, a.ip_address, a.user_agent, a.created_at,
               u.name AS user_name
        FROM audit_logs a
        LEFT JOIN users u ON u.user_id = a.user_id
        WHERE 1=1
    """
    params: dict = {}
    if user_id is not None:
        sql += " AND a.user_id = :uid "
        params["uid"] = user_id
    if action:
        sql += " AND a.action = :action "
        params["action"] = action
    if target_type:
        sql += " AND a.target_type = :ttype "
        params["ttype"] = target_type
    sql += " ORDER BY a.created_at DESC LIMIT :lim"
    params["lim"] = limit
    with engine.connect() as conn:
        rows = conn.execute(text(sql), params).mappings().all()
    return [clean(r) for r in rows]


# ---- Backup Management (Admin) ----
class BackupStartIn(BaseModel):
    backup_type: Literal["full", "incremental", "schema_only"]
    tables: Optional[str] = None

@app.post("/api/admin/backup/start")
def admin_backup_start(body: BackupStartIn, user: dict = Depends(admin_only)):
    """Start a backup operation (logs the start)."""
    with engine.begin() as conn:
        result = conn.execute(
            text("CALL sp_log_backup_start(:type, :path, :tables)"),
            {"type": body.backup_type, "path": f"backup_{body.backup_type}_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.sql", "tables": body.tables or "all"},
        ).mappings().first()
    return {"backup_id": result["backup_id"], "message": "Backup started. Run actual backup command separately."}


class BackupCompleteIn(BaseModel):
    backup_id: int
    file_size: int
    checksum: str
    status: Literal["completed", "failed"]
    error: Optional[str] = None

@app.post("/api/admin/backup/complete")
def admin_backup_complete(body: BackupCompleteIn, user: dict = Depends(admin_only)):
    """Mark backup as complete (call after running mysqldump)."""
    with engine.begin() as conn:
        conn.execute(
            text("CALL sp_log_backup_complete(:id, :size, :checksum, :status, :error)"),
            {"id": body.backup_id, "size": body.file_size, "checksum": body.checksum, "status": body.status, "error": body.error},
        )
    return {"message": "Backup log updated."}


@app.get("/api/admin/backup/logs")
def admin_backup_logs(limit: int = 50, user: dict = Depends(admin_only)):
    """Get backup logs."""
    limit = max(1, min(limit, 200))
    with engine.connect() as conn:
        rows = conn.execute(
            text("SELECT * FROM backup_log ORDER BY started_at DESC LIMIT :lim"),
            {"lim": limit},
        ).mappings().all()
    return [clean(r) for r in rows]


# ---- Database Maintenance (Admin) ----
@app.post("/api/admin/maintenance/clean-login-history")
def admin_clean_login_history(months: int = 12, user: dict = Depends(admin_only)):
    """Clean old login history entries."""
    with engine.begin() as conn:
        result = conn.execute(text("CALL sp_clean_login_history(:months)"), {"months": months}).mappings().first()
    return {"deleted_rows": result["deleted_rows"]}


@app.post("/api/admin/maintenance/clean-audit-logs")
def admin_clean_audit_logs(months: int = 12, user: dict = Depends(admin_only)):
    """Clean old audit log entries."""
    with engine.begin() as conn:
        result = conn.execute(text("CALL sp_clean_audit_logs(:months)"), {"months": months}).mappings().first()
    return {"deleted_rows": result["deleted_rows"]}


@app.get("/api/admin/maintenance/adviser-workload/{adviser_id}")
def admin_adviser_workload(adviser_id: int, user: dict = Depends(admin_only)):
    """Get adviser workload statistics."""
    with engine.connect() as conn:
        result = conn.execute(text("CALL sp_adviser_workload(:aid)"), {"aid": adviser_id}).mappings().first()
    return clean(result) if result else {}


@app.post("/api/applications/{application_id}/nudge")
def nudge_advisee(application_id: int, user: dict = Depends(adviser_only)):
    """Isang click na paalala sa advisee na i-update ang board niya (isang beses lang kada 24 oras)."""
    with engine.begin() as conn:
        a = conn.execute(
            text("SELECT student_id, status FROM applications WHERE application_id = :id AND adviser_id = :u"),
            {"id": application_id, "u": user["user_id"]},
        ).first()
        if a is None or a[1] != "approved":
            raise HTTPException(404, "Advisee not found.")
        msg = f"{user['name']} asked for a progress update on your board."
        recent = conn.execute(
            text("SELECT 1 FROM notifications WHERE user_id = :s AND message = :m AND date_sent > (NOW() - INTERVAL 1 DAY)"),
            {"s": a[0], "m": msg},
        ).first()
        if recent:
            raise HTTPException(429, "You already sent a reminder in the last 24 hours.")
        notify(conn, a[0], msg)
    return {"message": "Reminder sent."}


@app.get("/api/attention")
def attention(user: dict = Depends(current_user)):
    """Mga dapat gawin ngayon (iba para sa student at adviser), para hindi na maghanap sa bawat pahina."""
    with engine.connect() as conn:
        return build_attention(conn, user)


# =====================================================================
# Phase B: New Features
# =====================================================================

# ---- Messages (Student <-> Adviser chat per application) ----
def message_window_offset(conn, application_id: int, limit: int, target_message_id: Optional[int]) -> int:
    if target_message_id is None:
        return 0
    target_exists = conn.execute(
        text("SELECT 1 FROM messages WHERE application_id = :a AND message_id = :m"),
        {"a": application_id, "m": target_message_id},
    ).first()
    if target_exists is None:
        return 0
    newer_count = conn.execute(
        text("SELECT COUNT(*) FROM messages WHERE application_id = :a AND message_id > :m"),
        {"a": application_id, "m": target_message_id},
    ).scalar()
    return max(0, int(newer_count or 0) - limit // 2)


@app.get("/api/applications/{application_id}/messages")
def get_messages(
    application_id: int,
    limit: int = 50,
    target_message_id: Optional[int] = None,
    user: dict = Depends(current_user),
):
    """Get messages for an application (both student and adviser can see)."""
    limit = max(1, min(limit, 200))
    with engine.begin() as conn:
        app_row = get_approved_application(conn, application_id, user)
        peer_id = app_row["adviser_id"] if user["role"] == "student" else app_row["student_id"]
        offset = message_window_offset(conn, application_id, limit, target_message_id)
        conn.execute(
            text(
                "UPDATE messages SET delivered_at = COALESCE(delivered_at, NOW()) "
                "WHERE application_id = :a AND sender_id != :u AND delivered_at IS NULL "
                "AND (sender_id = :peer OR sender_id IN "
                "(SELECT user_id FROM users WHERE role = 'admin'))"
            ),
            {"a": application_id, "u": user["user_id"], "peer": peer_id},
        )
        rows = conn.execute(
            text(
                "SELECT m.message_id, m.body, m.is_read, m.delivered_at, m.read_at, m.created_at, u.name AS sender_name, "
                "u.profile_photo AS sender_profile_photo, u.role AS sender_role, m.sender_id, "
                "m.message_kind, m.language_code, m.moderation_categories "
                "FROM messages m JOIN users u ON u.user_id = m.sender_id "
                "WHERE m.application_id = :a ORDER BY m.created_at DESC, m.message_id DESC LIMIT :lim OFFSET :offset"
            ),
            {"a": application_id, "lim": limit, "offset": offset},
        ).mappings().all()
    return [clean(r) for r in reversed(rows)]


@app.post("/api/applications/{application_id}/messages/read")
def mark_messages_read(
    application_id: int,
    through_message_id: Optional[int] = None,
    user: dict = Depends(current_user),
):
    """Mark incoming messages as seen after the conversation has loaded."""
    with engine.begin() as conn:
        app_row = get_approved_application(conn, application_id, user)
        if through_message_id is None:
            return {"message": "No messages to mark as read."}
        peer_id = app_row["adviser_id"] if user["role"] == "student" else app_row["student_id"]
        conn.execute(
            text(
                "UPDATE messages SET is_read = 1, "
                "delivered_at = COALESCE(delivered_at, NOW()), "
                "read_at = COALESCE(read_at, NOW()) "
                "WHERE application_id = :a AND sender_id != :u "
                "AND message_id <= :message_id AND read_at IS NULL "
                "AND (sender_id = :peer OR sender_id IN "
                "(SELECT user_id FROM users WHERE role = 'admin'))"
            ),
            {
                "a": application_id,
                "u": user["user_id"],
                "peer": peer_id,
                "message_id": through_message_id,
            },
        )
    return {"message": "Messages marked as read."}


def get_chat_application(conn, application_id: int, user: dict) -> dict:
    if user["role"] != "admin":
        return get_approved_application(conn, application_id, user)
    app_row = conn.execute(
        text(
            "SELECT application_id, student_id, adviser_id FROM applications "
            "WHERE application_id = :a AND status = 'approved'"
        ),
        {"a": application_id},
    ).mappings().first()
    if app_row is None:
        raise HTTPException(404, "Approved application not found.")
    return dict(app_row)


class ChatActivityIn(BaseModel):
    typing: bool = False


@app.post("/api/applications/{application_id}/messages/activity")
def update_chat_activity(
    application_id: int,
    body: ChatActivityIn,
    user: dict = Depends(current_user),
):
    """Keep short-lived presence and typing state for an approved conversation."""
    with engine.begin() as conn:
        get_chat_application(conn, application_id, user)
        conn.execute(
            text(
                "INSERT INTO chat_presence (application_id, user_id, last_active_at, typing_until) "
                "VALUES (:a, :u, NOW(), CASE WHEN :typing THEN DATE_ADD(NOW(), INTERVAL 8 SECOND) ELSE NULL END) "
                "ON DUPLICATE KEY UPDATE last_active_at = NOW(), "
                "typing_until = CASE WHEN :typing THEN DATE_ADD(NOW(), INTERVAL 8 SECOND) ELSE NULL END"
            ),
            {"a": application_id, "u": user["user_id"], "typing": body.typing},
        )
    return {"message": "Activity updated."}


@app.get("/api/applications/{application_id}/messages/activity")
def get_chat_activity(application_id: int, user: dict = Depends(current_user)):
    """Return whether the other conversation participant is online or typing."""
    with engine.connect() as conn:
        app_row = get_chat_application(conn, application_id, user)
        rows = conn.execute(
            text(
                "SELECT "
                "CASE WHEN last_active_at >= DATE_SUB(NOW(), INTERVAL 45 SECOND) THEN 1 ELSE 0 END AS is_online, "
                "CASE WHEN typing_until > NOW() THEN 1 ELSE 0 END AS is_typing "
                "FROM chat_presence WHERE application_id = :a "
                "AND user_id IN (:student, :adviser)"
                + (" " if user["role"] == "admin" else " AND user_id != :current_user")
            ),
            {
                "a": application_id,
                "student": app_row["student_id"],
                "adviser": app_row["adviser_id"],
                **({"current_user": user["user_id"]} if user["role"] != "admin" else {}),
            },
        ).mappings().all()
    return {
        "is_online": any(row["is_online"] for row in rows),
        "is_typing": any(row["is_typing"] for row in rows),
    }


@app.post("/api/applications/{application_id}/messages", status_code=201)
def send_message(application_id: int, body: MessageIn, user: dict = Depends(current_user)):
    """Send a message in the application chat."""
    with engine.begin() as conn:
        app_row = get_approved_application(conn, application_id, user)
        if user["role"] == "student" and not is_application_leader(conn, app_row, user):
            raise HTTPException(403, "Only the group leader can message the adviser.")
        other_id = app_row["adviser_id"] if user["user_id"] == app_row["student_id"] else app_row["student_id"]
        message_body = body.body.strip()
        message_id = store_chat_message(
            conn,
            application_id,
            user["user_id"],
            message_body,
            [(other_id, f"New message from {user['name']}: {message_body[:100]}")],
        )
    return {"message_id": message_id, "message": "Message sent."}


@app.get("/api/admin/messages")
def admin_message_threads(user: dict = Depends(admin_only)):
    """Admin inbox: application conversations with their latest message and unread count."""
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT a.application_id, a.topic_brief, a.student_id, a.adviser_id, "
                "s.name AS student_name, s.profile_photo AS student_profile_photo, "
                "v.name AS adviser_name, v.profile_photo AS adviser_profile_photo, "
                "m.message_id, m.body AS latest_message, m.created_at AS latest_created_at, "
                "m.message_kind AS latest_message_kind, m.moderation_categories AS latest_moderation_categories, "
                "(SELECT flagged.moderation_categories FROM messages flagged "
                "WHERE flagged.application_id = a.application_id AND flagged.moderation_categories IS NOT NULL "
                "ORDER BY flagged.message_id DESC LIMIT 1) AS latest_flagged_categories, "
                "sender.name AS latest_sender_name, "
                "(SELECT COUNT(*) FROM messages unread WHERE unread.application_id = a.application_id "
                "AND unread.sender_id != :u AND unread.is_read = 0) AS unread_count "
                "FROM applications a "
                "JOIN users s ON s.user_id = a.student_id "
                "JOIN users v ON v.user_id = a.adviser_id "
                "JOIN messages m ON m.message_id = ("
                "SELECT MAX(latest.message_id) FROM messages latest WHERE latest.application_id = a.application_id"
                ") "
                "JOIN users sender ON sender.user_id = m.sender_id "
                "WHERE a.status = 'approved' "
                "ORDER BY m.created_at DESC LIMIT 200"
            ),
            {"u": user["user_id"]},
        ).mappings().all()
    return [clean(row) for row in rows]


@app.get("/api/admin/messages/{application_id}")
def admin_get_messages(
    application_id: int,
    limit: int = 100,
    target_message_id: Optional[int] = None,
    user: dict = Depends(admin_only),
):
    """Admin: open an approved application conversation and mark incoming messages read."""
    limit = max(1, min(limit, 200))
    with engine.begin() as conn:
        app_row = conn.execute(
            text(
                "SELECT application_id, student_id, adviser_id, topic_brief "
                "FROM applications WHERE application_id = :a AND status = 'approved'"
            ),
            {"a": application_id},
        ).mappings().first()
        if app_row is None:
            raise HTTPException(404, "Approved application not found.")
        offset = message_window_offset(conn, application_id, limit, target_message_id)
        rows = conn.execute(
            text(
                "SELECT m.message_id, m.body, m.is_read, m.delivered_at, m.read_at, m.created_at, m.sender_id, "
                "u.name AS sender_name, u.profile_photo AS sender_profile_photo, u.role AS sender_role, "
                "m.message_kind, m.language_code, m.moderation_categories "
                "FROM messages m JOIN users u ON u.user_id = m.sender_id "
                "WHERE m.application_id = :a ORDER BY m.created_at DESC, m.message_id DESC LIMIT :lim OFFSET :offset"
            ),
            {"a": application_id, "lim": limit, "offset": offset},
        ).mappings().all()
        conn.execute(
            text(
                "UPDATE messages SET is_read = 1, "
                "delivered_at = COALESCE(delivered_at, NOW()), "
                "read_at = COALESCE(read_at, NOW()) "
                "WHERE application_id = :a AND sender_id != :u AND read_at IS NULL"
            ),
            {"a": application_id, "u": user["user_id"]},
        )
    return {"application": clean(app_row), "messages": [clean(row) for row in reversed(rows)]}


@app.post("/api/admin/messages/{application_id}", status_code=201)
def admin_send_message(application_id: int, body: MessageIn, user: dict = Depends(admin_only)):
    """Admin: reply in an approved application conversation."""
    message_body = body.body.strip()
    if not message_body:
        raise HTTPException(400, "Message cannot be empty.")
    with engine.begin() as conn:
        app_row = conn.execute(
            text(
                "SELECT application_id, student_id, adviser_id FROM applications "
                "WHERE application_id = :a AND status = 'approved'"
            ),
            {"a": application_id},
        ).mappings().first()
        if app_row is None:
            raise HTTPException(404, "Approved application not found.")
        message_id = store_chat_message(
            conn,
            application_id,
            user["user_id"],
            message_body,
            [
                (app_row["student_id"], f"New message from admin {user['name']}: {message_body[:100]}"),
                (app_row["adviser_id"], f"New message from admin {user['name']}: {message_body[:100]}"),
            ],
        )
    return {"message_id": message_id, "message": "Message sent."}


# ---- Milestones ----
@app.get("/api/applications/{application_id}/milestones")
def get_milestones(application_id: int, user: dict = Depends(current_user)):
    """Get milestones for an application."""
    with engine.connect() as conn:
        get_approved_application(conn, application_id, user)
        rows = conn.execute(
            text(
                "SELECT m.milestone_id, m.title, m.description, m.stage, m.due_date, m.completed_date, m.status, "
                "m.created_by, m.created_at, m.updated_at, u.name AS created_by_name "
                "FROM milestones m JOIN users u ON u.user_id = m.created_by "
                "WHERE m.application_id = :a ORDER BY m.due_date IS NULL, m.due_date, m.milestone_id"
            ),
            {"a": application_id},
        ).mappings().all()
    return [clean(r) for r in rows]


@app.post("/api/applications/{application_id}/milestones", status_code=201)
def create_milestone(application_id: int, body: MilestoneIn, user: dict = Depends(adviser_only)):
    """Create a milestone (adviser only)."""
    with engine.begin() as conn:
        get_approved_application(conn, application_id, user)
        res = conn.execute(
            text(
                "INSERT INTO milestones (application_id, title, description, stage, due_date, created_by) "
                "VALUES (:a, :t, :d, :s, :dd, :u)"
            ),
            {"a": application_id, "t": body.title.strip(), "d": (body.description or "").strip() or None,
             "s": body.stage, "dd": body.due_date, "u": user["user_id"]},
        )
        notify(conn, conn.execute(
            text("SELECT student_id FROM applications WHERE application_id = :a"), {"a": application_id}
        ).scalar(), f"New milestone added: {body.title}")
    return {"milestone_id": res.lastrowid, "message": "Milestone created."}


@app.patch("/api/milestones/{milestone_id}")
def update_milestone(milestone_id: int, body: MilestonePatch, user: dict = Depends(adviser_only)):
    """Update a milestone (adviser only)."""
    with engine.begin() as conn:
        row = conn.execute(
            text("SELECT m.*, a.student_id FROM milestones m JOIN applications a ON a.application_id = m.application_id WHERE m.milestone_id = :id AND a.adviser_id = :u"),
            {"id": milestone_id, "u": user["user_id"]},
        ).mappings().first()
        if not row:
            raise HTTPException(404, "Milestone not found.")
        sets, params = [], {"id": milestone_id}
        for field in ("title", "description", "stage", "due_date", "status"):
            value = getattr(body, field)
            if value is not None:
                sets.append(f"{field} = :{field}")
                params[field] = value.strip() if isinstance(value, str) else value
        if not sets:
            raise HTTPException(400, "Nothing to update.")
        # Auto-set completed_date when status changes to completed
        if body.status == "completed" and row["status"] != "completed":
            sets.append("completed_date = :cd")
            params["cd"] = datetime.date.today()
        elif body.status and body.status != "completed" and row["status"] == "completed":
            sets.append("completed_date = NULL")
        conn.execute(text(f"UPDATE milestones SET {', '.join(sets)} WHERE milestone_id = :id"), params)
    return {"message": "Milestone updated."}


@app.delete("/api/milestones/{milestone_id}")
def delete_milestone(milestone_id: int, user: dict = Depends(adviser_only)):
    """Delete a milestone (adviser only)."""
    with engine.begin() as conn:
        res = conn.execute(
            text("DELETE m FROM milestones m JOIN applications a ON a.application_id = m.application_id WHERE m.milestone_id = :id AND a.adviser_id = :u"),
            {"id": milestone_id, "u": user["user_id"]},
        )
    if res.rowcount == 0:
        raise HTTPException(404, "Milestone not found.")
    return {"message": "Milestone deleted."}


# ---- Document Versions ----
@app.get("/api/documents/{document_id}/versions")
def get_document_versions(document_id: int, user: dict = Depends(current_user)):
    """Get all versions of a document."""
    with engine.connect() as conn:
        d = conn.execute(
            text("SELECT application_id FROM documents WHERE document_id = :id"), {"id": document_id}
        ).mappings().first()
        if not d:
            raise HTTPException(404, "Document not found.")
        get_approved_application(conn, d["application_id"], user)
        rows = conn.execute(
            text(
                "SELECT v.version_id, v.version_number, v.filename, v.size_bytes, v.comment, v.created_at, u.name AS uploaded_by_name "
                "FROM document_versions v JOIN users u ON u.user_id = v.uploaded_by "
                "WHERE v.document_id = :d ORDER BY v.version_number DESC"
            ),
            {"d": document_id},
        ).mappings().all()
    return [clean(r) for r in rows]


@app.post("/api/documents/{document_id}/versions", status_code=201)
async def upload_document_version(
    document_id: int,
    file: UploadFile = File(...),
    comment: Optional[str] = Form(default=None),
    user: dict = Depends(student_only),
):
    """Upload a new version of a document."""
    name = os.path.basename(file.filename or "file")
    ext = name.rsplit(".", 1)[-1].lower() if "." in name else ""
    if ext not in ALLOWED_EXT:
        raise HTTPException(400, "That file type is not allowed. Use: " + ", ".join(sorted(ALLOWED_EXT)) + ".")
    stored = f"{uuid.uuid4().hex}.{ext}"
    path = os.path.join(UPLOAD_DIR, stored)
    size = 0
    with engine.connect() as conn:
        d = conn.execute(
            text("SELECT application_id FROM documents WHERE document_id = :id"), {"id": document_id}
        ).mappings().first()
        if not d:
            raise HTTPException(404, "Document not found.")
        app_row = get_approved_application(conn, d["application_id"], user)
        if not is_application_leader(conn, app_row, user):
            raise HTTPException(403, "Only the group leader can upload board file versions.")
        # Get next version number
        ver = conn.execute(
            text("SELECT COALESCE(MAX(version_number), 0) + 1 FROM document_versions WHERE document_id = :d"),
            {"d": document_id},
        ).scalar()
    try:
        with open(path, "wb") as out:
            while True:
                chunk = await file.read(1024 * 256)
                if not chunk:
                    break
                if size == 0 and not file_matches_type(ext, chunk[:16]):
                    raise HTTPException(400, f"The file content does not look like a real .{ext} file.")
                size += len(chunk)
                if size > MAX_UPLOAD_BYTES:
                    raise HTTPException(413, "File is too large (10 MB max).")
                out.write(chunk)
    except HTTPException:
        if os.path.exists(path):
            os.remove(path)
        raise
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO document_versions (document_id, version_number, filename, stored_name, size_bytes, uploaded_by, comment) "
                "VALUES (:d, :vn, :f, :s, :z, :u, :c)"
            ),
            {"d": document_id, "vn": ver, "f": name[:255], "s": stored, "z": size, "u": user["user_id"], "c": (comment or "").strip() or None},
        )
        # Notify adviser
        app_row = conn.execute(
            text("SELECT a.adviser_id, u.name AS student_name FROM documents d JOIN applications a ON a.application_id = d.application_id JOIN users u ON u.user_id = d.uploaded_by WHERE d.document_id = :id"),
            {"id": document_id},
        ).mappings().first()
        if app_row:
            notify(conn, app_row["adviser_id"], f"{app_row['student_name']} uploaded version {ver} of {name[:80]}")
    return {"version_id": ver, "message": f"Version {ver} uploaded."}


@app.get("/api/document-versions/{version_id}/download")
def download_document_version(version_id: int, user: dict = Depends(current_user)):
    """Download a specific document version."""
    with engine.connect() as conn:
        v = conn.execute(
            text(
                "SELECT v.document_id, v.filename, v.stored_name, d.application_id "
                "FROM document_versions v JOIN documents d ON d.document_id = v.document_id WHERE v.version_id = :id"
            ),
            {"id": version_id},
        ).mappings().first()
        if not v:
            raise HTTPException(404, "Version not found.")
        get_approved_application(conn, v["application_id"], user)
    path = os.path.join(UPLOAD_DIR, v["stored_name"])
    if not os.path.exists(path):
        raise HTTPException(404, "The file is missing on the server.")
    return FileResponse(path, filename=v["filename"])


# ---- Availability Exceptions ----
@app.get("/api/adviser/exceptions")
def get_availability_exceptions(user: dict = Depends(adviser_only)):
    """Get adviser's availability exceptions (blocked dates)."""
    with engine.connect() as conn:
        rows = conn.execute(
            text("SELECT exception_id, specific_date, start_time, end_time, reason, is_all_day, created_at FROM availability_exceptions WHERE adviser_id = :a ORDER BY specific_date"),
            {"a": user["user_id"]},
        ).mappings().all()
    return [clean(r) for r in rows]


@app.post("/api/adviser/exceptions", status_code=201)
def add_availability_exception(body: AvailabilityExceptionIn, user: dict = Depends(adviser_only)):
    """Add an availability exception (block a date or time range)."""
    s = to_minutes(body.start_time) if body.start_time else None
    e = to_minutes(body.end_time) if body.end_time else None
    with engine.begin() as conn:
        # Check for overlapping exceptions
        if not body.is_all_day:
            rows = conn.execute(
                text("SELECT specific_date, start_time, end_time, is_all_day FROM availability_exceptions WHERE adviser_id = :a AND specific_date = :d"),
                {"a": user["user_id"], "d": body.specific_date},
            ).mappings().all()
            for r in rows:
                if r["is_all_day"]:
                    raise HTTPException(409, "That date is already blocked as all-day.")
                rs, re = to_minutes(r["start_time"]), to_minutes(r["end_time"])
                if overlaps(s, e, rs, re):
                    raise HTTPException(409, "That overlaps with an existing exception.")
        else:
            # Check if any exception exists on that date
            exists = conn.execute(
                text("SELECT 1 FROM availability_exceptions WHERE adviser_id = :a AND specific_date = :d"),
                {"a": user["user_id"], "d": body.specific_date},
            ).first()
            if exists:
                raise HTTPException(409, "That date already has an exception.")
        res = conn.execute(
            text(
                "INSERT INTO availability_exceptions (adviser_id, specific_date, start_time, end_time, reason, is_all_day) "
                "VALUES (:a, :d, :st, :en, :r, :ad)"
            ),
            {"a": user["user_id"], "d": body.specific_date, "st": to_hhmm(s) + ":00" if s else None, "en": to_hhmm(e) + ":00" if e else None,
             "r": (body.reason or "").strip() or None, "ad": 1 if body.is_all_day else 0},
        )
    return {"exception_id": res.lastrowid, "message": "Exception added."}


@app.delete("/api/adviser/exceptions/{exception_id}")
def delete_availability_exception(exception_id: int, user: dict = Depends(adviser_only)):
    """Delete an availability exception."""
    with engine.begin() as conn:
        res = conn.execute(
            text("DELETE FROM availability_exceptions WHERE exception_id = :id AND adviser_id = :a"),
            {"id": exception_id, "a": user["user_id"]},
        )
    if res.rowcount == 0:
        raise HTTPException(404, "Exception not found.")
    return {"message": "Exception removed."}


# ---- Waitlist ----
@app.post("/api/waitlist", status_code=201)
def join_waitlist(body: WaitlistIn, user: dict = Depends(student_only)):
    """Join waitlist for a full adviser."""
    if user.get("student_group_role") == "member":
        raise HTTPException(403, "Only student group leaders can request an adviser.")
    require_student_project_title(user)
    with engine.begin() as conn:
        # Check if adviser exists and is full
        prof = conn.execute(
            text("SELECT max_capacity, current_advisee_count FROM adviser_profiles WHERE adviser_id = :a"),
            {"a": body.adviser_id},
        ).first()
        if not prof:
            raise HTTPException(404, "Adviser not found.")
        if (prof[1] or 0) < (prof[0] or 0):
            raise HTTPException(400, "This adviser has open slots. Apply directly instead.")
        # Check if student already has pending/approved application
        existing = conn.execute(
            text("SELECT 1 FROM applications WHERE student_id = :s AND adviser_id = :a AND status IN ('pending', 'approved')"),
            {"s": user["user_id"], "a": body.adviser_id},
        ).first()
        if existing:
            raise HTTPException(409, "You already have an application with this adviser.")
        # Check if already on waitlist
        existing_wl = conn.execute(
            text("SELECT 1 FROM waitlist WHERE student_id = :s AND adviser_id = :a AND status = 'waiting'"),
            {"s": user["user_id"], "a": body.adviser_id},
        ).first()
        if existing_wl:
            raise HTTPException(409, "You are already on the waitlist for this adviser.")
        # Get next position
        pos = conn.execute(
            text("SELECT COALESCE(MAX(position), 0) + 1 FROM waitlist WHERE adviser_id = :a AND status = 'waiting'"),
            {"a": body.adviser_id},
        ).scalar()
        # Expires in 7 days
        expires = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=7)
        res = conn.execute(
            text(
                "INSERT INTO waitlist (student_id, adviser_id, topic_brief, position, expires_at) "
                "VALUES (:s, :a, :t, :p, :e)"
            ),
            {"s": user["user_id"], "a": body.adviser_id, "t": body.topic_brief.strip(), "p": pos, "e": expires},
        )
        # Notify adviser
        adviser_name = conn.execute(text("SELECT name FROM users WHERE user_id = :a"), {"a": body.adviser_id}).scalar()
        notify(conn, body.adviser_id, f"{user['name']} joined your waitlist (position {pos})")
    return {"waitlist_id": res.lastrowid, "position": pos, "message": f"Added to waitlist at position {pos}."}


@app.get("/api/waitlist/me")
def my_waitlist(user: dict = Depends(student_only)):
    """Get student's waitlist entries."""
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT w.waitlist_id, w.adviser_id, w.topic_brief, w.position, w.status, w.notified_at, "
                "w.expires_at, w.created_at, u.name AS adviser_name, u.profile_photo AS adviser_profile_photo "
                "FROM waitlist w JOIN users u ON u.user_id = w.adviser_id WHERE w.student_id = :s ORDER BY w.created_at DESC"
            ),
            {"s": user["user_id"]},
        ).mappings().all()
    return [clean(r) for r in rows]


@app.get("/api/adviser/waitlist")
def adviser_waitlist(user: dict = Depends(adviser_only)):
    """Get adviser's waitlist."""
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT w.waitlist_id, w.student_id, w.topic_brief, w.position, w.status, w.notified_at, "
                "w.expires_at, w.created_at, u.name AS student_name, u.email AS student_email, "
                "u.profile_photo AS student_profile_photo "
                "FROM waitlist w JOIN users u ON u.user_id = w.student_id WHERE w.adviser_id = :a AND w.status = 'waiting' ORDER BY w.position"
            ),
            {"a": user["user_id"]},
        ).mappings().all()
    return [clean(r) for r in rows]


@app.post("/api/waitlist/{waitlist_id}/notify")
def notify_waitlist(waitlist_id: int, user: dict = Depends(adviser_only)):
    """Notify waitlisted student that a slot opened up."""
    with engine.begin() as conn:
        w = conn.execute(
            text("SELECT student_id, adviser_id, position FROM waitlist WHERE waitlist_id = :id AND adviser_id = :a"),
            {"id": waitlist_id, "a": user["user_id"]},
        ).mappings().first()
        if not w:
            raise HTTPException(404, "Waitlist entry not found.")
        if w["status"] != "waiting":
            raise HTTPException(409, "This entry is no longer waiting.")
        conn.execute(
            text("UPDATE waitlist SET status = 'notified', notified_at = NOW() WHERE waitlist_id = :id"),
            {"id": waitlist_id},
        )
        notify(conn, w["student_id"], f"A slot opened with your waitlisted adviser! Apply now before the offer expires.")
    return {"message": "Student notified. They have 48 hours to apply."}


@app.post("/api/waitlist/{waitlist_id}/cancel")
def cancel_waitlist(waitlist_id: int, user: dict = Depends(current_user)):
    """Cancel waitlist entry (student or adviser)."""
    with engine.begin() as conn:
        w = conn.execute(
            text("SELECT student_id, adviser_id FROM waitlist WHERE waitlist_id = :id"),
            {"id": waitlist_id},
        ).mappings().first()
        if not w or user["user_id"] not in (w["student_id"], w["adviser_id"]):
            raise HTTPException(404, "Waitlist entry not found.")
        conn.execute(text("UPDATE waitlist SET status = 'cancelled' WHERE waitlist_id = :id"), {"id": waitlist_id})
    return {"message": "Waitlist entry cancelled."}


# ---- Group/Panel Support ----
def require_student_project_title(user: dict) -> None:
    if user.get("role") == "student" and len((user.get("thesis_title") or "").strip()) < 10:
        raise HTTPException(409, "Update your profile with your complete thesis or capstone title first.")


def topic_match(query: str, interests: str) -> tuple[int, list[str]]:
    stop_words = {"a", "an", "and", "for", "in", "of", "on", "or", "the", "to", "with"}
    query_terms = {
        word for word in re.findall(r"[a-z0-9]+", query.lower())
        if len(word) > 1 and word not in stop_words
    }
    interest_terms = {
        word for word in re.findall(r"[a-z0-9]+", (interests or "").lower())
        if len(word) > 1 and word not in stop_words
    }
    matched = sorted(
        term for term in query_terms
        if any(term in interest or interest in term for interest in interest_terms)
    )
    return len(matched), matched


def match_group_search(query: str, student_title: str, group: dict) -> dict | None:
    query_title_count, query_title_matches = topic_match(query, group["topic_brief"] or "")
    query_leader_count, query_leader_matches = topic_match(
        query, " ".join(filter(None, (group["leader_name"], group["leader_email"])))
    )
    query_adviser_count, query_adviser_matches = topic_match(query, group["adviser_name"] or "")
    title_match_count, title_matches = topic_match(student_title, group["topic_brief"] or "")
    matched_topics = sorted(set(
        query_title_matches + query_leader_matches + query_adviser_matches + title_matches
    ))
    if not matched_topics:
        return None

    match_source = (
        "group leader" if query_leader_count
        else "project topic" if query_title_count
        else "adviser"
        if query_adviser_count
        else "your project title"
    )
    return {
        "matched_topics": matched_topics,
        "matched_by": match_source,
        "match_score": title_match_count * 2 + query_title_count + query_leader_count + query_adviser_count,
    }


@app.get("/api/group-members")
def available_group_members(q: str = "", user: dict = Depends(student_only)):
    """Search available group members by keyword, project title, name, email, or interests."""
    if user.get("student_group_role") == "member":
        raise HTTPException(403, "Only student group leaders can find group members.")
    require_student_project_title(user)
    query = q.strip()[:200]
    query_terms = {
        word for word in re.findall(r"[a-z0-9]+", query.lower())
        if len(word) > 1 and word not in {"a", "an", "and", "for", "in", "of", "on", "or", "the", "to", "with"}
    }
    if not query_terms:
        return []
    with engine.connect() as conn:
        project_title = user["thesis_title"]
        rows = conn.execute(
            text(
                "SELECT u.user_id, u.name, u.email, u.profile_photo, u.research_interests, u.thesis_title "
                "FROM users u WHERE u.role = 'student' AND u.account_status = 'active' "
                "AND u.student_group_role = 'member' "
                "AND CHAR_LENGTH(TRIM(COALESCE(u.thesis_title, ''))) >= 10 "
                "AND NOT EXISTS (SELECT 1 FROM applications a WHERE a.student_id = u.user_id "
                " AND a.status IN ('pending','approved')) "
                "AND NOT EXISTS (SELECT 1 FROM application_groups g WHERE g.student_id = u.user_id) "
                "AND NOT EXISTS (SELECT 1 FROM group_invitations i WHERE i.student_id = u.user_id AND i.status = 'pending') "
                "AND NOT EXISTS (SELECT 1 FROM group_join_requests r WHERE r.student_id = u.user_id AND r.status = 'pending') "
                "AND NOT EXISTS (SELECT 1 FROM student_group_requests r WHERE r.member_id = u.user_id "
                " AND r.status IN ('pending','approved'))"
            )
        ).mappings().all()
    matches = []
    for row in rows:
        direct_match_count, matched_topics = topic_match(
            query,
            " ".join(filter(None, (row["name"], row["email"], row["research_interests"]))),
        )
        title_match_count, title_topics = topic_match(project_title, row["research_interests"])
        project_match_count, project_topics = topic_match(project_title, row["thesis_title"])
        if direct_match_count or title_match_count or project_match_count:
            matches.append({
                "user_id": row["user_id"],
                "name": row["name"],
                "email": row["email"],
                "profile_photo": row["profile_photo"],
                "research_interests": row["research_interests"],
                "thesis_title": row["thesis_title"],
                "matched_topics": matched_topics,
                "matched_title_topics": sorted(set(title_topics + project_topics)),
                "match_count": direct_match_count,
                "title_match_count": title_match_count + project_match_count,
                "matched_by": (
                    "name or email"
                    if topic_match(query, " ".join(filter(None, (row["name"], row["email"]))))[0]
                    else "research interests"
                    if matched_topics
                    else "project title"
                ),
            })
    return sorted(
        matches,
        key=lambda item: (-item["match_count"], -item["title_match_count"], item["name"].lower()),
    )


@app.post("/api/applications/{application_id}/group-invitations", status_code=201)
def invite_group_member(application_id: int, body: GroupInvitationIn, user: dict = Depends(current_user)):
    """Invite a student to an approved project group; the invitee must accept."""
    with engine.begin() as conn:
        conn.execute(
            text("SELECT application_id FROM applications WHERE application_id = :a FOR UPDATE"),
            {"a": application_id},
        ).first()
        app_row = get_approved_application(conn, application_id, user)
        is_leader = conn.execute(
            text("SELECT 1 FROM application_groups WHERE application_id = :a AND student_id = :u AND is_leader = 1"),
            {"a": application_id, "u": user["user_id"]},
        ).first()
        if not can_manage_group_members(user, bool(is_leader)):
            raise HTTPException(403, "Only a student group leader can add members.")
        require_student_project_title(user)
        student = conn.execute(
            text(
                "SELECT user_id, name, student_group_role, account_status, thesis_title FROM users "
                "WHERE LOWER(email) = :e AND role = 'student'"
            ),
            {"e": body.student_email.lower()},
        ).mappings().first()
        if not student:
            raise HTTPException(404, "Student not found.")
        if student["student_group_role"] != "member" or student["account_status"] != "active":
            raise HTTPException(409, "Only active student group members can be invited.")
        if len((student.get("thesis_title") or "").strip()) < 10:
            raise HTTPException(409, "This student must complete their project title in their profile first.")
        if student["user_id"] == user["user_id"]:
            raise HTTPException(409, "You are already a member of this group.")
        has_group = conn.execute(
            text("SELECT 1 FROM application_groups WHERE student_id = :s LIMIT 1"),
            {"s": student["user_id"]},
        ).first()
        has_adviser = conn.execute(
            text("SELECT 1 FROM applications WHERE student_id = :s AND status IN ('pending','approved') LIMIT 1"),
            {"s": student["user_id"]},
        ).first()
        if has_group or has_adviser:
            raise HTTPException(409, "This student already has a group or adviser application.")
        existing_member = conn.execute(
            text("SELECT 1 FROM application_groups WHERE application_id = :a AND student_id = :s"),
            {"a": application_id, "s": student["user_id"]},
        ).first()
        if existing_member:
            raise HTTPException(409, "This student is already in the group.")
        pending_invite = conn.execute(
            text("SELECT 1 FROM group_invitations WHERE application_id = :a AND student_id = :s AND status = 'pending'"),
            {"a": application_id, "s": student["user_id"]},
        ).first()
        if pending_invite:
            raise HTTPException(409, "This student already has a pending invitation.")
        count = conn.execute(
            text("SELECT COUNT(*) FROM application_groups WHERE application_id = :a"),
            {"a": application_id},
        ).scalar()
        pending_count = conn.execute(
            text("SELECT COUNT(*) FROM group_invitations WHERE application_id = :a AND status = 'pending'"),
            {"a": application_id},
        ).scalar()
        request_count = conn.execute(
            text("SELECT COUNT(*) FROM group_join_requests WHERE application_id = :a AND status = 'pending'"),
            {"a": application_id},
        ).scalar()
        if count + pending_count + request_count >= 4:
            raise HTTPException(409, "Group cannot have more than 4 members.")
        pending_request = conn.execute(
            text(
                "SELECT 1 FROM group_join_requests "
                "WHERE application_id = :a AND student_id = :s AND status = 'pending'"
            ),
            {"a": application_id, "s": student["user_id"]},
        ).first()
        if pending_request:
            raise HTTPException(409, "This student already requested to join the group.")
        ensure_no_pending_group_commitment(conn, student["user_id"])
        conn.execute(
            text(
                "INSERT INTO group_invitations (application_id, student_id, invited_by) "
                "VALUES (:a, :s, :u)"
            ),
            {"a": application_id, "s": student["user_id"], "u": user["user_id"]},
        )
        notify(conn, student["user_id"], f"{user['name']} invited you to join a project group advised by {app_row['adviser_name']}.")
        log_audit(conn, user["user_id"], "GROUP_INVITE", "application", application_id,
                  new_values={"invitee_id": student["user_id"]})
    return {"message": "Invitation sent. The student must accept before joining the group."}


@app.get("/api/groups")
def available_groups(q: str = "", user: dict = Depends(student_only)):
    """Search active student group leaders by project title or leader details."""
    if user.get("student_group_role") != "member":
        raise HTTPException(403, "Group leader accounts should use Find Members.")
    require_student_project_title(user)
    query = q.strip()[:200]
    query_terms = {
        word for word in re.findall(r"[a-z0-9]+", query.lower())
        if len(word) > 1 and word not in {"a", "an", "and", "for", "in", "of", "on", "or", "the", "to", "with"}
    }
    if not query_terms:
        return []
    with engine.connect() as conn:
        ensure_unattached_group_member(conn, user["user_id"])
        rows = conn.execute(
            text(
                "SELECT a.application_id, a.status AS application_status, "
                "COALESCE(a.topic_brief, leader.thesis_title) AS topic_brief, "
                "leader.user_id AS leader_id, leader.name AS leader_name, leader.email AS leader_email, "
                "leader.profile_photo AS leader_profile_photo, "
                "adviser.name AS adviser_name, "
                "(1 + (SELECT COUNT(*) FROM application_groups members "
                "  WHERE members.application_id = a.application_id AND members.is_leader = 0) + "
                "(SELECT COUNT(*) FROM student_group_requests accepted "
                "  WHERE accepted.leader_id = leader.user_id AND accepted.status = 'approved' "
                "  AND NOT EXISTS (SELECT 1 FROM application_groups linked "
                "   WHERE linked.application_id = a.application_id AND linked.student_id = accepted.member_id))) AS member_count, "
                "((SELECT COUNT(*) FROM student_group_requests pending "
                "  WHERE pending.leader_id = leader.user_id AND pending.status = 'pending') + "
                "(SELECT COUNT(*) FROM group_invitations legacy_invites "
                "  WHERE legacy_invites.application_id = a.application_id AND legacy_invites.status = 'pending') + "
                "(SELECT COUNT(*) FROM group_join_requests legacy_requests "
                "  WHERE legacy_requests.application_id = a.application_id AND legacy_requests.status = 'pending')) AS reserved_count, "
                "(SELECT r.status FROM student_group_requests r WHERE r.leader_id = leader.user_id "
                " AND r.member_id = :u ORDER BY r.request_id DESC LIMIT 1) AS request_status, "
                "EXISTS(SELECT 1 FROM student_group_requests r WHERE r.leader_id = leader.user_id "
                " AND r.member_id = :u AND r.requested_by = 'leader' AND r.status = 'pending') AS has_pending_invitation, "
                "EXISTS(SELECT 1 FROM student_group_requests r WHERE r.member_id = :u "
                " AND r.requested_by = 'member' AND r.status = 'pending') AS has_pending_request, "
                "EXISTS(SELECT 1 FROM student_group_requests r WHERE r.member_id = :u "
                " AND r.requested_by = 'leader' AND r.status = 'pending') AS has_any_pending_invitation "
                "FROM users leader "
                "LEFT JOIN applications a ON a.student_id = leader.user_id AND a.status = 'approved' "
                "LEFT JOIN users adviser ON adviser.user_id = a.adviser_id "
                "WHERE leader.role = 'student' AND COALESCE(leader.student_group_role, 'leader') = 'leader' "
                "AND leader.account_status = 'active' "
                "AND CHAR_LENGTH(TRIM(COALESCE(leader.thesis_title, ''))) >= 10 "
                "AND leader.user_id != :u "
                "AND NOT EXISTS (SELECT 1 FROM application_groups own "
                " WHERE own.student_id = :u AND own.application_id = a.application_id) "
                "AND NOT EXISTS (SELECT 1 FROM student_group_requests own "
                " WHERE own.leader_id = leader.user_id AND own.member_id = :u AND own.status = 'approved') "
                "AND NOT EXISTS (SELECT 1 FROM student_group_requests own "
                " WHERE own.member_id = :u AND own.status = 'approved') "
                "ORDER BY leader.name"
            ),
            {"u": user["user_id"]},
        ).mappings().all()
    matches = []
    for row in rows:
        match = match_group_search(query, user["thesis_title"], row)
        if match:
            item = clean(row)
            item.update(match)
            matches.append(item)
    return sorted(matches, key=lambda group: (-group["match_score"], group["member_count"] + group["reserved_count"], group["leader_name"].lower()))


def student_group_capacity(conn, leader_id: int, exclude_request_id: int | None = None) -> tuple[int, int, int | None]:
    application_id = conn.execute(
        text("SELECT application_id FROM applications WHERE student_id = :u AND status = 'approved' LIMIT 1"),
        {"u": leader_id},
    ).scalar()
    legacy_members = 0
    legacy_reserved = 0
    if application_id is not None:
        legacy_members = conn.execute(
            text("SELECT COUNT(*) FROM application_groups WHERE application_id = :a AND is_leader = 0"),
            {"a": application_id},
        ).scalar() or 0
        legacy_reserved = conn.execute(
            text(
                "SELECT (SELECT COUNT(*) FROM group_invitations WHERE application_id = :a AND status = 'pending') + "
                "(SELECT COUNT(*) FROM group_join_requests WHERE application_id = :a AND status = 'pending')"
            ),
            {"a": application_id},
        ).scalar() or 0
    standalone_members = conn.execute(
        text(
            "SELECT COUNT(*) FROM student_group_requests r "
            "WHERE r.leader_id = :l AND r.status = 'approved' "
            "AND NOT EXISTS (SELECT 1 FROM application_groups g "
            " WHERE g.application_id = :a AND g.student_id = r.member_id)"
        ),
        {"l": leader_id, "a": application_id or -1},
    ).scalar() or 0
    request_params = {"l": leader_id}
    request_filter = ""
    if exclude_request_id is not None:
        request_filter = " AND request_id != :request_id"
        request_params["request_id"] = exclude_request_id
    standalone_reserved = conn.execute(
        text(
            "SELECT COUNT(*) FROM student_group_requests "
            "WHERE leader_id = :l AND status = 'pending'" + request_filter
        ),
        request_params,
    ).scalar() or 0
    return 1 + legacy_members + standalone_members, legacy_reserved + standalone_reserved, application_id


@app.post("/api/student-group-requests", status_code=201)
def create_student_group_request(body: StudentGroupRequestIn, user: dict = Depends(student_only)):
    """Create a request or invitation between a group leader and a member."""
    role = user.get("student_group_role") or "leader"
    if role not in ("leader", "member"):
        raise HTTPException(403, "Only student group leaders and members can connect.")
    require_student_project_title(user)
    if body.user_id == user["user_id"]:
        raise HTTPException(409, "You cannot send a group request to yourself.")
    leader_id = user["user_id"] if role == "leader" else body.user_id
    member_id = body.user_id if role == "leader" else user["user_id"]
    requested_by = role
    with engine.begin() as conn:
        leader = conn.execute(
            text(
                "SELECT user_id, name, student_group_role, account_status, thesis_title "
                "FROM users WHERE user_id = :u AND role = 'student' FOR UPDATE"
            ),
            {"u": leader_id},
        ).mappings().first()
        member = conn.execute(
            text(
                "SELECT user_id, name, student_group_role, account_status, thesis_title "
                "FROM users WHERE user_id = :u AND role = 'student'"
            ),
            {"u": member_id},
        ).mappings().first()
        if not leader or (leader["student_group_role"] or "leader") != "leader" or leader["account_status"] != "active":
            raise HTTPException(404, "Active group leader not found.")
        if not member or member["student_group_role"] != "member" or member["account_status"] != "active":
            raise HTTPException(404, "Active group member not found.")
        if len((leader.get("thesis_title") or "").strip()) < 10 or len((member.get("thesis_title") or "").strip()) < 10:
            raise HTTPException(409, "Both students must complete their project title in their profile first.")
        ensure_unattached_group_member(conn, member_id)
        ensure_no_pending_group_commitment(conn, member_id)
        if conn.execute(
            text("SELECT 1 FROM student_group_requests WHERE member_id = :m AND status = 'approved' LIMIT 1"),
            {"m": member_id},
        ).first():
            raise HTTPException(409, "This student is already part of a project group.")
        current = conn.execute(
            text(
                "SELECT request_id, status FROM student_group_requests "
                "WHERE leader_id = :l AND member_id = :m FOR UPDATE"
            ),
            {"l": leader_id, "m": member_id},
        ).mappings().first()
        if current and current["status"] in ("pending", "approved"):
            message = "A group request is already pending." if current["status"] == "pending" else "This student is already in the group."
            raise HTTPException(409, message)
        existing_pending = conn.execute(
            text("SELECT 1 FROM student_group_requests WHERE member_id = :m AND status = 'pending' LIMIT 1"),
            {"m": member_id},
        ).first()
        if existing_pending:
            raise HTTPException(409, "This student already has a pending group request or invitation.")
        current_count, reserved_count, _ = student_group_capacity(conn, leader_id)
        if current_count + reserved_count >= 4:
            raise HTTPException(409, "This group has no open member slots.")
        if current:
            conn.execute(
                text(
                    "UPDATE student_group_requests SET requested_by = :by, status = 'pending', "
                    "created_at = CURRENT_TIMESTAMP, responded_at = NULL WHERE request_id = :id"
                ),
                {"by": requested_by, "id": current["request_id"]},
            )
        else:
            conn.execute(
                text(
                    "INSERT INTO student_group_requests (leader_id, member_id, requested_by) "
                    "VALUES (:l, :m, :by)"
                ),
                {"l": leader_id, "m": member_id, "by": requested_by},
            )
        notify(
            conn,
            member_id if requested_by == "leader" else leader_id,
            f"{user['name']} sent you a request to connect as a project group.",
        )
    return {"message": "Group request sent."}


@app.get("/api/student-group-requests")
def my_student_group_requests(user: dict = Depends(student_only)):
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT r.request_id, r.leader_id, r.member_id, r.requested_by, r.status, r.created_at, "
                "leader.name AS leader_name, leader.email AS leader_email, "
                "member.name AS member_name, member.email AS member_email, "
                "CASE WHEN r.leader_id = :u THEN member.name ELSE leader.name END AS other_name, "
                "CASE WHEN r.leader_id = :u THEN member.email ELSE leader.email END AS other_email, "
                "CASE WHEN r.status = 'pending' AND ((r.requested_by = 'member' AND r.leader_id = :u) "
                " OR (r.requested_by = 'leader' AND r.member_id = :u)) THEN 1 ELSE 0 END AS can_decide "
                "FROM student_group_requests r "
                "JOIN users leader ON leader.user_id = r.leader_id "
                "JOIN users member ON member.user_id = r.member_id "
                "WHERE r.status IN ('pending','approved') AND (r.leader_id = :u OR r.member_id = :u) "
                "ORDER BY r.created_at DESC"
            ),
            {"u": user["user_id"]},
        ).mappings().all()
    return [clean(row) for row in rows]


@app.patch("/api/student-group-requests/{request_id}")
def decide_student_group_request(
    request_id: int,
    body: StudentGroupRequestDecisionIn,
    user: dict = Depends(student_only),
):
    with engine.begin() as conn:
        request = conn.execute(
            text("SELECT * FROM student_group_requests WHERE request_id = :id FOR UPDATE"),
            {"id": request_id},
        ).mappings().first()
        if not request or request["status"] != "pending":
            raise HTTPException(404, "Pending group request not found.")
        is_recipient = (
            request["requested_by"] == "member" and request["leader_id"] == user["user_id"]
        ) or (
            request["requested_by"] == "leader" and request["member_id"] == user["user_id"]
        )
        if not is_recipient:
            raise HTTPException(403, "Only the recipient can respond to this group request.")
        if body.status == "approved":
            participants = conn.execute(
                text(
                    "SELECT user_id, student_group_role, account_status, thesis_title "
                    "FROM users WHERE user_id IN (:leader, :member)"
                ),
                {"leader": request["leader_id"], "member": request["member_id"]},
            ).mappings().all()
            participant_by_id = {participant["user_id"]: participant for participant in participants}
            leader = participant_by_id.get(request["leader_id"])
            member = participant_by_id.get(request["member_id"])
            if (
                not leader
                or not member
                or (leader["student_group_role"] or "leader") != "leader"
                or member["student_group_role"] != "member"
                or leader["account_status"] != "active"
                or member["account_status"] != "active"
                or len((leader.get("thesis_title") or "").strip()) < 10
                or len((member.get("thesis_title") or "").strip()) < 10
            ):
                raise HTTPException(409, "Both students must have active accounts and complete project titles.")
            ensure_unattached_group_member(conn, request["member_id"])
            if conn.execute(
                text("SELECT 1 FROM student_group_requests WHERE member_id = :m AND status = 'approved' LIMIT 1"),
                {"m": request["member_id"]},
            ).first():
                raise HTTPException(409, "This student has already joined a project group.")
            member_count, reserved_count, application_id = student_group_capacity(
                conn, request["leader_id"], exclude_request_id=request_id
            )
            if member_count + reserved_count >= 4:
                raise HTTPException(409, "This group has no open member slots.")
            conn.execute(
                text(
                    "UPDATE student_group_requests SET status = 'approved', responded_at = NOW() "
                    "WHERE request_id = :id"
                ),
                {"id": request_id},
            )
            if application_id is not None:
                conn.execute(
                    text(
                        "INSERT IGNORE INTO application_groups (application_id, student_id, is_leader) "
                        "VALUES (:a, :m, 0)"
                    ),
                    {"a": application_id, "m": request["member_id"]},
                )
            notify(
                conn,
                request["member_id"] if user["user_id"] == request["leader_id"] else request["leader_id"],
                f"{user['name']} accepted your project group request.",
            )
        else:
            conn.execute(
                text(
                    "UPDATE student_group_requests SET status = 'declined', responded_at = NOW() "
                    "WHERE request_id = :id"
                ),
                {"id": request_id},
            )
            notify(
                conn,
                request["member_id"] if user["user_id"] == request["leader_id"] else request["leader_id"],
                f"{user['name']} declined your project group request.",
            )
    return {"message": f"Group request {body.status}."}


def ensure_unattached_group_member(conn, student_id: int) -> None:
    has_adviser_application = conn.execute(
        text(
            "SELECT 1 FROM applications WHERE student_id = :u "
            "AND status IN ('pending','approved') LIMIT 1"
        ),
        {"u": student_id},
    ).first()
    if has_adviser_application:
        raise HTTPException(409, "You already have a pending or approved adviser application.")
    has_group = conn.execute(
        text("SELECT 1 FROM application_groups WHERE student_id = :u LIMIT 1"),
        {"u": student_id},
    ).first()
    if has_group:
        raise HTTPException(409, "You are already part of a project group.")
    has_standalone_group = conn.execute(
        text("SELECT 1 FROM student_group_requests WHERE member_id = :u AND status = 'approved' LIMIT 1"),
        {"u": student_id},
    ).first()
    if has_standalone_group:
        raise HTTPException(409, "You are already part of a project group.")


def ensure_no_pending_group_commitment(
    conn,
    student_id: int,
    invitation_id: int | None = None,
    student_group_request_id: int | None = None,
) -> None:
    has_pending_request = conn.execute(
        text(
            "SELECT 1 FROM group_join_requests WHERE student_id = :u "
            "AND status = 'pending' LIMIT 1"
        ),
        {"u": student_id},
    ).first()
    if has_pending_request:
        raise HTTPException(409, "You already have a pending request to join a project group.")
    invitation_query = (
        "SELECT 1 FROM group_invitations WHERE student_id = :u "
        "AND status = 'pending'"
    )
    params = {"u": student_id}
    if invitation_id is not None:
        invitation_query += " AND invitation_id != :i"
        params["i"] = invitation_id
    has_other_invitation = conn.execute(text(invitation_query + " LIMIT 1"), params).first()
    if has_other_invitation:
        raise HTTPException(409, "You already have a pending group invitation.")
    standalone_query = (
        "SELECT 1 FROM student_group_requests WHERE member_id = :u AND status = 'pending'"
    )
    standalone_params = {"u": student_id}
    if student_group_request_id is not None:
        standalone_query += " AND request_id != :r"
        standalone_params["r"] = student_group_request_id
    has_standalone_request = conn.execute(
        text(standalone_query + " LIMIT 1"), standalone_params
    ).first()
    if has_standalone_request:
        raise HTTPException(409, "You already have a pending group request or invitation.")


@app.post("/api/applications/{application_id}/group-join-requests", status_code=201)
def request_group_membership(application_id: int, user: dict = Depends(student_only)):
    """Request to join an approved student project group."""
    if user.get("student_group_role") != "member":
        raise HTTPException(403, "Only group member accounts can request to join a project group.")
    require_student_project_title(user)
    with engine.begin() as conn:
        ensure_unattached_group_member(conn, user["user_id"])
        ensure_no_pending_group_commitment(conn, user["user_id"])
        conn.execute(
            text("SELECT application_id FROM applications WHERE application_id = :a FOR UPDATE"),
            {"a": application_id},
        ).first()
        app_row = conn.execute(
            text(
                "SELECT student_id, adviser_id FROM applications "
                "WHERE application_id = :a AND status = 'approved'"
            ),
            {"a": application_id},
        ).mappings().first()
        if app_row is None:
            raise HTTPException(404, "Approved project group not found.")
        leader = conn.execute(
            text(
                "SELECT student_id FROM application_groups "
                "WHERE application_id = :a AND is_leader = 1"
            ),
            {"a": application_id},
        ).first()
        if leader is None:
            raise HTTPException(409, "This project does not have a group leader yet.")
        if user["user_id"] == leader[0] or conn.execute(
            text("SELECT 1 FROM application_groups WHERE application_id = :a AND student_id = :u"),
            {"a": application_id, "u": user["user_id"]},
        ).first():
            raise HTTPException(409, "You are already a member of this group.")
        if conn.execute(
            text(
                "SELECT 1 FROM group_invitations WHERE application_id = :a "
                "AND student_id = :u AND status = 'pending'"
            ),
            {"a": application_id, "u": user["user_id"]},
        ).first():
            raise HTTPException(409, "You already have an invitation to this group. Respond to it in Requests.")
        if conn.execute(
            text(
                "SELECT 1 FROM group_join_requests WHERE application_id = :a "
                "AND student_id = :u AND status = 'pending'"
            ),
            {"a": application_id, "u": user["user_id"]},
        ).first():
            raise HTTPException(409, "Your request to join this group is already pending.")
        member_count = conn.execute(
            text("SELECT COUNT(*) FROM application_groups WHERE application_id = :a"),
            {"a": application_id},
        ).scalar()
        pending_invitations = conn.execute(
            text("SELECT COUNT(*) FROM group_invitations WHERE application_id = :a AND status = 'pending'"),
            {"a": application_id},
        ).scalar()
        pending_requests = conn.execute(
            text("SELECT COUNT(*) FROM group_join_requests WHERE application_id = :a AND status = 'pending'"),
            {"a": application_id},
        ).scalar()
        if member_count + pending_invitations + pending_requests >= 4:
            raise HTTPException(409, "This group has no open member slots.")
        result = conn.execute(
            text(
                "INSERT INTO group_join_requests (application_id, student_id) "
                "VALUES (:a, :u)"
            ),
            {"a": application_id, "u": user["user_id"]},
        )
        notify(conn, leader[0], f"{user['name']} requested to join your project group.")
        log_audit(
            conn,
            user["user_id"],
            "GROUP_JOIN_REQUEST",
            "application",
            application_id,
            new_values={"request_id": result.lastrowid},
        )
    return {"message": "Join request sent to the group leader."}


@app.get("/api/applications/{application_id}/group-join-requests")
def group_join_requests(application_id: int, user: dict = Depends(current_user)):
    """List pending member requests for a student group leader."""
    with engine.connect() as conn:
        get_approved_application(conn, application_id, user)
        is_leader = conn.execute(
            text(
                "SELECT 1 FROM application_groups "
                "WHERE application_id = :a AND student_id = :u AND is_leader = 1"
            ),
            {"a": application_id, "u": user["user_id"]},
        ).first()
        if not can_manage_group_members(user, bool(is_leader)):
            raise HTTPException(403, "Only the student group leader can view join requests.")
        rows = conn.execute(
            text(
                "SELECT r.request_id, r.student_id, u.name AS student_name, "
                "u.email AS student_email, u.profile_photo AS student_profile_photo, r.created_at "
                "FROM group_join_requests r JOIN users u ON u.user_id = r.student_id "
                "WHERE r.application_id = :a AND r.status = 'pending' ORDER BY r.created_at"
            ),
            {"a": application_id},
        ).mappings().all()
    return [clean(row) for row in rows]


@app.patch("/api/group-join-requests/{request_id}")
def decide_group_join_request(
    request_id: int,
    body: GroupJoinDecisionIn,
    user: dict = Depends(student_only),
):
    with engine.begin() as conn:
        request = conn.execute(
            text(
                "SELECT r.application_id, r.student_id, r.status, a.adviser_id "
                "FROM group_join_requests r JOIN applications a ON a.application_id = r.application_id "
                "WHERE r.request_id = :id AND a.status = 'approved' FOR UPDATE"
            ),
            {"id": request_id},
        ).mappings().first()
        if request is None:
            raise HTTPException(404, "Pending group join request not found.")
        if request["status"] != "pending":
            raise HTTPException(409, f"This join request is already {request['status']}.")
        leader = conn.execute(
            text(
                "SELECT 1 FROM application_groups WHERE application_id = :a "
                "AND student_id = :u AND is_leader = 1"
            ),
            {"a": request["application_id"], "u": user["user_id"]},
        ).first()
        if not can_manage_group_members(user, bool(leader)):
            raise HTTPException(403, "Only the student group leader can decide join requests.")
        if body.status == "approved":
            ensure_no_pending_group_commitment(
                conn,
                request["member_id"],
                student_group_request_id=request_id,
            )
            member_count = conn.execute(
                text("SELECT COUNT(*) FROM application_groups WHERE application_id = :a"),
                {"a": request["application_id"]},
            ).scalar()
            pending_invitations = conn.execute(
                text(
                    "SELECT COUNT(*) FROM group_invitations "
                    "WHERE application_id = :a AND status = 'pending'"
                ),
                {"a": request["application_id"]},
            ).scalar()
            other_requests = conn.execute(
                text(
                    "SELECT COUNT(*) FROM group_join_requests "
                    "WHERE application_id = :a AND status = 'pending' AND request_id != :r"
                ),
                {"a": request["application_id"], "r": request_id},
            ).scalar()
            if member_count + pending_invitations + other_requests >= 4:
                raise HTTPException(409, "The group has no open member slots.")
            conn.execute(
                text(
                    "INSERT INTO application_groups (application_id, student_id, is_leader) "
                    "VALUES (:a, :s, 0)"
                ),
                {"a": request["application_id"], "s": request["student_id"]},
            )
        conn.execute(
            text(
                "UPDATE group_join_requests SET status = :s, responded_at = NOW() "
                "WHERE request_id = :r"
            ),
            {"s": body.status, "r": request_id},
        )
        message = (
            "Your request to join the project group was approved."
            if body.status == "approved"
            else "Your request to join the project group was declined."
        )
        notify(conn, request["student_id"], message)
        log_audit(
            conn,
            user["user_id"],
            f"GROUP_JOIN_REQUEST_{body.status.upper()}",
            "application",
            request["application_id"],
            new_values={"request_id": request_id, "student_id": request["student_id"]},
        )
    return {"message": f"Join request {body.status}."}


@app.get("/api/group-invitations")
def my_group_invitations(user: dict = Depends(student_only)):
    """List pending invitations sent to the current student."""
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT i.invitation_id, i.application_id, i.created_at, "
                "s.name AS invited_by_name, a.topic_brief, v.name AS adviser_name "
                "FROM group_invitations i "
                "JOIN users s ON s.user_id = i.invited_by "
                "JOIN applications a ON a.application_id = i.application_id "
                "JOIN users v ON v.user_id = a.adviser_id "
                "WHERE i.student_id = :u AND i.status = 'pending' AND a.status = 'approved' "
                "ORDER BY i.created_at DESC"
            ),
            {"u": user["user_id"]},
        ).mappings().all()
    return [clean(row) for row in rows]


@app.get("/api/applications/{application_id}/group-invitations")
def group_invitations(application_id: int, user: dict = Depends(current_user)):
    """List pending invitations for a group leader."""
    with engine.connect() as conn:
        get_approved_application(conn, application_id, user)
        is_leader = conn.execute(
            text("SELECT 1 FROM application_groups WHERE application_id = :a AND student_id = :u AND is_leader = 1"),
            {"a": application_id, "u": user["user_id"]},
        ).first()
        if not can_manage_group_members(user, bool(is_leader)):
            raise HTTPException(403, "Only a student group leader can view group invitations.")
        rows = conn.execute(
            text(
                "SELECT i.invitation_id, i.student_id, u.name AS student_name, u.email, i.created_at "
                "FROM group_invitations i JOIN users u ON u.user_id = i.student_id "
                "WHERE i.application_id = :a AND i.status = 'pending' ORDER BY i.created_at"
            ),
            {"a": application_id},
        ).mappings().all()
    return [clean(row) for row in rows]


@app.post("/api/group-invitations/{invitation_id}/accept")
def accept_group_invitation(invitation_id: int, user: dict = Depends(student_only)):
    require_student_project_title(user)
    with engine.begin() as conn:
        ensure_unattached_group_member(conn, user["user_id"])
        ensure_no_pending_group_commitment(conn, user["user_id"], invitation_id)
        invite = conn.execute(
            text(
                "SELECT i.application_id, i.invited_by, a.adviser_id, a.status, v.name AS adviser_name "
                "FROM group_invitations i "
                "JOIN applications a ON a.application_id = i.application_id "
                "JOIN users v ON v.user_id = a.adviser_id "
                "WHERE i.invitation_id = :id AND i.student_id = :u AND i.status = 'pending' FOR UPDATE"
            ),
            {"id": invitation_id, "u": user["user_id"]},
        ).mappings().first()
        if not invite:
            raise HTTPException(404, "Pending group invitation not found.")
        if invite["status"] != "approved":
            raise HTTPException(409, "This application is no longer approved.")
        leader = conn.execute(
            text(
                "SELECT 1 FROM application_groups "
                "WHERE application_id = :a AND student_id = :u AND is_leader = 1"
            ),
            {"a": invite["application_id"], "u": invite["invited_by"]},
        ).first()
        if not leader:
            raise HTTPException(409, "The group leader is no longer able to invite members.")
        is_already_member = conn.execute(
            text("SELECT 1 FROM application_groups WHERE application_id = :a AND student_id = :u"),
            {"a": invite["application_id"], "u": user["user_id"]},
        ).first()
        if is_already_member:
            raise HTTPException(409, "You are already a member of this group.")
        count = conn.execute(
            text("SELECT COUNT(*) FROM application_groups WHERE application_id = :a"),
            {"a": invite["application_id"]},
        ).scalar()
        pending_invitations = conn.execute(
            text(
                "SELECT COUNT(*) FROM group_invitations WHERE application_id = :a "
                "AND status = 'pending' AND invitation_id != :i"
            ),
            {"a": invite["application_id"], "i": invitation_id},
        ).scalar()
        pending_requests = conn.execute(
            text("SELECT COUNT(*) FROM group_join_requests WHERE application_id = :a AND status = 'pending'"),
            {"a": invite["application_id"]},
        ).scalar()
        if count + pending_invitations + pending_requests >= 4:
            raise HTTPException(409, "The group is already at its 4-member limit.")
        conn.execute(
            text(
                "INSERT INTO application_groups (application_id, student_id, is_leader) "
                "VALUES (:a, :s, 0)"
            ),
            {"a": invite["application_id"], "s": user["user_id"]},
        )
        conn.execute(
            text("UPDATE group_invitations SET status = 'accepted', responded_at = NOW() WHERE invitation_id = :id"),
            {"id": invitation_id},
        )
        notify(conn, invite["invited_by"], f"{user['name']} accepted your project group invitation.")
        notify(conn, invite["adviser_id"], f"{user['name']} joined an advisee project group.")
        log_audit(conn, user["user_id"], "GROUP_INVITE_ACCEPT", "application", invite["application_id"],
                  new_values={"group_member_id": user["user_id"]})
    return {"message": "You joined the project group."}


@app.post("/api/group-invitations/{invitation_id}/decline")
def decline_group_invitation(invitation_id: int, user: dict = Depends(student_only)):
    with engine.begin() as conn:
        invite = conn.execute(
            text(
                "SELECT i.application_id, i.invited_by FROM group_invitations i "
                "WHERE i.invitation_id = :id AND i.student_id = :u AND i.status = 'pending' FOR UPDATE"
            ),
            {"id": invitation_id, "u": user["user_id"]},
        ).mappings().first()
        if not invite:
            raise HTTPException(404, "Pending group invitation not found.")
        conn.execute(
            text("UPDATE group_invitations SET status = 'declined', responded_at = NOW() WHERE invitation_id = :id"),
            {"id": invitation_id},
        )
        notify(conn, invite["invited_by"], f"{user['name']} declined your project group invitation.")
        log_audit(conn, user["user_id"], "GROUP_INVITE_DECLINE", "application", invite["application_id"],
                  new_values={"invitee_id": user["user_id"]})
    return {"message": "Invitation declined."}


@app.delete("/api/group-invitations/{invitation_id}")
def cancel_group_invitation(invitation_id: int, user: dict = Depends(current_user)):
    with engine.begin() as conn:
        invite = conn.execute(
            text(
                "SELECT i.application_id, i.student_id FROM group_invitations i "
                "WHERE i.invitation_id = :id AND i.status = 'pending'"
            ),
            {"id": invitation_id},
        ).mappings().first()
        if not invite:
            raise HTTPException(404, "Pending group invitation not found.")
        leader = conn.execute(
            text(
                "SELECT 1 FROM application_groups "
                "WHERE application_id = :a AND student_id = :u AND is_leader = 1"
            ),
            {"a": invite["application_id"], "u": user["user_id"]},
        ).first()
        if not can_manage_group_members(user, bool(leader)):
            raise HTTPException(403, "Only the student group leader can cancel an invitation.")
        conn.execute(
            text("UPDATE group_invitations SET status = 'cancelled', responded_at = NOW() WHERE invitation_id = :id"),
            {"id": invitation_id},
        )
        notify(conn, invite["student_id"], "A project group invitation was cancelled by the group leader.")
        log_audit(conn, user["user_id"], "GROUP_INVITE_CANCEL", "application", invite["application_id"],
                  new_values={"invitee_id": invite["student_id"]})
    return {"message": "Invitation cancelled."}


@app.get("/api/applications/{application_id}/group")
def get_group_members(application_id: int, user: dict = Depends(current_user)):
    """Get group members for an application."""
    with engine.connect() as conn:
        app_row = conn.execute(
            text("SELECT adviser_id, status FROM applications WHERE application_id = :id"),
            {"id": application_id},
        ).mappings().first()
        if app_row is None:
            raise HTTPException(404, "Application not found.")
        if app_row["status"] != "approved":
            raise HTTPException(409, "This is available once the adviser approves the application.")
        is_group_member = conn.execute(
            text("SELECT 1 FROM application_groups WHERE application_id = :a AND student_id = :u"),
            {"a": application_id, "u": user["user_id"]},
        ).first()
        if user["user_id"] != app_row["adviser_id"] and not is_group_member:
            raise HTTPException(403, "This is not your advisee group.")
        rows = conn.execute(
            text(
                "SELECT g.group_id, g.student_id, g.is_leader, g.joined_at, u.name, u.email, u.profile_photo "
                "FROM application_groups g JOIN users u ON u.user_id = g.student_id WHERE g.application_id = :a"
            ),
            {"a": application_id},
        ).mappings().all()
    return [clean(r) for r in rows]


@app.delete("/api/group/{group_id}")
def remove_group_member(group_id: int, user: dict = Depends(current_user)):
    """Remove a group member from an approved application (group leader only)."""
    with engine.begin() as conn:
        g = conn.execute(
            text(
                "SELECT g.student_id, g.application_id, a.adviser_id, a.status "
                "FROM application_groups g JOIN applications a ON a.application_id = g.application_id "
                "WHERE g.group_id = :id"
            ),
            {"id": group_id},
        ).mappings().first()
        if not g:
            raise HTTPException(404, "Group member not found.")
        if g["status"] != "approved":
            raise HTTPException(409, "This is available once the adviser approves the application.")
        is_leader = conn.execute(
            text("SELECT 1 FROM application_groups WHERE application_id = :a AND student_id = :u AND is_leader = 1"),
            {"a": g["application_id"], "u": user["user_id"]},
        ).first()
        if not can_manage_group_members(user, bool(is_leader)):
            raise HTTPException(403, "Only a student group leader can remove members.")
        if g["student_id"] == user["user_id"]:
            other_leader = conn.execute(
                text("SELECT 1 FROM application_groups WHERE application_id = :a AND student_id != :u AND is_leader = 1"),
                {"a": g["application_id"], "u": user["user_id"]},
            ).first()
            if not other_leader:
                raise HTTPException(409, "Assign another group leader before removing yourself.")
        notify(conn, g["student_id"], "You were removed from a project group by its student group leader.")
        log_audit(conn, user["user_id"], "GROUP_MEMBER_REMOVE", "application", g["application_id"],
                  new_values={"removed_student_id": g["student_id"]})
        conn.execute(text("DELETE FROM application_groups WHERE group_id = :id"), {"id": group_id})
    return {"message": "Group member removed."}


# ---- Admin Audit Log ----
def log_admin_action(conn, admin_id: int, action: str, target_type: str, target_id: int, details: Optional[str] = None):
    conn.execute(
        text("INSERT INTO admin_audit_log (admin_id, action, target_type, target_id, details) VALUES (:a, :ac, :tt, :ti, :d)"),
        {"a": admin_id, "ac": action, "tt": target_type, "ti": target_id, "d": details},
    )


@app.get("/api/admin/audit-log")
def admin_audit_log(limit: int = 100, user: dict = Depends(admin_only)):
    """Get the admin audit trail, including security and export actions."""
    limit = max(1, min(limit, 500))
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT * FROM ("
                "SELECT a.audit_id AS log_id, a.action, a.target_type, a.target_id, "
                "CONCAT_WS(' | ', "
                "IF(a.old_values IS NULL, NULL, CONCAT('Before: ', CAST(a.old_values AS CHAR))), "
                "IF(a.new_values IS NULL, NULL, CONCAT('After: ', CAST(a.new_values AS CHAR)))) AS details, "
                "a.created_at, COALESCE(u.name, 'Deleted account') AS admin_name "
                "FROM audit_logs a LEFT JOIN users u ON u.user_id = a.user_id "
                "UNION ALL "
                "SELECT l.log_id, l.action, l.target_type, l.target_id, l.details, "
                "l.created_at, u.name AS admin_name "
                "FROM admin_audit_log l JOIN users u ON u.user_id = l.admin_id"
                ") AS audit_entries ORDER BY created_at DESC, log_id DESC LIMIT :lim"
            ),
            {"lim": limit},
        ).mappings().all()
    return [clean(r) for r in rows]


# Update admin_set_status to log action
# (Already handled in the existing endpoint, but we add logging)


# =====================================================================
# Phase B: Admin Export Endpoints
# =====================================================================
import csv
from io import StringIO
from fastapi.responses import StreamingResponse


@app.get("/api/admin/export/users")
def export_users_csv(user: dict = Depends(admin_only)):
    """Export all users as CSV."""
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT u.user_id, u.name, u.email, u.role, u.contact_number, u.account_status, u.email_verified, "
                "u.created_at, ap.specialization_tags, ap.certifications, ap.max_capacity, ap.current_advisee_count, "
                "ap.is_available, ap.auto_approve "
                "FROM users u LEFT JOIN adviser_profiles ap ON ap.adviser_id = u.user_id ORDER BY u.user_id"
            )
        ).mappings().all()
        output = StringIO()
        writer = csv.writer(output)
        writer.writerow([
            "User ID", "Name", "Email", "Role", "Contact Number", "Account Status", "Email Verified",
            "Created At", "Specializations", "Certifications", "Max Capacity", "Current Advisees",
            "Is Available", "Auto Approve"
        ])
        for r in rows:
            writer.writerow([
                r["user_id"], r["name"], r["email"], r["role"], r["contact_number"] or "",
                r["account_status"], "Yes" if r["email_verified"] else "No",
                r["created_at"], r["specialization_tags"] or "", r["certifications"] or "",
                r["max_capacity"] or "", r["current_advisee_count"] or "",
                "Yes" if r["is_available"] else "No", "Yes" if r["auto_approve"] else "No"
            ])
        log_admin_action(conn, user["user_id"], "export", "users", 0, "Exported all users to CSV")
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=users.csv"}
    )


@app.get("/api/admin/export/applications")
def export_applications_csv(user: dict = Depends(admin_only)):
    """Export all applications as CSV."""
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT a.application_id, a.student_id, a.adviser_id, a.topic_brief, a.status, a.created_at, "
                "u1.name AS student_name, u1.email AS student_email, u2.name AS adviser_name, u2.email AS adviser_email "
                "FROM applications a "
                "JOIN users u1 ON u1.user_id = a.student_id "
                "JOIN users u2 ON u2.user_id = a.adviser_id "
                "ORDER BY a.application_id"
            )
        ).mappings().all()
        output = StringIO()
        writer = csv.writer(output)
        writer.writerow([
            "Application ID", "Student ID", "Adviser ID", "Topic Brief", "Status", "Created At",
            "Student Name", "Student Email", "Adviser Name", "Adviser Email"
        ])
        for r in rows:
            writer.writerow([
                r["application_id"], r["student_id"], r["adviser_id"], r["topic_brief"],
                r["status"], r["created_at"], r["student_name"], r["student_email"],
                r["adviser_name"], r["adviser_email"]
            ])
        log_admin_action(conn, user["user_id"], "export", "applications", 0, "Exported all applications to CSV")
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=applications.csv"}
    )


@app.get("/api/admin/export/bookings")
def export_bookings_csv(user: dict = Depends(admin_only)):
    """Export all bookings as CSV."""
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                "SELECT b.booking_id, b.student_id, b.adviser_id, b.slot_date, b.start_time, b.end_time, "
                "b.meeting_type, b.location, b.status, b.topic_brief, b.created_at, b.completed_at, "
                "u1.name AS student_name, u2.name AS adviser_name "
                "FROM bookings b "
                "JOIN users u1 ON u1.user_id = b.student_id "
                "JOIN users u2 ON u2.user_id = b.adviser_id "
                "ORDER BY b.booking_id"
            )
        ).mappings().all()
        output = StringIO()
        writer = csv.writer(output)
        writer.writerow([
            "Booking ID", "Student ID", "Adviser ID", "Date", "Start Time", "End Time",
            "Meeting Type", "Location", "Status", "Topic", "Created At", "Completed At",
            "Student Name", "Adviser Name"
        ])
        for r in rows:
            writer.writerow([
                r["booking_id"], r["student_id"], r["adviser_id"], r["slot_date"],
                r["start_time"], r["end_time"], r["meeting_type"] or "", r["location"] or "",
                r["status"], r["topic_brief"], r["created_at"], r["completed_at"] or "",
                r["student_name"], r["adviser_name"]
            ])
        log_admin_action(conn, user["user_id"], "export", "bookings", 0, "Exported all bookings to CSV")
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=bookings.csv"}
    )


@app.get("/api/admin/export/analytics")
def export_analytics_report(user: dict = Depends(admin_only)):
    """Export the current analytics summary as a text report."""
    with engine.connect() as conn:
        report = build_report(conn)
        descriptive = report["descriptive"]
        totals = descriptive["totals"]
        diagnostic = report["diagnostic"]
        predictive = report["predictive"]
        demand = predictive["demand"]
        lines = [
            "ADVISERLINK ANALYTICS REPORT",
            f"Generated: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "",
            "=== TOTALS ===",
            f"Students: {totals['students']}",
            f"Advisers: {totals['advisers']}",
            f"Applications: {totals['applications']}",
            f"Pending Applications: {totals['pending']}",
            f"Consultations: {totals['consultations']}",
            f"Completed Consultations: {totals['completed']}",
            f"Tasks: {totals['tasks']}",
            f"Completed Tasks: {totals['tasks_done']}",
            "",
            "=== APPLICATION STATUS ===",
            *[f"{row['name']}: {row['value']}" for row in descriptive["application_status"]],
            "",
            "=== BOOKING STATUS ===",
            *[f"{row['name']}: {row['value']}" for row in descriptive["booking_status"]],
            "",
            "=== RATINGS ===",
            f"Total Ratings: {descriptive['rating_count']}",
            f"Average Rating: {descriptive['avg_rating'] if descriptive['avg_rating'] is not None else 'No ratings'}",
            *[f"{row['name']}: {row['value']}" for row in descriptive["rating_distribution"]],
            "",
            "=== ADVISER WORKLOAD ===",
        ]
        for adviser in descriptive["advisers"]:
            lines.append(
                f"{adviser['name']}: {adviser['advisees']}/{adviser['capacity']} advisees, "
                f"{adviser['utilization']}% utilization, {adviser['consultations']} consultations, "
                f"{adviser['completed']} completed, {adviser['cancelled']} cancelled"
            )
        lines.append("")
        lines.append("=== CANCELLATIONS ===")
        lines.extend(diagnostic["notes"] or ["No notable cancellation patterns."])
        lines.append(f"Past consultations not marked completed: {diagnostic['unmarked_past']}")
        lines.append("")
        lines.append("=== DEMAND FORECAST ===")
        lines.append(f"Expected consultations next week: {demand['next_week']}")
        lines.append(f"Trend: {demand['trend']} ({demand['slope']} per week)")
        lines.append(f"Model fit (R²): {demand['r2']}")
        lines.append(
            "Model accuracy: "
            + (f"off by about {demand['mae']} per week" if demand["mae"] is not None else "not enough weeks yet")
        )
        lines.append("")
        lines.append("=== ADVISEE PROGRESS AND RISK ===")
        if predictive["advisees"]:
            for advisee in predictive["advisees"]:
                lines.append(
                    f"{advisee['student']} ({advisee['adviser']}): {advisee['done']}/{advisee['total']} tasks, "
                    f"{advisee['progress']}% progress, {advisee['risk']}"
                )
        else:
            lines.append("No approved advisees.")
        lines.append("")
        lines.append("=== PRESCRIPTIVE ===")
        for rec in report["prescriptive"]:
            lines.append(f"  - {rec['text']}")
        content = "\n".join(lines)
        log_admin_action(conn, user["user_id"], "export", "analytics", 0, "Exported analytics report")
    return StreamingResponse(
        iter([content]),
        media_type="text/plain",
        headers={"Content-Disposition": "attachment; filename=analytics_report.txt"}
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8001, reload=True)
