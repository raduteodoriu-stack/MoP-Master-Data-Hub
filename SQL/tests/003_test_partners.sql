-- MDH-003 constraint tests: business partners.
-- Integrity rules: I05, I06, I07, I08, I09. All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

SELECT pg_temp.ok(1, 'A Spanish partner with a well-formed NIF is stored',
    $q$INSERT INTO hub.business_partners (bp_id, legal_name, legal_form, country, tax_id, web_domain, phone)
       VALUES ('BP-990001', 'Acme Research S.L.', 'S.L.', 'ES', 'B12345674', 'acme-research.example', '+34930000000')$q$);
SELECT pg_temp.check(2, 'I08: the Spanish VAT number is derived (ES + NIF)',
    $q$SELECT vat_number = 'ESB12345674' FROM hub.business_partners WHERE bp_id = 'BP-990001'$q$);
SELECT pg_temp.ok(3, 'A French partner with a SIREN is stored',
    $q$INSERT INTO hub.business_partners (bp_id, legal_name, country, tax_id) VALUES ('BP-990002', 'Etudes Test SAS', 'FR', '123456782')$q$);
SELECT pg_temp.check(4, 'I08: the French VAT number carries the computed key (FR + key + SIREN)',
    $q$SELECT vat_number = 'FR11123456782' FROM hub.business_partners WHERE bp_id = 'BP-990002'$q$);
SELECT pg_temp.ok(5, 'A Portuguese partner with a NIPC is stored',
    $q$INSERT INTO hub.business_partners (bp_id, trading_name, country, tax_id) VALUES ('BP-990005', 'Estudos Teste', 'PT', '509876543')$q$);
SELECT pg_temp.check(6, 'I08: the Portuguese VAT number is derived (PT + NIPC)',
    $q$SELECT vat_number = 'PT509876543' FROM hub.business_partners WHERE bp_id = 'BP-990005'$q$);
SELECT pg_temp.fails(7, 'I08: a VAT number cannot be typed',
    $q$INSERT INTO hub.business_partners (bp_id, legal_name, country, vat_number) VALUES ('BP-990006', 'X', 'ES', 'ESB00000000')$q$,
    'vat_number');
SELECT pg_temp.fails(8, 'I09: a Spanish tax ID in the wrong format is refused',
    $q$INSERT INTO hub.business_partners (bp_id, legal_name, country, tax_id) VALUES ('BP-990007', 'X', 'ES', 'X1234567')$q$,
    'business_partners_tax_id_format');
SELECT pg_temp.fails(9, 'I07: two active partners cannot share a country and tax ID',
    $q$INSERT INTO hub.business_partners (bp_id, legal_name, country, tax_id) VALUES ('BP-990008', 'Acme Copy', 'ES', 'B12345674')$q$,
    'business_partners_one_active_per_tax_id');
SELECT pg_temp.ok(10, 'I06: a partner is merged into an active survivor',
    $q$INSERT INTO hub.business_partners (bp_id, trading_name, country) VALUES ('BP-990003', 'Acme (duplicate)', 'ES');
       UPDATE hub.business_partners SET status = 'merged', merged_into_bp_id = 'BP-990001', merged_at = now()
       WHERE bp_id = 'BP-990003'$q$);
SELECT pg_temp.ok(11, 'I07: a merged partner may keep the same tax ID as its survivor',
    $q$UPDATE hub.business_partners SET tax_id = 'B12345674' WHERE bp_id = 'BP-990003'$q$);
SELECT pg_temp.fails(12, 'I06: a merged partner must point to its survivor',
    $q$INSERT INTO hub.business_partners (bp_id, trading_name, country, status, merged_at) VALUES ('BP-990009', 'X', 'ES', 'merged', now())$q$,
    'business_partners_merge_pointer');
SELECT pg_temp.fails(13, 'I06: a partner cannot be merged into itself',
    $q$UPDATE hub.business_partners SET status = 'merged', merged_into_bp_id = 'BP-990002', merged_at = now() WHERE bp_id = 'BP-990002'$q$,
    'business_partners_merge_pointer');
SELECT pg_temp.fails(14, 'I06: a partner cannot be merged into a merged partner',
    $q$UPDATE hub.business_partners SET status = 'merged', merged_into_bp_id = 'BP-990003', merged_at = now() WHERE bp_id = 'BP-990002'$q$,
    'I06');
SELECT pg_temp.fails(15, 'I06: a survivor cannot be merged while others point to it',
    $q$UPDATE hub.business_partners SET status = 'merged', merged_into_bp_id = 'BP-990002', merged_at = now() WHERE bp_id = 'BP-990001'$q$,
    'I06');
SELECT pg_temp.fails(16, 'I05: a partner cannot be deleted',
    $q$DELETE FROM hub.business_partners WHERE bp_id = 'BP-990002'$q$,
    'I05');
SELECT pg_temp.fails(17, 'I05: a partner ID cannot change',
    $q$UPDATE hub.business_partners SET bp_id = 'BP-990099' WHERE bp_id = 'BP-990002'$q$,
    'I05');
SELECT pg_temp.fails(18, 'I05: a partner ID must follow BP-NNNNNN',
    $q$INSERT INTO hub.business_partners (bp_id, trading_name, country) VALUES ('BP-12', 'X', 'ES')$q$,
    'business_partners_id_format');
SELECT pg_temp.check(19, 'I05: a new partner gets its ID from the sequence',
    $q$WITH x AS (INSERT INTO hub.business_partners (trading_name, country) VALUES ('Sequence Test', 'ES') RETURNING bp_id)
       SELECT bp_id ~ '^BP-[0-9]{6}$' FROM x$q$);
SELECT pg_temp.fails(20, 'A partner needs a legal or trading name',
    $q$INSERT INTO hub.business_partners (bp_id, country) VALUES ('BP-990010', 'ES')$q$,
    'business_partners_has_name');
SELECT pg_temp.fails(21, 'I09: a web domain with www is refused',
    $q$INSERT INTO hub.business_partners (bp_id, trading_name, country, web_domain) VALUES ('BP-990011', 'X', 'ES', 'www.acme.example')$q$,
    'business_partners_web_domain_format');
SELECT pg_temp.fails(22, 'I09: a web domain in upper case is refused',
    $q$INSERT INTO hub.business_partners (bp_id, trading_name, country, web_domain) VALUES ('BP-990012', 'X', 'ES', 'Acme.example')$q$,
    'business_partners_web_domain_format');
SELECT pg_temp.fails(23, 'I09: a phone number not in international format is refused',
    $q$INSERT INTO hub.business_partners (bp_id, trading_name, country, phone) VALUES ('BP-990013', 'X', 'ES', '93 123 45 67')$q$,
    'business_partners_phone_format');
SELECT pg_temp.fails(24, 'I09: a three-letter country code is refused',
    $q$INSERT INTO hub.business_partners (bp_id, trading_name, country) VALUES ('BP-990014', 'X', 'ESP')$q$,
    'country_code_format');

\ir _report.sql
ROLLBACK;
