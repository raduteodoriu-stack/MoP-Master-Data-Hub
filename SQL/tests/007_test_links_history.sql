-- MDH-003 constraint tests: cross-reference (source links) and field history.
-- Integrity rules: I04, I15, I16. All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

SELECT pg_temp.make_record('crm', 'C-701', '{"name": "Link Test SL"}');
SELECT pg_temp.make_record('erp', 'E-701', '{"name": "LINK TEST S.L.", "nif": "B23456785"}');
INSERT INTO hub.business_partners (bp_id, trading_name, country) VALUES
    ('BP-990401', 'Link Test', 'ES'), ('BP-990402', 'Link Test Two', 'ES'), ('BP-990403', 'Merged Away', 'ES');
UPDATE hub.business_partners SET status = 'merged', merged_into_bp_id = 'BP-990402', merged_at = now()
WHERE bp_id = 'BP-990403';

SELECT pg_temp.ok(1, 'A source record is linked to a partner',
    $q$INSERT INTO hub.source_links (system_code, source_key, bp_id, valid_period, link_method, rules_version)
       VALUES ('crm', 'C-701', 'BP-990401', '[2026-11-02,)', 'new_partner', 'TEST-RULES')$q$);
SELECT pg_temp.fails(2, 'I04: a source record belongs to one partner at a time',
    $q$INSERT INTO hub.source_links (system_code, source_key, bp_id, valid_period, link_method, rules_version)
       VALUES ('crm', 'C-701', 'BP-990402', '[2026-11-05,)', 'request', 'TEST-RULES')$q$,
    'source_links_one_partner_at_a_time');
SELECT pg_temp.ok(3, 'The link is closed and the record moves to another partner',
    $q$UPDATE hub.source_links SET valid_period = '[2026-11-02,2026-11-05)' WHERE source_key = 'C-701';
       INSERT INTO hub.source_links (system_code, source_key, bp_id, valid_period, link_method, linked_by, rules_version)
       VALUES ('crm', 'C-701', 'BP-990402', '[2026-11-05,)', 'request', 'ST-901', 'TEST-RULES')$q$);
SELECT pg_temp.check(4, 'Trace: the current partner of crm C-701 is found with one query',
    $q$SELECT bp_id = 'BP-990402' FROM hub.source_links
       WHERE system_code = 'crm' AND source_key = 'C-701' AND upper_inf(valid_period)$q$);
SELECT pg_temp.check(5, 'Trace: the partner of crm C-701 on 3 November is still found',
    $q$SELECT bp_id = 'BP-990401' FROM hub.source_links
       WHERE system_code = 'crm' AND source_key = 'C-701' AND valid_period @> '2026-11-03 12:00+01'::TIMESTAMPTZ$q$);
SELECT pg_temp.fails(6, 'I04: a link must name a stored source record',
    $q$INSERT INTO hub.source_links (system_code, source_key, bp_id, valid_period, link_method, rules_version)
       VALUES ('support', 'S-NONE', 'BP-990401', '[2026-11-02,)', 'new_partner', 'TEST-RULES')$q$,
    'I04');
SELECT pg_temp.fails(7, 'A steward-confirmed link needs the suggestion and the steward',
    $q$INSERT INTO hub.source_links (system_code, source_key, bp_id, valid_period, link_method, rules_version)
       VALUES ('erp', 'E-701', 'BP-990402', '[2026-11-02,)', 'steward_confirmed', 'TEST-RULES')$q$,
    'source_links_steward_evidence');
SELECT pg_temp.fails(8, 'A merge link needs its merge event',
    $q$INSERT INTO hub.source_links (system_code, source_key, bp_id, valid_period, link_method, rules_version)
       VALUES ('erp', 'E-701', 'BP-990402', '[2026-11-02,)', 'merge', 'TEST-RULES')$q$,
    'source_links_merge_evidence');
