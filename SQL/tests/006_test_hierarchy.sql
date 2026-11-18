-- MDH-003 constraint tests: company hierarchy.
-- Integrity rule: I12 (rule K05). All test data is rolled back.

BEGIN;
\ir _helpers.sql
\o /dev/null

INSERT INTO hub.business_partners (bp_id, trading_name, country)
SELECT 'BP-99030' || n, 'Group Test ' || n, 'ES' FROM generate_series(1, 7) AS n;
UPDATE hub.business_partners SET status = 'merged', merged_into_bp_id = 'BP-990306', merged_at = now()
WHERE bp_id = 'BP-990307';

SELECT pg_temp.ok(1, 'A subsidiary is linked to its parent (2 levels)',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, valid_period) VALUES ('BP-990302', 'BP-990301', '[2026-01-01,)')$q$);
SELECT pg_temp.ok(2, 'A third level is added',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, valid_period) VALUES ('BP-990303', 'BP-990302', '[2026-01-01,)')$q$);
SELECT pg_temp.fails(3, 'I12: a partner has one parent at a time',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, valid_period) VALUES ('BP-990302', 'BP-990304', '[2026-06-01,)')$q$,
    'partner_relationships_one_parent');
SELECT pg_temp.fails(4, 'I12: a link that would create a loop is refused',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, valid_period) VALUES ('BP-990301', 'BP-990303', '[2026-01-01,)')$q$,
    'loop');
SELECT pg_temp.fails(5, 'I12: a partner cannot be its own parent',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, valid_period) VALUES ('BP-990304', 'BP-990304', '[2026-01-01,)')$q$,
    'partner_relationships_not_self');
SELECT pg_temp.ok(6, 'Five levels are allowed',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, valid_period) VALUES ('BP-990304', 'BP-990303', '[2026-01-01,)');
       INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, valid_period) VALUES ('BP-990305', 'BP-990304', '[2026-01-01,)')$q$);
SELECT pg_temp.fails(7, 'I12: a sixth level below is refused',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, valid_period) VALUES ('BP-990306', 'BP-990305', '[2026-01-01,)')$q$,
    'levels');
SELECT pg_temp.fails(8, 'I12: a new top parent above five levels is refused',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, valid_period) VALUES ('BP-990301', 'BP-990306', '[2026-01-01,)')$q$,
    'levels');
SELECT pg_temp.ok(9, 'A closed (historic) link is not checked against the current hierarchy',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, valid_period) VALUES ('BP-990306', 'BP-990305', '[2024-01-01,2025-01-01)')$q$);
SELECT pg_temp.fails(10, 'I12: a merged partner cannot be in the current hierarchy',
    $q$INSERT INTO hub.partner_relationships (child_bp_id, parent_bp_id, valid_period) VALUES ('BP-990307', 'BP-990306', '[2026-01-01,)')$q$,
    'must be active');
SELECT pg_temp.check(11, 'The whole group is read top-down with one recursive query (5 members, 5 levels)',
    $q$WITH RECURSIVE grp AS (
           SELECT 'BP-990301'::TEXT AS bp_id, 1 AS level
         UNION ALL
           SELECT r.child_bp_id, g.level + 1
           FROM hub.partner_relationships r JOIN grp g ON r.parent_bp_id = g.bp_id
           WHERE upper_inf(r.valid_period))
       SELECT count(*) = 5 AND max(level) = 5 FROM grp$q$);

\ir _report.sql
ROLLBACK;
