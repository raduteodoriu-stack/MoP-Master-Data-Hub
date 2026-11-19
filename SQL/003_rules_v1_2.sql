-- MoP Master Data Hub migration 003 (rules v1.2): same tax ID, different names.
--
-- Rules v1.2 links two records on a shared tax ID automatically (M1) only when their
-- standardised names also agree. A shared tax ID with clearly different names becomes a
-- high-priority suggestion for the steward (M1B, strength 'tax_conflict'): one legal entity
-- with an office or trading name, or a subsidiary carrying its mother company's tax ID.
-- This migration lets governance.match_suggestions store M1B. Quality rule K09 needs no
-- change: rule IDs already follow the C/V/U/K/T pattern.
--
-- Safe to run again.

BEGIN;

DO $$
BEGIN
    IF current_database() NOT IN ('mop_mdh', 'mop_mdh_test') THEN
        RAISE EXCEPTION 'I01: wrong database %. Connect to mop_mdh or mop_mdh_test.',
            current_database();
    END IF;
END
$$;

ALTER TABLE governance.match_suggestions
    DROP CONSTRAINT IF EXISTS match_suggestions_rule_strength_valid;

ALTER TABLE governance.match_suggestions
    ADD CONSTRAINT match_suggestions_rule_strength_valid CHECK (
        (rule_id, strength) IN (('M1B', 'tax_conflict'), ('M2', 'group'), ('M3', 'strong'),
                                ('M4', 'normal'), ('M5', 'weak'), ('M6', 'bank_risk'))
    );

DO $$
BEGIN
    RAISE NOTICE 'Migration 003 OK in %: M1B suggestions allowed.', current_database();
END
$$;

COMMIT;
