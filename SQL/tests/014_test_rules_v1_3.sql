-- MDH-003 constraint tests for migration 004 (rules v1.3): lifecycle blocks, successor links,
-- contact status, VIES, payee type, reference extracts, rule exceptions, suppression list.
-- Integrity rules: I14 (extended), I21-I24; access rule A01. All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

INSERT INTO hub.business_partners (bp_id, legal_name, country, tax_id) VALUES
    ('BP-991401', 'Paneles Prueba S.L.', 'ES', 'B31488208'),
    ('BP-991402', 'Grupo Ensayo S.A.', 'ES', 'A55204176'),
    ('BP-991403', 'Holding Ensayo S.A.', 'ES', NULL),
    ('BP-991404', 'Filial Ensayo S.L.', 'ES', NULL);
INSERT INTO hub.supplier_roles (bp_id, category, internal_contact_id) VALUES ('BP-991401', 'software', 'ST-901');
INSERT INTO hub.customer_roles (bp_id) VALUES ('BP-991402');
INSERT INTO governance.change_requests (request_id, request_type, risk, target_bp_id, status, requested_by,
    target_working_hours, submitted_at, rules_version) VALUES
    ('RQ-991401', 'corporate_event', 'high', 'BP-991401', 'approved', 'ST-904', 16, now(), 'TEST-RULES'),
    ('RQ-991402', 'erase_contact', 'high', 'BP-991402', 'approved', 'ST-906', 40, now(), 'TEST-RULES');

SELECT pg_temp.ok(1, 'Rules v1.3: block reason absorbed is accepted',
    $q$UPDATE hub.supplier_roles SET stage = 'inactive', block_reason = 'absorbed', blocked_by = 'ST-902', blocked_at = now(),
              block_request_id = 'RQ-991401' WHERE bp_id = 'BP-991401'$q$);
SELECT pg_temp.ok(2, 'Rules v1.3: block reason insolvency is accepted',
    $q$UPDATE hub.customer_roles SET block_reason = 'insolvency', blocked_by = 'ST-902', blocked_at = now() WHERE bp_id = 'BP-991402'$q$);
SELECT pg_temp.fails(3, 'An unknown block reason is still refused',
    $q$UPDATE hub.customer_roles SET block_reason = 'dormant' WHERE bp_id = 'BP-991402'$q$,
    'customer_roles_block_reason_valid');
SELECT pg_temp.ok(4, 'Corporate event and supplier reactivation are request types',
    $q$INSERT INTO governance.change_requests (request_type, risk, requested_by, target_working_hours, rules_version) VALUES
         ('corporate_event', 'high', 'ST-904', 16, 'TEST-RULES'), ('reactivate_supplier', 'high', 'ST-904', 16, 'TEST-RULES')$q$);
SELECT pg_temp.ok(5, 'I24: an absorbed partner is linked to its successor',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, relationship_type, valid_period, request_id)
       VALUES ('BP-991401', 'BP-991402', 'successor_of', '[2026-11-10,)', 'RQ-991401')$q$);
SELECT pg_temp.ok(6, 'A partner can have a parent and a successor at the same time',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, relationship_type, valid_period)
       VALUES ('BP-991401', 'BP-991403', 'subsidiary_of', '[2025-01-01,)')$q$);
SELECT pg_temp.fails(7, 'I24: only one successor at a time',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, relationship_type, valid_period)
       VALUES ('BP-991401', 'BP-991403', 'successor_of', '[2026-11-15,)')$q$,
    'partner_relationships_one_parent');
SELECT pg_temp.fails(8, 'I24: a successor that has itself been absorbed is refused',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, relationship_type, valid_period)
       VALUES ('BP-991404', 'BP-991401', 'successor_of', '[2026-11-20,)')$q$,
    'I24');
SELECT pg_temp.fails(9, 'Unknown relationship types are refused',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, relationship_type, valid_period)
       VALUES ('BP-991404', 'BP-991402', 'partner_of', '[2026-01-01,)')$q$,
    'partner_relationships_type_valid');
SELECT pg_temp.check(10, 'I12 ignores successor links: the hierarchy above BP-991401 has one parent',
    $q$WITH RECURSIVE up AS (SELECT 'BP-991401'::TEXT AS bp_id, 0 AS n
         UNION ALL SELECT r.parent_bp_id, up.n + 1 FROM hub.partner_relationships r JOIN up ON r.child_bp_id = up.bp_id
         WHERE r.relationship_type = 'subsidiary_of' AND upper_inf(r.valid_period))
       SELECT max(n) = 1 FROM up$q$);
