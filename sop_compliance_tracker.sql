-- ============================================================================
-- SOP COMPLIANCE AND TRAINING TRACKER
-- Complete MySQL Database System for Quality Control Department
-- Designed for regulated manufacturing / pharmaceutical environments
-- Requires MySQL 8.0+ (window function support)
-- ============================================================================

-- ============================================================================
-- SECTION 1: DATABASE AND SCHEMA CREATION
-- ============================================================================

DROP DATABASE IF EXISTS sop_tracker;
CREATE DATABASE sop_tracker CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sop_tracker;

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
-- Table 6: training_attendance  (junction table for session attendees)
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
-- Log table used by the revision trigger
-- ----------------------------------------------------------------------------
CREATE TABLE revision_log (
    log_id      INT AUTO_INCREMENT PRIMARY KEY,
    sop_id      INT           NOT NULL,
    new_version DECIMAL(3,1)  NOT NULL,
    message     TEXT          NOT NULL,
    logged_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;


-- ============================================================================
-- SECTION 2: SEED DATA INSERTION
-- ============================================================================

-- ----- 2a. Employees (15 across 5 departments) -----
INSERT INTO employees (full_name, department, designation, date_of_joining, is_active) VALUES
-- Production (3)
('Rajesh Kumar',      'Production',  'Production Supervisor',   '2021-03-15', 1),
('Anita Sharma',      'Production',  'Machine Operator',        '2022-07-01', 1),
('Vikram Singh',      'Production',  'Line Technician',         '2025-06-20', 1),
-- QC (3)
('Priya Menon',       'QC',          'QC Analyst',              '2020-11-10', 1),
('Suresh Reddy',      'QC',          'QC Manager',              '2019-04-22', 1),
('Kavita Joshi',      'QC',          'Lab Technician',          '2023-01-09', 1),
-- QA (3)
('Amit Patel',        'QA',          'QA Officer',              '2021-08-30', 1),
('Neha Gupta',        'QA',          'Validation Specialist',   '2022-02-14', 1),
('Rohan Desai',       'QA',          'QA Manager',              '2018-06-05', 1),
-- Packaging (3)
('Sunita Rao',        'Packaging',   'Packaging Operator',      '2023-05-11', 1),
('Manoj Tiwari',      'Packaging',   'Packaging Supervisor',    '2020-09-01', 1),
('Deepa Nair',        'Packaging',   'Line Inspector',          '2025-08-15', 1),
-- Warehouse (3)
('Arjun Mehta',       'Warehouse',   'Warehouse Executive',     '2022-12-01', 1),
('Pooja Iyer',        'Warehouse',   'Inventory Analyst',       '2024-03-18', 1),
('Sanjay Kulkarni',   'Warehouse',   'Warehouse Manager',       '2019-07-25', 0);  -- inactive


-- ----- 2b. SOPs (8 SOPs; two will later have revisions) -----
INSERT INTO sops (sop_number, title, version, effective_date, review_due_date, department, approved_by) VALUES
('SOP-PRD-001', 'Batch Manufacturing Record Handling',       1.0, '2024-01-15', '2026-01-15', 'Production',  'Dr. R. Verma'),
('SOP-PRD-002', 'Equipment Cleaning and Sanitisation',       1.0, '2024-03-01', '2026-03-01', 'Production',  'Dr. R. Verma'),
('SOP-QC-001',  'HPLC Method Validation',                    1.0, '2023-06-01', '2025-06-01', 'QC',          'Dr. S. Iyer'),
('SOP-QC-002',  'Stability Testing Protocol',                1.0, '2024-05-20', '2026-05-20', 'QC',          'Dr. S. Iyer'),
('SOP-QA-001',  'Change Control Procedure',                  1.0, '2023-09-10', '2025-09-10', 'QA',          'Mr. A. Bhatt'),
('SOP-PKG-001', 'Primary Packaging Line Operation',          1.0, '2024-02-28', '2026-02-28', 'Packaging',   'Ms. K. Das'),
('SOP-WH-001',  'Cold Storage Temperature Monitoring',       1.0, '2024-07-15', '2026-07-15', 'Warehouse',   'Mr. V. Kapoor'),
('SOP-WH-002',  'Material Receipt and Quarantine Procedure', 1.0, '2024-08-01', '2026-08-01', 'Warehouse',   'Mr. V. Kapoor');


-- ----- 2c. SOP Revisions (two SOPs revised) -----
-- We insert revisions BEFORE the trigger is defined, so we manually update sops.
-- SOP-QC-001 revised 1.0 -> 1.1
INSERT INTO sop_revisions (sop_id, old_version, new_version, revised_on, revised_by, change_note) VALUES
(3, 1.0, 1.1, '2024-12-01', 'Dr. S. Iyer',
 'Updated column calibration acceptance criteria per FDA guidance.');
UPDATE sops SET version = 1.1, effective_date = '2024-12-01' WHERE sop_id = 3;

-- SOP-PRD-001 revised 1.0 -> 2.0
INSERT INTO sop_revisions (sop_id, old_version, new_version, revised_on, revised_by, change_note) VALUES
(1, 1.0, 2.0, '2025-07-01', 'Dr. R. Verma',
 'Major overhaul to align with Annex-1 2023 requirements; added environmental monitoring section.');
UPDATE sops SET version = 2.0, effective_date = '2025-07-01' WHERE sop_id = 1;


-- ----- 2d. SOP Assignments (20 rows) -----
INSERT INTO sop_assignments (employee_id, sop_id, assigned_date) VALUES
-- Production employees -> Production SOPs
(1, 1, '2024-01-20'),   -- Rajesh -> Batch Manufacturing
(1, 2, '2024-03-05'),   -- Rajesh -> Equipment Cleaning
(2, 1, '2024-01-20'),   -- Anita  -> Batch Manufacturing
(2, 2, '2024-03-05'),   -- Anita  -> Equipment Cleaning
(3, 1, '2025-06-25'),   -- Vikram -> Batch Manufacturing
(3, 2, '2025-06-25'),   -- Vikram -> Equipment Cleaning
-- QC employees -> QC SOPs
(4, 3, '2023-06-10'),   -- Priya  -> HPLC
(4, 4, '2024-05-25'),   -- Priya  -> Stability
(5, 3, '2023-06-10'),   -- Suresh -> HPLC
(5, 4, '2024-05-25'),   -- Suresh -> Stability
(6, 3, '2023-06-10'),   -- Kavita -> HPLC
-- QA employees -> QA SOP
(7, 5, '2023-09-15'),   -- Amit   -> Change Control
(8, 5, '2023-09-15'),   -- Neha   -> Change Control
(9, 5, '2023-09-15'),   -- Rohan  -> Change Control
-- Packaging employees -> Packaging SOP
(10, 6, '2024-03-01'),  -- Sunita -> Primary Packaging
(11, 6, '2024-03-01'),  -- Manoj  -> Primary Packaging
(12, 6, '2025-08-20'),  -- Deepa  -> Primary Packaging
-- Warehouse employees -> Warehouse SOPs
(13, 7, '2024-07-20'),  -- Arjun  -> Cold Storage
(13, 8, '2024-08-05'),  -- Arjun  -> Material Receipt
(14, 7, '2024-07-20');   -- Pooja  -> Cold Storage


-- ----- 2e. Training Sessions (6 sessions) -----
INSERT INTO training_sessions (sop_id, trainer_name, training_date, mode, notes) VALUES
(1, 'Dr. R. Verma',   '2024-02-10', 'Classroom',  'Initial roll-out training for Batch Manufacturing v1.0'),
(1, 'Dr. R. Verma',   '2025-08-05', 'Classroom',  'Re-training for Batch Manufacturing v2.0 (Annex-1 update)'),
(3, 'Dr. S. Iyer',    '2023-07-15', 'Online',      'HPLC method validation fundamentals'),
(3, 'Dr. S. Iyer',    '2025-01-20', 'Classroom',  'HPLC v1.1 delta training'),
(5, 'Mr. A. Bhatt',   '2023-10-05', 'On-the-Job', 'Hands-on change control walkthrough'),
(6, 'Ms. K. Das',     '2024-04-12', 'Classroom',  'Packaging line start-up and shut-down procedures');


-- ----- 2f. Training Attendance -----
-- Session 1 (Batch Mfg v1.0): Rajesh, Anita attended
INSERT INTO training_attendance (session_id, employee_id) VALUES (1, 1), (1, 2);
-- Session 2 (Batch Mfg v2.0): Rajesh attended; Anita & Vikram did NOT
INSERT INTO training_attendance (session_id, employee_id) VALUES (2, 1);
-- Session 3 (HPLC v1.0): Priya, Suresh attended
INSERT INTO training_attendance (session_id, employee_id) VALUES (3, 4), (3, 5);
-- Session 4 (HPLC v1.1 delta): Priya attended; Suresh & Kavita did NOT
INSERT INTO training_attendance (session_id, employee_id) VALUES (4, 4);
-- Session 5 (Change Control): Amit, Neha attended; Rohan did NOT
INSERT INTO training_attendance (session_id, employee_id) VALUES (5, 7), (5, 8);
-- Session 6 (Packaging): Sunita, Manoj attended; Deepa did NOT
INSERT INTO training_attendance (session_id, employee_id) VALUES (6, 10), (6, 11);


-- ----- 2g. Acknowledgements -----
-- Deliberately leave gaps so compliance queries return meaningful results.

-- SOP 1 (Batch Manufacturing v2.0): only Rajesh acknowledged latest
INSERT INTO acknowledgements (employee_id, sop_id, version_acked, ack_timestamp, mode) VALUES
(1, 1, 1.0, '2024-02-15 09:30:00', 'Digital'),   -- old version
(2, 1, 1.0, '2024-02-16 10:00:00', 'Digital'),   -- old version
(1, 1, 2.0, '2025-08-10 11:00:00', 'Digital');    -- latest

-- SOP 2 (Equipment Cleaning v1.0): Rajesh acked, Anita acked, Vikram pending
INSERT INTO acknowledgements (employee_id, sop_id, version_acked, ack_timestamp, mode) VALUES
(1, 2, 1.0, '2024-03-10 14:00:00', 'Physical'),
(2, 2, 1.0, '2024-03-12 08:45:00', 'Physical');

-- SOP 3 (HPLC v1.1): Priya acknowledged 1.1; Suresh only has 1.0; Kavita nothing
INSERT INTO acknowledgements (employee_id, sop_id, version_acked, ack_timestamp, mode) VALUES
(4, 3, 1.0, '2023-07-20 10:15:00', 'Digital'),
(5, 3, 1.0, '2023-07-21 09:00:00', 'Digital'),
(4, 3, 1.1, '2025-01-25 16:30:00', 'Digital');

-- SOP 4 (Stability v1.0): Priya acknowledged, Suresh pending
INSERT INTO acknowledgements (employee_id, sop_id, version_acked, ack_timestamp, mode) VALUES
(4, 4, 1.0, '2024-06-01 13:00:00', 'Digital');

-- SOP 5 (Change Control v1.0): Amit & Neha acknowledged, Rohan pending
INSERT INTO acknowledgements (employee_id, sop_id, version_acked, ack_timestamp, mode) VALUES
(7, 5, 1.0, '2023-10-10 10:00:00', 'Physical'),
(8, 5, 1.0, '2023-10-11 11:30:00', 'Physical');

-- SOP 6 (Packaging v1.0): Sunita acknowledged, Manoj & Deepa pending
INSERT INTO acknowledgements (employee_id, sop_id, version_acked, ack_timestamp, mode) VALUES
(10, 6, 1.0, '2024-04-15 09:00:00', 'Digital');

-- SOP 7 (Cold Storage v1.0): Arjun acknowledged, Pooja pending
INSERT INTO acknowledgements (employee_id, sop_id, version_acked, ack_timestamp, mode) VALUES
(13, 7, 1.0, '2024-08-01 10:00:00', 'Digital');

-- SOP 8 (Material Receipt v1.0): nobody acknowledged
-- (intentionally left empty to create a full gap)


-- ============================================================================
-- SECTION 3: TRIGGER DEFINITIONS
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
               '. All existing acknowledgements for this SOP are now OUTDATED and must be re-acknowledged.'),
        NOW()
    );
