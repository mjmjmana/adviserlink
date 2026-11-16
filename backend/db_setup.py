"""
Auto-migration for Sprint 2 and Enhanced Features.

This runs every time the API starts. It does NOT erase your database:
it only adds missing columns/tables. So even if you already imported
Sprint 1's schema.sql, this still works (you don't need to re-import).
"""
from sqlalchemy import text

# (table, column, definition)
NEW_COLUMNS = [
    ("adviser_profiles", "department", "VARCHAR(120) NULL"),
    ("users", "account_status", "ENUM('active','pending','disabled') NOT NULL DEFAULT 'active'"),
    ("users", "student_group_role", "ENUM('leader','member') NULL DEFAULT NULL"),
    ("users", "research_interests", "VARCHAR(500) NULL"),
    ("users", "thesis_title", "VARCHAR(500) NULL"),
    ("users", "title_setup_required", "TINYINT(1) NOT NULL DEFAULT 0"),
    ("users", "email_verified", "TINYINT(1) NOT NULL DEFAULT 0"),
    ("users", "password_reset_token", "VARCHAR(64) NULL"),
    ("users", "password_reset_expires", "DATETIME NULL"),
    ("users", "profile_photo", "VARCHAR(255) NULL"),
    ("users", "encrypted_contact", "VARBINARY(512) NULL"),
    ("users", "encryption_iv", "VARBINARY(16) NULL"),
    ("notifications", "is_read", "TINYINT(1) NOT NULL DEFAULT 0"),
    ("notifications", "related_user_id", "INT NULL"),
    ("notifications", "related_application_id", "INT NULL"),
    ("notifications", "related_message_id", "INT NULL"),
    ("bookings", "meeting_type", "ENUM('online','in-person') NULL DEFAULT NULL"),
    ("bookings", "location", "VARCHAR(255) NULL"),
    ("bookings", "notes", "TEXT NULL"),
    ("bookings", "cancel_reason", "TEXT NULL"),
    ("bookings", "cancelled_by", "INT NULL"),
    ("bookings", "reminded", "TINYINT(1) NOT NULL DEFAULT 0"),
    ("documents", "category", "ENUM('todo','in_progress','review','done') NOT NULL DEFAULT 'todo'"),
    ("documents", "task_id", "INT NULL"),
    ("documents", "task_comment_id", "INT NULL"),
    ("adviser_profiles", "is_available", "TINYINT(1) NOT NULL DEFAULT 1"),
    ("adviser_profiles", "auto_approve", "TINYINT(1) NOT NULL DEFAULT 0"),
    ("kanban_tasks", "due_date", "DATE NULL"),
    ("kanban_tasks", "reminder_sent_at", "DATETIME NULL"),
    ("milestones", "reminder_sent_at", "DATETIME NULL"),
    ("messages", "message_kind", "VARCHAR(24) NOT NULL DEFAULT 'user'"),
    ("messages", "language_code", "VARCHAR(12) NOT NULL DEFAULT 'unknown'"),
    ("messages", "moderation_categories", "VARCHAR(255) NULL"),
    ("messages", "delivered_at", "DATETIME NULL"),
    ("messages", "read_at", "DATETIME NULL"),
]

