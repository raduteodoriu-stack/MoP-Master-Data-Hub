-- MDH-003 access tests for the read-only reporting role.
-- Access rules: A01, A02, A03. All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

INSERT INTO hub.business_partners (bp_id, legal_name, country) VALUES ('BP-991201', 'Access Test S.L.', 'ES');
INSERT INTO hub.supplier_roles (bp_id, category, internal_contact_id) VALUES ('BP-991201', 'software', 'ST-901');
INSERT INTO hub.bank_accounts (bp_id, iban, account_holder_name, valid_period)
VALUES ('BP-991201', 'ES9121000418450200051332', 'Access Test S.L.', '[2026-01-01,)');
INSERT INTO hub.contact_persons (bp_id, first_name, last_name, work_email, legal_basis)
VALUES ('BP-991201', 'Marta', 'Test', 'marta.test@access-test.example', 'contract');
INSERT INTO governance.change_requests (request_id, request_type, risk, target_bp_id, status, requested_by,
    proposed_values, target_working_hours, submitted_at, rules_version)
VALUES ('RQ-991201', 'change_bank_details', 'high', 'BP-991201', 'applied', 'ST-902',
        '{"iban": "ES9121000418450200051332"}', 16, now(), 'TEST-RULES');
INSERT INTO hub.field_history (bp_id, field_name, old_value, new_value, valid_from, request_id, rules_version) VALUES
    ('BP-991201', 'iban', NULL, 'ES9121000418450200051332', '2026-01-01', 'RQ-991201', 'TEST-RULES'),
    ('BP-991201', 'legal_name', NULL, 'Access Test S.L.', '2026-01-01', 'RQ-991201', 'TEST-RULES');

SELECT pg_temp.fails(1, 'A01: reporting cannot read raw source records',
    $q$SELECT count(*) FROM source.source_records$q$, 'permission denied', 'mdh_reporting');
SELECT pg_temp.check(2, 'A01: reporting can read golden partners',
    $q$SELECT count(*) >= 1 FROM hub.business_partners WHERE bp_id = 'BP-991201'$q$, 'mdh_reporting');
SELECT pg_temp.fails(3, 'A01: reporting cannot write',
    $q$INSERT INTO hub.business_partners (bp_id, trading_name, country) VALUES ('BP-991202', 'X', 'ES')$q$,
    'permission denied', 'mdh_reporting');
SELECT pg_temp.fails(4, 'A02: reporting cannot read contact names',
    $q$SELECT first_name FROM hub.contact_persons$q$, 'permission denied', 'mdh_reporting');
SELECT pg_temp.check(5, 'A02: reporting can count contacts and their status',
    $q$SELECT count(*) = 1 FROM (SELECT contact_id, status FROM hub.contact_persons WHERE bp_id = 'BP-991201') c$q$,
    'mdh_reporting');
SELECT pg_temp.fails(6, 'A02: reporting cannot read IBANs',
    $q$SELECT iban FROM hub.bank_accounts$q$, 'permission denied', 'mdh_reporting');
SELECT pg_temp.check(7, 'A02: reporting can see the IBAN country and verification status',
    $q$SELECT iban_country = 'ES' AND verified_at IS NULL FROM hub.bank_accounts WHERE bp_id = 'BP-991201'$q$,
    'mdh_reporting');
SELECT pg_temp.fails(8, 'A02: reporting cannot read proposed values of requests',
    $q$SELECT proposed_values FROM governance.change_requests$q$, 'permission denied', 'mdh_reporting');
SELECT pg_temp.fails(9, 'A02: reporting cannot read compared values of match suggestions',
    $q$SELECT compared_values FROM governance.match_suggestions$q$, 'permission denied', 'mdh_reporting');
SELECT pg_temp.check(10, 'A03: reporting does not see the history of bank fields',
    $q$SELECT count(*) = 0 FROM hub.field_history WHERE bp_id = 'BP-991201' AND field_name = 'iban'$q$,
    'mdh_reporting');
SELECT pg_temp.check(11, 'A03: reporting sees the history of other fields',
    $q$SELECT count(*) = 1 FROM hub.field_history WHERE bp_id = 'BP-991201' AND field_name = 'legal_name'$q$,
    'mdh_reporting');
SELECT pg_temp.check(12, 'A03: the table owner still sees the bank history',
    $q$SELECT count(*) = 1 FROM hub.field_history WHERE bp_id = 'BP-991201' AND field_name = 'iban'$q$);
SELECT pg_temp.check(13, 'Reporting can use the working-time function',
    $q$SELECT config.working_minutes('2026-11-02 09:00+01', '2026-11-02 10:00+01') = 60$q$, 'mdh_reporting');

\ir _report.sql
ROLLBACK;