SELECT pg_temp.ok(11, 'A contact who left the company keeps its name and email, with dates',
    $q$INSERT INTO hub.contact_persons (bp_id, status, first_name, last_name, work_email, last_verified_at, last_contact_at)
       VALUES ('BP-991401', 'left_company', 'Jordi', 'Exemple', 'jordi.exemple@paneles-prueba.example', '2025-08-20', '2025-09-01')$q$);
SELECT pg_temp.fails(12, 'I14: a bounced contact still needs a work email',
    $q$INSERT INTO hub.contact_persons (bp_id, status, first_name, last_name) VALUES ('BP-991401', 'bounced', 'Eva', 'Exemple')$q$,
    'contact_persons_erasure_state');
SELECT pg_temp.fails(13, 'An unknown contact status is refused',
    $q$INSERT INTO hub.contact_persons (bp_id, status, first_name, last_name, work_email)
       VALUES ('BP-991401', 'retired', 'Eva', 'Exemple', 'eva.exemple@paneles-prueba.example')$q$,
    'contact_persons_status_valid');
SELECT pg_temp.ok(14, 'I23: VIES status, check date and evidence are stored together',
    $q$UPDATE hub.business_partners SET vies_status = 'valid', vies_checked_at = '2026-04-02', vies_evidence_ref = 'VIES-SIM-000123'
       WHERE bp_id = 'BP-991402'$q$);
SELECT pg_temp.fails(15, 'I23: a VIES status without its check date is refused',
    $q$UPDATE hub.business_partners SET vies_status = 'not_registered' WHERE bp_id = 'BP-991403'$q$,
    'business_partners_vies_complete');
SELECT pg_temp.fails(16, 'An unknown VIES status is refused',
    $q$UPDATE hub.business_partners SET vies_status = 'pending', vies_checked_at = now(), vies_evidence_ref = 'X' WHERE bp_id = 'BP-991403'$q$,
    'business_partners_vies_status_valid');
SELECT pg_temp.ok(17, 'I22: a factoring company with an assignment letter is stored',
    $q$INSERT INTO hub.supplier_roles (bp_id, category, internal_contact_id) VALUES ('BP-991403', 'software', 'ST-901');
       INSERT INTO hub.bank_accounts (bp_id, iban, account_holder_name, valid_period, payee_type, assignment_evidence_ref, holder_match)
       VALUES ('BP-991403', 'FR9899999000200009876543217', 'Affacturage Test SA', '[2026-01-01,)', 'factoring_company', 'DMS/2026/ASSIGN-0007', 'no_match')$q$);
SELECT pg_temp.fails(18, 'I22: a factoring company without an assignment letter is refused',
    $q$INSERT INTO hub.supplier_roles (bp_id, category, internal_contact_id) VALUES ('BP-991404', 'software', 'ST-901');
       INSERT INTO hub.bank_accounts (bp_id, iban, account_holder_name, valid_period, payee_type)
       VALUES ('BP-991404', 'FR9899999000200009876543217', 'Affacturage Test SA', '[2026-01-01,)', 'factoring_company')$q$,
    'bank_accounts_payee_evidence');
SELECT pg_temp.fails(19, 'An unknown holder-match outcome is refused',
    $q$UPDATE hub.bank_accounts SET holder_match = 'partial' WHERE bp_id = 'BP-991403'$q$,
    'bank_accounts_holder_match_valid');
SELECT pg_temp.ok(20, 'A registry extract entry is stored',
    $q$INSERT INTO source.registry_entries (country, tax_id, registry_status, event_date, notice_ref, successor_tax_id, extract_date)
       VALUES ('ES', 'B31488208', 'absorbed', '2026-11-10', 'BORME-SIM-2026-0042', 'A55204176', '2026-11-16')$q$);
SELECT pg_temp.fails(21, 'A company appears once per registry extract',
    $q$INSERT INTO source.registry_entries (country, tax_id, registry_status, extract_date)
       VALUES ('ES', 'B31488208', 'active', '2026-11-16')$q$,
    'registry_entries_once_per_extract');