END$$

DELIMITER ;


-- ============================================================================
-- SECTION 4: STORED PROCEDURE DEFINITIONS
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
-- SECTION 5: MODERATE DIFFICULTY QUERIES
-- ============================================================================

-- ############################################################################
-- ##                     MODERATE DIFFICULTY QUERIES                        ##
-- ############################################################################

-- --------------------------------------------------------------------------
-- MQ1: All employees who joined in the last 1 year and are currently active,
--      sorted by department then joining date.
-- --------------------------------------------------------------------------
SELECT employee_id, full_name, department, designation, date_of_joining
  FROM employees
 WHERE is_active = 1
   AND date_of_joining >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
 ORDER BY department, date_of_joining;


-- --------------------------------------------------------------------------
-- MQ2: Total number of SOPs assigned per employee (name, department),
--      only employees with >= 2 assignments.  (GROUP BY + HAVING)
-- --------------------------------------------------------------------------
SELECT
    e.employee_id,
    e.full_name,
    e.department,
    COUNT(sa.sop_id) AS sops_assigned
FROM employees e
JOIN sop_assignments sa ON sa.employee_id = e.employee_id
GROUP BY e.employee_id, e.full_name, e.department
HAVING COUNT(sa.sop_id) >= 2
ORDER BY sops_assigned DESC;


