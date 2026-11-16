-- =====================================================================
-- AdviserLink Database User Roles & Privileges
-- Run this as root/MySQL admin AFTER importing schema.sql and enhanced_schema.sql
-- =====================================================================

USE adviserlink_db;

-- ---------------------------------------------------------
-- 1. Application User (for the Python/FastAPI backend)
-- Has DML access but no DDL (no CREATE/DROP/ALTER)
-- ---------------------------------------------------------
-- IMPORTANT: Change 'strong_random_password' to a secure random password
CREATE USER IF NOT EXISTS 'adviserlink_app'@'%' IDENTIFIED BY 'strong_random_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON adviserlink_db.* TO 'adviserlink_app'@'%';
GRANT EXECUTE ON adviserlink_db.* TO 'adviserlink_app'@'%';

-- ---------------------------------------------------------
-- 2. Read-Only User (for reporting/analytics dashboards)
-- Only SELECT access to all tables and views
-- ---------------------------------------------------------
-- IMPORTANT: Change 'another_strong_password' to a secure random password
CREATE USER IF NOT EXISTS 'adviserlink_readonly'@'%' IDENTIFIED BY 'another_strong_password';
GRANT SELECT ON adviserlink_db.* TO 'adviserlink_readonly'@'%';

-- ---------------------------------------------------------
-- 3. Backup User (for automated backup scripts/mysqldump)
-- Needs SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER
-- ---------------------------------------------------------
-- IMPORTANT: Change 'backup_password' to a secure random password
CREATE USER IF NOT EXISTS 'adviserlink_backup'@'%' IDENTIFIED BY 'backup_password';
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON adviserlink_db.* TO 'adviserlink_backup'@'%';

-- ---------------------------------------------------------
-- 4. Admin User (for database administration via application)
-- Full access including DDL (CREATE/DROP/ALTER)
-- ---------------------------------------------------------
-- IMPORTANT: Change 'admin_strong_password' to a secure random password
CREATE USER IF NOT EXISTS 'adviserlink_admin'@'%' IDENTIFIED BY 'admin_strong_password';
GRANT ALL PRIVILEGES ON adviserlink_db.* TO 'adviserlink_admin'@'%';

-- ---------------------------------------------------------
-- Apply privilege changes
-- ---------------------------------------------------------
FLUSH PRIVILEGES;

-- ---------------------------------------------------------
-- Verification: Check created users and their privileges
-- ---------------------------------------------------------
SELECT User, Host FROM mysql.user WHERE User LIKE 'adviserlink_%';
SHOW GRANTS FOR 'adviserlink_app'@'%';
SHOW GRANTS FOR 'adviserlink_readonly'@'%';
SHOW GRANTS FOR 'adviserlink_backup'@'%';
SHOW GRANTS FOR 'adviserlink_admin'@'%';

-- =====================================================================
-- USAGE NOTES:
-- =====================================================================
-- 1. Replace all placeholder passwords with strong random strings before running
--    Generate with: openssl rand -base64 32
-- 2. For production, restrict @'%' to specific IPs/hosts (e.g., @'192.168.1.%')
-- 3. The application should use 'adviserlink_app' in DATABASE_URL
-- 4. Read-only user is for external reporting tools (Metabase, Grafana, etc.)
-- 5. Backup user is for mysqldump automated scripts
-- 6. Admin user is for emergency manual database administration
-- =====================================================================