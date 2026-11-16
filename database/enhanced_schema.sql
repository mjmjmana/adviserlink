-- =====================================================================
-- AdviserLink Enhanced Database Schema
-- Adds: Login History, Audit Logs, Triggers, Indexes, Encryption,
--       Domain Constraints, Optimization, Recovery/Backup support
-- =====================================================================

USE adviserlink_db;

-- =====================================================================
-- 1. LOGIN HISTORY TABLE
-- Tracks all login attempts for security auditing
-- =====================================================================
CREATE TABLE IF NOT EXISTS login_history (
    login_id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id           INT NULL,
    email_attempted   VARCHAR(100) NOT NULL,
    ip_address        VARCHAR(45) NOT NULL,
    user_agent        TEXT,
    success           TINYINT(1) NOT NULL DEFAULT 0,
    failure_reason    VARCHAR(100) NULL,  -- 'invalid_password', 'account_locked', 'not_verified', 'inactive', 'not_found'
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_login_history_user (user_id),
    INDEX idx_login_history_email (email_attempted),
    INDEX idx_login_history_ip (ip_address),
    INDEX idx_login_history_created (created_at),
    INDEX idx_login_history_success (success)
) ENGINE=InnoDB;

-- =====================================================================
-- 2. ENHANCED AUDIT LOGS (extends existing admin_audit_log)
-- Comprehensive audit trail for all sensitive operations
-- =====================================================================
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
) ENGINE=InnoDB;

-- Project-group join requests submitted by students and reviewed by the group leader
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
) ENGINE=InnoDB;

-- Student group requests also support leaders who have not yet been assigned an adviser
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
) ENGINE=InnoDB;

-- =====================================================================
-- 3. DATABASE USER ROLES & PRIVILEGES
-- Separate database users with limited privileges
-- =====================================================================
-- Run these as root/MySQL admin:
-- CREATE USER 'adviserlink_app'@'%' IDENTIFIED BY 'strong_random_password';
-- GRANT SELECT, INSERT, UPDATE, DELETE ON adviserlink_db.* TO 'adviserlink_app'@'%';
-- GRANT EXECUTE ON adviserlink_db.* TO 'adviserlink_app'@'%';
--
-- CREATE USER 'adviserlink_readonly'@'%' IDENTIFIED BY 'another_strong_password';
-- GRANT SELECT ON adviserlink_db.* TO 'adviserlink_readonly'@'%';
--
-- CREATE USER 'adviserlink_backup'@'%' IDENTIFIED BY 'backup_password';
-- GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON adviserlink_db.* TO 'adviserlink_backup'@'%';
-- FLUSH PRIVILEGES;

-- =====================================================================
-- 4. DOMAIN CONSTRAINTS & CHECK CONSTRAINTS
-- Add validation at database level
-- =====================================================================