-- --------------------------------------------------------------------------
-- MQ3: Training sessions in the last 6 months with SOP title and department.
--      (JOIN training_sessions + sops; date filter)
-- --------------------------------------------------------------------------
SELECT
    ts.session_id,
    s.sop_number,
    s.title         AS sop_title,
    s.department,
    ts.trainer_name,
    ts.training_date,
    ts.mode,
    ts.notes
FROM training_sessions ts
JOIN sops s ON s.sop_id = ts.sop_id
WHERE ts.training_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
ORDER BY ts.training_date DESC;


-- --------------------------------------------------------------------------
-- MQ4: Number of acknowledgements per SOP (across all versions),
--      grouped by SOP title, sorted most-to-least.
-- --------------------------------------------------------------------------
SELECT
    s.sop_number,
    s.title        AS sop_title,
    COUNT(a.ack_id) AS total_acks
FROM sops s
LEFT JOIN acknowledgements a ON a.sop_id = s.sop_id
GROUP BY s.sop_id, s.sop_number, s.title
ORDER BY total_acks DESC;


-- --------------------------------------------------------------------------
-- MQ5: SOPs that have NEVER been assigned to any employee.
--      (LEFT JOIN + IS NULL)
-- --------------------------------------------------------------------------
SELECT
    s.sop_id,
    s.sop_number,
    s.title,
    s.department