NEW_TABLES = [
    """
    CREATE TABLE IF NOT EXISTS consultation_ratings (
        rating_id    INT AUTO_INCREMENT PRIMARY KEY,
        booking_id   INT NOT NULL UNIQUE,
        student_id   INT NOT NULL,
        adviser_id   INT NOT NULL,
        stars        TINYINT NOT NULL,
        comment      VARCHAR(500) NULL,
        created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
        FOREIGN KEY (adviser_id) REFERENCES users(user_id) ON DELETE CASCADE
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS kanban_tasks (
        task_id         INT AUTO_INCREMENT PRIMARY KEY,
        application_id  INT NOT NULL,
        title           VARCHAR(150) NOT NULL,
        description     TEXT,
        status          ENUM('todo','in_progress','review','done') NOT NULL DEFAULT 'todo',
        points          TINYINT NOT NULL DEFAULT 1,
        due_date        DATE NULL,
        reminder_sent_at DATETIME NULL,
        created_by      INT NOT NULL,
        created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE,
        FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE CASCADE
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS task_comments (
        comment_id   INT AUTO_INCREMENT PRIMARY KEY,
        task_id      INT NOT NULL,
        author_id    INT NOT NULL,
        body         TEXT NOT NULL,
        created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (task_id) REFERENCES kanban_tasks(task_id) ON DELETE CASCADE,
        FOREIGN KEY (author_id) REFERENCES users(user_id) ON DELETE CASCADE
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS documents (
        document_id     INT AUTO_INCREMENT PRIMARY KEY,
        application_id  INT NOT NULL,
        booking_id      INT NULL,
        uploaded_by     INT NOT NULL,
        filename        VARCHAR(255) NOT NULL,
        stored_name     VARCHAR(100) NOT NULL,
        size_bytes      INT NOT NULL DEFAULT 0,
        category        ENUM('todo','in_progress','review','done') NOT NULL DEFAULT 'todo',
        task_id         INT NULL,
        task_comment_id INT NULL,
        uploaded_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE,
        FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE SET NULL,
        FOREIGN KEY (task_id) REFERENCES kanban_tasks(task_id) ON DELETE SET NULL,
        FOREIGN KEY (task_comment_id) REFERENCES task_comments(comment_id) ON DELETE SET NULL,
        FOREIGN KEY (uploaded_by) REFERENCES users(user_id) ON DELETE CASCADE
    ) ENGINE=InnoDB
    """,
    # Phase B: New tables for messaging, milestones, document versions, exceptions, waitlist, groups
    """
    CREATE TABLE IF NOT EXISTS messages (
        message_id      INT AUTO_INCREMENT PRIMARY KEY,
        application_id  INT NOT NULL,
        sender_id       INT NOT NULL,
        body            TEXT NOT NULL,
        is_read         TINYINT(1) NOT NULL DEFAULT 0,
        delivered_at    DATETIME NULL,
        read_at         DATETIME NULL,
        message_kind    VARCHAR(24) NOT NULL DEFAULT 'user',
        language_code   VARCHAR(12) NOT NULL DEFAULT 'unknown',
        moderation_categories VARCHAR(255) NULL,
        created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE,
        FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE CASCADE
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS chat_presence (
        application_id  INT NOT NULL,
        user_id         INT NOT NULL,
        last_active_at  DATETIME NOT NULL,
        typing_until    DATETIME NULL,
        PRIMARY KEY (application_id, user_id),
        FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS milestones (
        milestone_id    INT AUTO_INCREMENT PRIMARY KEY,
        application_id  INT NOT NULL,
        title           VARCHAR(150) NOT NULL,
        description     TEXT,
        stage           ENUM('title_defense','chapters_1_3','proposal_defense','final_defense','custom') NOT NULL,
        due_date        DATE NULL,
        reminder_sent_at DATETIME NULL,
        completed_date  DATE NULL,
        status          ENUM('pending','in_progress','completed','overdue') NOT NULL DEFAULT 'pending',
        created_by      INT NOT NULL,
        created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE,
        FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE CASCADE
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS document_versions (
        version_id      INT AUTO_INCREMENT PRIMARY KEY,
        document_id     INT NOT NULL,
        version_number  INT NOT NULL,
        filename        VARCHAR(255) NOT NULL,
        stored_name     VARCHAR(100) NOT NULL,
        size_bytes      INT NOT NULL DEFAULT 0,
        uploaded_by     INT NOT NULL,
        comment         TEXT NULL,
        created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (document_id) REFERENCES documents(document_id) ON DELETE CASCADE,
        FOREIGN KEY (uploaded_by) REFERENCES users(user_id) ON DELETE CASCADE,
        UNIQUE KEY unique_doc_version (document_id, version_number)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS availability_exceptions (
        exception_id    INT AUTO_INCREMENT PRIMARY KEY,
        adviser_id      INT NOT NULL,
        specific_date   DATE NOT NULL,
        start_time      TIME NULL,
        end_time        TIME NULL,
        reason          VARCHAR(255) NULL,
        is_all_day      TINYINT(1) NOT NULL DEFAULT 0,
        created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (adviser_id) REFERENCES adviser_profiles(adviser_id) ON DELETE CASCADE
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS waitlist (
        waitlist_id     INT AUTO_INCREMENT PRIMARY KEY,
        student_id      INT NOT NULL,
        adviser_id      INT NOT NULL,
        topic_brief     TEXT NOT NULL,
        position        INT NOT NULL,
        status          ENUM('waiting','notified','expired','cancelled') NOT NULL DEFAULT 'waiting',
        notified_at     DATETIME NULL,
        expires_at      DATETIME NULL,
        created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
        FOREIGN KEY (adviser_id) REFERENCES adviser_profiles(adviser_id) ON DELETE CASCADE
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS application_groups (
        group_id        INT AUTO_INCREMENT PRIMARY KEY,
        application_id  INT NOT NULL,
        student_id      INT NOT NULL,
        is_leader       TINYINT(1) NOT NULL DEFAULT 0,
        joined_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
        UNIQUE KEY unique_group_member (application_id, student_id)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS group_invitations (
        invitation_id   INT AUTO_INCREMENT PRIMARY KEY,
        application_id  INT NOT NULL,
        student_id      INT NOT NULL,
        invited_by      INT NOT NULL,
        status          ENUM('pending','accepted','declined','cancelled') NOT NULL DEFAULT 'pending',
        created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        responded_at    DATETIME NULL,
        FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
        FOREIGN KEY (invited_by) REFERENCES users(user_id) ON DELETE CASCADE,
        INDEX idx_group_invites_student_status (student_id, status),
        INDEX idx_group_invites_application_status (application_id, status)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS group_join_requests (
        request_id      INT AUTO_INCREMENT PRIMARY KEY,
        application_id  INT NOT NULL,
        student_id      INT NOT NULL,
        status          ENUM('pending','approved','declined') NOT NULL DEFAULT 'pending',
        created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        responded_at    DATETIME NULL,
        FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
        INDEX idx_group_join_requests_application_status (application_id, status),
        INDEX idx_group_join_requests_student (student_id, application_id, request_id)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS student_group_requests (
        request_id      INT AUTO_INCREMENT PRIMARY KEY,
        leader_id       INT NOT NULL,
        member_id       INT NOT NULL,
        requested_by    ENUM('leader','member') NOT NULL,
        status          ENUM('pending','approved','declined','cancelled') NOT NULL DEFAULT 'pending',
        created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        responded_at    DATETIME NULL,
        FOREIGN KEY (leader_id) REFERENCES users(user_id) ON DELETE CASCADE,
        FOREIGN KEY (member_id) REFERENCES users(user_id) ON DELETE CASCADE,
        UNIQUE KEY unique_student_group_pair (leader_id, member_id),
        INDEX idx_student_group_request_leader (leader_id, status),
        INDEX idx_student_group_request_member (member_id, status)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS admin_audit_log (
        log_id          INT AUTO_INCREMENT PRIMARY KEY,
        admin_id        INT NOT NULL,
        action          VARCHAR(100) NOT NULL,
        target_type     VARCHAR(50) NOT NULL,
        target_id       INT NOT NULL,
        details         TEXT NULL,
        created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (admin_id) REFERENCES users(user_id) ON DELETE CASCADE
    ) ENGINE=InnoDB
    """,
    # Enhanced features: Login History, Audit Logs, Backup Log
    """
    CREATE TABLE IF NOT EXISTS login_history (
        login_id          BIGINT AUTO_INCREMENT PRIMARY KEY,
        user_id           INT NULL,
        email_attempted   VARCHAR(100) NOT NULL,
        ip_address        VARCHAR(45) NOT NULL,
        user_agent        TEXT,
        success           TINYINT(1) NOT NULL DEFAULT 0,
        failure_reason    VARCHAR(100) NULL,
        created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
        INDEX idx_login_history_user (user_id),
        INDEX idx_login_history_email (email_attempted),
        INDEX idx_login_history_ip (ip_address),
        INDEX idx_login_history_created (created_at),
        INDEX idx_login_history_success (success)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS audit_logs (
        audit_id          BIGINT AUTO_INCREMENT PRIMARY KEY,
        user_id           INT NULL,
        action            VARCHAR(100) NOT NULL,
        target_type       VARCHAR(50) NOT NULL,
        target_id         INT NULL,
        old_values        JSON NULL,
        new_values        JSON NULL,
        ip_address        VARCHAR(45) NULL,
        user_agent        TEXT NULL,
        session_id        VARCHAR(64) NULL,
        created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
        INDEX idx_audit_logs_user (user_id),
        INDEX idx_audit_logs_action (action),
        INDEX idx_audit_logs_target (target_type, target_id),
        INDEX idx_audit_logs_created (created_at)
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS backup_log (
        backup_id         INT AUTO_INCREMENT PRIMARY KEY,
        backup_type       ENUM('full', 'incremental', 'schema_only') NOT NULL,
        file_path         VARCHAR(500) NOT NULL,
        file_size_bytes   BIGINT,
        checksum          VARCHAR(64),
        tables_included   TEXT,
        started_at        TIMESTAMP NOT NULL,
        completed_at      TIMESTAMP NULL,
        status            ENUM('running', 'completed', 'failed') NOT NULL DEFAULT 'running',
        error_message     TEXT NULL,
        created_by        VARCHAR(100) DEFAULT 'system',
        INDEX idx_backup_log_type_date (backup_type, started_at),
        INDEX idx_backup_log_status (status)
    ) ENGINE=InnoDB
    """,
    # Aggregate tables for performance
    """
    CREATE TABLE IF NOT EXISTS daily_consultation_stats (
        stat_date         DATE NOT NULL,
        adviser_id        INT NOT NULL,
        total_bookings    INT DEFAULT 0,
        completed         INT DEFAULT 0,
        cancelled         INT DEFAULT 0,
        no_show           INT DEFAULT 0,
        PRIMARY KEY (stat_date, adviser_id),
        FOREIGN KEY (adviser_id) REFERENCES adviser_profiles(adviser_id) ON DELETE CASCADE
    ) ENGINE=InnoDB
    """,
    """
    CREATE TABLE IF NOT EXISTS monthly_user_activity (
        activity_month    DATE NOT NULL,
        user_id           INT NOT NULL,
        logins            INT DEFAULT 0,
        bookings_made     INT DEFAULT 0,
        documents_uploaded INT DEFAULT 0,
        messages_sent     INT DEFAULT 0,
        PRIMARY KEY (activity_month, user_id),
        FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
    ) ENGINE=InnoDB
    """,
]


