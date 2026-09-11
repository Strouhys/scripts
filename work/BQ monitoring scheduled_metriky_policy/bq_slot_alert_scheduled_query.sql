-- ============================================================
-- Scheduled Query: alert na job(y) blizko max kapacity rezervace
--
-- Hlida joby bezici v projektu o2cz-dp-wm-200.
-- Maximalni kapacita rezervace res-200 se nacita dynamicky
-- z INFORMATION_SCHEMA.RESERVATIONS_TIMELINE.
--
-- Pokud se kapacita zmeni napr. z 800 na 1000,
-- alert se automaticky prizpusobi.
-- ============================================================

DECLARE target_reservation_id STRING
  DEFAULT 'o2cz-dp-admin:europe-west4.res-200';

DECLARE target_reservation_name STRING
  DEFAULT 'res-200';

DECLARE alert_threshold_pct FLOAT64
  DEFAULT 0.9;  -- 90 %

DECLARE lookback_minutes INT64
  DEFAULT 15;

DECLARE reservation_max_slots INT64;

DECLARE hot_job_id STRING;
DECLARE hot_owner STRING;
DECLARE hot_reservation STRING;
DECLARE hot_avg_slots FLOAT64;


-- ------------------------------------------------------------
-- 1. Nacti aktualni maximalni kapacitu rezervace
-- ------------------------------------------------------------

SET reservation_max_slots = (
  SELECT
    autoscale.max_slots
  FROM
    `o2cz-dp-admin.region-europe-west4`
      .INFORMATION_SCHEMA.RESERVATIONS_TIMELINE
  WHERE
    reservation_name = target_reservation_name
  ORDER BY
    period_start DESC
  LIMIT 1
);


-- ------------------------------------------------------------
-- 2. Najdi aktualne nejvice slotu vyuzivajici job
-- ------------------------------------------------------------

SET (hot_job_id, hot_owner, hot_reservation, hot_avg_slots) = (

  SELECT AS STRUCT
    job_id,
    ANY_VALUE(user_email) AS user_email,
    ANY_VALUE(reservation_id) AS reservation_id,
    AVG(period_slot_ms) / 1000.0 AS avg_slots

  FROM
    `o2cz-dp-wm-200.region-europe-west4`
      .INFORMATION_SCHEMA.JOBS_TIMELINE_BY_PROJECT

  WHERE
    -- kvuli partitioningu a dlouho bezicim jobum
    job_creation_time >= TIMESTAMP_SUB(
      CURRENT_TIMESTAMP(),
      INTERVAL 12 HOUR
    )

    -- sledujeme jen poslednich X minut
    AND period_start >= TIMESTAMP_SUB(
      CURRENT_TIMESTAMP(),
      INTERVAL lookback_minutes MINUTE
    )

    AND state = 'RUNNING'

    AND reservation_id = target_reservation_id

    -- nezapocitavat SCRIPT parent + child joby dvakrat
    AND (
      statement_type != 'SCRIPT'
      OR statement_type IS NULL
    )

  GROUP BY
    job_id

  ORDER BY
    avg_slots DESC

  LIMIT 1
);


-- ------------------------------------------------------------
-- 3. Kontrola, ze se podarilo nacist kapacitu rezervace
-- ------------------------------------------------------------

IF reservation_max_slots IS NULL THEN

  RAISE USING MESSAGE =
    'BQ SLOT ALERT ERROR: Nelze zjistit max kapacitu rezervace res-200.';

END IF;


-- ------------------------------------------------------------
-- 4. Vyvolej alert pri prekroceni limitu
-- ------------------------------------------------------------

IF hot_avg_slots IS NOT NULL
   AND hot_avg_slots >= reservation_max_slots * alert_threshold_pct
THEN

  RAISE USING MESSAGE = FORMAT(

    'BQ SLOT ALERT\nCas (Europe/Prague): %s\nJob ID: %s\nOwner: %s\nReservation: %s\nPrumerne slotu (%d min): %.0f\nLimit alertu: %.0f (%.0f%% z %d)',

    FORMAT_TIMESTAMP(
      '%Y-%m-%d %H:%M:%S',
      CURRENT_TIMESTAMP(),
      'Europe/Prague'
    ),

    hot_job_id,

    IFNULL(hot_owner, 'neznamy'),

    IFNULL(
      hot_reservation,
      'ON-DEMAND / bez rezervace'
    ),

    lookback_minutes,

    hot_avg_slots,

    reservation_max_slots * alert_threshold_pct,

    alert_threshold_pct * 100,

    reservation_max_slots
  );

END IF;