FROM sops s
LEFT JOIN sop_assignments sa ON sa.sop_id = s.sop_id
WHERE sa.assignment_id IS NULL;


-- --------------------------------------------------------------------------
-- MQ6: Employees who have acknowledged at least one SOP but have NEVER
--      attended any training session.  (NOT EXISTS subquery)
-- --------------------------------------------------------------------------
SELECT DISTINCT
    e.employee_id,
    e.full_name,
    e.department
FROM employees e
JOIN acknowledgements a ON a.employee_id = e.employee_id
WHERE NOT EXISTS (
    SELECT 1
      FROM training_attendance ta
     WHERE ta.employee_id = e.employee_id
)
ORDER BY e.full_name;


-- ============================================================================
-- SECTION 6: ADVANCED ANALYTICAL QUERIES
-- ============================================================================

-- ############################################################################
-- ##                     ADVANCED ANALYTICAL QUERIES                        ##
-- ############################################################################

-- --------------------------------------------------------------------------
-- AQ1: Employees who have NOT acknowledged the latest version of any
--      assigned SOP.
-- --------------------------------------------------------------------------
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
          WHERE a.employee_id  = e.employee_id
            AND a.sop_id       = s.sop_id),
        NULL
    )                    AS last_ack_version,
    CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM acknowledgements a
             WHERE a.employee_id   = e.employee_id
               AND a.sop_id        = s.sop_id
               AND a.version_acked  = s.version
        ) THEN 'Pending'
        ELSE 'Acknowledged'
    END                  AS ack_status
