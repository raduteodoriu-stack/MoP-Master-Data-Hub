-- MDH-003 constraint tests: match suggestions, merges and undos.
-- Integrity rules: I15, I17; M1B from migration 003 (rules v1.2). All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

INSERT INTO hub.business_partners (bp_id, trading_name, country) VALUES
    ('BP-990501', 'Merge Survivor', 'ES'), ('BP-990502', 'Merge Absorbed', 'ES'),
    ('BP-990503', 'Merge Survivor B', 'ES'), ('BP-990504', 'Merge Absorbed B', 'ES');

SELECT pg_temp.ok(1, 'A suggestion stores its pair in order with rule, score and compared values',
    $q$INSERT INTO governance.match_suggestions (a_system_code, a_source_key, a_content_sha256, b_system_code, b_source_key,
           b_content_sha256, rule_id, strength, score, compared_values, rules_version)
       VALUES ('crm', 'C-801', repeat('1', 64), 'erp', 'E-801', repeat('2', 64), 'M4', 'normal', 0.871,
               '{"name": {"a": "ACME RESEARCH", "b": "ACME RESEARCH IBERIA"}, "postal_code": "08001"}', 'TEST-RULES')$q$);
SELECT pg_temp.fails(2, 'I17: a pair stored in the wrong order is refused',
    $q$INSERT INTO governance.match_suggestions (a_system_code, a_source_key, a_content_sha256, b_system_code, b_source_key,
           b_content_sha256, rule_id, strength, score, compared_values, rules_version)
       VALUES ('erp', 'E-801', repeat('2', 64), 'crm', 'C-801', repeat('1', 64), 'M4', 'normal', 0.871, '{}', 'TEST-RULES')$q$,
    'match_suggestions_pair_ordered');
SELECT pg_temp.fails(3, 'I17: only one open suggestion per pair',
    $q$INSERT INTO governance.match_suggestions (a_system_code, a_source_key, a_content_sha256, b_system_code, b_source_key,
           b_content_sha256, rule_id, strength, score, compared_values, rules_version)
       VALUES ('crm', 'C-801', repeat('1', 64), 'erp', 'E-801', repeat('2', 64), 'M5', 'weak', 0.8, '{}', 'TEST-RULES')$q$,
    'match_suggestions_one_open_per_pair');
SELECT pg_temp.fails(4, 'Rule and strength must agree (M3 is strong)',
    $q$INSERT INTO governance.match_suggestions (a_system_code, a_source_key, a_content_sha256, b_system_code, b_source_key,
           b_content_sha256, rule_id, strength, score, compared_values, rules_version)
       VALUES ('crm', 'C-802', repeat('1', 64), 'erp', 'E-802', repeat('2', 64), 'M3', 'weak', 0.95, '{}', 'TEST-RULES')$q$,
    'match_suggestions_rule_strength_valid');
SELECT pg_temp.fails(5, 'A score above 1 is refused',
    $q$INSERT INTO governance.match_suggestions (a_system_code, a_source_key, a_content_sha256, b_system_code, b_source_key,
           b_content_sha256, rule_id, strength, score, compared_values, rules_version)
       VALUES ('crm', 'C-803', repeat('1', 64), 'erp', 'E-803', repeat('2', 64), 'M4', 'normal', 1.5, '{}', 'TEST-RULES')$q$,
    'match_suggestions_score_range');
SELECT pg_temp.fails(6, 'I17: a decided suggestion needs a decider and a time',
    $q$UPDATE governance.match_suggestions SET status = 'rejected' WHERE a_source_key = 'C-801'$q$,
    'match_suggestions_decision_complete');
SELECT pg_temp.ok(7, 'The steward rejects the suggestion',
    $q$UPDATE governance.match_suggestions SET status = 'rejected', decided_at = now(), decided_by = 'ST-901',
              decision_reason = 'Different legal entities' WHERE a_source_key = 'C-801'$q$);
SELECT pg_temp.ok(8, 'The pair can be suggested again after a record changes',
    $q$INSERT INTO governance.match_suggestions (a_system_code, a_source_key, a_content_sha256, b_system_code, b_source_key,
           b_content_sha256, rule_id, strength, score, compared_values, rules_version)
       VALUES ('crm', 'C-801', repeat('3', 64), 'erp', 'E-801', repeat('2', 64), 'M4', 'normal', 0.9, '{}', 'TEST-RULES')$q$);
SELECT pg_temp.ok(9, 'An automatic M1 merge needs no approver',
    $q$INSERT INTO governance.merge_events (merge_event_id, event_type, survivor_bp_id, absorbed_bp_id, reason, rules_version)
       VALUES ('00000000-0000-0000-0000-000000000801', 'merge', 'BP-990501', 'BP-990502', 'Same tax ID (M1)', 'TEST-RULES')$q$);
