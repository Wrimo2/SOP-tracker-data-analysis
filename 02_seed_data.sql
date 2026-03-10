-- ============================================================================
-- SOP COMPLIANCE AND TRAINING TRACKER
-- FILE 2 OF 3: SEED DATA INSERTION
-- Prerequisite: Run 01_schema.sql first.
-- ============================================================================

USE sop_tracker;


-- ============================================================================
-- 2a. EMPLOYEES (15 across 5 departments)
-- ============================================================================

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


-- ============================================================================
-- 2b. SOPs (8 SOPs; two will have revisions applied below)
-- ============================================================================

INSERT INTO sops (sop_number, title, version, effective_date, review_due_date, department, approved_by) VALUES
('SOP-PRD-001', 'Batch Manufacturing Record Handling',       1.0, '2024-01-15', '2026-01-15', 'Production',  'Dr. R. Verma'),
('SOP-PRD-002', 'Equipment Cleaning and Sanitisation',       1.0, '2024-03-01', '2026-03-01', 'Production',  'Dr. R. Verma'),
('SOP-QC-001',  'HPLC Method Validation',                    1.0, '2023-06-01', '2025-06-01', 'QC',          'Dr. S. Iyer'),
('SOP-QC-002',  'Stability Testing Protocol',                1.0, '2024-05-20', '2026-05-20', 'QC',          'Dr. S. Iyer'),
('SOP-QA-001',  'Change Control Procedure',                  1.0, '2023-09-10', '2025-09-10', 'QA',          'Mr. A. Bhatt'),
('SOP-PKG-001', 'Primary Packaging Line Operation',          1.0, '2024-02-28', '2026-02-28', 'Packaging',   'Ms. K. Das'),
('SOP-WH-001',  'Cold Storage Temperature Monitoring',       1.0, '2024-07-15', '2026-07-15', 'Warehouse',   'Mr. V. Kapoor'),
('SOP-WH-002',  'Material Receipt and Quarantine Procedure', 1.0, '2024-08-01', '2026-08-01', 'Warehouse',   'Mr. V. Kapoor');


-- ============================================================================
-- 2c. SOP REVISIONS (two SOPs revised)
-- Note: The after_sop_revision trigger (created in 01_schema.sql) will
--       automatically bump sops.version and write to revision_log.
-- ============================================================================

-- SOP-QC-001 revised 1.0 -> 1.1
INSERT INTO sop_revisions (sop_id, old_version, new_version, revised_on, revised_by, change_note) VALUES
(3, 1.0, 1.1, '2024-12-01', 'Dr. S. Iyer',
 'Updated column calibration acceptance criteria per FDA guidance.');
-- Trigger auto-updates sops.version to 1.1
UPDATE sops SET effective_date = '2024-12-01' WHERE sop_id = 3;

-- SOP-PRD-001 revised 1.0 -> 2.0
INSERT INTO sop_revisions (sop_id, old_version, new_version, revised_on, revised_by, change_note) VALUES
(1, 1.0, 2.0, '2025-07-01', 'Dr. R. Verma',
 'Major overhaul to align with Annex-1 2023 requirements; added environmental monitoring section.');
-- Trigger auto-updates sops.version to 2.0
UPDATE sops SET effective_date = '2025-07-01' WHERE sop_id = 1;


-- ============================================================================
-- 2d. SOP ASSIGNMENTS (20 rows)
-- ============================================================================

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


-- ============================================================================
-- 2e. TRAINING SESSIONS (6 sessions)
-- ============================================================================

INSERT INTO training_sessions (sop_id, trainer_name, training_date, mode, notes) VALUES
(1, 'Dr. R. Verma',   '2024-02-10', 'Classroom',  'Initial roll-out training for Batch Manufacturing v1.0'),
(1, 'Dr. R. Verma',   '2025-08-05', 'Classroom',  'Re-training for Batch Manufacturing v2.0 (Annex-1 update)'),
(3, 'Dr. S. Iyer',    '2023-07-15', 'Online',      'HPLC method validation fundamentals'),
(3, 'Dr. S. Iyer',    '2025-01-20', 'Classroom',  'HPLC v1.1 delta training'),
(5, 'Mr. A. Bhatt',   '2023-10-05', 'On-the-Job', 'Hands-on change control walkthrough'),
(6, 'Ms. K. Das',     '2024-04-12', 'Classroom',  'Packaging line start-up and shut-down procedures');


-- ============================================================================
-- 2f. TRAINING ATTENDANCE
-- ============================================================================

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


-- ============================================================================
-- 2g. ACKNOWLEDGEMENTS
-- Deliberately leaves gaps so compliance queries return meaningful results.
-- ============================================================================

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
-- VERIFICATION: Quick row counts
-- ============================================================================

SELECT 'employees'           AS tbl, COUNT(*) AS rows FROM employees
UNION ALL SELECT 'sops',                COUNT(*)       FROM sops
UNION ALL SELECT 'sop_revisions',       COUNT(*)       FROM sop_revisions
UNION ALL SELECT 'sop_assignments',     COUNT(*)       FROM sop_assignments
UNION ALL SELECT 'training_sessions',   COUNT(*)       FROM training_sessions
UNION ALL SELECT 'training_attendance', COUNT(*)       FROM training_attendance
UNION ALL SELECT 'acknowledgements',    COUNT(*)       FROM acknowledgements
UNION ALL SELECT 'revision_log',        COUNT(*)       FROM revision_log;


-- ============================================================================
-- END OF SEED DATA FILE
-- Next: Run 03_queries.sql to execute analytical queries.
-- ============================================================================