FROM employees e
JOIN sop_assignments sa ON sa.employee_id = e.employee_id
JOIN sops s             ON s.sop_id       = sa.sop_id
WHERE e.is_active = 1
  AND NOT EXISTS (
      SELECT 1 FROM acknowledgements a
       WHERE a.employee_id   = e.employee_id
         AND a.sop_id        = s.sop_id
         AND a.version_acked  = s.version
  )
ORDER BY e.department, e.full_name, s.sop_number;


-- --------------------------------------------------------------------------
-- AQ2: Overall compliance rate per department (percentage).
--      Uses COUNT + CASE approach.
-- --------------------------------------------------------------------------
SELECT
    e.department,
    COUNT(*)                                                  AS total_assignments,
    SUM(CASE
            WHEN EXISTS (
                SELECT 1 FROM acknowledgements a
                 WHERE a.employee_id   = e.employee_id
                   AND a.sop_id        = s.sop_id
                   AND a.version_acked  = s.version
            ) THEN 1 ELSE 0
        END)                                                  AS compliant_count,
    ROUND(
        SUM(CASE
                WHEN EXISTS (
                    SELECT 1 FROM acknowledgements a
                     WHERE a.employee_id   = e.employee_id
                       AND a.sop_id        = s.sop_id
                       AND a.version_acked  = s.version
                ) THEN 1 ELSE 0
            END) * 100.0 / COUNT(*), 1
    )                                                         AS compliance_pct
FROM employees e
JOIN sop_assignments sa ON sa.employee_id = e.employee_id
JOIN sops s             ON s.sop_id       = sa.sop_id
WHERE e.is_active = 1
GROUP BY e.department
ORDER BY compliance_pct DESC;


-- --------------------------------------------------------------------------
-- AQ3: Each employee's acknowledgement count vs. department average.
--      Uses COUNT with OVER() window function.
-- --------------------------------------------------------------------------
SELECT
    e.employee_id,
    e.full_name,
    e.department,
    COUNT(a.ack_id)                                            AS personal_ack_count,
    ROUND(AVG(COUNT(a.ack_id)) OVER (PARTITION BY e.department), 2)
                                                               AS dept_avg_ack_count
FROM employees e
LEFT JOIN acknowledgements a ON a.employee_id = e.employee_id
WHERE e.is_active = 1
GROUP BY e.employee_id, e.full_name, e.department
ORDER BY e.department, personal_ack_count DESC;


-- --------------------------------------------------------------------------
-- AQ4: SOPs overdue for review (review_due_date < today).
-- --------------------------------------------------------------------------
SELECT
    sop_id,
    sop_number,
    title,
    version,
    department,
    review_due_date,
    DATEDIFF(CURDATE(), review_due_date) AS days_overdue
FROM sops
WHERE review_due_date < CURDATE()
ORDER BY days_overdue DESC;


-- --------------------------------------------------------------------------
-- AQ5: Employees assigned > 3 SOPs but acknowledged < half of them.
--      Uses CTE.
-- --------------------------------------------------------------------------
WITH emp_stats AS (
    SELECT
        e.employee_id,
        e.full_name,
        e.department,
        COUNT(DISTINCT sa.sop_id) AS assigned_count,
        COUNT(DISTINCT CASE
            WHEN EXISTS (
                SELECT 1 FROM acknowledgements a
                 WHERE a.employee_id   = e.employee_id
                   AND a.sop_id        = sa.sop_id
                   AND a.version_acked  = s.version
            ) THEN sa.sop_id END
        ) AS acked_count
    FROM employees e
    JOIN sop_assignments sa ON sa.employee_id = e.employee_id
    JOIN sops s             ON s.sop_id       = sa.sop_id
    WHERE e.is_active = 1
    GROUP BY e.employee_id, e.full_name, e.department
)
SELECT
    employee_id,
    full_name,
    department,
    assigned_count,
    acked_count,
    ROUND(acked_count * 100.0 / assigned_count, 1) AS ack_pct