def _column_exists(conn, table: str, column: str) -> bool:
    row = conn.execute(
        text(
            "SELECT COUNT(*) FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :t AND COLUMN_NAME = :c"
        ),
        {"t": table, "c": column},
    ).first()
    return bool(row and row[0])


def _foreign_key_exists(conn, table: str, column: str, referenced_table: str, referenced_column: str) -> bool:
    row = conn.execute(
        text(
            "SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :t AND COLUMN_NAME = :c "
            "AND REFERENCED_TABLE_NAME = :rt AND REFERENCED_COLUMN_NAME = :rc"
        ),
        {"t": table, "c": column, "rt": referenced_table, "rc": referenced_column},
    ).first()
    return bool(row and row[0])


def _is_nullable(conn, table: str, column: str) -> bool:
    row = conn.execute(
        text(
            "SELECT IS_NULLABLE FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :t AND COLUMN_NAME = :c"
        ),
        {"t": table, "c": column},
    ).first()
    return bool(row and row[0] == "YES")


# Performance indexes to add
PERFORMANCE_INDEXES = [
    "CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users (LOWER(email))",
    "CREATE INDEX IF NOT EXISTS idx_users_role_status ON users (role, account_status)",
    "CREATE INDEX IF NOT EXISTS idx_users_created ON users (created_at)",
    "CREATE INDEX IF NOT EXISTS idx_applications_student_status ON applications (student_id, status)",
    "CREATE INDEX IF NOT EXISTS idx_applications_adviser_status ON applications (adviser_id, status)",
    "CREATE INDEX IF NOT EXISTS idx_applications_date_submitted ON applications (date_submitted)",
    "CREATE INDEX IF NOT EXISTS idx_bookings_adviser_date_status ON bookings (adviser_id, slot_date, status)",
    "CREATE INDEX IF NOT EXISTS idx_bookings_student_date_status ON bookings (student_id, slot_date, status)",
    "CREATE INDEX IF NOT EXISTS idx_bookings_application ON bookings (application_id)",
    "CREATE INDEX IF NOT EXISTS idx_bookings_date_range ON bookings (slot_date, start_time)",
    "CREATE INDEX IF NOT EXISTS idx_availability_adviser_date ON availability (adviser_id, specific_date, day_of_week)",
    "CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON notifications (user_id, is_read)",
    "CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications (date_sent)",
    "CREATE INDEX IF NOT EXISTS idx_documents_application ON documents (application_id)",
    "CREATE INDEX IF NOT EXISTS idx_documents_task ON documents (task_id)",
    "CREATE INDEX IF NOT EXISTS idx_documents_booking ON documents (booking_id)",
    "CREATE INDEX IF NOT EXISTS idx_kanban_tasks_application ON kanban_tasks (application_id)",
    "CREATE INDEX IF NOT EXISTS idx_kanban_tasks_status ON kanban_tasks (status)",
    "CREATE INDEX IF NOT EXISTS idx_messages_application ON messages (application_id)",
    "CREATE INDEX IF NOT EXISTS idx_messages_created ON messages (created_at)",
    "CREATE INDEX IF NOT EXISTS idx_milestones_application ON milestones (application_id)",
    "CREATE INDEX IF NOT EXISTS idx_milestones_due_date ON milestones (due_date)",
    "CREATE INDEX IF NOT EXISTS idx_milestones_status ON milestones (status)",
    "CREATE INDEX IF NOT EXISTS idx_waitlist_adviser_status ON waitlist (adviser_id, status)",
    "CREATE INDEX IF NOT EXISTS idx_waitlist_student_status ON waitlist (student_id, status)",
    "CREATE INDEX IF NOT EXISTS idx_document_versions_document ON document_versions (document_id)",
    "CREATE INDEX IF NOT EXISTS idx_availability_exceptions_adviser_date ON availability_exceptions (adviser_id, specific_date)",
    "CREATE INDEX IF NOT EXISTS idx_application_groups_application ON application_groups (application_id)",
    "CREATE INDEX IF NOT EXISTS idx_admin_audit_log_admin ON admin_audit_log (admin_id)",
    "CREATE INDEX IF NOT EXISTS idx_admin_audit_log_created ON admin_audit_log (created_at)",
    "CREATE INDEX IF NOT EXISTS idx_login_history_user_created ON login_history (user_id, created_at)",
    "CREATE INDEX IF NOT EXISTS idx_login_history_ip_created ON login_history (ip_address, created_at)",
    "CREATE INDEX IF NOT EXISTS idx_audit_logs_user_created ON audit_logs (user_id, created_at)",
    "CREATE INDEX IF NOT EXISTS idx_audit_logs_target_created ON audit_logs (target_type, target_id, created_at)",
]

