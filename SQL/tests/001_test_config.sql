-- MDH-003 constraint tests: config (rules versions, source systems, staff, staff roles).
-- Integrity rules: I19, plus formats. All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

SELECT pg_temp.ok(1, 'A rules version with a valid checksum is stored',
    $q$INSERT INTO config.rule_versions (rules_version, file_sha256) VALUES ('MDH-RULES-v9.9', repeat('0', 64))$q$);
SELECT pg_temp.fails(2, 'A checksum that is not 64 hex characters is refused',
    $q$INSERT INTO config.rule_versions (rules_version, file_sha256) VALUES ('MDH-RULES-v9.8', 'abc')$q$,
    'sha256_hex_format');
SELECT pg_temp.fails(3, 'The same rules version cannot be loaded twice',
    $q$INSERT INTO config.rule_versions (rules_version, file_sha256) VALUES ('TEST-RULES', repeat('b', 64))$q$,
    'rule_versions_pkey');
SELECT pg_temp.check(4, 'The four source systems are seeded',
    $q$SELECT array_agg(system_code ORDER BY system_code) = ARRAY['crm','erp','procurement_sheet','support'] FROM config.source_systems$q$);
SELECT pg_temp.fails(5, 'An unknown source system is refused',
    $q$INSERT INTO config.source_systems VALUES ('sap', 'SAP', 'Not in scope', TRUE)$q$,
    'source_systems_code_valid');
SELECT pg_temp.ok(6, 'A synthetic staff member is stored',
    $q$INSERT INTO config.staff (staff_id, full_name, email, department, sales_owner_id)
       VALUES ('ST-950', 'Test AE France', 'ae.fr.test@mop-cloud.example', 'sales', 'AE-FR-09')$q$);
SELECT pg_temp.fails(7, 'A staff ID in the wrong format is refused',
    $q$INSERT INTO config.staff (staff_id, full_name, email, department) VALUES ('S-1', 'X', 'x.test@mop-cloud.example', 'sales')$q$,
    'staff_id_format');
SELECT pg_temp.fails(8, 'A staff email outside .example (real data) is refused',
    $q$INSERT INTO config.staff (staff_id, full_name, email, department) VALUES ('ST-951', 'X', 'x@mop-cloud.com', 'sales')$q$,
    'staff_email_synthetic');
SELECT pg_temp.fails(9, 'A malformed email is refused',
    $q$INSERT INTO config.staff (staff_id, full_name, email, department) VALUES ('ST-952', 'X', 'not-an-email', 'sales')$q$,
    'email_address_format');
SELECT pg_temp.fails(10, 'An unknown department is refused',
    $q$INSERT INTO config.staff (staff_id, full_name, email, department) VALUES ('ST-953', 'X', 'y.test@mop-cloud.example', 'marketing')$q$,
    'staff_department_valid');
SELECT pg_temp.fails(11, 'A sales owner ID in the wrong format is refused',
    $q$INSERT INTO config.staff (staff_id, full_name, email, department, sales_owner_id) VALUES ('ST-954', 'X', 'z.test@mop-cloud.example', 'sales', 'ES-1')$q$,
    'staff_sales_owner_id_format');
SELECT pg_temp.fails(12, 'Two people cannot share a sales owner ID',
    $q$INSERT INTO config.staff (staff_id, full_name, email, department, sales_owner_id) VALUES ('ST-955', 'X', 'w.test@mop-cloud.example', 'sales', 'ES-09')$q$,
    'staff_sales_owner_id_unique');
SELECT pg_temp.ok(13, 'A current role for a person is stored',
    $q$INSERT INTO config.staff_roles (staff_id, role, valid_period) VALUES ('ST-901', 'steward', '[2026-01-01,)')$q$);
SELECT pg_temp.fails(14, 'I19: the same role for the same person cannot overlap',
    $q$INSERT INTO config.staff_roles (staff_id, role, valid_period) VALUES ('ST-901', 'steward', '[2026-06-01,2026-12-31)')$q$,
    'staff_roles_no_overlap');
SELECT pg_temp.ok(15, 'A person can hold two different roles at the same time',
    $q$INSERT INTO config.staff_roles (staff_id, role, valid_period) VALUES ('ST-901', 'requester', '[2026-01-01,)')$q$);
SELECT pg_temp.ok(16, 'The same role can be held again in a later, non-overlapping period',
    $q$INSERT INTO config.staff_roles (staff_id, role, valid_period) VALUES ('ST-901', 'steward', '[2024-01-01,2026-01-01)')$q$);
SELECT pg_temp.fails(17, 'A role period must have a start',
    $q$INSERT INTO config.staff_roles (staff_id, role, valid_period) VALUES ('ST-902', 'finance_controller', '(,2026-01-01)')$q$,
    'valid_period_bounded_start');
SELECT pg_temp.fails(18, 'An unknown governance role is refused',
    $q$INSERT INTO config.staff_roles (staff_id, role, valid_period) VALUES ('ST-902', 'ceo', '[2026-01-01,)')$q$,
    'staff_roles_role_valid');

\ir _report.sql
ROLLBACK;