FROM emp_stats
WHERE assigned_count > 3
  AND acked_count < (assigned_count / 2)
ORDER BY ack_pct;


-- --------------------------------------------------------------------------
-- AQ6: Pareto-style breakdown — SOPs with the most pending acknowledgements
--      in descending order with a running total (SUM() OVER()).
-- --------------------------------------------------------------------------
WITH pending AS (
    SELECT
        s.sop_id,
        s.sop_number,
        s.title,
        COUNT(*) AS pending_acks
    FROM sop_assignments sa
    JOIN sops s      ON s.sop_id       = sa.sop_id
    JOIN employees e ON e.employee_id  = sa.employee_id
    WHERE e.is_active = 1
      AND NOT EXISTS (
          SELECT 1 FROM acknowledgements a
           WHERE a.employee_id   = sa.employee_id
             AND a.sop_id        = sa.sop_id
             AND a.version_acked  = s.version
      )
    GROUP BY s.sop_id, s.sop_number, s.title
)
SELECT
    sop_number,
    title,
    pending_acks,
    SUM(pending_acks) OVER (ORDER BY pending_acks DESC
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        AS running_total
FROM pending
ORDER BY pending_acks DESC;


-- --------------------------------------------------------------------------
-- AQ7: Trainer-wise training coverage — unique employees trained per trainer.
-- --------------------------------------------------------------------------
SELECT
    ts.trainer_name,
    COUNT(DISTINCT ta.employee_id) AS unique_employees_trained,
    COUNT(DISTINCT ts.session_id)  AS sessions_conducted,
    GROUP_CONCAT(DISTINCT s.sop_number ORDER BY s.sop_number SEPARATOR ', ')
                                   AS sops_covered
FROM training_sessions ts
JOIN training_attendance ta ON ta.session_id = ts.session_id
JOIN sops s                 ON s.sop_id      = ts.sop_id
GROUP BY ts.trainer_name
ORDER BY unique_employees_trained DESC;


-- --------------------------------------------------------------------------
-- AQ8: SOP version progression history using LAG().
--      Shows previous version, current version, and revision date side by side.
-- --------------------------------------------------------------------------
SELECT
    s.sop_number,
    s.title,
    sr.new_version                                              AS current_version,
    LAG(sr.new_version, 1) OVER (PARTITION BY sr.sop_id
                                  ORDER BY sr.revised_on)       AS previous_version,
    sr.revised_on                                               AS revision_date,
    sr.revised_by,
    sr.change_note
FROM sop_revisions sr
JOIN sops s ON s.sop_id = sr.sop_id
ORDER BY s.sop_number, sr.revised_on;


-- ============================================================================
-- SECTION 7: DEMONSTRATION / VERIFICATION CALLS
-- ============================================================================

-- Call stored procedures to verify they work:
-- CALL get_compliance_gap('Production');
-- CALL get_compliance_gap('QC');
-- CALL get_training_status();

-- Test the trigger by inserting a new revision:
-- INSERT INTO sop_revisions (sop_id, old_version, new_version, revised_on, revised_by, change_note)
-- VALUES (4, 1.0, 1.1, '2026-03-10', 'Dr. S. Iyer', 'Added accelerated stability conditions.');
-- SELECT * FROM sops WHERE sop_id = 4;       -- version should now be 1.1
-- SELECT * FROM revision_log WHERE sop_id = 4; -- log entry should exist

-- ============================================================================
-- END OF FILE
-- ============================================================================
