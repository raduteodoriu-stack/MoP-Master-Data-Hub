-- MDH-003 constraint tests: erasure of a contact person (D11).
-- Integrity rules: I02, I14, I15. All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

INSERT INTO hub.business_partners (bp_id, legal_name, country) VALUES ('BP-990601', 'Client A S.L.', 'ES');
INSERT INTO hub.contact_persons (contact_id, bp_id, first_name, last_name, work_email, role_title, legal_basis)
VALUES ('00000000-0000-0000-0000-000000000601', 'BP-990601', 'Ana', 'Test', 'ana.test@client-a.example',
        'Research Director', 'contract');
SELECT pg_temp.make_record('crm', 'C-601',
    '{"name": "Client A SL", "contacts": [{"first": "Ana", "email": "ana.test@client-a.example"},
                                          {"first": "Luis", "email": "luis.test@client-a.example"}]}');
SELECT pg_temp.make_record('support', 'S-601',
    '{"org": "Client A", "requester": {"name": "Ana Test", "email": "Ana.Test@client-a.example"}}');
SELECT pg_temp.make_record('erp', 'E-601', '{"name": "CLIENT A S.L.", "nif": "B34567891"}');
INSERT INTO governance.change_requests (request_id, request_type, risk, target_bp_id, status,
    requested_by, target_working_hours, submitted_at, rules_version)
VALUES ('RQ-990601', 'erase_contact', 'high', 'BP-990601', 'approved', 'ST-906', 40, now(), 'TEST-RULES'),
       ('RQ-990602', 'erase_contact', 'high', 'BP-990601', 'submitted', 'ST-906', 40, now(), 'TEST-RULES');

SELECT pg_temp.fails(1, 'An erasure needs an approved erasure request',
    $q$SELECT governance.erase_contact('00000000-0000-0000-0000-000000000601', 'RQ-990602', 'ST-901')$q$,
    'not an approved erasure request');
SELECT pg_temp.ok(2, 'The contact is erased in one transaction',
    $q$SELECT governance.erase_contact('00000000-0000-0000-0000-000000000601', 'RQ-990601', 'ST-901')$q$);
SELECT pg_temp.check(3, 'I14: the contact keeps no personal data',
    $q$SELECT status = 'erased' AND num_nonnulls(first_name, last_name, work_email, role_title, legal_basis) = 0
       FROM hub.contact_persons WHERE contact_id = '00000000-0000-0000-0000-000000000601'$q$);
SELECT pg_temp.check(4, 'No stored source record still holds the person (any letter case)',
    $q$SELECT NOT EXISTS (SELECT 1 FROM source.source_records
                          WHERE strpos(lower(payload::TEXT), 'ana.test@client-a.example') > 0)$q$);
SELECT pg_temp.check(5, 'Other people in the same record are kept',
    $q$SELECT payload -> 'contacts' -> 1 ->> 'email' = 'luis.test@client-a.example'
              AND payload -> 'contacts' -> 0 = '{"redacted": true}'
       FROM source.source_records WHERE source_key = 'C-601'$q$);
SELECT pg_temp.check(6, 'The proof counts 2 records in crm and support, without the erased data',
    $q$SELECT source_records_redacted = 2 AND systems_affected @> ARRAY['crm', 'support']
              AND cardinality(systems_affected) = 2
              AND strpos(lower(to_jsonb(p)::TEXT), 'ana') = 0
       FROM governance.erasure_proofs p WHERE request_id = 'RQ-990601'$q$);
SELECT pg_temp.check(7, 'A record without the person is untouched',
    $q$SELECT redacted_at IS NULL FROM source.source_records WHERE source_key = 'E-601'$q$);
SELECT pg_temp.check(8, 'Redacted records keep their original content hash (an old extract cannot bring the data back)',
    $q$SELECT bool_and(redaction_request_id = 'RQ-990601' AND content_sha256 = encode(sha256(convert_to(
              '{"name": "Client A SL", "contacts": [{"email": "ana.test@client-a.example", "first": "Ana"}, {"email": "luis.test@client-a.example", "first": "Luis"}]}', 'UTF8')), 'hex'))
       FROM source.source_records WHERE source_key = 'C-601'$q$);
SELECT pg_temp.fails(9, 'A contact cannot be erased twice',
    $q$SELECT governance.erase_contact('00000000-0000-0000-0000-000000000601', 'RQ-990601', 'ST-901')$q$,
    'already erased');
SELECT pg_temp.fails(10, 'I02: after the erasure, source records are insert-only again',
    $q$UPDATE source.source_records SET payload = '{}' WHERE source_key = 'E-601'$q$,
    'I02');
SELECT pg_temp.fails(11, 'I15: an erasure proof cannot be changed',
    $q$UPDATE governance.erasure_proofs SET source_records_redacted = 0 WHERE request_id = 'RQ-990601'$q$,
    'I15');

\ir _report.sql
ROLLBACK;
