
USE sop_tracker;

-- --------------------------------------------------------------------------
-- MQ1: All employees who joined in the last 1 year and are currently active, sorted by department then joining date.
-- --------------------------------------------------------------------------
SELECT *
FROM employees
WHERE is_active = 1 AND date_of_joining >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
ORDER BY department, date_of_joining;

-- --------------------------------------------------------------------------
-- MQ2: Total number of SOPs assigned per employee (name, department), only employees with >= 2 assignments.  (GROUP BY + HAVING)
-- --------------------------------------------------------------------------
select employee_id, full_name, department
from employees 
where employee_id in (
                      select employee_id
                      from sop_assignments
                      group by employee_id 
                      having count(*) >= 2);

-- --------------------------------------------------------------------------
-- MQ3: Training sessions in the last 6 months with SOP title and department. 
-- --------------------------------------------------------------------------
select title, department
from sops 
where sop_id in (
                 select sop_id 
                 from training_sessions
                 where training_date >= date_sub(current_date(), interval 6 month));

-- --------------------------------------------------------------------------
-- MQ4: Number of acknowledgements per SOP (across all versions), grouped by SOP title, sorted most-to-least.
-- --------------------------------------------------------------------------
SELECT
    s.sop_number,
    s.title        AS sop_title,
    COUNT(a.ack_id) AS total_acks
FROM sops s
LEFT JOIN acknowledgements a ON a.sop_id = s.sop_id
GROUP BY s.sop_number, s.title
ORDER BY total_acks DESC;


-- --------------------------------------------------------------------------
-- MQ5: SOPs that have NEVER been assigned to any employee. (LEFT JOIN + IS NULL)
-- --------------------------------------------------------------------------
SELECT
    s.sop_id,
    s.sop_number,
    s.title,
    s.department
FROM sops s
LEFT JOIN sop_assignments sa ON sa.sop_id = s.sop_id
WHERE sa.assignment_id IS NULL;

-- Another way to solve using subquery

select *
from sops
where sop_id not in (
					 select sop_id
                     from sop_assignments);
-- --------------------------------------------------------------------------
-- MQ6: Employees who have acknowledged at least one SOP but have NEVER attended any training session.  (NOT EXISTS subquery)
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

-- using subquery

select *
from employees
where employee_id in (
                      select employee_id
                      from acknowledgements) 
	  AND employee_id not in (
                              select employee_id
                              from training_attendance);

-- ############################################################################
-- ##                                                                        ##
-- ##              ADVANCED ANALYTICAL QUERIES  (AQ1 – AQ8)                 ##
-- ##                                                                        ##
-- ############################################################################


-- --------------------------------------------------------------------------
-- AQ1: Employees who have NOT acknowledged the latest version of any assigned SOP.
-- Shows: employee name, department, SOP title, required version, last acknowledged version, and status.
-- --------------------------------------------------------------------------
SELECT 
    e.name,
    e.department,
    s.sop_code,
    s.version AS current_version

FROM employees e
JOIN sop_assignments sa ON e.employee_id = sa.employee_id
JOIN sops s ON sa.sop_id = s.sop_id

WHERE e.is_active = 1
AND (e.employee_id, s.sop_id, s.version) NOT IN (
    SELECT employee_id, sop_id, version_acked
    FROM acknowledgements
);


-- --------------------------------------------------------------------------
-- AQ2: Overall compliance rate per department (percentage).
--      Uses COUNT + CASE approach.
-- --------------------------------------------------------------------------
SELECT
    e.department,
    COUNT(*) AS total_assignments,
    
    COUNT(CASE 
            WHEN a.version_acked = s.version THEN 1 
          END) AS compliant_count,
    
    ROUND(
        COUNT(CASE 
                WHEN a.version_acked = s.version THEN 1 
              END) * 100.0 / COUNT(*), 
    2) AS compliance_rate_pct

FROM employees e
JOIN sop_assignments sa ON e.employee_id = sa.employee_id
JOIN sops s ON sa.sop_id = s.sop_id
LEFT JOIN acknowledgements a 
    ON a.employee_id = e.employee_id 
    AND a.sop_id = s.sop_id

WHERE e.is_active = 1
GROUP BY e.department;


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
-- AQ4: SOPs overdue for review.
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
-- END OF QUERIES FILE
-- ============================================================================