-- Users table enhancements
ALTER TABLE users
    ADD CONSTRAINT chk_users_email_format
    CHECK (email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'),
    ADD CONSTRAINT chk_users_contact_format
    CHECK (contact_number IS NULL OR contact_number REGEXP '^[0-9+\\-\\s()]{7,20}$'),
    ADD CONSTRAINT chk_users_name_length
    CHECK (CHAR_LENGTH(name) >= 2 AND CHAR_LENGTH(name) <= 100);

-- Applications enhancements
ALTER TABLE applications
    ADD CONSTRAINT chk_applications_topic_length
    CHECK (CHAR_LENGTH(topic_brief) >= 10 AND CHAR_LENGTH(topic_brief) <= 2000);

-- Adviser profiles enhancements
ALTER TABLE adviser_profiles
    ADD CONSTRAINT chk_adviser_capacity
    CHECK (max_capacity >= 1 AND max_capacity <= 50),
    ADD CONSTRAINT chk_adviser_current_count
    CHECK (current_advisee_count >= 0 AND current_advisee_count <= max_capacity);

-- Bookings enhancements
ALTER TABLE bookings
    ADD CONSTRAINT chk_bookings_time_order
    CHECK (end_time > start_time),
    ADD CONSTRAINT chk_bookings_slot_future
    CHECK (slot_date >= DATE_SUB(CURDATE(), INTERVAL 1 DAY)); -- Allow same-day bookings

-- Ratings enhancements
ALTER TABLE consultation_ratings
    ADD CONSTRAINT chk_ratings_stars
    CHECK (stars BETWEEN 1 AND 5);

-- =====================================================================
-- 5. PERFORMANCE INDEXES (Optimization)
-- =====================================================================

-- Users indexes
CREATE INDEX idx_users_email_lower ON users (LOWER(email));
CREATE INDEX idx_users_role_status ON users (role, account_status);
CREATE INDEX idx_users_created ON users (created_at);

-- Applications indexes
CREATE INDEX idx_applications_student_status ON applications (student_id, status);
CREATE INDEX idx_applications_adviser_status ON applications (adviser_id, status);
CREATE INDEX idx_applications_date_submitted ON applications (date_submitted);

-- Bookings indexes
CREATE INDEX idx_bookings_adviser_date_status ON bookings (adviser_id, slot_date, status);
CREATE INDEX idx_bookings_student_date_status ON bookings (student_id, slot_date, status);
CREATE INDEX idx_bookings_application ON bookings (application_id);
CREATE INDEX idx_bookings_date_range ON bookings (slot_date, start_time);

-- Availability indexes
CREATE INDEX idx_availability_adviser_date ON availability (adviser_id, specific_date, day_of_week);

-- Notifications indexes
CREATE INDEX idx_notifications_user_read ON notifications (user_id, is_read);
CREATE INDEX idx_notifications_created ON notifications (date_sent);

-- Documents indexes
CREATE INDEX idx_documents_application ON documents (application_id);
CREATE INDEX idx_documents_booking ON documents (booking_id);

-- Kanban tasks indexes
CREATE INDEX idx_kanban_tasks_application ON kanban_tasks (application_id);
CREATE INDEX idx_kanban_tasks_status ON kanban_tasks (status);

-- Messages indexes
CREATE INDEX idx_messages_application ON messages (application_id);
CREATE INDEX idx_messages_created ON messages (created_at);

-- Milestones indexes
CREATE INDEX idx_milestones_application ON milestones (application_id);
CREATE INDEX idx_milestones_due_date ON milestones (due_date);
CREATE INDEX idx_milestones_status ON milestones (status);

-- Waitlist indexes
CREATE INDEX idx_waitlist_adviser_status ON waitlist (adviser_id, status);
CREATE INDEX idx_waitlist_student_status ON waitlist (student_id, status);

-- Document versions indexes
CREATE INDEX idx_document_versions_document ON document_versions (document_id);

-- Availability exceptions indexes
CREATE INDEX idx_availability_exceptions_adviser_date ON availability_exceptions (adviser_id, specific_date);

-- Application groups indexes
CREATE INDEX idx_application_groups_application ON application_groups (application_id);

-- Admin audit log indexes
CREATE INDEX idx_admin_audit_log_admin ON admin_audit_log (admin_id);
CREATE INDEX idx_admin_audit_log_created ON admin_audit_log (created_at);

-- New indexes for login_history
CREATE INDEX idx_login_history_user_created ON login_history (user_id, created_at);
CREATE INDEX idx_login_history_ip_created ON login_history (ip_address, created_at);

-- New indexes for audit_logs
CREATE INDEX idx_audit_logs_user_created ON audit_logs (user_id, created_at);
CREATE INDEX idx_audit_logs_target_created ON audit_logs (target_type, target_id, created_at);

-- =====================================================================
-- 6. TRIGGERS
-- Automated audit logging and data integrity
-- =====================================================================

DELIMITER $$

-- Trigger: Log user creation
CREATE TRIGGER trg_users_after_insert
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, action, target_type, target_id, new_values, created_at)
    VALUES (NEW.user_id, 'CREATE', 'user', NEW.user_id,
            JSON_OBJECT('name', NEW.name, 'email', NEW.email, 'role', NEW.role, 'account_status', NEW.account_status),
            NOW());
