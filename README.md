# AdviserLink

A Thesis/Capstone Adviser Consultation and Matching System for CCSICT Students

IT 313 — System Integration and Architecture | ISU Echague

**Proponents:** Mark John Ymana (Leader), Simpolrod Abuena (Member)

## Tech stack
- **Backend / API:** Python (FastAPI), JWT login, bcrypt password hashing
- **Web:** React (Vite) + Tailwind + shadcn/ui
- **Mobile (student):** Flutter, kumakausap sa parehong Python API (tingnan ang `mobile/README.md`)
- **Database:** MySQL (XAMPP), schema sa `database/schema.sql` + enhanced schema sa `database/enhanced_schema.sql`

## Folders
- `backend/` Python API
- `web/` React web app
- `mobile/` Flutter app (pang-student)
- `database/` schema.sql at enhanced_schema.sql
- `diagrams/` Use Case Diagram at ERD
- `legacy_php/` ang unang PHP prototype (Sprint 1, may sariling `web/` at `backend/`), iniwan para sa history

## 🚀 Quick Start (Windows)

### 1. Database (MySQL via XAMPP)
```bash
# Buksan XAMPP, start MySQL
# Import schema:
mysql -u root -p adviserlink_db < database/schema.sql
```

### 2. Backend (FastAPI)
```bash
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
# Edit .env with your settings (JWT_SECRET, DATABASE_URL, etc.)
python seed_demo_scenario.py --reset --yes
uvicorn main:app --reload --host 0.0.0.0 --port 8001
```
The demo seed backs up `adviserlink_db` under `~/AdviserLinkBackups` before replacing its accounts and related workflow data. Use it only with the local demo database.
**API Docs:** http://localhost:8001/docs

### Gmail verification
Email addresses are verified by sending a one-time verification link; this confirms the user can access that inbox (it cannot independently prove that an address exists without the recipient opening the link).

To send these messages through Gmail, enable 2-Step Verification and create a Gmail App Password at https://myaccount.google.com/apppasswords. In `backend/.env`, set `SMTP_HOST=smtp.gmail.com`, `SMTP_PORT=587`, `SMTP_USER` and `SMTP_FROM` to the sending Gmail address, and `SMTP_PASS` to the App Password. Then set `SKIP_EMAIL_VERIFICATION=false` and restart the backend. Do not use your regular Gmail password or share the App Password in chat or source control. For local demos without SMTP, keep verification skipped.

### 3. Web (React + Vite)
```bash
cd web
npm install
npm run dev
```
**Web App:** http://localhost:5173

### 4. Mobile (Flutter)
```bash
cd mobile
flutter create . --project-name adviserlink --org ph.edu.isu
flutter pub get
flutter pub run flutter_launcher_icons:main
# Configure android/app/src/main/AndroidManifest.xml for cleartext traffic (see DEPLOYMENT_GUIDE.md)
flutter run
```

---

## 📱 Demo Accounts
After running `python seed_demo_scenario.py --reset --yes`, all accounts use password `AdviserLink2026!`.
- **Admin:** `admin.demo@example.com`
- **Advisers:** `adviser.<department>.<01-10>@example.com` for `it`, `cs`, `is`, `dsa`, and `lis`
- **Students:** `student.<department>.<001-120>@example.com` for the same department codes
- **Requests:** Each of 50 advisers has four three-member groups: two approved, one pending, and one declined
- **Progress:** Approved groups include tasks, milestones, messages, completed and upcoming consultations, and progress notes

---

## ✨ Features by Sprint

### Sprint 1: Core Auth & Profiles
- Register/Login with JWT
- Role-based access (Student, Adviser, Admin)
- Email verification (via SMTP)
- Adviser approval workflow

### Sprint 2: Consultation Management
- **Adviser Search:** Keyword search with smart matching (% match, best match)
- **Applications:** Student applies → Adviser approves/declines → Capacity check
- **Availability:** Adviser sets weekly/specific-date time windows
- **Bookings:** 30-min slots, conflict detection, online/in-person, cancel with reason, mark completed
- **Kanban Board:** To Do / In Progress / For Review / Done per advisee
- **Documents:** Student uploads, adviser views, category-based
- **Notifications:** In-app + 15-min reminders

### Sprint 3: Smart & Hassle-Free
- **Attention Panel:** What to do now (1-click actions)
- **Quick Book:** Earliest available slots (next 4 weeks)
- **Reschedule:** Single-step move with conflict check
- **Calendar Export:** .ics download + Google Calendar link
- **Smart Matching:** NLP-based topic-to-specialization matching
- **Ratings:** 1-5 stars + feedback after consultation
- **Progress Tracking:** Stage status & remarks visible to student

