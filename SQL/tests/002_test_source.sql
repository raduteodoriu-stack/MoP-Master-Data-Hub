-- MDH-003 constraint tests: load batches, source records, standardised records.
-- Integrity rules: I02, I03. All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

SELECT pg_temp.ok(1, 'A load batch whose counts balance is stored',
    $q$INSERT INTO source.load_batches (batch_id, system_code, file_name, file_sha256, extracted_at,
                                        rows_received, rows_stored, rows_unchanged, rows_rejected)
       VALUES ('00000000-0000-0000-0000-000000000201', 'crm', 'crm_2026-11-02.json', repeat('b', 64),
               '2026-11-02 08:00+01', 10, 7, 2, 1)$q$);
SELECT pg_temp.fails(2, 'Counts must balance: received = stored + unchanged + rejected',
    $q$INSERT INTO source.load_batches (system_code, file_name, file_sha256, extracted_at,
                                        rows_received, rows_stored, rows_unchanged, rows_rejected)
       VALUES ('crm', 'bad.json', repeat('c', 64), '2026-11-02 08:00+01', 10, 7, 2, 0)$q$,
    'load_batches_counts_balance');
SELECT pg_temp.fails(3, 'I03: the same file cannot be loaded twice from one system',
    $q$INSERT INTO source.load_batches (system_code, file_name, file_sha256, extracted_at,
                                        rows_received, rows_stored, rows_unchanged, rows_rejected)
       VALUES ('crm', 'crm_again.json', repeat('b', 64), '2026-11-03 08:00+01', 0, 0, 0, 0)$q$,
    'load_batches_file_once');
SELECT pg_temp.ok(4, 'The same checksum from another system is a different load',
    $q$INSERT INTO source.load_batches (system_code, file_name, file_sha256, extracted_at,
                                        rows_received, rows_stored, rows_unchanged, rows_rejected)
       VALUES ('erp', 'erp.json', repeat('b', 64), '2026-11-02 08:00+01', 0, 0, 0, 0)$q$);
SELECT pg_temp.ok(5, 'A source record is stored as received',
    $q$SELECT pg_temp.make_record('crm', 'C-201', '{"name": "Acme Research SL", "country": "ES"}')$q$);
SELECT pg_temp.fails(6, 'I03: the same version of a record is stored only once',
    $q$INSERT INTO source.source_records (system_code, source_key, record_version, content_sha256, payload, batch_id)
       SELECT system_code, source_key, 2, content_sha256, payload, batch_id
       FROM source.source_records WHERE source_key = 'C-201'$q$,
    'source_records_content_once');
SELECT pg_temp.ok(7, 'A changed record arrives as a new version',
    $q$SELECT pg_temp.make_record('crm', 'C-201', '{"name": "Acme Research S.L.", "country": "ES"}')$q$);
SELECT pg_temp.check(8, 'The record now has versions 1 and 2',
    $q$SELECT array_agg(record_version ORDER BY record_version) = ARRAY[1, 2]
       FROM source.source_records WHERE system_code = 'crm' AND source_key = 'C-201'$q$);
SELECT pg_temp.fails(9, 'A record must come from a batch of its own system',
    $q$INSERT INTO source.source_records (system_code, source_key, record_version, content_sha256, payload, batch_id)
       VALUES ('erp', 'E-201', 1, repeat('d', 64), '{}', '00000000-0000-0000-0000-000000000201')$q$,
    'source_records_batch_same_system');
SELECT pg_temp.fails(10, 'The payload must be a JSON object',
    $q$INSERT INTO source.source_records (system_code, source_key, record_version, content_sha256, payload, batch_id)
       VALUES ('crm', 'C-202', 1, repeat('e', 64), '[1, 2]', '00000000-0000-0000-0000-000000000201')$q$,
    'source_records_payload_object');
SELECT pg_temp.fails(11, 'A blank source key is refused',
    $q$INSERT INTO source.source_records (system_code, source_key, record_version, content_sha256, payload, batch_id)
       VALUES ('crm', ' ', 1, repeat('f', 64), '{}', '00000000-0000-0000-0000-000000000201')$q$,
    'source_records_key_not_blank');
SELECT pg_temp.fails(12, 'I02: a source record cannot be updated',
    $q$UPDATE source.source_records SET payload = '{"name": "changed"}' WHERE source_key = 'C-201'$q$,
    'I02');
SELECT pg_temp.fails(13, 'I02: a source record cannot be deleted',
    $q$DELETE FROM source.source_records WHERE source_key = 'C-201'$q$,
    'I02');
SELECT pg_temp.fails(14, 'Redaction time and request are filled together',
    $q$INSERT INTO source.source_records (system_code, source_key, record_version, content_sha256, payload, batch_id, redacted_at)
       VALUES ('crm', 'C-203', 1, repeat('1', 64), '{}', '00000000-0000-0000-0000-000000000201', now())$q$,
    'source_records_redaction_pair');
SELECT pg_temp.ok(15, 'A standardised value that is still invalid is accepted (the quality rules report it)',
    $q$INSERT INTO source.standardised_records (source_record_id, rules_version, role_hint, name_std, country, phone_std)
       SELECT source_record_id, 'TEST-RULES', 'customer', 'ACME RESEARCH', 'ES', '93 000'
       FROM source.source_records WHERE source_key = 'C-201' AND record_version = 2$q$);
SELECT pg_temp.fails(16, 'An unknown role hint is refused',
    $q$INSERT INTO source.standardised_records (source_record_id, rules_version, role_hint)
       SELECT source_record_id, 'TEST-RULES', 'partner'
       FROM source.source_records WHERE source_key = 'C-201' AND record_version = 1$q$,
    'standardised_records_role_hint_valid');

\ir _report.sql
ROLLBACK;
