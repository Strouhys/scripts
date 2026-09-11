-- ============================================================
-- 0) POUZIT JAKO PRVNI, KDYZ PRIJDE ALERT: najde AKTUALNE nejvice
--    slotu vyuzivajici job(y) v rezervaci res-200 - bez znalosti job_id.
-- ============================================================
SELECT
  job_id,
  user_email,
  reservation_id,
  parent_job_id,
  statement_type,
  ROUND(AVG(period_slot_ms) / 1000.0, 1) AS avg_slots_last_5_min
FROM
  `o2cz-dp-wm-200.region-europe-west4`.INFORMATION_SCHEMA.JOBS_TIMELINE_BY_PROJECT
WHERE
  job_creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR)
  AND period_start >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 5 MINUTE)
  AND state = 'RUNNING'
  AND reservation_id = 'o2cz-dp-admin:europe-west4.res-200'
  AND (statement_type != 'SCRIPT' OR statement_type IS NULL)
GROUP BY job_id, user_email, reservation_id, parent_job_id, statement_type
ORDER BY avg_slots_last_5_min DESC;

-- ============================================================
-- 1) Az mate konkretni job_id (z dotazu 0, nebo z e-mailu alertu):
--    ktere kroky skriptu zraly sloty (pokud jde o SCRIPT/child joby).
--    Staci zmenit TARGET_JOB_ID a spustit.
-- ============================================================
DECLARE target_job_id STRING DEFAULT 'DOSAD_JOB_ID_ZDE';

SELECT
  job_id,
  reservation_id,
  state,
  error_result.reason AS error_reason,
  start_time,
  end_time,
  TIMESTAMP_DIFF(end_time, start_time, SECOND) AS duration_sec,
  total_slot_ms,
  ROUND(SAFE_DIVIDE(total_slot_ms, TIMESTAMP_DIFF(end_time, start_time, MILLISECOND)), 1) AS avg_slots,
  total_bytes_processed,
  query
FROM
  `o2cz-dp-wm-200.region-europe-west4`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE
  (job_id = target_job_id OR parent_job_id = target_job_id)
  AND creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
ORDER BY
  total_slot_ms DESC;

-- ============================================================
-- 2) Casova osa spotreby slotu pro dany job_id (i deti).
--    Vyzaduje roli BigQuery Admin / bigquery.jobs.listAll.
-- ============================================================
SELECT
  period_start,
  job_id,
  reservation_id,
  state,
  period_slot_ms,
  ROUND(period_slot_ms / 1000.0, 1) AS avg_slots_in_this_second
FROM
  `o2cz-dp-wm-200.region-europe-west4`.INFORMATION_SCHEMA.JOBS_TIMELINE_BY_PROJECT
WHERE
  job_creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR)
  AND (job_id = target_job_id OR parent_job_id = target_job_id)
ORDER BY
  period_start;

-- ============================================================
-- 3) Ke ktere rezervaci je projekt o2cz-dp-wm-200 prirazen
--    (spustit v ramci admin projektu o2cz-dp-admin).
-- ============================================================
SELECT
  assignment.assignee_id,
  assignment.job_type,
  reservation.reservation_name,
  reservation.slot_capacity,
  reservation.autoscale.max_slots AS autoscale_max_slots,
  reservation.ignore_idle_slots
FROM
  `o2cz-dp-admin.region-europe-west4`.INFORMATION_SCHEMA.ASSIGNMENTS_BY_PROJECT AS assignment
INNER JOIN
  `o2cz-dp-admin.region-europe-west4`.INFORMATION_SCHEMA.RESERVATIONS_BY_PROJECT AS reservation
  ON assignment.reservation_name = reservation.reservation_name
WHERE
  assignment.assignee_id = 'o2cz-dp-wm-200';