# Check constraints to add
CHECK_CONSTRAINTS = [
    "ALTER TABLE users ADD CONSTRAINT chk_users_email_format CHECK (email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\\\.[A-Za-z]{2,}$')",
    "ALTER TABLE users ADD CONSTRAINT chk_users_contact_format CHECK (contact_number IS NULL OR contact_number REGEXP '^[0-9+\\\\-\\\\s()]{7,20}$')",
    "ALTER TABLE users ADD CONSTRAINT chk_users_name_length CHECK (CHAR_LENGTH(name) >= 2 AND CHAR_LENGTH(name) <= 100)",
    "ALTER TABLE applications ADD CONSTRAINT chk_applications_topic_length CHECK (CHAR_LENGTH(topic_brief) >= 10 AND CHAR_LENGTH(topic_brief) <= 2000)",
    "ALTER TABLE adviser_profiles ADD CONSTRAINT chk_adviser_capacity CHECK (max_capacity >= 1 AND max_capacity <= 50)",
    "ALTER TABLE adviser_profiles ADD CONSTRAINT chk_adviser_current_count CHECK (current_advisee_count >= 0 AND current_advisee_count <= max_capacity)",
    "ALTER TABLE bookings ADD CONSTRAINT chk_bookings_time_order CHECK (end_time > start_time)",
    "ALTER TABLE bookings ADD CONSTRAINT chk_bookings_slot_future CHECK (slot_date >= DATE_SUB(CURDATE(), INTERVAL 1 DAY))",
    "ALTER TABLE consultation_ratings ADD CONSTRAINT chk_ratings_stars CHECK (stars BETWEEN 1 AND 5)",
]

