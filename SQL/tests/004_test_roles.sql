-- MDH-003 constraint tests: customer and supplier roles, customer tier, blocks.
-- Integrity rules: I10, I11. All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

INSERT INTO hub.business_partners (bp_id, legal_name, country) VALUES
    ('BP-990101', 'Tier Test Research S.L.', 'ES'),
    ('BP-990102', 'Supplier Test S.L.', 'ES');
INSERT INTO governance.change_requests (request_id, request_type, risk, target_bp_id, status,
    requested_by, target_working_hours, submitted_at, rules_version)
VALUES ('RQ-990101', 'override_customer_tier', 'low', 'BP-990101', 'approved', 'ST-905', 8, now(), 'TEST-RULES'),
       ('RQ-990102', 'block_unblock', 'high', 'BP-990101', 'approved', 'ST-902', 4, now(), 'TEST-RULES');

SELECT pg_temp.ok(1, 'A customer role starts as a prospect with an unknown tier',
    $q$INSERT INTO hub.customer_roles (bp_id, account_owner_id) VALUES ('BP-990101', 'ES-09')$q$);
SELECT pg_temp.check(2, 'The effective tier of a new customer role is unknown',
    $q$SELECT stage = 'prospect' AND tier_effective = 'unknown' FROM hub.customer_roles WHERE bp_id = 'BP-990101'$q$);
SELECT pg_temp.ok(3, 'A calculated tier is stored with its score and reason codes',
    $q$UPDATE hub.customer_roles
       SET industry_code = 'market_research', employee_band = '250-999', tier_calculated = 'tier_1',
           tier_score = 55, tier_group = 'tier_1', tier_reason_codes = ARRAY['TIER_INDUSTRY_CORE', 'TIER_SIZE_250_999'],
           tier_rules_version = 'TEST-RULES', tier_calculated_at = now()
       WHERE bp_id = 'BP-990101'$q$);
SELECT pg_temp.fails(4, 'A tier score above 60 is refused',
    $q$UPDATE hub.customer_roles SET tier_score = 70 WHERE bp_id = 'BP-990101'$q$,
    'customer_roles_tier_score_range');
SELECT pg_temp.fails(5, 'A known tier needs its score',
    $q$UPDATE hub.customer_roles SET tier_score = NULL WHERE bp_id = 'BP-990101'$q$,
    'customer_roles_tier_score_when_known');
SELECT pg_temp.fails(6, 'The group tier cannot be lower than the partner''s own tier',
    $q$UPDATE hub.customer_roles SET tier_group = 'tier_2' WHERE bp_id = 'BP-990101'$q$,
    'customer_roles_group_tier_not_lower');
SELECT pg_temp.fails(7, 'A tier override needs the request that approved it',
    $q$UPDATE hub.customer_roles SET tier_override = 'tier_2' WHERE bp_id = 'BP-990101'$q$,
    'customer_roles_override_pair');
SELECT pg_temp.fails(8, 'A tier override cannot be unknown',
    $q$UPDATE hub.customer_roles SET tier_override = 'unknown', tier_override_request_id = 'RQ-990101' WHERE bp_id = 'BP-990101'$q$,
    'customer_roles_override_not_unknown');
SELECT pg_temp.ok(9, 'A tier override with its request is stored',
    $q$UPDATE hub.customer_roles SET tier_override = 'tier_2', tier_override_request_id = 'RQ-990101' WHERE bp_id = 'BP-990101'$q$);
SELECT pg_temp.check(10, 'The effective tier is the override; calculated and group tiers are kept',
    $q$SELECT tier_effective = 'tier_2' AND tier_calculated = 'tier_1' AND tier_group = 'tier_1'
       FROM hub.customer_roles WHERE bp_id = 'BP-990101'$q$);
SELECT pg_temp.fails(11, 'The effective tier cannot be typed',
    $q$UPDATE hub.customer_roles SET tier_effective = 'tier_3' WHERE bp_id = 'BP-990101'$q$,
    'tier_effective');
SELECT pg_temp.fails(12, 'I10: an unknown customer stage is refused',
    $q$UPDATE hub.customer_roles SET stage = 'lead' WHERE bp_id = 'BP-990101'$q$,
    'customer_roles_stage_valid');
SELECT pg_temp.fails(13, 'An unknown industry code is refused',
    $q$UPDATE hub.customer_roles SET industry_code = 'banking' WHERE bp_id = 'BP-990101'$q$,
    'customer_roles_industry_valid');
SELECT pg_temp.fails(14, 'The account owner must be a known sales owner ID',
    $q$UPDATE hub.customer_roles SET account_owner_id = 'ES-77' WHERE bp_id = 'BP-990101'$q$,
    'customer_roles_account_owner_id_fkey');
SELECT pg_temp.fails(15, 'I11: a block needs a reason, an approver and a time',
    $q$UPDATE hub.customer_roles SET block_reason = 'credit' WHERE bp_id = 'BP-990101'$q$,
    'customer_roles_block_complete');
SELECT pg_temp.ok(16, 'I11: a complete block is stored',
    $q$UPDATE hub.customer_roles SET block_reason = 'credit', blocked_by = 'ST-902', blocked_at = now(),
              block_request_id = 'RQ-990102' WHERE bp_id = 'BP-990101'$q$);
SELECT pg_temp.fails(17, 'Payment terms outside the allowed list are refused',
    $q$UPDATE hub.customer_roles SET payment_terms = 'NET90' WHERE bp_id = 'BP-990101'$q$,
    'customer_roles_payment_terms_valid');
SELECT pg_temp.fails(18, 'I10: a partner has at most one customer role',
    $q$INSERT INTO hub.customer_roles (bp_id) VALUES ('BP-990101')$q$,
    'customer_roles_pkey');
SELECT pg_temp.fails(19, 'A malformed invoice email is refused',
    $q$UPDATE hub.customer_roles SET invoice_email = 'billing at acme' WHERE bp_id = 'BP-990101'$q$,
    'email_address_format');
SELECT pg_temp.ok(20, 'A supplier role starts as requested',
    $q$INSERT INTO hub.supplier_roles (bp_id, category, internal_contact_id) VALUES ('BP-990102', 'software', 'ST-901')$q$);
SELECT pg_temp.fails(21, 'An approved supplier needs an approval time and approver',
    $q$UPDATE hub.supplier_roles SET stage = 'approved' WHERE bp_id = 'BP-990102'$q$,
    'supplier_roles_approved_has_approval');
SELECT pg_temp.ok(22, 'A supplier is approved with approver and time',
    $q$UPDATE hub.supplier_roles SET stage = 'approved', approved_at = now(), approved_by = 'ST-902' WHERE bp_id = 'BP-990102'$q$);
SELECT pg_temp.fails(23, 'An unknown supplier category is refused',
    $q$UPDATE hub.supplier_roles SET category = 'catering' WHERE bp_id = 'BP-990102'$q$,
    'supplier_roles_category_valid');
SELECT pg_temp.ok(24, 'One partner can be both a customer and a supplier',
    $q$INSERT INTO hub.supplier_roles (bp_id, category, internal_contact_id) VALUES ('BP-990101', 'panel_sample_provider', 'ST-901')$q$);

\ir _report.sql
ROLLBACK;