END$$

-- Trigger: Log user updates
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
END$$

-- Trigger: Log user deletion
CREATE TRIGGER trg_users_before_delete
BEFORE DELETE ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, action, target_type, target_id, old_values, created_at)
    VALUES (OLD.user_id, 'DELETE', 'user', OLD.user_id,
            JSON_OBJECT('name', OLD.name, 'email', OLD.email, 'role', OLD.role),
            NOW());
END$$

-- Trigger: Log application status changes
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
    END IF
END$$

-- Trigger: Log booking creation/modification
CREATE TRIGGER trg_bookings_after_insert
AFTER INSERT ON bookings
FOR EACH ROW
BEGIN
    INSERT INTO audit_logs (user_id, action, target_type, target_id, new_values, created_at)
    VALUES (NEW.student_id, 'CREATE', 'booking', NEW.booking_id,
            JSON_OBJECT('application_id', NEW.application_id, 'adviser_id', NEW.adviser_id,
                       'slot_date', NEW.slot_date, 'start_time', NEW.start_time, 'end_time', NEW.end_time),
            NOW());
END$$

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
END$$

-- Trigger: Maintain adviser capacity count
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
    ELSEIF OLD.status = 'approved' AND NEW.status = 'declined' THEN
        UPDATE adviser_profiles
        SET current_advisee_count = GREATEST(current_advisee_count - 1, 0)
        WHERE adviser_id = NEW.adviser_id;
    END IF;
END$$

-- Trigger: Auto-set completed_date for milestones
CREATE TRIGGER trg_milestones_before_update
BEFORE UPDATE ON milestones
FOR EACH ROW
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        SET NEW.completed_date = CURDATE();
    ELSEIF NEW.status != 'completed' AND OLD.status = 'completed' THEN
        SET NEW.completed_date = NULL;
    END IF;
END$$

-- Trigger: Validate capacity before approving application
CREATE TRIGGER trg_applications_before_approve
BEFORE UPDATE ON applications
FOR EACH ROW
BEGIN
    IF NEW.status = 'approved' AND OLD.status = 'pending' THEN
        DECLARE current_count INT;
        DECLARE max_cap INT;
        SELECT current_advisee_count, max_capacity INTO current_count, max_cap
        FROM adviser_profiles WHERE adviser_id = NEW.adviser_id;
        IF current_count >= max_cap THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Adviser has reached maximum capacity';
        END IF;
    END IF;
END$$

DELIMITER ;

-- =====================================================================
-- 7. ENCRYPTION SUPPORT
-- Column-level encryption for sensitive data
-- =====================================================================

-- Add encrypted columns for sensitive data (application-level encryption keys)
ALTER TABLE users
    ADD COLUMN encrypted_contact VARBINARY(512) NULL COMMENT 'AES-256 encrypted contact number',
    ADD COLUMN encryption_iv VARBINARY(16) NULL COMMENT 'IV used for encryption';

-- Encryption helper functions (use with application-managed keys)
-- Example usage in application:
-- ENCRYPT: AES_ENCRYPT(contact_number, UNHEX(SHA2('your_app_encryption_key', 256)), @iv)
-- DECRYPT: AES_DECRYPT(encrypted_contact, UNHEX(SHA2('your_app_encryption_key', 256)), @iv)

-- =====================================================================
-- 8. VIEWS FOR COMMON QUERIES (Optimization - Vertical Partitioning)
-- =====================================================================

-- View: Active users with minimal columns (for listings)
CREATE OR REPLACE VIEW v_active_users AS
SELECT user_id, name, email, role, account_status, created_at
FROM users
WHERE account_status = 'active';

-- View: Adviser search optimized
CREATE OR REPLACE VIEW v_adviser_search AS
SELECT u.user_id, u.name, u.email, p.specialization_tags, p.certifications,
       p.max_capacity, p.current_advisee_count,
       (p.max_capacity - p.current_advisee_count) AS slots_left
