-- MoP Master Data Hub migration 005 (rules v1.5, G9): group tier of a partner with an unknown tier.
--
-- A partner whose own calculated customer tier is unknown keeps group tier unknown until its
-- industry and employee band are known. The existing rule "the group tier is never lower than
-- the partner's own known tier" stays.
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

ALTER TABLE hub.customer_roles DROP CONSTRAINT IF EXISTS customer_roles_group_tier_not_lower;
ALTER TABLE hub.customer_roles ADD CONSTRAINT customer_roles_group_tier_not_lower CHECK (
    (tier_calculated = 'unknown' AND tier_group = 'unknown')
    OR (tier_calculated <> 'unknown' AND tier_group <> 'unknown' AND tier_group <= tier_calculated)
);

DO $$
BEGIN
    RAISE NOTICE 'Migration 005 OK in %: unknown tier keeps group tier unknown (G9).', current_database();
END
$$;

COMMIT;