SELECT pg_temp.fails(22, 'A non-active registry status needs its event date',
    $q$INSERT INTO source.registry_entries (country, tax_id, registry_status, extract_date)
       VALUES ('ES', 'B66201948', 'insolvency_proceedings', '2026-11-16')$q$,
    'registry_entries_event_when_not_active');
SELECT pg_temp.ok(23, 'A synthetic HR extract row is stored',
    $q$INSERT INTO source.hr_employees (employee_ref, extract_date, iban, street_std, postal_code, city)
       VALUES ('E-0042', '2026-11-16', 'ES5999990007000123123123', 'CALLE MALLORCA 120 3 2', '08036', 'BARCELONA')$q$);
SELECT pg_temp.fails(24, 'A01: reporting cannot read the HR extract',
    $q$SELECT count(*) FROM source.hr_employees$q$, 'permission denied', 'mdh_reporting');
SELECT pg_temp.ok(25, 'A K10 clearance is recorded as a rule exception',
    $q$INSERT INTO governance.rule_exceptions (rule_id, bp_id, reason, approved_by, valid_period)
       VALUES ('K10', 'BP-991403', 'Conflict of interest declared and approved', 'ST-902', '[2026-11-20,)')$q$);
SELECT pg_temp.fails(26, 'One exception per rule and partner at a time',
    $q$INSERT INTO governance.rule_exceptions (rule_id, bp_id, reason, approved_by, valid_period)
       VALUES ('K10', 'BP-991403', 'Again', 'ST-902', '[2026-11-25,)')$q$,
    'rule_exceptions_one_at_a_time');
SELECT pg_temp.ok(27, 'Erasure puts the person on the suppression list',
    $q$INSERT INTO hub.contact_persons (contact_id, bp_id, first_name, last_name, work_email)
       VALUES ('00000000-0000-0000-0000-000000001427', 'BP-991402', 'Ana', 'Test', 'ana.test@client-a.example');
       SELECT governance.erase_contact('00000000-0000-0000-0000-000000001427', 'RQ-991402', 'ST-901')$q$);
SELECT pg_temp.check(28, 'The suppression list holds only the hash of the lower-cased email',
    $q$SELECT email_sha256 = encode(sha256(convert_to('ana.test@client-a.example', 'UTF8')), 'hex') AND reason = 'erased'
       FROM governance.suppression_list WHERE request_id = 'RQ-991402'$q$);
SELECT pg_temp.fails(29, 'I21: the erased person cannot be stored again, in any letter case',
    $q$INSERT INTO hub.contact_persons (bp_id, first_name, last_name, work_email)
       VALUES ('BP-991402', 'Ana', 'Test', 'Ana.Test@Client-A.example')$q$,
    'I21');
SELECT pg_temp.fails(30, 'I15: the suppression list is append-only',
    $q$DELETE FROM governance.suppression_list WHERE request_id = 'RQ-991402'$q$,
    'I15');
SELECT pg_temp.fails(31, 'A01: reporting cannot read the suppression list',
    $q$SELECT count(*) FROM governance.suppression_list$q$, 'permission denied', 'mdh_reporting');
SELECT pg_temp.ok(32, 'A rename is recorded in field history with its request',
    $q$UPDATE hub.business_partners SET legal_name = 'Norte Analytics S.L.' WHERE bp_id = 'BP-991404';
       INSERT INTO hub.field_history (bp_id, field_name, old_value, new_value, valid_from, request_id, rules_version)
       VALUES ('BP-991404', 'legal_name', 'Filial Ensayo S.L.', 'Norte Analytics S.L.', now(), 'RQ-991401', 'TEST-RULES')$q$);
SELECT pg_temp.check(33, 'The names view returns the current and the former name',
    $q$SELECT array_agg(name || ':' || is_current ORDER BY is_current) = ARRAY['Filial Ensayo S.L.:false', 'Norte Analytics S.L.:true']
       FROM hub.partner_names WHERE bp_id = 'BP-991404'$q$);
SELECT pg_temp.check(34, 'Reporting can read the names view and the new bank and contact columns',
    $q$SELECT (SELECT count(*) FROM hub.partner_names WHERE bp_id = 'BP-991404') = 2
          AND (SELECT payee_type FROM hub.bank_accounts WHERE bp_id = 'BP-991403') = 'factoring_company'$q$,
    'mdh_reporting');

\ir _report.sql
ROLLBACK;