FROM users u
JOIN adviser_profiles p ON p.adviser_id = u.user_id
WHERE u.role = 'adviser' AND u.account_status = 'active';

-- View: Student applications with adviser info
CREATE OR REPLACE VIEW v_student_applications AS
SELECT a.application_id, a.student_id, a.adviser_id, a.topic_brief, a.status, a.date_submitted,
       ad.name AS adviser_name, ad.email AS adviser_email
FROM applications a
JOIN users ad ON ad.user_id = a.adviser_id;

-- View: Upcoming bookings
CREATE OR REPLACE VIEW v_upcoming_bookings AS
SELECT b.booking_id, b.application_id, b.student_id, b.adviser_id, b.slot_date, b.start_time, b.end_time,
       b.status, b.meeting_type, b.location, b.notes,
       s.name AS student_name, a.name AS adviser_name
FROM bookings b
JOIN users s ON s.user_id = b.student_id
JOIN users a ON a.user_id = b.adviser_id
WHERE b.status = 'confirmed' AND b.slot_date >= CURDATE()
ORDER BY b.slot_date, b.start_time;

-- View: System statistics for admin dashboard
CREATE OR REPLACE VIEW v_system_stats AS
SELECT
    (SELECT COUNT(*) FROM users WHERE role = 'student') AS total_students,
    (SELECT COUNT(*) FROM users WHERE role = 'adviser' AND account_status = 'active') AS active_advisers,
    (SELECT COUNT(*) FROM users WHERE role = 'adviser' AND account_status = 'pending') AS pending_advisers,
    (SELECT COUNT(*) FROM applications WHERE status = 'pending') AS pending_applications,
    (SELECT COUNT(*) FROM bookings WHERE status = 'confirmed' AND slot_date >= CURDATE()) AS upcoming_consultations,
    (SELECT COUNT(*) FROM bookings WHERE status = 'completed') AS completed_consultations;

-- =====================================================================
-- 9. STORED PROCEDURES FOR COMMON OPERATIONS
-- =====================================================================

DELIMITER $$

-- Procedure: Clean old login history (run monthly)
CREATE PROCEDURE sp_clean_login_history(IN months_to_keep INT)
BEGIN
    DECLARE rows_deleted INT DEFAULT 0;
    DELETE FROM login_history
    WHERE created_at < DATE_SUB(NOW(), INTERVAL months_to_keep MONTH);
    SET rows_deleted = ROW_COUNT();
    SELECT rows_deleted AS deleted_rows;
END$$

-- Procedure: Clean old audit logs (run monthly)
CREATE PROCEDURE sp_clean_audit_logs(IN months_to_keep INT)
BEGIN
    DECLARE rows_deleted INT DEFAULT 0;
    DELETE FROM audit_logs
    WHERE created_at < DATE_SUB(NOW(), INTERVAL months_to_keep MONTH);
    SET rows_deleted = ROW_COUNT();
    SELECT rows_deleted AS deleted_rows;
END$$

-- Procedure: Get adviser workload
CREATE PROCEDURE sp_adviser_workload(IN adviser_id INT)
BEGIN
    SELECT
        p.max_capacity,
        p.current_advisee_count,
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
END$$

-- Procedure: Archive old completed bookings (horizontal partitioning simulation)
CREATE PROCEDURE sp_archive_bookings(IN months_to_keep INT)
BEGIN
    -- This would move old bookings to an archive table
    -- For now, just report what would be archived
    SELECT COUNT(*) AS would_archive
    FROM bookings
    WHERE status = 'completed'
    AND slot_date < DATE_SUB(CURDATE(), INTERVAL months_to_keep MONTH);
END$$

DELIMITER ;

-- =====================================================================
-- 10. RECOVERY & BACKUP SUPPORT
-- =====================================================================

-- Backup verification table
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
) ENGINE=InnoDB;