# Views for common queries (vertical partitioning)
VIEWS = [
    """
    CREATE OR REPLACE VIEW v_active_users AS
    SELECT user_id, name, email, role, account_status, created_at
    FROM users WHERE account_status = 'active'
    """,
    """
    CREATE OR REPLACE VIEW v_adviser_search AS
    SELECT u.user_id, u.name, u.email, p.specialization_tags, p.certifications,
           p.max_capacity, p.current_advisee_count,
           (p.max_capacity - p.current_advisee_count) AS slots_left
    FROM users u JOIN adviser_profiles p ON p.adviser_id = u.user_id
    WHERE u.role = 'adviser' AND u.account_status = 'active'
    """,
    """
    CREATE OR REPLACE VIEW v_student_applications AS
    SELECT a.application_id, a.student_id, a.adviser_id, a.topic_brief, a.status, a.date_submitted,
           ad.name AS adviser_name, ad.email AS adviser_email
    FROM applications a JOIN users ad ON ad.user_id = a.adviser_id
    """,
    """
    CREATE OR REPLACE VIEW v_upcoming_bookings AS
    SELECT b.booking_id, b.application_id, b.student_id, b.adviser_id, b.slot_date, b.start_time, b.end_time,
           b.status, b.meeting_type, b.location, b.notes,
           s.name AS student_name, a.name AS adviser_name
    FROM bookings b
    JOIN users s ON s.user_id = b.student_id
    JOIN users a ON a.user_id = b.adviser_id
    WHERE b.status = 'confirmed' AND b.slot_date >= CURDATE()
    ORDER BY b.slot_date, b.start_time
    """,
    """
    CREATE OR REPLACE VIEW v_system_stats AS
    SELECT
        (SELECT COUNT(*) FROM users WHERE role = 'student') AS total_students,
        (SELECT COUNT(*) FROM users WHERE role = 'adviser' AND account_status = 'active') AS active_advisers,
        (SELECT COUNT(*) FROM users WHERE role = 'adviser' AND account_status = 'pending') AS pending_advisers,
        (SELECT COUNT(*) FROM applications WHERE status = 'pending') AS pending_applications,
        (SELECT COUNT(*) FROM bookings WHERE status = 'confirmed' AND slot_date >= CURDATE()) AS upcoming_consultations,
        (SELECT COUNT(*) FROM bookings WHERE status = 'completed') AS completed_consultations
    """,
]