### Phase B: Advanced Features (New!)
- **Messaging:** Student ↔ Adviser chat per application
- **Milestones:** Thesis stages (Title Defense, Chapters 1-3, Proposal, Final Defense) with deadlines
- **Document Versions:** Version history with comments
- **Availability Exceptions:** Block dates (leave, holidays)
- **Waitlist:** Join queue for full advisers, get notified when slot opens
- **Group Support:** 2-4 students per application
- **Group invitations:** student group leaders invite; students accept or decline; advisers are view-only for membership
- **Deadline reminders:** optional due dates for board tasks and one-day notifications for upcoming tasks and milestones
- **Admin Audit Log:** Full action trail
- **Admin Exports:** CSV (users, applications, bookings) + Analytics report

---

## 🔒 Security Features
- Adviser approval by admin (pending → active)
- Account deactivate/reactivate (except admin)
- Login throttling (5 fails = 10 min lock)
- Auto-generated JWT secret (no defaults)
- CORS + optional email domain restriction (`ALLOWED_EMAIL_DOMAIN`)
- File content validation (magic bytes, not just extension)
- Change password in Settings
- Bcrypt password hashing (compatible with PHP `password_hash`)
- Group membership and document access are checked by the API; project files are not publicly served
- Production startup requires HTTPS origins, configured SMTP, a strong JWT secret, persistent uploads, and a non-root DB account

---

## 📊 Analytics (4 Types)
| Type | Description |
|------|-------------|
| **Descriptive** | Consultations by day/hour, application/booking status, adviser workload |
| **Diagnostic** | Cancellation analysis (who, when), unmarked past consultations |
| **Predictive** | Linear regression demand forecast (4 weeks), advisee risk levels (On track/At risk/Stalled) |
| **Prescriptive** | Rule-based recommendations (open more slots, follow up stalled students, etc.) |

**Model Accuracy:** Walk-forward backtest MAE vs naive "same as last week"

---

## 🗄️ Enhanced Database Features

Run `database/enhanced_schema.sql` for production features:

### Core Enhancements
- **Login History** (`login_history` table) - tracks all login attempts
- **Audit Logs** (`audit_logs` table) - comprehensive action trail with JSON old/new values
- **Triggers** - auto-maintain capacity counts, audit logs, daily stats
- **Check Constraints** - domain validation at DB level
- **Performance Indexes** - 30+ indexes for common queries
- **Views** - vertical partitioning for common queries (`v_active_users`, `v_adviser_search`, etc.)

### Optimization
- **Aggregate Tables** - `daily_consultation_stats`, `monthly_user_activity`
- **Horizontal Partitioning** - bookings by year (MySQL 8.0+)
- **Stored Procedures** - maintenance (clean logs, adviser workload, backup logging)
- **Events** - automated cleanup (monthly)

### Security
- **Database Users** - separate app/readonly/backup users with minimal privileges
- **Column Encryption** - `encrypted_contact` + `encryption_iv` for sensitive data
- **Referential Integrity** - all FKs with CASCADE/SET NULL

### Recovery & Backup
- **Backup Log** table with checksums
- **Stored Procedures** for backup start/complete
- **Automated Events** for log cleanup
- **Point-in-time recovery** ready

---

## 🌐 Deployment (Free Options)

| Method | Cost | HTTPS | Best For |
|--------|------|-------|----------|
| **Local Network** | Free | No | Development, demo |
| **GitHub Pages** | Free for public repos | Yes | Static web/mobile files; requires a separately hosted API |
| **Cloudflare Tunnel** | Free | Yes | Public access without VPS |
| **Railway.app** | Free tier | Yes | Easy deploy + managed DB |
| **Render.com** | Free preview tier | Yes | Test/demo services; no native MySQL |
| **Fly.io** | Free allowance | Yes | Container deploy |
| **Oracle Cloud** | Always Free | Manual | Persistent VPS |

**Mobile Distribution (Free):**
- **APK Direct Share** - `flutter build apk --release` → Google Drive/GitHub Releases
- **Firebase App Distribution** - Free tester distribution
- **PWA** - `flutter build web --release` → Netlify/Vercel/GitHub Pages (no install needed)

---

## 📖 Documentation
- **DEPLOYMENT_GUIDE.md** - Production configuration, HTTPS, mobile API URL, persistent uploads, release checks
- **database/BACKUP_RECOVERY.md** - Verified backups, scheduled task setup, and isolated restore guidance
- **ROADMAP.md** - Future features checklist
- **database/enhanced_schema.sql** - Production database features
- **API Docs** - http://localhost:8001/docs (Swagger UI)

---

## 🧪 Testing
```bash
# Backend tests
cd backend
pip install -r requirements-dev.txt
pytest

# Mobile
cd mobile
flutter test

# Web
cd web
npm test
```

---

## 📄 License
Educational/Thesis Project - ISU Echague

---

**Need help?** Check `DEPLOYMENT_GUIDE.md` for step-by-step instructions on running on another PC, installing on phone, and free deployment options.