-- Procedure: Log backup start
DELIMITER $$
CREATE PROCEDURE sp_log_backup_start(
    IN p_type ENUM('full', 'incremental', 'schema_only'),
    IN p_file_path VARCHAR(500),
    IN p_tables TEXT
)
BEGIN
    INSERT INTO backup_log (backup_type, file_path, tables_included, started_at, status)
    VALUES (p_type, p_file_path, p_tables, NOW(), 'running');
    SELECT LAST_INSERT_ID() AS backup_id;
END$$

-- Procedure: Log backup completion
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
END$$
DELIMITER ;

-- =====================================================================
-- 11. HORIZONTAL PARTITIONING (by date for large tables)
-- Example: Partition bookings by year (run on MySQL 8.0+)
-- =====================================================================
/*
ALTER TABLE bookings
PARTITION BY RANGE (YEAR(slot_date)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p2026 VALUES LESS THAN (2027),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
*/

-- =====================================================================
-- 12. DENORMALIZATION FOR PERFORMANCE (Optional - Aggregate Tables)
-- =====================================================================

-- Aggregate: Daily consultation counts
CREATE TABLE IF NOT EXISTS daily_consultation_stats (
    stat_date         DATE NOT NULL,
    adviser_id        INT NOT NULL,
    total_bookings    INT DEFAULT 0,
    completed         INT DEFAULT 0,
    cancelled         INT DEFAULT 0,
    no_show           INT DEFAULT 0,
    PRIMARY KEY (stat_date, adviser_id),
    FOREIGN KEY (adviser_id) REFERENCES adviser_profiles(adviser_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Aggregate: Monthly user activity
CREATE TABLE IF NOT EXISTS monthly_user_activity (
    activity_month    DATE NOT NULL, -- First day of month
    user_id           INT NOT NULL,
    logins            INT DEFAULT 0,
    bookings_made     INT DEFAULT 0,
    documents_uploaded INT DEFAULT 0,
    messages_sent     INT DEFAULT 0,
    PRIMARY KEY (activity_month, user_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Trigger to maintain daily stats
DELIMITER $$
CREATE TRIGGER trg_bookings_after_insert_stats
AFTER INSERT ON bookings
FOR EACH ROW
BEGIN
    INSERT INTO daily_consultation_stats (stat_date, adviser_id, total_bookings)
    VALUES (NEW.slot_date, NEW.adviser_id, 1)
    ON DUPLICATE KEY UPDATE total_bookings = total_bookings + 1;
END$$

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
END$$
DELIMITER ;

-- =====================================================================
-- 13. EVENTS FOR AUTOMATED MAINTENANCE (MySQL Event Scheduler)
-- =====================================================================

-- Enable event scheduler: SET GLOBAL event_scheduler = ON;

CREATE EVENT IF NOT EXISTS ev_clean_old_login_history
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
DO
    CALL sp_clean_login_history(12); -- Keep 12 months

CREATE EVENT IF NOT EXISTS ev_clean_old_audit_logs
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 2 DAY
DO
    CALL sp_clean_audit_logs(12); -- Keep 12 months

CREATE EVENT IF NOT EXISTS ev_update_daily_stats
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 HOUR
DO
    -- Recalculate yesterday's stats for accuracy
    INSERT INTO daily_consultation_stats (stat_date, adviser_id, total_bookings, completed, cancelled)
    SELECT
        DATE_SUB(CURDATE(), INTERVAL 1 DAY) as stat_date,
        b.adviser_id,
        COUNT(*) as total_bookings,
        SUM(CASE WHEN b.status = 'completed' THEN 1 ELSE 0 END) as completed,
        SUM(CASE WHEN b.status = 'cancelled' THEN 1 ELSE 0 END) as cancelled
    FROM bookings b
    WHERE b.slot_date = DATE_SUB(CURDATE(), INTERVAL 1 DAY)
    GROUP BY b.adviser_id
    ON DUPLICATE KEY UPDATE
        total_bookings = VALUES(total_bookings),
        completed = VALUES(completed),
        cancelled = VALUES(cancelled);

-- =====================================================================
-- END OF ENHANCED SCHEMA
-- =====================================================================