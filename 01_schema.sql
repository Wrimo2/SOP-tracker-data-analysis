-- ============================================================================
-- SOP COMPLIANCE AND TRAINING TRACKER
-- FILE 1 OF 3: DATABASE SCHEMA CREATION
-- Requires MySQL 8.0+
-- Run this file FIRST before seed data or queries.
-- ============================================================================

DROP DATABASE IF EXISTS sop_tracker;
CREATE DATABASE sop_tracker CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sop_tracker;


-- ============================================================================
-- TABLE DEFINITIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Table 1: employees
-- Stores all personnel across departments
-- ----------------------------------------------------------------------------
CREATE TABLE employees (
    employee_id   INT AUTO_INCREMENT PRIMARY KEY,
    full_name     VARCHAR(120)  NOT NULL,
    department    VARCHAR(50)   NOT NULL,
    designation   VARCHAR(80)   NOT NULL,
    date_of_joining DATE        NOT NULL,
    is_active     TINYINT(1)    NOT NULL DEFAULT 1,

    INDEX idx_emp_dept (department),
    INDEX idx_emp_active (is_active)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 2: sops
-- Master list of Standard Operating Procedures
-- ----------------------------------------------------------------------------
CREATE TABLE sops (
    sop_id        INT AUTO_INCREMENT PRIMARY KEY,
    sop_number    VARCHAR(20)   NOT NULL UNIQUE,
    title         VARCHAR(200)  NOT NULL,
    version       DECIMAL(3,1)  NOT NULL DEFAULT 1.0,
    effective_date DATE         NOT NULL,
    review_due_date DATE        NOT NULL,
    department    VARCHAR(50)   NOT NULL,
    approved_by   VARCHAR(120)  NOT NULL,

    INDEX idx_sop_dept (department),
    INDEX idx_sop_review (review_due_date)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 3: sop_revisions
-- Full version history of every SOP
-- ----------------------------------------------------------------------------
CREATE TABLE sop_revisions (
    revision_id   INT AUTO_INCREMENT PRIMARY KEY,
    sop_id        INT           NOT NULL,
    old_version   DECIMAL(3,1)  NOT NULL,
    new_version   DECIMAL(3,1)  NOT NULL,
    revised_on    DATE          NOT NULL,
    revised_by    VARCHAR(120)  NOT NULL,
    change_note   TEXT,

    FOREIGN KEY (sop_id) REFERENCES sops(sop_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_rev_sop (sop_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 4: sop_assignments
-- Many-to-many link between employees and SOPs
-- ----------------------------------------------------------------------------
CREATE TABLE sop_assignments (
    assignment_id INT AUTO_INCREMENT PRIMARY KEY,
    employee_id   INT           NOT NULL,
    sop_id        INT           NOT NULL,
    assigned_date DATE          NOT NULL,

    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (sop_id) REFERENCES sops(sop_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    UNIQUE KEY uq_emp_sop (employee_id, sop_id),
    INDEX idx_asgn_sop (sop_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 5: training_sessions
-- Logs every training event conducted
-- ----------------------------------------------------------------------------
CREATE TABLE training_sessions (
    session_id    INT AUTO_INCREMENT PRIMARY KEY,
    sop_id        INT           NOT NULL,
    trainer_name  VARCHAR(120)  NOT NULL,
    training_date DATE          NOT NULL,
    mode          ENUM('Classroom','Online','On-the-Job') NOT NULL,
    notes         TEXT,

    FOREIGN KEY (sop_id) REFERENCES sops(sop_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_ts_sop (sop_id),
    INDEX idx_ts_date (training_date)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 6: training_attendance (junction table for session attendees)
-- Records which employees attended which training session
-- ----------------------------------------------------------------------------
CREATE TABLE training_attendance (
    attendance_id INT AUTO_INCREMENT PRIMARY KEY,
    session_id    INT NOT NULL,
    employee_id   INT NOT NULL,

    FOREIGN KEY (session_id) REFERENCES training_sessions(session_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    UNIQUE KEY uq_session_emp (session_id, employee_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 7: acknowledgements
-- Formal sign-off records for SOP versions
-- ----------------------------------------------------------------------------
CREATE TABLE acknowledgements (
    ack_id        INT AUTO_INCREMENT PRIMARY KEY,
    employee_id   INT           NOT NULL,
    sop_id        INT           NOT NULL,
    version_acked DECIMAL(3,1)  NOT NULL,
    ack_timestamp DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    mode          ENUM('Digital','Physical') NOT NULL DEFAULT 'Digital',

    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (sop_id) REFERENCES sops(sop_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_ack_emp (employee_id),
    INDEX idx_ack_sop (sop_id)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 8: revision_log
-- Log table populated by the after_sop_revision trigger
-- ----------------------------------------------------------------------------
CREATE TABLE revision_log (
    log_id      INT AUTO_INCREMENT PRIMARY KEY,
    sop_id      INT           NOT NULL,
    new_version DECIMAL(3,1)  NOT NULL,
    message     TEXT          NOT NULL,
    logged_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;


-- ============================================================================
-- TRIGGER DEFINITIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Trigger: after_sop_revision
-- Fires AFTER INSERT on sop_revisions.
--   1. Updates the sops.version to the new version.
--   2. Logs a note that all prior acknowledgements for that SOP are outdated.
-- ----------------------------------------------------------------------------
DELIMITER $$

CREATE TRIGGER after_sop_revision
AFTER INSERT ON sop_revisions
FOR EACH ROW
BEGIN
    -- 1. Bump the version in the master sops table
    UPDATE sops
       SET version = NEW.new_version
     WHERE sop_id = NEW.sop_id;

    -- 2. Log that existing acknowledgements are now outdated
    INSERT INTO revision_log (sop_id, new_version, message, logged_at)
    VALUES (
        NEW.sop_id,
        NEW.new_version,
        CONCAT('SOP revised from v', NEW.old_version, ' to v', NEW.new_version,
               '. All existing acknowledgements for this SOP are now OUTDATED ',
               'and must be re-acknowledged.'),
        NOW()
    );
END$$

DELIMITER ;


-- ============================================================================
-- STORED PROCEDURE DEFINITIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Procedure: get_compliance_gap
-- Input   : p_department (VARCHAR)
-- Returns : Every employee in the department with each assigned SOP,
--           their acknowledgement status, and the required SOP version.
-- ----------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE get_compliance_gap(IN p_department VARCHAR(50))
BEGIN
    SELECT
        e.employee_id,
        e.full_name,
        e.department,
        s.sop_number,
        s.title              AS sop_title,
        s.version            AS required_version,
        COALESCE(
            (SELECT MAX(a.version_acked)
               FROM acknowledgements a
              WHERE a.employee_id = e.employee_id
                AND a.sop_id     = s.sop_id),
            0
        )                    AS latest_ack_version,
        CASE
            WHEN EXISTS (
                SELECT 1
                  FROM acknowledgements a
                 WHERE a.employee_id  = e.employee_id
                   AND a.sop_id       = s.sop_id
                   AND a.version_acked = s.version
            ) THEN 'Acknowledged'
            ELSE 'Pending'
        END                  AS ack_status
    FROM employees e
    JOIN sop_assignments sa ON sa.employee_id = e.employee_id
    JOIN sops s             ON s.sop_id       = sa.sop_id
    WHERE e.department = p_department
      AND e.is_active  = 1
    ORDER BY e.full_name, s.sop_number;
END$$

DELIMITER ;


-- ----------------------------------------------------------------------------
-- Procedure: get_training_status
-- Returns : Training completion rate per department — how many employees
--           attended at least one training session for each assigned SOP
--           vs. total assigned.
-- ----------------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE get_training_status()
BEGIN
    SELECT
        e.department,
        s.sop_number,
        s.title                                                  AS sop_title,
        COUNT(DISTINCT sa.employee_id)                           AS total_assigned,
        COUNT(DISTINCT
            CASE WHEN ta.employee_id IS NOT NULL
                 THEN sa.employee_id END)                        AS trained_count,
        ROUND(
            COUNT(DISTINCT
                CASE WHEN ta.employee_id IS NOT NULL
                     THEN sa.employee_id END)
            * 100.0
            / COUNT(DISTINCT sa.employee_id), 1
        )                                                        AS training_completion_pct
    FROM sop_assignments sa
    JOIN employees e         ON e.employee_id  = sa.employee_id
    JOIN sops s              ON s.sop_id       = sa.sop_id
    LEFT JOIN training_sessions ts
        ON ts.sop_id = sa.sop_id
    LEFT JOIN training_attendance ta
        ON ta.session_id  = ts.session_id
       AND ta.employee_id = sa.employee_id
    WHERE e.is_active = 1
    GROUP BY e.department, s.sop_number, s.title
    ORDER BY e.department, s.sop_number;
END$$

DELIMITER ;


-- ============================================================================
-- END OF SCHEMA FILE
-- Next: Run 02_seed_data.sql to populate tables.
-- ============================================================================