# Triggers for audit logging and data integrity
TRIGGERS = [
    """
    CREATE TRIGGER trg_users_after_insert
    AFTER INSERT ON users
    FOR EACH ROW
    BEGIN
        INSERT INTO audit_logs (user_id, action, target_type, target_id, new_values, created_at)
        VALUES (NEW.user_id, 'CREATE', 'user', NEW.user_id,
                JSON_OBJECT('name', NEW.name, 'email', NEW.email, 'role', NEW.role, 'account_status', NEW.account_status),
                NOW());
    END
    """,
    """
    CREATE TRIGGER trg_users_after_update
    AFTER UPDATE ON users
    FOR EACH ROW
    BEGIN
        IF OLD.name != NEW.name OR OLD.email != NEW.email OR OLD.role != NEW.role
           OR OLD.account_status != NEW.account_status OR OLD.password != NEW.password
           OR OLD.contact_number != NEW.contact_number OR OLD.email_verified != NEW.email_verified
        THEN
            INSERT INTO audit_logs (user_id, action, target_type, target_id, old_values, new_values, created_at)
            VALUES (NEW.user_id, 'UPDATE', 'user', NEW.user_id,
                    JSON_OBJECT('name', OLD.name, 'email', OLD.email, 'role', OLD.role,
                               'account_status', OLD.account_status, 'contact_number', OLD.contact_number,
                               'email_verified', OLD.email_verified),
                    JSON_OBJECT('name', NEW.name, 'email', NEW.email, 'role', NEW.role,
                               'account_status', NEW.account_status, 'contact_number', NEW.contact_number,
                               'email_verified', NEW.email_verified),
                    NOW());
        END IF;
    END
    """,
    """
    CREATE TRIGGER trg_users_before_delete
    BEFORE DELETE ON users
    FOR EACH ROW
    BEGIN
        INSERT INTO audit_logs (user_id, action, target_type, target_id, old_values, created_at)
        VALUES (OLD.user_id, 'DELETE', 'user', OLD.user_id,
                JSON_OBJECT('name', OLD.name, 'email', OLD.email, 'role', OLD.role),
                NOW());
    END
    """,
    """
    CREATE TRIGGER trg_applications_after_update
    AFTER UPDATE ON applications
    FOR EACH ROW
    BEGIN
        IF OLD.status != NEW.status THEN
            INSERT INTO audit_logs (user_id, action, target_type, target_id, old_values, new_values, created_at)
            VALUES (NEW.adviser_id, 'STATUS_CHANGE', 'application', NEW.application_id,
                    JSON_OBJECT('status', OLD.status),
                    JSON_OBJECT('status', NEW.status),
                    NOW());
        END IF;
    END
    """,
    """
    CREATE TRIGGER trg_bookings_after_insert
    AFTER INSERT ON bookings
    FOR EACH ROW
    BEGIN
        INSERT INTO audit_logs (user_id, action, target_type, target_id, new_values, created_at)
        VALUES (NEW.student_id, 'CREATE', 'booking', NEW.booking_id,
                JSON_OBJECT('application_id', NEW.application_id, 'adviser_id', NEW.adviser_id,
                           'slot_date', NEW.slot_date, 'start_time', NEW.start_time, 'end_time', NEW.end_time),
                NOW());
    END
    """,
    """
    CREATE TRIGGER trg_bookings_after_update
    AFTER UPDATE ON bookings
    FOR EACH ROW
    BEGIN
        IF OLD.status != NEW.status OR OLD.meeting_type != NEW.meeting_type
           OR OLD.location != NEW.location OR OLD.cancel_reason != NEW.cancel_reason
        THEN
            INSERT INTO audit_logs (user_id, action, target_type, target_id, old_values, new_values, created_at)
            VALUES (COALESCE(NEW.cancelled_by, NEW.student_id, NEW.adviser_id),
                    CASE WHEN OLD.status != NEW.status THEN 'STATUS_CHANGE' ELSE 'UPDATE' END,
                    'booking', NEW.booking_id,
                    JSON_OBJECT('status', OLD.status, 'meeting_type', OLD.meeting_type,
                               'location', OLD.location, 'cancel_reason', OLD.cancel_reason),
                    JSON_OBJECT('status', NEW.status, 'meeting_type', NEW.meeting_type,
                               'location', NEW.location, 'cancel_reason', NEW.cancel_reason),
                    NOW());
        END IF;
    END
    """,
    """
    CREATE TRIGGER trg_applications_after_status_change
    AFTER UPDATE ON applications
    FOR EACH ROW
    BEGIN
        IF OLD.status = 'pending' AND NEW.status = 'approved' THEN
            UPDATE adviser_profiles
            SET current_advisee_count = current_advisee_count + 1
            WHERE adviser_id = NEW.adviser_id;
        ELSEIF OLD.status = 'approved' AND NEW.status IN ('declined', 'pending') THEN
            UPDATE adviser_profiles
            SET current_advisee_count = GREATEST(current_advisee_count - 1, 0)
            WHERE adviser_id = NEW.adviser_id;
        END IF;
    END
    """,
    """
    CREATE TRIGGER trg_milestones_before_update
    BEFORE UPDATE ON milestones
    FOR EACH ROW
    BEGIN
        IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
            SET NEW.completed_date = CURDATE();
        ELSEIF NEW.status != 'completed' AND OLD.status = 'completed' THEN
            SET NEW.completed_date = NULL;
        END IF;
    END
    """,
    """
    CREATE TRIGGER trg_bookings_after_insert_stats
    AFTER INSERT ON bookings
    FOR EACH ROW
    BEGIN
        INSERT INTO daily_consultation_stats (stat_date, adviser_id, total_bookings)
        VALUES (NEW.slot_date, NEW.adviser_id, 1)
        ON DUPLICATE KEY UPDATE total_bookings = total_bookings + 1;
    END
    """,
    """
    CREATE TRIGGER trg_bookings_after_update_stats
    AFTER UPDATE ON bookings
    FOR EACH ROW
    BEGIN
        IF OLD.status != NEW.status THEN
            CASE NEW.status
                WHEN 'completed' THEN
                    UPDATE daily_consultation_stats
                    SET completed = completed + 1
                    WHERE stat_date = NEW.slot_date AND adviser_id = NEW.adviser_id;
                WHEN 'cancelled' THEN
                    UPDATE daily_consultation_stats
                    SET cancelled = cancelled + 1
                    WHERE stat_date = NEW.slot_date AND adviser_id = NEW.adviser_id;
            END CASE;
        END IF;
    END
    """,
]

