-- =====================================================================
-- AdviserLink Database Schema
-- Sprint 1 — Feature 3: Tech Stack Setup & Database Schema Design
-- Import this file directly in phpMyAdmin (Import tab) or run it in
-- the SQL tab after creating an empty database named `adviserlink_db`.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS adviserlink_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE adviserlink_db;

-- ---------------------------------------------------------------------
-- USERS
-- Holds every account: students, advisers, and admin.
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id         INT AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(100)  NOT NULL,
    email           VARCHAR(100)  NOT NULL UNIQUE,
    password        VARCHAR(255)  NOT NULL,          -- store a bcrypt/password_hash(), never plain text
    role            ENUM('student', 'adviser', 'admin') NOT NULL,
    student_group_role ENUM('leader','member') NULL DEFAULT NULL,
    research_interests VARCHAR(500) NULL,
    thesis_title    VARCHAR(500) NULL,
    title_setup_required TINYINT(1) NOT NULL DEFAULT 0,
    contact_number  VARCHAR(20),
    account_status  ENUM('active','pending','disabled') NOT NULL DEFAULT 'active',  -- Sprint 3: adviser ay pending hanggang i-approve ng admin
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- ADVISER_PROFILES
-- One row per adviser; adviser_id is both PK and FK to users.
-- ---------------------------------------------------------------------
CREATE TABLE adviser_profiles (
    adviser_id              INT PRIMARY KEY,
    department              VARCHAR(120) NULL,
    specialization_tags     TEXT,                    -- comma-separated or JSON list of tags
    certifications          TEXT,
    max_capacity            INT DEFAULT 10,
    current_advisee_count   INT DEFAULT 0,
    FOREIGN KEY (adviser_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- APPLICATIONS
-- A student's request to be advised by a specific adviser.
-- ---------------------------------------------------------------------
CREATE TABLE applications (
    application_id   INT AUTO_INCREMENT PRIMARY KEY,
    student_id       INT NOT NULL,
    adviser_id       INT NOT NULL,
    topic_brief      TEXT NOT NULL,
    status           ENUM('pending', 'approved', 'declined') DEFAULT 'pending',
    date_submitted   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (adviser_id) REFERENCES adviser_profiles(adviser_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- AVAILABILITY
-- Time windows an adviser has opened up for consultation.
-- ---------------------------------------------------------------------
CREATE TABLE availability (
    availability_id  INT AUTO_INCREMENT PRIMARY KEY,
    adviser_id       INT NOT NULL,
    day_of_week      ENUM('Mon','Tue','Wed','Thu','Fri','Sat','Sun') NULL,
    specific_date    DATE NULL,                       -- use this OR day_of_week depending on your design
    start_time       TIME NOT NULL,
    end_time         TIME NOT NULL,
    FOREIGN KEY (adviser_id) REFERENCES adviser_profiles(adviser_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- BOOKINGS
-- A confirmed consultation slot. Only created from an approved application.
-- ---------------------------------------------------------------------
CREATE TABLE bookings (
    booking_id       INT AUTO_INCREMENT PRIMARY KEY,
    application_id   INT NOT NULL,
    student_id       INT NOT NULL,
    adviser_id       INT NOT NULL,
    slot_date        DATE NOT NULL,
    start_time       TIME NOT NULL,
    end_time         TIME NOT NULL,
    status           ENUM('confirmed', 'cancelled', 'completed') DEFAULT 'confirmed',
    meeting_type     ENUM('online','in-person') NULL DEFAULT NULL,  -- Sprint 2: ang adviser ang nagse-set
    location         VARCHAR(255) NULL,
    notes            TEXT NULL,
    cancel_reason    TEXT NULL,
    cancelled_by     INT NULL,
    reminded         TINYINT(1) NOT NULL DEFAULT 0,
    leader_accepted  TINYINT(1) NOT NULL DEFAULT 0,
    FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE,
    FOREIGN KEY (student_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (adviser_id) REFERENCES adviser_profiles(adviser_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- PROGRESS_LOGS
-- Adviser's notes/remarks logged after each consultation.
-- ---------------------------------------------------------------------
CREATE TABLE progress_logs (
    log_id         INT AUTO_INCREMENT PRIMARY KEY,
    booking_id     INT NOT NULL,
    stage_status   VARCHAR(100),                     -- e.g. "Chapter 1 draft", "Revision", "Defense-ready"
    remarks        TEXT,
    date_logged    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- RATINGS
-- One rating per completed booking.
-- ---------------------------------------------------------------------
CREATE TABLE ratings (
    rating_id       INT AUTO_INCREMENT PRIMARY KEY,
    booking_id      INT NOT NULL UNIQUE,
    score           TINYINT NOT NULL CHECK (score BETWEEN 1 AND 5),
    feedback_text   TEXT,
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- NOTIFICATIONS
-- SMS / in-app messages sent to a user.
-- ---------------------------------------------------------------------
CREATE TABLE notifications (
    notification_id  INT AUTO_INCREMENT PRIMARY KEY,
    user_id          INT NOT NULL,
    message          TEXT NOT NULL,
    type             ENUM('SMS', 'in-app') DEFAULT 'in-app',
    is_read          TINYINT(1) NOT NULL DEFAULT 0,  -- Sprint 2
    related_user_id  INT NULL,
    related_application_id INT NULL,
    related_message_id INT NULL,
    date_sent        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE chat_presence (
    application_id  INT NOT NULL,
    user_id         INT NOT NULL,
    last_active_at  DATETIME NOT NULL,
    typing_until    DATETIME NULL,
    PRIMARY KEY (application_id, user_id),
    FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;


-- ---------------------------------------------------------------------
-- SPRINT 2 TABLES
-- (Kung naka-import na ang Sprint 1, hindi mo kailangang i-import ito ulit:
--  awtomatiko itong idinadagdag ng API pagka-start.)
-- ---------------------------------------------------------------------
CREATE TABLE kanban_tasks (
    task_id         INT AUTO_INCREMENT PRIMARY KEY,
    application_id  INT NOT NULL,
    title           VARCHAR(150) NOT NULL,
    description     TEXT,
    status          ENUM('todo','in_progress','review','done') NOT NULL DEFAULT 'todo',
    points          TINYINT NOT NULL DEFAULT 1,
    created_by      INT NOT NULL,
    created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE task_comments (
    comment_id   INT AUTO_INCREMENT PRIMARY KEY,
    task_id      INT NOT NULL,
    author_id    INT NOT NULL,
    body         TEXT NOT NULL,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (task_id) REFERENCES kanban_tasks(task_id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE documents (
    document_id     INT AUTO_INCREMENT PRIMARY KEY,
    application_id  INT NOT NULL,
    booking_id      INT NULL,
    uploaded_by     INT NOT NULL,
    filename        VARCHAR(255) NOT NULL,
    stored_name     VARCHAR(100) NOT NULL,
    size_bytes      INT NOT NULL DEFAULT 0,
    category        ENUM('todo','in_progress','review','done') NOT NULL DEFAULT 'todo',  -- saang column ng board in-upload
    task_id         INT NULL,
    task_comment_id INT NULL,
    uploaded_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (application_id) REFERENCES applications(application_id) ON DELETE CASCADE,
    FOREIGN KEY (booking_id) REFERENCES bookings(booking_id) ON DELETE SET NULL,
    FOREIGN KEY (task_id) REFERENCES kanban_tasks(task_id) ON DELETE SET NULL,
    FOREIGN KEY (task_comment_id) REFERENCES task_comments(comment_id) ON DELETE SET NULL,
    FOREIGN KEY (uploaded_by) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;


-- Sprint 3: rating at feedback ng student pagkatapos ng consultation
CREATE TABLE consultation_ratings (
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
) ENGINE=InnoDB;

-- =====================================================================
-- DUMMY / SEED DATA — for Step 3.7 (testing that relationships work)
-- =====================================================================

-- Users: 1 student, 1 adviser, 1 admin
-- Password for all demo accounts: test1234 (bcrypt hashed)
-- Run seed_demo_users.py to add more demo data after import
INSERT INTO users (name, email, password, role, contact_number, account_status, email_verified) VALUES
('Juan Dela Cruz', 'juan.delacruz@isu.edu.ph', '$2b$12$8/8QT2et3sRgKTtFfJfFzenIyq6xrhvMV1N.0/5GRuCqR6ZN38S5q', 'student', '09171234567', 'active', 1),
('Engr. Maria Santos', 'maria.santos@isu.edu.ph', '$2b$12$8/8QT2et3sRgKTtFfJfFzenIyq6xrhvMV1N.0/5GRuCqR6ZN38S5q', 'adviser', '09179876543', 'active', 1),
('Admin Account', 'admin@isu.edu.ph', '$2b$12$8/8QT2et3sRgKTtFfJfFzenIyq6xrhvMV1N.0/5GRuCqR6ZN38S5q', 'admin', '09170000000', 'active', 1);

-- Adviser profile for Maria Santos (user_id = 2)
INSERT INTO adviser_profiles (adviser_id, specialization_tags, certifications, max_capacity) VALUES
(2, 'web development, database design, PHP', 'CCPE, MSIT', 10);

-- Sample application from Juan (user_id = 1) to Maria (adviser_id = 2)
INSERT INTO applications (student_id, adviser_id, topic_brief, status) VALUES
(1, 2, 'Online ordering system for local restaurants using PHP and MySQL', 'pending');

-- Sample availability slot for Maria
INSERT INTO availability (adviser_id, day_of_week, start_time, end_time) VALUES
(2, 'Mon', '13:00:00', '15:00:00');

-- To test the booking flow, first approve the application, then insert a booking:
-- UPDATE applications SET status = 'approved' WHERE application_id = 1;
-- INSERT INTO bookings (application_id, student_id, adviser_id, slot_date, start_time, end_time)
-- VALUES (1, 1, 2, '2026-10-06', '13:00:00', '13:30:00');
