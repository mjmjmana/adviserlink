"""Create a complete, repeatable AdviserLink demo scenario.

Run from backend with:
    python seed_demo_scenario.py --reset
Add --dry-run to roll back the generated rows after validation.
"""
import argparse
import datetime as dt
import os
import shutil
import subprocess
from pathlib import Path

from sqlalchemy import bindparam, text

from db_setup import ensure_schema
from main import engine, hash_password

DEMO_PASSWORD = "AdviserLink2026!"
DEFAULT_BACKUP_DIR = Path.home() / "AdviserLinkBackups"
FIRST_NAMES = [
    "Adrian", "Althea", "Andrea", "Angelica", "Angelo", "Ariana", "Beatrice", "Bianca",
    "Carlo", "Clarisse", "Daniel", "Daniela", "Elise", "Emmanuel", "Farah", "Gabriel",
    "Hazel", "Ian", "Isabella", "Janelle", "Joshua", "Katrina", "Lorenzo", "Mara",
    "Miguel", "Nathan", "Patricia", "Rafael", "Sofia", "Theodore",
]
LAST_NAMES = [
    "Aguilar", "Alonzo", "Bautista", "Cabrera", "Castillo", "Cruz", "DelaCruz", "Domingo",
    "Enriquez", "Fernandez", "Garcia", "Gonzales", "Hernandez", "Jimenez", "Lim", "Mendoza",
    "Mercado", "Navarro", "Ocampo", "Perez", "Ramos", "Reyes", "Rivera", "Santos", "Soriano",
    "Tan", "Torres", "Valdez", "Villanueva", "Yambao",
]
DEPARTMENTS = [
    {
        "code": "it",
        "name": "Information Technology",
        "specialties": "web systems, network administration, cloud computing",
        "certification": "MS in Information Technology",
        "topics": [
            "Campus equipment service and preventive maintenance portal",
            "Secure student services platform with role-based access",
            "Cloud-based laboratory reservation and asset tracking system",
            "Accessible campus navigation and facilities web application",
        ],
    },
    {
        "code": "cs",
        "name": "Computer Science",
        "specialties": "software engineering, algorithms, artificial intelligence",
        "certification": "MS in Computer Science",
        "topics": [
            "Explainable machine learning model for academic support referrals",
            "Graph-based analysis of collaboration in student project teams",
            "Automated test generation for university service applications",
            "Natural language search for institutional research materials",
        ],
    },
    {
        "code": "is",
        "name": "Information Systems",
        "specialties": "systems analysis, database design, business process management",
        "certification": "MS in Information Systems",
        "topics": [
            "Student records workflow and document tracking information system",
            "Process improvement dashboard for academic advising services",
            "Inventory and procurement management system for campus offices",
            "Service quality reporting platform for university stakeholders",
        ],
    },
    {
        "code": "dsa",
        "name": "Data Science and Analytics",
        "specialties": "statistical modeling, data visualization, predictive analytics",
        "certification": "MS in Data Science",
        "topics": [
            "Enrollment demand forecast using anonymized institutional data",
            "Learning resource usage dashboard with privacy-preserving analytics",
            "Campus energy consumption analysis and demand forecasting model",
            "Student consultation trends and service capacity analysis dashboard",
        ],
    },
    {
        "code": "lis",
        "name": "Library and Information Science",
        "specialties": "digital repositories, information literacy, library services",
        "certification": "MS in Library and Information Science",
        "topics": [
            "Digital repository with metadata review and preservation workflows",
            "Library discovery portal for locally produced research materials",
            "Information literacy assessment and learning resource platform",
            "Circulation and collection insights dashboard for library services",
        ],
    },
]
WEEKDAYS = [("Mon", 0), ("Tue", 1), ("Wed", 2), ("Thu", 3), ("Fri", 4)]
APPLICATION_STATUSES = ("approved", "approved", "pending", "declined")
TASKS = [
    ("Confirm research objectives", "Align the objectives with the approved project scope."),
    ("Complete literature review matrix", "Record sources, methods, and findings for review."),
    ("Draft system requirements", "Document functional and non-functional requirements."),
    ("Prepare methodology chapter", "Describe participants, instruments, and analysis methods."),
    ("Review prototype and test plan", "Prepare a reproducible test plan for the next consultation."),
]