# Stored procedures
STORED_PROCEDURES = [
    """
    CREATE PROCEDURE sp_clean_login_history(IN months_to_keep INT)
    BEGIN
        DECLARE rows_deleted INT DEFAULT 0;
        DELETE FROM login_history WHERE created_at < DATE_SUB(NOW(), INTERVAL months_to_keep MONTH);
        SET rows_deleted = ROW_COUNT();
        SELECT rows_deleted AS deleted_rows;
    END
    """,
    """
    CREATE PROCEDURE sp_clean_audit_logs(IN months_to_keep INT)
    BEGIN
        DECLARE rows_deleted INT DEFAULT 0;
        DELETE FROM audit_logs WHERE created_at < DATE_SUB(NOW(), INTERVAL months_to_keep MONTH);
        SET rows_deleted = ROW_COUNT();
        SELECT rows_deleted AS deleted_rows;
    END
    """,
    """
    CREATE PROCEDURE sp_adviser_workload(IN adviser_id INT)
    BEGIN
        SELECT p.max_capacity, p.current_advisee_count,
               (p.max_capacity - p.current_advisee_count) AS slots_available,
               COUNT(DISTINCT a.application_id) AS total_applications,
               COUNT(DISTINCT CASE WHEN a.status = 'approved' THEN a.application_id END) AS approved_applications,
               COUNT(DISTINCT b.booking_id) AS upcoming_bookings,
               COUNT(DISTINCT CASE WHEN b.status = 'completed' THEN b.booking_id END) AS completed_consultations
        FROM adviser_profiles p
        LEFT JOIN applications a ON a.adviser_id = p.adviser_id
        LEFT JOIN bookings b ON b.adviser_id = p.adviser_id AND b.slot_date >= CURDATE()
        WHERE p.adviser_id = adviser_id
        GROUP BY p.adviser_id;
    END
    """,
    """
    CREATE PROCEDURE sp_log_backup_start(
        IN p_type ENUM('full', 'incremental', 'schema_only'),
        IN p_file_path VARCHAR(500),
        IN p_tables TEXT
    )
    BEGIN
        INSERT INTO backup_log (backup_type, file_path, tables_included, started_at, status)
        VALUES (p_type, p_file_path, p_tables, NOW(), 'running');
        SELECT LAST_INSERT_ID() AS backup_id;
    END
    """,
    """
    CREATE PROCEDURE sp_log_backup_complete(
        IN p_backup_id INT,
        IN p_file_size BIGINT,
        IN p_checksum VARCHAR(64),
        IN p_status ENUM('completed', 'failed'),
        IN p_error TEXT
    )
    BEGIN
        UPDATE backup_log
        SET file_size_bytes = p_file_size,
            checksum = p_checksum,
            completed_at = NOW(),
            status = p_status,
            error_message = p_error
        WHERE backup_id = p_backup_id;
    END
    """,
]


def _index_exists(conn, index_name: str) -> bool:
    row = conn.execute(
        text("SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND INDEX_NAME = :name"),
        {"name": index_name},
    ).first()
    return bool(row and row[0] > 0)


def _constraint_exists(conn, constraint_name: str) -> bool:
    row = conn.execute(
        text("SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA = DATABASE() AND CONSTRAINT_NAME = :name"),
        {"name": constraint_name},
    ).first()
    return bool(row and row[0] > 0)


def _trigger_exists(conn, trigger_name: str) -> bool:
    row = conn.execute(
        text("SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = DATABASE() AND TRIGGER_NAME = :name"),
        {"name": trigger_name},
    ).first()
    return bool(row and row[0] > 0)


def _procedure_exists(conn, proc_name: str) -> bool:
    row = conn.execute(
        text("SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_NAME = :name"),
        {"name": proc_name},
    ).first()
    return bool(row and row[0] > 0)


def _view_exists(conn, view_name: str) -> bool:
    row = conn.execute(
        text("SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :name"),
        {"name": view_name},
    ).first()
    return bool(row and row[0] > 0)


def backfill_existing_student_profiles(conn) -> None:
    conn.execute(
        text(
            "UPDATE users u SET thesis_title = ("
            " SELECT TRIM(a.topic_brief) FROM applications a "
            " WHERE a.student_id = u.user_id "
            " AND CHAR_LENGTH(TRIM(COALESCE(a.topic_brief, ''))) >= 10 "
            " ORDER BY (a.status = 'approved') DESC, (a.status = 'pending') DESC, "
            " a.date_submitted DESC, a.application_id DESC LIMIT 1"
            ") WHERE u.role = 'student' "
            "AND COALESCE(u.student_group_role, 'leader') = 'leader' "
            "AND (u.thesis_title IS NULL OR CHAR_LENGTH(TRIM(u.thesis_title)) < 10) "
            "AND EXISTS (SELECT 1 FROM applications a WHERE a.student_id = u.user_id "
            " AND CHAR_LENGTH(TRIM(COALESCE(a.topic_brief, ''))) >= 10)"
        )
    )
    conn.execute(
        text(
            "UPDATE users u SET student_group_role = 'member' "
            "WHERE u.role = 'student' AND u.student_group_role IS NULL "
            "AND EXISTS (SELECT 1 FROM application_groups g "
            " WHERE g.student_id = u.user_id AND g.is_leader = 0) "
            "AND NOT EXISTS (SELECT 1 FROM application_groups g "
            " WHERE g.student_id = u.user_id AND g.is_leader = 1)"
        )
    )
    conn.execute(
        text(
            "UPDATE users u SET thesis_title = ("
            " SELECT COALESCE(NULLIF(TRIM(leader.thesis_title), ''), NULLIF(TRIM(a.topic_brief), '')) "
            " FROM application_groups g "
            " JOIN applications a ON a.application_id = g.application_id "
            " JOIN users leader ON leader.user_id = a.student_id "
            " WHERE g.student_id = u.user_id AND g.is_leader = 0 "
            " AND CHAR_LENGTH(TRIM(COALESCE(NULLIF(leader.thesis_title, ''), a.topic_brief, ''))) >= 10 "
            " ORDER BY (a.status = 'approved') DESC, a.date_submitted DESC, "
            " a.application_id DESC LIMIT 1"
            ") WHERE u.role = 'student' AND u.student_group_role = 'member' "
            "AND (u.thesis_title IS NULL OR CHAR_LENGTH(TRIM(u.thesis_title)) < 10) "
            "AND EXISTS (SELECT 1 FROM application_groups g "
            " WHERE g.student_id = u.user_id AND g.is_leader = 0)"
        )
    )
    conn.execute(
        text(
            "UPDATE users member "
            "JOIN student_group_requests r ON r.member_id = member.user_id AND r.status = 'approved' "
            "JOIN users leader ON leader.user_id = r.leader_id "
            "SET member.student_group_role = 'member' "
            "WHERE member.role = 'student' AND member.student_group_role IS NULL "
            "AND CHAR_LENGTH(TRIM(COALESCE(leader.thesis_title, ''))) >= 10 "
            "AND NOT EXISTS (SELECT 1 FROM application_groups g "
            " WHERE g.student_id = member.user_id AND g.is_leader = 1)"
        )
    )
    conn.execute(
        text(
            "UPDATE users member "
            "JOIN student_group_requests r ON r.member_id = member.user_id AND r.status = 'approved' "
            "JOIN users leader ON leader.user_id = r.leader_id "
            "SET member.thesis_title = TRIM(leader.thesis_title) "
            "WHERE member.role = 'student' AND member.student_group_role = 'member' "
            "AND (member.thesis_title IS NULL OR CHAR_LENGTH(TRIM(member.thesis_title)) < 10) "
            "AND CHAR_LENGTH(TRIM(COALESCE(leader.thesis_title, ''))) >= 10"
        )
    )


