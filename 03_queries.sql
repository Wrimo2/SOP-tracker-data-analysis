-- ============================================================================
-- SOP COMPLIANCE AND TRAINING TRACKER
-- FILE 3 OF 3: ANALYTICAL QUERIES
-- Prerequisite: Run 01_schema.sql then 02_seed_data.sql first.
-- Requires MySQL 8.0+ (window function support)
-- ============================================================================

USE sop_tracker;


-- ############################################################################
-- ##                                                                        ##
-- ##               MODERATE DIFFICULTY QUERIES  (MQ1 – MQ6)                 ##
-- ##                                                                        ##
-- ############################################################################


-- --------------------------------------------------------------------------
-- MQ1: All employees who joined in the last 1 year and are currently active,
--      sorted by department then joining date.
-- --------------------------------------------------------------------------
SELECT
    employee_id,
    full_name,
    department,
    designation,
    date_of_joining
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
--      (JOIN training_sessions + sops; date filter with DATEDIFF)
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


-- ############################################################################
-- ##                                                                        ##
-- ##              ADVANCED ANALYTICAL QUERIES  (AQ1 – AQ8)                 ##
-- ##                                                                        ##
-- ############################################################################


-- --------------------------------------------------------------------------
-- AQ1: Employees who have NOT acknowledged the latest version of any
--      assigned SOP.
--      Shows: employee name, department, SOP title, required version,
--             last acknowledged version, and status.
-- --------------------------------------------------------------------------
SELECT
    e.employee_id,
    e.full_name,
    e.department,
    s.sop_number,
    s.title              AS sop_title,
    s.version            AS required_version,
    (SELECT MAX(a.version_acked)
       FROM acknowledgements a
      WHERE a.employee_id = e.employee_id
        AND a.sop_id      = s.sop_id
    )                    AS last_ack_version,
    'Pending'            AS ack_status
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
--      Uses COUNT with AVG() OVER() window function.
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
--      Uses CTE (Common Table Expression).
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
-- STORED PROCEDURE DEMO CALLS
-- Uncomment to test:
-- ============================================================================

-- CALL get_compliance_gap('Production');
-- CALL get_compliance_gap('QC');
-- CALL get_compliance_gap('QA');
-- CALL get_compliance_gap('Packaging');
-- CALL get_compliance_gap('Warehouse');
-- CALL get_training_status();


-- ============================================================================
-- TRIGGER TEST
-- Uncomment to verify the after_sop_revision trigger:
-- ============================================================================

-- INSERT INTO sop_revisions (sop_id, old_version, new_version, revised_on, revised_by, change_note)
-- VALUES (4, 1.0, 1.1, '2026-03-10', 'Dr. S. Iyer', 'Added accelerated stability conditions.');
--
-- -- Verify trigger effects:
-- SELECT sop_id, sop_number, title, version FROM sops WHERE sop_id = 4;
-- SELECT * FROM revision_log WHERE sop_id = 4;


-- ============================================================================
-- END OF QUERIES FILE
-- ============================================================================
