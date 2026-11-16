"""
Hashes passwords for the 3 demo users from schema.sql (Juan, Maria, Admin)
so they can log in. Default password for all: test1234

Also adds demo data for immediate testing:
- Specialization tags and availability for Maria Santos
- Second demo adviser (Jose Reyes) with availability
Run: python seed_demo_users.py
"""
from sqlalchemy import text
from main import engine, hash_password
from db_setup import ensure_schema

DEMO_EMAILS = [
    "juan.delacruz@isu.edu.ph",
    "maria.santos@isu.edu.ph",
    "admin@isu.edu.ph",
]

ensure_schema(engine)
with engine.begin() as conn:
    # Hash plain-text passwords if any remain
    for email in DEMO_EMAILS:
        row = conn.execute(text("SELECT password FROM users WHERE email = :e"), {"e": email}).first()
        if row is None:
            print(f"Not in database: {email}")
        elif not row[0].startswith("$2"):
            conn.execute(text("UPDATE users SET password = :p WHERE email = :e"),
                         {"p": hash_password("test1234"), "e": email})
            print(f"Hashed password for: {email}")
        else:
            print(f"Already hashed: {email}")

    # Ensure Maria Santos has profile data
    maria = conn.execute(text("SELECT user_id FROM users WHERE email = 'maria.santos@isu.edu.ph'")).first()
    if maria:
        mid = maria[0]
        conn.execute(text("UPDATE adviser_profiles SET specialization_tags = 'web development, database design, PHP, React' WHERE adviser_id = :a"), {"a": mid})
        have = conn.execute(text("SELECT COUNT(*) FROM availability WHERE adviser_id = :a"), {"a": mid}).scalar()
        if have < 2:
            for day in ["Tue", "Wed", "Thu"]:
                conn.execute(text("INSERT INTO availability (adviser_id, day_of_week, start_time, end_time) VALUES (:a, :d, '09:00:00', '12:00:00')"), {"a": mid, "d": day})
            print("Added availability slots for Maria Santos")

    # Add second demo adviser: Jose Reyes
    jose = conn.execute(text("SELECT user_id FROM users WHERE email = 'jose.reyes@isu.edu.ph'")).first()
    if jose is None:
        res = conn.execute(text("INSERT INTO users (name, email, password, role, account_status, email_verified) VALUES ('Engr. Jose Reyes', 'jose.reyes@isu.edu.ph', :p, 'adviser', 'active', 1)"),
                           {"p": hash_password("test1234")})
        conn.execute(text("INSERT INTO adviser_profiles (adviser_id, specialization_tags, certifications, max_capacity) VALUES (:a, 'mobile development, Flutter, IoT, networking', 'MSCS', 8)"),
                     {"a": res.lastrowid})
        for day in ["Mon", "Fri"]:
            conn.execute(text("INSERT INTO availability (adviser_id, day_of_week, start_time, end_time) VALUES (:a, :d, '13:00:00', '16:00:00')"), {"a": res.lastrowid, "d": day})
        print("Added demo adviser: jose.reyes@isu.edu.ph (password: test1234)")