def ensure_schema(engine) -> None:
    with engine.begin() as conn:
        # Create tables
        for ddl in NEW_TABLES:
            conn.execute(text(ddl))

        # Add columns after new tables exist, including columns on Sprint 2 tables.
        for table, column, definition in NEW_COLUMNS:
            if not _column_exists(conn, table, column):
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {definition}"))

        conn.execute(
            text(
                "UPDATE messages SET delivered_at = created_at "
                "WHERE delivered_at IS NULL AND is_read = 1"
            )
        )
        conn.execute(
            text(
                "UPDATE messages SET read_at = created_at "
                "WHERE read_at IS NULL AND is_read = 1"
            )
        )

        if not _foreign_key_exists(conn, "documents", "task_comment_id", "task_comments", "comment_id"):
            conn.execute(
                text(
                    "ALTER TABLE documents ADD CONSTRAINT fk_documents_task_comment "
                    "FOREIGN KEY (task_comment_id) REFERENCES task_comments(comment_id) ON DELETE SET NULL"
                )
            )

        if not _column_exists(conn, "bookings", "leader_accepted"):
            conn.execute(
                text("ALTER TABLE bookings ADD COLUMN leader_accepted TINYINT(1) NOT NULL DEFAULT 0")
            )
            conn.execute(
                text(
                    "UPDATE bookings SET leader_accepted = 1 WHERE status = 'confirmed' "
                    "AND (slot_date < CURDATE() OR (slot_date = CURDATE() AND start_time < CURTIME()))"
                )
            )

        conn.execute(
            text(
                "INSERT INTO application_groups (application_id, student_id, is_leader) "
                "SELECT a.application_id, a.student_id, 1 FROM applications a "
                "JOIN users u ON u.user_id = a.student_id "
                "WHERE a.status = 'approved' AND COALESCE(u.student_group_role, 'leader') = 'leader' "
                "ON DUPLICATE KEY UPDATE is_leader = 1"
            )
        )
        backfill_existing_student_profiles(conn)

        # Fix meeting_type nullable
        if not _is_nullable(conn, "bookings", "meeting_type"):
            conn.execute(text("ALTER TABLE bookings MODIFY meeting_type ENUM('online','in-person') NULL DEFAULT NULL"))
            conn.execute(text("UPDATE bookings SET meeting_type = NULL WHERE location IS NULL"))

        # Add performance indexes
        for idx_sql in PERFORMANCE_INDEXES:
            try:
                conn.execute(text(idx_sql))
            except Exception:
                pass  # Index may already exist

        # Add check constraints
        for constraint_sql in CHECK_CONSTRAINTS:
            try:
                conn.execute(text(constraint_sql))
            except Exception:
                pass  # Constraint may already exist

        # Create views
        for view_sql in VIEWS:
            try:
                conn.execute(text(view_sql))
            except Exception:
                pass  # View may already exist

        # Create triggers (need to handle delimiter)
        for trigger_sql in TRIGGERS:
            trigger_name = trigger_sql.split()[2].strip('`"')
            if not _trigger_exists(conn, trigger_name):
                try:
                    conn.execute(text(trigger_sql))
                except Exception as e:
                    # Trigger creation might fail due to delimiter issues
                    print(f"Trigger {trigger_name} creation skipped: {e}")

        # Create stored procedures
        for proc_sql in STORED_PROCEDURES:
            proc_name = proc_sql.split()[2].split('(')[0].strip('`"')
            if not _procedure_exists(conn, proc_name):
                try:
                    conn.execute(text(proc_sql))
                except Exception as e:
                    print(f"Procedure {proc_name} creation skipped: {e}")
