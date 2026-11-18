-- MDH-003 constraint tests: change requests, status history, approvals, evidence.
-- Integrity rules: I15, I18. All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

INSERT INTO hub.business_partners (bp_id, legal_name, country) VALUES ('BP-990901', 'Request Test S.L.', 'ES');

SELECT pg_temp.check(1, 'A new request gets an RQ-NNNNNN ID and starts as a draft',
    $q$WITH x AS (INSERT INTO governance.change_requests (request_type, risk, target_bp_id, requested_by, target_working_hours, rules_version)
                  VALUES ('change_low_risk', 'low', 'BP-990901', 'ST-904', 8, 'TEST-RULES') RETURNING request_id, status)
       SELECT request_id ~ '^RQ-[0-9]{6}$' AND status = 'draft' FROM x$q$);
SELECT pg_temp.ok(2, 'A submitted request is stored',
    $q$INSERT INTO governance.change_requests (request_id, request_type, risk, target_bp_id, status, requested_by,
           proposed_values, target_working_hours, created_at, submitted_at, rules_version)
       VALUES ('RQ-990901', 'change_high_risk', 'high', 'BP-990901', 'submitted', 'ST-904',
               '{"legal_name": "Request Test Iberia S.L."}', 16, '2026-11-02 09:00+01', '2026-11-02 09:30+01', 'TEST-RULES')$q$);
SELECT pg_temp.fails(3, 'An unknown request type is refused',
    $q$INSERT INTO governance.change_requests (request_type, risk, requested_by, target_working_hours, rules_version)
       VALUES ('rename', 'low', 'ST-904', 8, 'TEST-RULES')$q$,
    'change_requests_type_valid');
SELECT pg_temp.fails(4, 'A request past draft must have a submission time',
    $q$INSERT INTO governance.change_requests (request_type, risk, status, requested_by, target_working_hours, rules_version)
       VALUES ('change_low_risk', 'low', 'in_review', 'ST-904', 8, 'TEST-RULES')$q$,
    'change_requests_submitted_unless_draft');
SELECT pg_temp.fails(5, 'A closed request must have a closing time',
    $q$UPDATE governance.change_requests SET status = 'closed' WHERE request_id = 'RQ-990901'$q$,
    'change_requests_closed_time');
SELECT pg_temp.fails(6, 'A request cannot close before it was submitted',
    $q$UPDATE governance.change_requests SET status = 'closed', closed_at = '2026-11-02 09:00+01' WHERE request_id = 'RQ-990901'$q$,
    'change_requests_time_order');
SELECT pg_temp.fails(7, 'Proposed values must be a JSON object',
    $q$UPDATE governance.change_requests SET proposed_values = '["legal_name"]' WHERE request_id = 'RQ-990901'$q$,
    'change_requests_values_object');
SELECT pg_temp.ok(8, 'The first status row has no previous status',
    $q$INSERT INTO governance.request_status_history (request_id, seq, from_status, to_status, changed_by, changed_at)
       VALUES ('RQ-990901', 1, NULL, 'draft', 'ST-904', '2026-11-02 09:00+01'),
              ('RQ-990901', 2, 'draft', 'submitted', 'ST-904', '2026-11-02 09:30+01')$q$);
SELECT pg_temp.fails(9, 'Later status rows name the previous status',
    $q$INSERT INTO governance.request_status_history (request_id, seq, from_status, to_status, changed_by)
       VALUES ('RQ-990901', 3, NULL, 'in_review', 'ST-901')$q$,
    'request_status_history_first_row');
SELECT pg_temp.fails(10, 'A status row must change the status',
    $q$INSERT INTO governance.request_status_history (request_id, seq, from_status, to_status, changed_by)
       VALUES ('RQ-990901', 3, 'submitted', 'submitted', 'ST-901')$q$,
    'request_status_history_changes');
SELECT pg_temp.fails(11, 'I15: status history cannot be changed',
    $q$UPDATE governance.request_status_history SET changed_by = 'ST-901' WHERE request_id = 'RQ-990901'$q$,
    'I15');
SELECT pg_temp.ok(12, 'I18: another person approves the request',
    $q$INSERT INTO governance.request_approvals (request_id, requested_by, approver_id, approver_role, decision)
       VALUES ('RQ-990901', 'ST-904', 'ST-902', 'finance_controller', 'approved')$q$);
SELECT pg_temp.fails(13, 'I18: nobody approves a request they raised',
    $q$INSERT INTO governance.request_approvals (request_id, requested_by, approver_id, approver_role, decision)
       VALUES ('RQ-990901', 'ST-904', 'ST-904', 'finance_controller', 'approved')$q$,
    'request_approvals_four_eyes');
SELECT pg_temp.fails(14, 'I18: the approval cannot name a different requester than the request',
    $q$INSERT INTO governance.request_approvals (request_id, requested_by, approver_id, approver_role, decision)
       VALUES ('RQ-990901', 'ST-905', 'ST-904', 'finance_controller', 'approved')$q$,
    'request_approvals_request_requester');
SELECT pg_temp.fails(15, 'I18: the requester cannot be changed after an approval',
    $q$UPDATE governance.change_requests SET requested_by = 'ST-902' WHERE request_id = 'RQ-990901'$q$,
    'request_approvals_request_requester');
SELECT pg_temp.fails(16, 'An approver role outside governance is refused',
    $q$INSERT INTO governance.request_approvals (request_id, requested_by, approver_id, approver_role, decision)
       VALUES ('RQ-990901', 'ST-904', 'ST-903', 'ceo', 'approved')$q$,
    'request_approvals_role_valid');
SELECT pg_temp.fails(17, 'I15: approvals cannot be changed',
    $q$UPDATE governance.request_approvals SET decision = 'rejected' WHERE request_id = 'RQ-990901'$q$,
    'I15');
SELECT pg_temp.ok(18, 'Evidence is stored as a reference and checksum',
    $q$INSERT INTO governance.request_evidence (request_id, evidence_type, reference, document_sha256, added_by)
       VALUES ('RQ-990901', 'supporting_document', 'DMS/2026/000123', repeat('9', 64), 'ST-904')$q$);
SELECT pg_temp.fails(19, 'An evidence checksum must be 64 hex characters',
    $q$INSERT INTO governance.request_evidence (request_id, evidence_type, reference, document_sha256, added_by)
       VALUES ('RQ-990901', 'supporting_document', 'DMS/2026/000124', 'not-a-hash', 'ST-904')$q$,
    'sha256_hex_format');

\ir _report.sql
ROLLBACK;