SELECT pg_temp.ok(10, 'A second, steward-approved merge is recorded',
    $q$INSERT INTO governance.merge_events (merge_event_id, event_type, survivor_bp_id, absorbed_bp_id, reason,
           match_suggestion_id, approved_by, rules_version)
       SELECT '00000000-0000-0000-0000-000000000802', 'merge', 'BP-990503', 'BP-990504', 'Confirmed duplicate',
              suggestion_id, 'ST-901', 'TEST-RULES'
       FROM governance.match_suggestions WHERE status = 'open' AND a_source_key = 'C-801'$q$);
SELECT pg_temp.fails(11, 'A merge from a suggestion needs an approver',
    $q$INSERT INTO governance.merge_events (event_type, survivor_bp_id, absorbed_bp_id, reason, match_suggestion_id, rules_version)
       SELECT 'merge', 'BP-990503', 'BP-990502', 'No approver', suggestion_id, 'TEST-RULES'
       FROM governance.match_suggestions WHERE status = 'open' AND a_source_key = 'C-801'$q$,
    'merge_events_approver_required');
SELECT pg_temp.fails(12, 'A partner cannot be merged with itself',
    $q$INSERT INTO governance.merge_events (event_type, survivor_bp_id, absorbed_bp_id, reason, rules_version)
       VALUES ('merge', 'BP-990501', 'BP-990501', 'Self', 'TEST-RULES')$q$,
    'merge_events_two_partners');
SELECT pg_temp.ok(13, 'A merge is undone by an undo naming the same partners',
    $q$INSERT INTO governance.merge_events (merge_event_id, event_type, survivor_bp_id, absorbed_bp_id, undoes_merge_event_id,
           reason, approved_by, rules_version)
       VALUES ('00000000-0000-0000-0000-000000000803', 'undo', 'BP-990501', 'BP-990502',
               '00000000-0000-0000-0000-000000000801', 'Wrong merge: different legal entities', 'ST-902', 'TEST-RULES')$q$);
SELECT pg_temp.fails(14, 'A merge can be undone only once',
    $q$INSERT INTO governance.merge_events (event_type, survivor_bp_id, absorbed_bp_id, undoes_merge_event_id, reason, approved_by, rules_version)
       VALUES ('undo', 'BP-990501', 'BP-990502', '00000000-0000-0000-0000-000000000801', 'Again', 'ST-902', 'TEST-RULES')$q$,
    'merge_events_undone_once');
SELECT pg_temp.fails(15, 'An undo must name the same partners as the merge it reverses',
    $q$INSERT INTO governance.merge_events (event_type, survivor_bp_id, absorbed_bp_id, undoes_merge_event_id, reason, approved_by, rules_version)
       VALUES ('undo', 'BP-990504', 'BP-990503', '00000000-0000-0000-0000-000000000802', 'Swapped', 'ST-902', 'TEST-RULES')$q$,
    'merge_events_undo_same_partners');
SELECT pg_temp.fails(16, 'An undo cannot reverse another undo',
    $q$INSERT INTO governance.merge_events (event_type, survivor_bp_id, absorbed_bp_id, undoes_merge_event_id, reason, approved_by, rules_version)
       VALUES ('undo', 'BP-990501', 'BP-990502', '00000000-0000-0000-0000-000000000803', 'Undo the undo', 'ST-902', 'TEST-RULES')$q$,
    'not another undo');
SELECT pg_temp.fails(17, 'An undo must point to the merge it reverses',
    $q$INSERT INTO governance.merge_events (event_type, survivor_bp_id, absorbed_bp_id, reason, approved_by, rules_version)
       VALUES ('undo', 'BP-990503', 'BP-990504', 'No pointer', 'ST-902', 'TEST-RULES')$q$,
    'merge_events_undo_pointer');
SELECT pg_temp.fails(18, 'I15: merge events cannot be changed',
    $q$UPDATE governance.merge_events SET reason = 'Rewritten' WHERE merge_event_id = '00000000-0000-0000-0000-000000000801'$q$,
    'I15');

SELECT pg_temp.ok(19, 'Rules v1.2: a same-tax-ID, different-name pair is stored as an M1B suggestion',
    $q$INSERT INTO governance.match_suggestions (a_system_code, a_source_key, a_content_sha256, b_system_code, b_source_key,
           b_content_sha256, rule_id, strength, score, compared_values, rules_version)
       VALUES ('crm', 'C-819', repeat('4', 64), 'erp', 'E-819', repeat('5', 64), 'M1B', 'tax_conflict', 0.420,
               '{"tax_id": "B12345674", "name": {"a": "ACME RESEARCH PORTUGAL", "b": "ACME RESEARCH"}}', 'TEST-RULES')$q$);
SELECT pg_temp.fails(20, 'Rules v1.2: M1B must have the tax_conflict strength',
    $q$INSERT INTO governance.match_suggestions (a_system_code, a_source_key, a_content_sha256, b_system_code, b_source_key,
           b_content_sha256, rule_id, strength, score, compared_values, rules_version)
       VALUES ('crm', 'C-820', repeat('4', 64), 'erp', 'E-820', repeat('5', 64), 'M1B', 'strong', 0.420, '{}', 'TEST-RULES')$q$,
    'match_suggestions_rule_strength_valid');

\ir _report.sql
ROLLBACK;
