-- MDH-003 constraint tests for migration 005 (rules v1.5, G9): group tier of a partner whose
-- own customer tier is unknown. Integrity rule I10. All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

INSERT INTO hub.business_partners (bp_id, trading_name, country) VALUES
    ('BP-991501', 'Holding Teste SGPS', 'PT'), ('BP-991502', 'Teste Norte Lda.', 'PT');
INSERT INTO hub.customer_roles (bp_id) VALUES ('BP-991501');
INSERT INTO hub.customer_roles (bp_id, industry_code, employee_band, tier_calculated, tier_score, tier_group)
VALUES ('BP-991502', 'other', '11-49', 'tier_3', 5, 'tier_3');

SELECT pg_temp.check(1, 'A new customer role starts with calculated and group tier unknown',
    $q$SELECT tier_calculated = 'unknown' AND tier_group = 'unknown' AND tier_effective = 'unknown'
       FROM hub.customer_roles WHERE bp_id = 'BP-991501'$q$);
SELECT pg_temp.fails(2, 'G9: a partner with an unknown tier cannot take its group''s tier',
    $q$UPDATE hub.customer_roles SET tier_group = 'tier_3' WHERE bp_id = 'BP-991501'$q$,
    'customer_roles_group_tier_not_lower');
SELECT pg_temp.fails(3, 'A partner with a known tier cannot have an unknown group tier',
    $q$UPDATE hub.customer_roles SET tier_group = 'unknown' WHERE bp_id = 'BP-991502'$q$,
    'customer_roles_group_tier_not_lower');
SELECT pg_temp.ok(4, 'An override still applies to a partner with an unknown tier',
    $q$INSERT INTO governance.change_requests (request_id, request_type, risk, target_bp_id, status, requested_by,
           target_working_hours, submitted_at, rules_version)
       VALUES ('RQ-991501', 'override_customer_tier', 'low', 'BP-991501', 'approved', 'ST-905', 8, now(), 'TEST-RULES');
       UPDATE hub.customer_roles SET tier_override = 'tier_2', tier_override_request_id = 'RQ-991501' WHERE bp_id = 'BP-991501'$q$);
SELECT pg_temp.check(5, 'The override becomes the effective tier',
    $q$SELECT tier_effective = 'tier_2' AND tier_group = 'unknown' FROM hub.customer_roles WHERE bp_id = 'BP-991501'$q$);

\ir _report.sql
ROLLBACK;