def person_name(index):
    given = FIRST_NAMES[index % len(FIRST_NAMES)]
    family = LAST_NAMES[(index // len(FIRST_NAMES)) % len(LAST_NAMES)]
    return f"{given} {family}"


def make_backup(backup_dir):
    url = engine.url
    if url.drivername != "mysql+pymysql" or not url.database:
        raise RuntimeError("The demo reset requires a MySQL DATABASE_URL with a database name.")

    configured_dump = os.getenv("MYSQLDUMP_PATH")
    dump_executable = configured_dump or shutil.which("mysqldump")
    if not dump_executable:
        xampp_dump = Path(r"C:\xampp\mysql\bin\mysqldump.exe")
        if xampp_dump.exists():
            dump_executable = str(xampp_dump)
    if not dump_executable:
        raise RuntimeError("mysqldump was not found. Set MYSQLDUMP_PATH before resetting the database.")

    backup_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = backup_dir / f"adviserlink_before_demo_reset_{stamp}.sql"
    command = [
        dump_executable,
        "--single-transaction",
        "--routines",
        "--triggers",
        "--events",
        "--databases",
        url.database,
        f"--host={url.host or 'localhost'}",
        f"--port={url.port or 3306}",
        f"--user={url.username or 'root'}",
        f"--result-file={backup_path}",
    ]
    environment = os.environ.copy()
    if url.password is not None:
        environment["MYSQL_PWD"] = url.password

    result = subprocess.run(command, capture_output=True, text=True, env=environment, check=False)
    if result.returncode != 0:
        backup_path.unlink(missing_ok=True)
        raise RuntimeError(f"Database backup failed: {result.stderr.strip() or result.returncode}")
    if not backup_path.exists() or backup_path.stat().st_size == 0:
        raise RuntimeError("mysqldump completed without producing a non-empty backup file.")
    return backup_path


def reset_accounts(conn):
    conn.execute(text("DELETE FROM users"))
    conn.execute(text("DELETE FROM login_history"))
    conn.execute(text("DELETE FROM audit_logs"))


def user_rows(now, password_hash):
    rows = []
    admin_email = "admin.demo@example.com"
    rows.append({
        "name": "AdviserLink Demo Administrator",
        "email": admin_email,
        "password": password_hash,
        "role": "admin",
        "contact_number": None,
        "account_status": "active",
        "email_verified": 1,
        "created_at": now - dt.timedelta(days=90),
    })

    adviser_rows = []
    student_rows = []
    for department_index, department in enumerate(DEPARTMENTS):
        for adviser_number in range(1, 11):
            name_index = 600 + department_index * 10 + adviser_number - 1
            email = f"adviser.{department['code']}.{adviser_number:02d}@example.com"
            adviser_rows.append({
                "name": person_name(name_index),
                "email": email,
                "password": password_hash,
                "role": "adviser",
                "contact_number": None,
                "account_status": "active",
                "email_verified": 1,
                "created_at": now - dt.timedelta(days=75 - adviser_number),
                "department": department,
                "adviser_number": adviser_number,
            })
        for student_number in range(1, 121):
            name_index = department_index * 120 + student_number - 1
            student_rows.append({
                "name": person_name(name_index),
                "email": f"student.{department['code']}.{student_number:03d}@example.com",
                "password": password_hash,
                "role": "student",
                "contact_number": None,
                "account_status": "active",
                "email_verified": 1,
                "created_at": now - dt.timedelta(days=60 - student_number % 30),
                "department": department,
                "student_number": student_number,
            })
    rows.extend(adviser_rows)
    rows.extend(student_rows)
    return rows, adviser_rows, student_rows, admin_email


def insert_users(conn, rows):
    conn.execute(
        text(
            "INSERT INTO users "
            "(name, email, password, role, contact_number, account_status, email_verified, created_at) "
            "VALUES (:name, :email, :password, :role, :contact_number, :account_status, :email_verified, :created_at)"
        ),
        rows,
    )
    emails = [row["email"] for row in rows]
    result = conn.execute(
        text("SELECT user_id, email FROM users WHERE email IN :emails").bindparams(bindparam("emails", expanding=True)),
        {"emails": emails},
    )
    return {row.email: row.user_id for row in result}


def seed_data(conn, now):
    password_hash = hash_password(DEMO_PASSWORD)
    rows, adviser_rows, student_rows, admin_email = user_rows(now, password_hash)
    ids_by_email = insert_users(conn, rows)
    admin_id = ids_by_email[admin_email]

    adviser_profiles = []
    for adviser in adviser_rows:
        department = adviser["department"]
        adviser_id = ids_by_email[adviser["email"]]
        adviser["user_id"] = adviser_id
        adviser_profiles.append({
            "adviser_id": adviser_id,
            "specialization_tags": f"Department: {department['name']}, {department['specialties']}",
            "certifications": department["certification"],
            "max_capacity": 8,
            "current_advisee_count": 0,
            "is_available": 1,
            "auto_approve": 0,
        })
    conn.execute(
        text(
            "INSERT INTO adviser_profiles "
            "(adviser_id, specialization_tags, certifications, max_capacity, current_advisee_count, is_available, auto_approve) "
            "VALUES (:adviser_id, :specialization_tags, :certifications, :max_capacity, :current_advisee_count, :is_available, :auto_approve)"
        ),
        adviser_profiles,
    )

    availability_rows = []
    for adviser in adviser_rows:
        adviser_id = adviser["user_id"]
        for day_name, _ in WEEKDAYS:
            availability_rows.extend([
                {"adviser_id": adviser_id, "day_of_week": day_name, "start_time": "09:00:00", "end_time": "12:00:00"},
                {"adviser_id": adviser_id, "day_of_week": day_name, "start_time": "13:00:00", "end_time": "16:00:00"},
            ])
    conn.execute(
        text("INSERT INTO availability (adviser_id, day_of_week, start_time, end_time) VALUES (:adviser_id, :day_of_week, :start_time, :end_time)"),
        availability_rows,
    )

    app_rows = []
    group_rows = []
    app_metadata = []
    for department_index, department in enumerate(DEPARTMENTS):
        for adviser_number in range(1, 11):
            adviser_email = f"adviser.{department['code']}.{adviser_number:02d}@example.com"
            adviser_id = ids_by_email[adviser_email]
            for group_number, status in enumerate(APPLICATION_STATUSES):
                first_student_number = (adviser_number - 1) * 12 + group_number * 3 + 1
                student_numbers = [first_student_number + member_offset for member_offset in range(3)]
                student_emails = [
                    f"student.{department['code']}.{number:03d}@example.com"
                    for number in student_numbers
                ]
                student_ids = [ids_by_email[email] for email in student_emails]
                submitted_days = {"approved": 24 - group_number, "pending": 1, "declined": 16}[status]
                submitted_at = now - dt.timedelta(days=submitted_days)
                topic = f"{department['topics'][group_number]} for the {department['name']} department."
                app_rows.append({
                    "student_id": student_ids[0],
                    "adviser_id": adviser_id,
                    "topic_brief": topic,
                    "status": status,
                    "date_submitted": submitted_at,
                })
                app_metadata.append({
                    "leader_id": student_ids[0],
                    "student_ids": student_ids,
                    "adviser_id": adviser_id,
                    "department": department,
                    "department_index": department_index,
                    "adviser_number": adviser_number,
                    "group_number": group_number,
                    "status": status,
                    "submitted_at": submitted_at,
                    "topic": topic,
                })

    conn.execute(
        text(
            "INSERT INTO applications (student_id, adviser_id, topic_brief, status, date_submitted) "
            "VALUES (:student_id, :adviser_id, :topic_brief, :status, :date_submitted)"
        ),
        app_rows,
    )
    leader_ids = [row["leader_id"] for row in app_metadata]
    app_result = conn.execute(
        text("SELECT application_id, student_id FROM applications WHERE student_id IN :student_ids").bindparams(bindparam("student_ids", expanding=True)),
        {"student_ids": leader_ids},
    )
    app_ids_by_leader = {row.student_id: row.application_id for row in app_result}
    for application in app_metadata:
        application["application_id"] = app_ids_by_leader[application["leader_id"]]
        for member_index, student_id in enumerate(application["student_ids"]):
            group_rows.append({
                "application_id": application["application_id"],
                "student_id": student_id,
                "is_leader": int(member_index == 0),
                "joined_at": application["submitted_at"],
            })
    conn.execute(
        text(
            "INSERT INTO application_groups (application_id, student_id, is_leader, joined_at) "
            "VALUES (:application_id, :student_id, :is_leader, :joined_at)"
        ),
        group_rows,
    )

    approved_apps = [row for row in app_metadata if row["status"] == "approved"]
    task_rows = []
    milestone_rows = []
    message_rows = []
    notification_rows = []
    for application in app_metadata:
        if application["status"] == "pending":
            notification_rows.append({
                "user_id": application["adviser_id"],
                "message": f"New three-member advisee request: {application['topic']}",
                "date_sent": application["submitted_at"],
            })
        else:
            outcome = "approved" if application["status"] == "approved" else "declined"
            notification_rows.append({
                "user_id": application["leader_id"],
                "message": f"Your group request was {outcome}: {application['topic']}",
                "date_sent": application["submitted_at"],
            })

    for application in approved_apps:
        application_id = application["application_id"]
        adviser_id = application["adviser_id"]
        leader_id = application["leader_id"]
        group_number = application["group_number"]
        start_time = application["submitted_at"]
        for task_index, (title, description) in enumerate(TASKS):
            if group_number == 0:
                statuses = ("done", "done", "in_progress", "review", "todo")
            else:
                statuses = ("done", "in_progress", "todo", "todo", "todo")
            task_rows.append({
                "application_id": application_id,
                "title": title,
                "description": description,
                "status": statuses[task_index],
                "points": 1,
                "created_by": adviser_id,
                "created_at": start_time + dt.timedelta(days=task_index),
                "updated_at": now - dt.timedelta(days=max(0, 5 - task_index)),
            })
        if group_number == 0:
            chapter_status, chapter_due = "in_progress", now.date() + dt.timedelta(days=7)
        else:
            chapter_status, chapter_due = "overdue", now.date() - dt.timedelta(days=2)
        milestone_rows.extend([
            {
                "application_id": application_id,
                "title": "Title defense",
                "description": "Confirm the research title, problem statement, and project scope.",
                "stage": "title_defense",
                "due_date": now.date() - dt.timedelta(days=21),
                "completed_date": now.date() - dt.timedelta(days=18),
                "status": "completed",
                "created_by": adviser_id,
            },
            {
                "application_id": application_id,
                "title": "Chapters 1-3",
                "description": "Prepare the introduction, literature review, and methodology.",
                "stage": "chapters_1_3",
                "due_date": chapter_due,
                "completed_date": None,
                "status": chapter_status,
                "created_by": adviser_id,
            },
            {
                "application_id": application_id,
                "title": "Proposal defense",
                "description": "Submit the proposal and prepare the presentation for review.",
                "stage": "proposal_defense",
                "due_date": now.date() + dt.timedelta(days=28),
                "completed_date": None,
                "status": "pending",
                "created_by": adviser_id,
            },
            {
                "application_id": application_id,
                "title": "Final defense",
                "description": "Complete final revisions and prepare the defense materials.",
                "stage": "final_defense",
                "due_date": now.date() + dt.timedelta(days=70),
                "completed_date": None,
                "status": "pending",
                "created_by": adviser_id,
            },
        ])
        message_rows.extend([
            {
                "application_id": application_id,
                "sender_id": leader_id,
                "body": "Our group has reviewed the project scope and is preparing the first progress update.",
                "created_at": start_time + dt.timedelta(days=1),
            },
            {
                "application_id": application_id,
                "sender_id": adviser_id,
                "body": "Please bring your updated literature matrix and requirements draft to the next consultation.",
                "created_at": start_time + dt.timedelta(days=2),
            },
        ])

    conn.execute(
        text(
            "INSERT INTO kanban_tasks "
            "(application_id, title, description, status, points, created_by, created_at, updated_at) "
            "VALUES (:application_id, :title, :description, :status, :points, :created_by, :created_at, :updated_at)"
        ),
        task_rows,
    )
    conn.execute(
        text(
            "INSERT INTO milestones "
            "(application_id, title, description, stage, due_date, completed_date, status, created_by) "
            "VALUES (:application_id, :title, :description, :stage, :due_date, :completed_date, :status, :created_by)"
        ),
        milestone_rows,
    )
    conn.execute(
        text("INSERT INTO messages (application_id, sender_id, body, created_at) VALUES (:application_id, :sender_id, :body, :created_at)"),
        message_rows,
    )

    comment_rows = []
    for index, task in enumerate(task_rows):
        if task["status"] == "review":
            comment_rows.append({
                "task_id": index + 1,
                "author_id": task["created_by"],
                "body": "Please check the references and formatting before marking this item complete.",
                "created_at": task["updated_at"],
            })
    if comment_rows:
        task_result = conn.execute(
            text("SELECT task_id, application_id, title FROM kanban_tasks WHERE application_id IN :ids").bindparams(bindparam("ids", expanding=True)),
            {"ids": [row["application_id"] for row in approved_apps]},
        )
        task_ids = {(row.application_id, row.title): row.task_id for row in task_result}
        for comment, task in zip(comment_rows, [row for row in task_rows if row["status"] == "review"]):
            comment["task_id"] = task_ids[(task["application_id"], task["title"])]
        conn.execute(
            text("INSERT INTO task_comments (task_id, author_id, body, created_at) VALUES (:task_id, :author_id, :body, :created_at)"),
            comment_rows,
        )

    booking_rows = []
    progress_rows = []
    rating_rows = []
    today = now.date()
    for application in approved_apps:
        group_number = application["group_number"]
        completed = group_number == 0
        slot_date = today - dt.timedelta(days=1) if completed else today + dt.timedelta(days=7)
        start = "10:00:00" if completed else "14:00:00"
        end = "10:30:00" if completed else "14:30:00"
        meeting_type = "online" if application["adviser_number"] % 2 else "in-person"
        location = "Microsoft Teams" if meeting_type == "online" else "Consultation Room 204"
        result = conn.execute(
            text(
                "INSERT INTO bookings "
                "(application_id, student_id, adviser_id, slot_date, start_time, end_time, status, meeting_type, location, notes) "
                "VALUES (:application_id, :student_id, :adviser_id, :slot_date, :start_time, :end_time, :status, :meeting_type, :location, :notes)"
            ),
            {
                "application_id": application["application_id"],
                "student_id": application["leader_id"],
                "adviser_id": application["adviser_id"],
                "slot_date": slot_date,
                "start_time": start,
                "end_time": end,
                "status": "completed" if completed else "confirmed",
                "meeting_type": meeting_type,
                "location": location,
                "notes": "Demo consultation for testing the booking and progress workflow.",
            },
        )
        booking_id = result.lastrowid
        if completed:
            progress_rows.append({
                "booking_id": booking_id,
                "stage_status": "Chapter 1 draft",
                "remarks": "Refined the problem statement and aligned the objectives with the project scope.",
            })
            rating_rows.append({
                "booking_id": booking_id,
                "student_id": application["leader_id"],
                "adviser_id": application["adviser_id"],
                "stars": 5 if application["adviser_number"] % 2 else 4,
                "comment": "Clear feedback and actionable next steps.",
            })
            conn.execute(
                text("UPDATE daily_consultation_stats SET completed = completed + 1 WHERE stat_date = :date AND adviser_id = :adviser_id"),
                {"date": slot_date, "adviser_id": application["adviser_id"]},
            )

    conn.execute(
        text("INSERT INTO progress_logs (booking_id, stage_status, remarks) VALUES (:booking_id, :stage_status, :remarks)"),
        progress_rows,
    )
    conn.execute(
        text("INSERT INTO consultation_ratings (booking_id, student_id, adviser_id, stars, comment) VALUES (:booking_id, :student_id, :adviser_id, :stars, :comment)"),
        rating_rows,
    )
    conn.execute(
        text("INSERT INTO notifications (user_id, message, type, is_read, date_sent) VALUES (:user_id, :message, 'in-app', 0, :date_sent)"),
        notification_rows,
    )

    for adviser in adviser_rows:
        adviser_id = adviser["user_id"]
        conn.execute(
            text(
                "UPDATE adviser_profiles SET current_advisee_count = "
                "(SELECT COUNT(*) FROM applications WHERE adviser_id = :adviser_id AND status = 'approved') "
                "WHERE adviser_id = :adviser_id"
            ),
            {"adviser_id": adviser_id},
        )

    return {
        "admin_id": admin_id,
        "accounts": len(rows),
        "advisers": len(adviser_rows),
        "students": len(student_rows),
        "applications": len(app_metadata),
        "groups": len(group_rows),
        "bookings": len(approved_apps),
        "tasks": len(task_rows),
        "milestones": len(milestone_rows),
        "messages": len(message_rows),
    }


def verify_data(conn):
    roles = {row.role: row.count for row in conn.execute(text("SELECT role, COUNT(*) AS count FROM users GROUP BY role"))}
    expected_roles = {"admin": 1, "adviser": 50, "student": 600}
    if roles != expected_roles:
        raise RuntimeError(f"Unexpected user counts: {roles}")

    statuses = {row.status: row.count for row in conn.execute(text("SELECT status, COUNT(*) AS count FROM applications GROUP BY status"))}
    expected_statuses = {"approved": 100, "pending": 50, "declined": 50}
    if statuses != expected_statuses:
        raise RuntimeError(f"Unexpected application statuses: {statuses}")

    invalid_groups = conn.execute(
        text("SELECT COUNT(*) FROM (SELECT application_id FROM application_groups GROUP BY application_id HAVING COUNT(*) <> 3) AS grouped")
    ).scalar_one()
    if invalid_groups:
        raise RuntimeError(f"Found {invalid_groups} groups that do not have exactly three members.")

    for department in DEPARTMENTS:
        count = conn.execute(
            text("SELECT COUNT(*) FROM adviser_profiles WHERE specialization_tags LIKE :tag"),
            {"tag": f"%Department: {department['name']}%"},
        ).scalar_one()
        if count != 10:
            raise RuntimeError(f"Expected 10 advisers in {department['name']}; found {count}.")

    expected_rows = {
        "application_groups": 600,
        "bookings": 100,
        "kanban_tasks": 500,
        "milestones": 400,
        "messages": 200,
        "progress_logs": 50,
        "consultation_ratings": 50,
    }
    for table, expected in expected_rows.items():
        actual = conn.execute(text(f"SELECT COUNT(*) FROM {table}")).scalar_one()
        if actual != expected:
            raise RuntimeError(f"Expected {expected} {table}; found {actual}.")


def main():
    parser = argparse.ArgumentParser(description="Back up and replace AdviserLink demo accounts and workflow data.")
    parser.add_argument("--reset", action="store_true", help="Replace every account in adviserlink_db with the demo scenario.")
    parser.add_argument("--yes", action="store_true", help="Confirm the destructive reset without an interactive prompt.")
    parser.add_argument("--dry-run", action="store_true", help="Seed and validate inside a transaction, then roll it back.")
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    args = parser.parse_args()

    if not args.reset:
        parser.error("Pass --reset to replace existing accounts and workflow data.")
    if (engine.url.database or "").lower() != "adviserlink_db":
        parser.error("Refusing to reset a database other than adviserlink_db.")
    if not args.yes and input("This replaces all AdviserLink accounts and related records. Type RESET to continue: ") != "RESET":
        raise SystemExit("Reset cancelled.")

    backup_path = make_backup(args.backup_dir)
    ensure_schema(engine)
    now = dt.datetime.now().replace(microsecond=0)

    with engine.connect() as conn:
        transaction = conn.begin()
        try:
            reset_accounts(conn)
            summary = seed_data(conn, now)
            verify_data(conn)
            if args.dry_run:
                transaction.rollback()
            else:
                transaction.commit()
        except Exception:
            transaction.rollback()
            raise

    if args.dry_run:
        print("Dry run validated: 1 admin, 50 advisers, 600 students, 200 requests, and 600 group memberships.")
        print("All seeded account and workflow rows were rolled back.")
    else:
        print(f"Verified backup: {backup_path}")
        print(f"Committed {summary['accounts']} accounts and {summary['groups']} group memberships.")
    print("Per adviser: 4 groups with exactly 3 members, weekday availability, board tasks, and milestones.")
    print("Workflow examples: 50 completed and 50 upcoming bookings, 50 progress entries, 50 ratings, 200 messages.")
    print("Login pattern: admin.demo@example.com, adviser.<department>.<01-10>@example.com, student.<department>.<001-120>@example.com")
    print(f"Shared demo password: {DEMO_PASSWORD}")


if __name__ == "__main__":
    main()
