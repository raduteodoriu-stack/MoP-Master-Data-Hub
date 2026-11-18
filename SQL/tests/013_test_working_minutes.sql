-- MDH-003 tests for config.working_minutes (migration 002): the same calendar as LeadFlow EU,
-- Monday to Friday 09:00-18:00 Europe/Madrid, no public holidays.

BEGIN;
\ir _helpers.sql
\o /dev/null

SELECT pg_temp.check(1, 'A full working day is 540 minutes',
    $q$SELECT config.working_minutes('2026-11-02 09:00+01', '2026-11-02 18:00+01') = 540$q$);
SELECT pg_temp.check(2, '8 working hours inside one day (same as LeadFlow''s self-check)',
    $q$SELECT config.working_minutes('2026-10-13 09:59+02', '2026-10-13 17:59+02') = 480$q$);
SELECT pg_temp.check(3, 'Across a weekend only working time counts (Fri 17:00 to Mon 10:00 = 120)',
    $q$SELECT config.working_minutes('2026-11-06 17:00+01', '2026-11-09 10:00+01') = 120$q$);
SELECT pg_temp.check(4, 'Nights are not counted (18:00 to 09:00 next day = 0)',
    $q$SELECT config.working_minutes('2026-11-03 18:00+01', '2026-11-04 09:00+01') = 0$q$);
SELECT pg_temp.check(5, 'A whole week is 5 x 540 minutes',
    $q$SELECT config.working_minutes('2026-11-02 09:00+01', '2026-11-09 09:00+01') = 2700$q$);
SELECT pg_temp.check(6, 'Across the change from summer time (25 Oct 2026) days stay 540 minutes',
    $q$SELECT config.working_minutes('2026-10-23 09:00+02', '2026-10-27 09:00+01') = 1080$q$);
SELECT pg_temp.check(7, 'An end before the start gives 0',
    $q$SELECT config.working_minutes('2026-11-04 12:00+01', '2026-11-04 10:00+01') = 0$q$);
SELECT pg_temp.check(8, 'A missing moment gives NULL',
    $q$SELECT config.working_minutes(NULL, '2026-11-04 10:00+01') IS NULL$q$);
SELECT pg_temp.check(9, 'Moments given in another time zone are converted to Madrid time',
    $q$SELECT config.working_minutes('2026-11-02 08:00+00', '2026-11-02 09:00+00') = 60$q$);

\ir _report.sql
ROLLBACK;
