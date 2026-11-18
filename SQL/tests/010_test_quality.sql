-- MDH-003 constraint tests: quality runs and results.
-- Integrity rule: I15. All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

INSERT INTO hub.business_partners (bp_id, legal_name, country) VALUES ('BP-991001', 'Quality Test S.L.', 'ES');
INSERT INTO governance.quality_runs (run_id, rules_version, scope, as_of)
VALUES ('00000000-0000-0000-0000-000000001001', 'TEST-RULES', 'full', '2026-11-06 18:00+01');

SELECT pg_temp.fails(1, 'A request-scoped run must name its request',
    $q$INSERT INTO governance.quality_runs (rules_version, scope, as_of) VALUES ('TEST-RULES', 'request', now())$q$,
    'quality_runs_request_scope');
SELECT pg_temp.ok(2, 'A rule result for a partner is stored',
    $q$INSERT INTO governance.quality_results (run_id, rule_id, severity, bp_id, outcome, details)
       VALUES ('00000000-0000-0000-0000-000000001001', 'V01', 'error', 'BP-991001', 'fail', '{"tax_id": null}')$q$);
SELECT pg_temp.fails(3, 'A result is for one partner or one source record, not both',
    $q$INSERT INTO governance.quality_results (run_id, rule_id, severity, bp_id, source_record_id, outcome)
       VALUES ('00000000-0000-0000-0000-000000001001', 'C01', 'error', 'BP-991001',
               pg_temp.make_record('crm', 'C-1001', '{"name": "Quality Test"}'), 'pass')$q$,
    'quality_results_one_subject');
SELECT pg_temp.fails(4, 'A rule ID outside the C/V/U/K/T pattern is refused',
    $q$INSERT INTO governance.quality_results (run_id, rule_id, severity, bp_id, outcome)
       VALUES ('00000000-0000-0000-0000-000000001001', 'X01', 'error', 'BP-991001', 'pass')$q$,
    'quality_results_rule_id_format');
SELECT pg_temp.fails(5, 'A rule is checked once per subject per run',
    $q$INSERT INTO governance.quality_results (run_id, rule_id, severity, bp_id, outcome)
       VALUES ('00000000-0000-0000-0000-000000001001', 'V01', 'error', 'BP-991001', 'pass')$q$,
    'quality_results_once_per_run');
SELECT pg_temp.fails(6, 'An unknown outcome is refused',
    $q$INSERT INTO governance.quality_results (run_id, rule_id, severity, bp_id, outcome)
       VALUES ('00000000-0000-0000-0000-000000001001', 'V02', 'error', 'BP-991001', 'warn')$q$,
    'quality_results_outcome_valid');
SELECT pg_temp.fails(7, 'I15: quality results cannot be changed',
    $q$UPDATE governance.quality_results SET outcome = 'pass' WHERE rule_id = 'V01'$q$,
    'I15');
SELECT pg_temp.fails(8, 'A run cannot finish before it started',
    $q$UPDATE governance.quality_runs SET finished_at = started_at - INTERVAL '1 minute'
       WHERE run_id = '00000000-0000-0000-0000-000000001001'$q$,
    'quality_runs_time_order');

\ir _report.sql
ROLLBACK;
