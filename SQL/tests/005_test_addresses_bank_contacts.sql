-- MDH-003 constraint tests: addresses, bank accounts, contact persons.
-- Integrity rules: I09, I13, I14. All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

INSERT INTO hub.business_partners (bp_id, legal_name, country) VALUES
    ('BP-990201', 'Address Test S.L.', 'ES'),
    ('BP-990202', 'No Supplier Role S.L.', 'ES');
INSERT INTO hub.supplier_roles (bp_id, category, internal_contact_id) VALUES ('BP-990201', 'software', 'ST-901');
INSERT INTO governance.change_requests (request_id, request_type, risk, target_bp_id, status,
    requested_by, target_working_hours, submitted_at, rules_version)
VALUES ('RQ-990201', 'erase_contact', 'high', 'BP-990201', 'approved', 'ST-906', 40, now(), 'TEST-RULES');

SELECT pg_temp.ok(1, 'A current registered address is stored',
    $q$INSERT INTO hub.addresses (bp_id, address_type, street, postal_code, city, country, valid_period)
       VALUES ('BP-990201', 'registered', 'Carrer de Prova 1', '08001', 'Barcelona', 'ES', '[2026-01-01,)')$q$);
SELECT pg_temp.fails(2, 'Only one registered address at a time',
    $q$INSERT INTO hub.addresses (bp_id, address_type, street, postal_code, city, country, valid_period)
       VALUES ('BP-990201', 'registered', 'Carrer Nou 2', '08002', 'Barcelona', 'ES', '[2026-06-01,)')$q$,
    'addresses_one_current_per_type');
SELECT pg_temp.ok(3, 'An earlier registered address that ended before is stored',
    $q$INSERT INTO hub.addresses (bp_id, address_type, street, postal_code, city, country, valid_period)
       VALUES ('BP-990201', 'registered', 'Carrer Antic 3', '08003', 'Barcelona', 'ES', '[2020-01-01,2026-01-01)')$q$);
SELECT pg_temp.ok(4, 'Branch addresses may overlap',
    $q$INSERT INTO hub.addresses (bp_id, address_type, street, postal_code, city, country, valid_period)
       VALUES ('BP-990201', 'branch', 'Calle Uno 1', '28001', 'Madrid', 'ES', '[2026-01-01,)'),
              ('BP-990201', 'branch', 'Rua Um 1', '1000-001', 'Lisboa', 'PT', '[2026-01-01,)')$q$);
SELECT pg_temp.fails(5, 'I09: a Spanish postal code must start 01-52',
    $q$INSERT INTO hub.addresses (bp_id, address_type, street, postal_code, city, country, valid_period)
       VALUES ('BP-990201', 'billing', 'Calle X 1', '60001', 'Nowhere', 'ES', '[2026-01-01,)')$q$,
    'addresses_postal_code_format');
SELECT pg_temp.fails(6, 'I09: a Portuguese postal code must be NNNN-NNN',
    $q$INSERT INTO hub.addresses (bp_id, address_type, street, postal_code, city, country, valid_period)
       VALUES ('BP-990201', 'billing', 'Rua X 1', '1000', 'Lisboa', 'PT', '[2026-01-01,)')$q$,
    'addresses_postal_code_format');
SELECT pg_temp.ok(7, 'A French billing address is stored',
    $q$INSERT INTO hub.addresses (bp_id, address_type, street, postal_code, city, country, valid_period)
       VALUES ('BP-990201', 'billing', '1 rue du Test', '75001', 'Paris', 'FR', '[2026-01-01,)')$q$);
SELECT pg_temp.fails(8, 'A blank street is refused',
    $q$INSERT INTO hub.addresses (bp_id, address_type, street, postal_code, city, country, valid_period)
       VALUES ('BP-990201', 'branch', '  ', '75002', 'Paris', 'FR', '[2026-01-01,)')$q$,
    'addresses_lines_not_blank');
SELECT pg_temp.ok(9, 'A current Spanish bank account is stored',
    $q$INSERT INTO hub.bank_accounts (bp_id, iban, account_holder_name, valid_period, verified_at, verification_method, verified_by)
       VALUES ('BP-990201', 'ES9121000418450200051332', 'Address Test S.L.', '[2026-01-01,)', now(), 'callback_known_contact', 'ST-901')$q$);