SELECT pg_temp.fails(9, 'I04: a current link must point to an active partner',
    $q$INSERT INTO hub.source_links (system_code, source_key, bp_id, valid_period, link_method, rules_version)
       VALUES ('erp', 'E-701', 'BP-990403', '[2026-11-02,)', 'rule_m1', 'TEST-RULES')$q$,
    'I04');
SELECT pg_temp.ok(10, 'A field change is recorded with its source record',
    $q$INSERT INTO hub.field_history (bp_id, field_name, old_value, new_value, valid_from, source_record_id, survivorship_step, rules_version)
       SELECT 'BP-990402', 'legal_name', NULL, 'Link Test S.L.', '2026-11-02 09:00+01', source_record_id, 2, 'TEST-RULES'
       FROM source.source_records WHERE source_key = 'E-701'$q$);
SELECT pg_temp.ok(11, 'A later change is recorded',
    $q$INSERT INTO hub.field_history (bp_id, field_name, old_value, new_value, valid_from, source_record_id, survivorship_step, rules_version)
       SELECT 'BP-990402', 'legal_name', 'Link Test S.L.', 'Link Test Iberia S.L.', '2026-11-10 09:00+01', source_record_id, 3, 'TEST-RULES'
       FROM source.source_records WHERE source_key = 'C-701'$q$);
SELECT pg_temp.check(12, 'Lineage: the value valid on 5 November and the record it came from are found',
    $q$SELECT h.new_value = 'Link Test S.L.' AND s.source_key = 'E-701'
       FROM hub.field_history h JOIN source.source_records s USING (source_record_id)
       WHERE h.bp_id = 'BP-990402' AND h.field_name = 'legal_name' AND h.valid_from <= '2026-11-05'
       ORDER BY h.valid_from DESC, h.history_id DESC LIMIT 1$q$);
SELECT pg_temp.fails(13, 'I16: a field change must name its lineage',
    $q$INSERT INTO hub.field_history (bp_id, field_name, old_value, new_value, valid_from, rules_version)
       VALUES ('BP-990402', 'web_domain', NULL, 'link-test.example', now(), 'TEST-RULES')$q$,
    'field_history_lineage');
SELECT pg_temp.fails(14, 'A change must change the value',
    $q$INSERT INTO hub.field_history (bp_id, field_name, old_value, new_value, valid_from, source_record_id, rules_version)
       SELECT 'BP-990402', 'phone', '+34930000000', '+34930000000', now(), source_record_id, 'TEST-RULES'
       FROM source.source_records WHERE source_key = 'E-701'$q$,
    'field_history_value_changed');
SELECT pg_temp.fails(15, 'The survivorship step is 1 to 4',
    $q$INSERT INTO hub.field_history (bp_id, field_name, old_value, new_value, valid_from, source_record_id, survivorship_step, rules_version)
       SELECT 'BP-990402', 'phone', NULL, '+34930000000', now(), source_record_id, 5, 'TEST-RULES'
       FROM source.source_records WHERE source_key = 'E-701'$q$,
    'field_history_step_range');
SELECT pg_temp.fails(16, 'I15: field history cannot be updated',
    $q$UPDATE hub.field_history SET new_value = 'Rewritten' WHERE bp_id = 'BP-990402'$q$,
    'I15');
SELECT pg_temp.fails(17, 'I15: field history cannot be deleted',
    $q$DELETE FROM hub.field_history WHERE bp_id = 'BP-990402'$q$,
    'I15');

SELECT pg_temp.fails(18, 'I20: a link must name a loaded rules version',
    $q$INSERT INTO hub.source_links (system_code, source_key, bp_id, valid_period, link_method, rules_version)
       VALUES ('erp', 'E-701', 'BP-990401', '[2026-11-02,)', 'rule_m1', 'MDH-RULES-v0.0')$q$,
    'source_links_rules_version_fkey');

\ir _report.sql
ROLLBACK;
