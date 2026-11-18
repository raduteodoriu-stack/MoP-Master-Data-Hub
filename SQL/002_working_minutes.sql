-- MoP Master Data Hub migration 002 (MDH-003): working time.
--
-- config.working_minutes(a, b): working minutes from a up to (not including) b, on the same
-- calendar as LeadFlow EU: Monday to Friday, 09:00-18:00 Europe/Madrid, no public holidays.
-- 0 when b is not after a; NULL when either moment is NULL. Copied from LeadFlow's
-- SQL/006_reporting_support.sql, so request SLAs here and lead SLAs there are measured the
-- same way. Used for request turnaround, SLA attainment and match-review age (KPI06-KPI08).
--
-- Safe to run again.

BEGIN;

DO $$
BEGIN
    IF current_database() NOT IN ('mop_mdh', 'mop_mdh_test') THEN
        RAISE EXCEPTION 'I01: wrong database %. Connect to mop_mdh or mop_mdh_test.',
            current_database();
    END IF;
END
$$;

CREATE OR REPLACE FUNCTION config.working_minutes(a TIMESTAMPTZ, b TIMESTAMPTZ)
RETURNS INTEGER
LANGUAGE sql STABLE PARALLEL SAFE
AS $$
    SELECT CASE WHEN a IS NULL OR b IS NULL THEN NULL
                WHEN b <= a THEN 0
                ELSE coalesce(floor(sum(extract(epoch FROM least(b, w.closes) - greatest(a, w.opens))) / 60), 0)::INTEGER
           END
    FROM (
        SELECT (d::DATE + TIME '09:00') AT TIME ZONE 'Europe/Madrid' AS opens,
               (d::DATE + TIME '18:00') AT TIME ZONE 'Europe/Madrid' AS closes
        FROM generate_series((a AT TIME ZONE 'Europe/Madrid')::DATE::TIMESTAMP,
                             (b AT TIME ZONE 'Europe/Madrid')::DATE::TIMESTAMP, INTERVAL '1 day') AS d
        WHERE extract(isodow FROM d) < 6
    ) AS w
    WHERE least(b, w.closes) > greatest(a, w.opens)
$$;

COMMENT ON FUNCTION config.working_minutes(TIMESTAMPTZ, TIMESTAMPTZ) IS
    'Working minutes from a up to b (Mon-Fri 09:00-18:00 Europe/Madrid, no holidays). Same as LeadFlow EU.';

GRANT EXECUTE ON FUNCTION config.working_minutes(TIMESTAMPTZ, TIMESTAMPTZ) TO mdh_reporting;

-- Self-check: a full working day, and a span across a weekend.
DO $$
BEGIN
    IF config.working_minutes('2026-10-13 09:59+02', '2026-10-13 17:59+02') <> 480
       OR config.working_minutes('2026-11-06 17:00+01', '2026-11-09 10:00+01') <> 120 THEN
        RAISE EXCEPTION 'working_minutes self-check failed';
    END IF;
    RAISE NOTICE 'Migration 002 OK in %.', current_database();
END
$$;

COMMIT;