SELECT pg_temp.check(10, 'The IBAN country is derived from the IBAN',
    $q$SELECT iban_country = 'ES' FROM hub.bank_accounts WHERE bp_id = 'BP-990201'$q$);
SELECT pg_temp.fails(11, 'I13: a supplier has one current bank account at a time',
    $q$INSERT INTO hub.bank_accounts (bp_id, iban, account_holder_name, valid_period)
       VALUES ('BP-990201', 'ES7921000813610123456789', 'Address Test S.L.', '[2026-03-01,)')$q$,
    'bank_accounts_one_current');
SELECT pg_temp.fails(12, 'I09: a Spanish IBAN must have 24 characters',
    $q$INSERT INTO hub.bank_accounts (bp_id, iban, account_holder_name, valid_period)
       VALUES ('BP-990201', 'ES91210004184502000513', 'Address Test S.L.', '[2025-01-01,2026-01-01)')$q$,
    'bank_accounts_iban_length');
SELECT pg_temp.fails(13, 'I09: an IBAN with spaces or lower case is refused',
    $q$INSERT INTO hub.bank_accounts (bp_id, iban, account_holder_name, valid_period)
       VALUES ('BP-990201', 'es91 2100 0418 4502 0005 1332', 'Address Test S.L.', '[2025-01-01,2026-01-01)')$q$,
    'bank_accounts_iban_format');
SELECT pg_temp.fails(14, 'I13: verification time, method and verifier are filled together',
    $q$INSERT INTO hub.bank_accounts (bp_id, iban, account_holder_name, valid_period, verified_at)
       VALUES ('BP-990201', 'ES7921000813610123456789', 'Address Test S.L.', '[2025-01-01,2026-01-01)', now())$q$,
    'bank_accounts_verification_complete');
SELECT pg_temp.fails(15, 'I13: only a partner with a supplier role can have a bank account',
    $q$INSERT INTO hub.bank_accounts (bp_id, iban, account_holder_name, valid_period)
       VALUES ('BP-990202', 'ES7921000813610123456789', 'No Supplier Role S.L.', '[2026-01-01,)')$q$,
    'bank_accounts_bp_id_fkey');
SELECT pg_temp.ok(16, 'An active contact person is stored',
    $q$INSERT INTO hub.contact_persons (contact_id, bp_id, first_name, last_name, work_email, role_title, legal_basis)
       VALUES ('00000000-0000-0000-0000-000000000216', 'BP-990201', 'Ana', 'Prueba', 'ana.prueba@address-test.example',
               'Head of Insights', 'contract')$q$);
SELECT pg_temp.fails(17, 'I14: an active contact needs a work email',
    $q$INSERT INTO hub.contact_persons (bp_id, first_name, last_name) VALUES ('BP-990201', 'Luis', 'Prueba')$q$,
    'contact_persons_erasure_state');
SELECT pg_temp.fails(18, 'I14: an erased contact cannot keep personal data',
    $q$UPDATE hub.contact_persons SET status = 'erased', erased_at = now(), erasure_request_id = 'RQ-990201'
       WHERE contact_id = '00000000-0000-0000-0000-000000000216'$q$,
    'contact_persons_erasure_state');
SELECT pg_temp.ok(19, 'I14: an erased contact keeps only its ID and erasure details',
    $q$UPDATE hub.contact_persons SET status = 'erased', first_name = NULL, last_name = NULL, work_email = NULL,
              role_title = NULL, legal_basis = NULL, erased_at = now(), erasure_request_id = 'RQ-990201'
       WHERE contact_id = '00000000-0000-0000-0000-000000000216'$q$);
SELECT pg_temp.fails(20, 'An unknown legal basis is refused',
    $q$INSERT INTO hub.contact_persons (bp_id, first_name, last_name, work_email, legal_basis)
       VALUES ('BP-990201', 'Eva', 'Prueba', 'eva.prueba@address-test.example', 'marketing')$q$,
    'contact_persons_legal_basis_valid');

\ir _report.sql
ROLLBACK;
