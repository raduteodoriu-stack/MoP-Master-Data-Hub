-- MoP Master Data Hub migration 004 (rules v1.3): partner lifecycle, fraud and privacy.
--
-- Adds what rules v1.3 and the reviewed MDH-004 batch C need:
--   * block reasons insolvency and absorbed; a successor_of link after a merger
--   * contact status (active, left_company, bounced, erased), last verified and last contact
--   * VIES status on partners; last ERP activity on suppliers
--   * payee type (own account, factoring company, alternative payee) and holder-name outcome
--   * reference extracts in source: registry entries and the synthetic HR extract
--   * rule exceptions (K03 exceptions, K10 clearances), suppression list, former-names view
--   * request types corporate_event and reactivate_supplier
-- New integrity rules I21-I24 are described in docs/database_design.md.
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

-- =========================================================
-- 1. Block reasons (insolvency, absorbed)
-- =========================================================

ALTER TABLE hub.customer_roles DROP CONSTRAINT IF EXISTS customer_roles_block_reason_valid;
ALTER TABLE hub.customer_roles ADD CONSTRAINT customer_roles_block_reason_valid
    CHECK (block_reason IN ('duplicate', 'credit', 'payment', 'compliance', 'insolvency', 'absorbed'));

ALTER TABLE hub.supplier_roles DROP CONSTRAINT IF EXISTS supplier_roles_block_reason_valid;
ALTER TABLE hub.supplier_roles ADD CONSTRAINT supplier_roles_block_reason_valid
    CHECK (block_reason IN ('duplicate', 'credit', 'payment', 'compliance', 'insolvency', 'absorbed'));

-- =========================================================
-- 2. Successor link after a merger (I24)
-- =========================================================

ALTER TABLE hub.partner_relationships DROP CONSTRAINT IF EXISTS partner_relationships_type_valid;
ALTER TABLE hub.partner_relationships ADD CONSTRAINT partner_relationships_type_valid
    CHECK (relationship_type IN ('subsidiary_of', 'successor_of'));

-- One parent and one successor at a time: the exclusion now includes the link type.
ALTER TABLE hub.partner_relationships DROP CONSTRAINT IF EXISTS partner_relationships_one_parent;
ALTER TABLE hub.partner_relationships ADD CONSTRAINT partner_relationships_one_parent
    EXCLUDE USING gist (child_bp_id WITH =, relationship_type WITH =, valid_period WITH &&);

-- I12 applies to the company hierarchy (subsidiary_of) only. A successor link needs an active
-- successor that has no current successor of its own (no chains or loops of successors).
CREATE OR REPLACE FUNCTION hub.check_hierarchy() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    ancestors INTEGER;
    loop_found BOOLEAN;
    below INTEGER;
BEGIN
    IF NOT upper_inf(NEW.valid_period) OR NEW.child_bp_id = NEW.parent_bp_id THEN
        RETURN NEW;  -- closed (historic) links are not checked; a self-link is left to the CHECK
    END IF;

    IF NEW.relationship_type = 'successor_of' THEN
        IF NOT EXISTS (SELECT 1 FROM hub.business_partners
                       WHERE bp_id = NEW.parent_bp_id AND status = 'active') THEN
            RAISE EXCEPTION 'I24: the successor % must be an active partner', NEW.parent_bp_id;
        END IF;
        IF EXISTS (SELECT 1 FROM hub.partner_relationships
                   WHERE relationship_type = 'successor_of' AND upper_inf(valid_period)
                     AND child_bp_id = NEW.parent_bp_id
                     AND relationship_id <> NEW.relationship_id) THEN
            RAISE EXCEPTION 'I24: % has itself been absorbed; link to its successor instead', NEW.parent_bp_id;
        END IF;
        RETURN NEW;
    END IF;

    IF EXISTS (SELECT 1 FROM hub.business_partners
               WHERE bp_id IN (NEW.child_bp_id, NEW.parent_bp_id) AND status <> 'active') THEN
        RAISE EXCEPTION 'I12: both partners of a current hierarchy link must be active (% under %)',
            NEW.child_bp_id, NEW.parent_bp_id;
    END IF;

    WITH RECURSIVE up AS (
        SELECT NEW.parent_bp_id AS bp_id, 0 AS steps
      UNION ALL
        SELECT r.parent_bp_id, up.steps + 1
        FROM hub.partner_relationships r
        JOIN up ON r.child_bp_id = up.bp_id
        WHERE upper_inf(r.valid_period)
          AND r.relationship_type = 'subsidiary_of'
          AND r.relationship_id <> NEW.relationship_id
          AND up.steps < 10
    )
    SELECT max(steps), bool_or(bp_id = NEW.child_bp_id) INTO ancestors, loop_found FROM up;

    IF loop_found THEN
        RAISE EXCEPTION 'I12: % cannot be placed under % because that would create a loop',
            NEW.child_bp_id, NEW.parent_bp_id;
    END IF;

    WITH RECURSIVE down AS (
        SELECT NEW.child_bp_id AS bp_id, 0 AS steps
      UNION ALL
        SELECT r.child_bp_id, down.steps + 1
        FROM hub.partner_relationships r
        JOIN down ON r.parent_bp_id = down.bp_id
        WHERE upper_inf(r.valid_period)
          AND r.relationship_type = 'subsidiary_of'
          AND r.relationship_id <> NEW.relationship_id
          AND down.steps < 10
    )
    SELECT max(steps) INTO below FROM down;

    IF ancestors + 2 + below > 5 THEN
        RAISE EXCEPTION 'I12: hierarchy would have % levels (at most 5)', ancestors + 2 + below;
    END IF;

    RETURN NEW;
END
$$;

-- =========================================================
-- 3. Contact status, verification and last contact
-- =========================================================

ALTER TABLE hub.contact_persons ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ;
ALTER TABLE hub.contact_persons ADD COLUMN IF NOT EXISTS last_contact_at TIMESTAMPTZ;

ALTER TABLE hub.contact_persons DROP CONSTRAINT IF EXISTS contact_persons_status_valid;
ALTER TABLE hub.contact_persons ADD CONSTRAINT contact_persons_status_valid
    CHECK (status IN ('active', 'left_company', 'bounced', 'erased'));

-- I14, extended: any contact that is not erased keeps a name and work email; an erased one has none.
ALTER TABLE hub.contact_persons DROP CONSTRAINT IF EXISTS contact_persons_erasure_state;
ALTER TABLE hub.contact_persons ADD CONSTRAINT contact_persons_erasure_state CHECK (
    (status <> 'erased'
        AND first_name IS NOT NULL AND last_name IS NOT NULL AND work_email IS NOT NULL
        AND erased_at IS NULL AND erasure_request_id IS NULL)
    OR (status = 'erased'
        AND num_nonnulls(first_name, last_name, work_email, role_title, legal_basis,
                         last_verified_at, last_contact_at) = 0
        AND erased_at IS NOT NULL AND erasure_request_id IS NOT NULL)
);

-- =========================================================
-- 4. VIES status (I23) and supplier activity
-- =========================================================

ALTER TABLE hub.business_partners ADD COLUMN IF NOT EXISTS vies_status TEXT;
ALTER TABLE hub.business_partners ADD COLUMN IF NOT EXISTS vies_checked_at TIMESTAMPTZ;
ALTER TABLE hub.business_partners ADD COLUMN IF NOT EXISTS vies_evidence_ref TEXT;

ALTER TABLE hub.business_partners DROP CONSTRAINT IF EXISTS business_partners_vies_status_valid;
ALTER TABLE hub.business_partners ADD CONSTRAINT business_partners_vies_status_valid
    CHECK (vies_status IN ('valid', 'not_registered', 'invalid'));
ALTER TABLE hub.business_partners DROP CONSTRAINT IF EXISTS business_partners_vies_complete;
ALTER TABLE hub.business_partners ADD CONSTRAINT business_partners_vies_complete
    CHECK (num_nulls(vies_status, vies_checked_at, vies_evidence_ref) IN (0, 3));

ALTER TABLE hub.supplier_roles ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMPTZ;

-- =========================================================
-- 5. Payee type and holder-name outcome (I22)
-- =========================================================

ALTER TABLE hub.bank_accounts ADD COLUMN IF NOT EXISTS payee_type TEXT NOT NULL DEFAULT 'own_account';
ALTER TABLE hub.bank_accounts ADD COLUMN IF NOT EXISTS assignment_evidence_ref TEXT;
ALTER TABLE hub.bank_accounts ADD COLUMN IF NOT EXISTS holder_match TEXT;

ALTER TABLE hub.bank_accounts DROP CONSTRAINT IF EXISTS bank_accounts_payee_type_valid;
ALTER TABLE hub.bank_accounts ADD CONSTRAINT bank_accounts_payee_type_valid
    CHECK (payee_type IN ('own_account', 'factoring_company', 'alternative_payee'));
ALTER TABLE hub.bank_accounts DROP CONSTRAINT IF EXISTS bank_accounts_payee_evidence;
ALTER TABLE hub.bank_accounts ADD CONSTRAINT bank_accounts_payee_evidence
    CHECK ((payee_type = 'own_account') = (assignment_evidence_ref IS NULL));
ALTER TABLE hub.bank_accounts DROP CONSTRAINT IF EXISTS bank_accounts_holder_match_valid;
ALTER TABLE hub.bank_accounts ADD CONSTRAINT bank_accounts_holder_match_valid
    CHECK (holder_match IN ('match', 'close_match', 'no_match'));

-- =========================================================
-- 6. Request types
-- =========================================================

ALTER TABLE governance.change_requests DROP CONSTRAINT IF EXISTS change_requests_type_valid;
ALTER TABLE governance.change_requests ADD CONSTRAINT change_requests_type_valid CHECK (request_type IN (
    'create_customer', 'create_supplier', 'approve_supplier', 'change_low_risk',
    'override_customer_tier', 'change_high_risk', 'change_bank_details', 'corporate_event',
    'reactivate_supplier', 'block_unblock', 'merge_hierarchy', 'mass_upload', 'erase_contact'));

-- =========================================================
-- 7. Reference extracts (in source: never visible to reporting, A01)
-- =========================================================

CREATE TABLE IF NOT EXISTS source.registry_entries (
    registry_entry_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    country config.country_code NOT NULL,
    tax_id TEXT NOT NULL,
    registry_status TEXT NOT NULL,
    event_date DATE,
    notice_ref TEXT,
    successor_tax_id TEXT,
    extract_date DATE NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT registry_entries_status_valid
        CHECK (registry_status IN ('active', 'ceased', 'insolvency_proceedings', 'absorbed')),
    CONSTRAINT registry_entries_event_when_not_active
        CHECK (registry_status = 'active' OR event_date IS NOT NULL),
    CONSTRAINT registry_entries_successor_only_when_absorbed
        CHECK (successor_tax_id IS NULL OR registry_status = 'absorbed'),
    -- A company appears once per extract.
    CONSTRAINT registry_entries_once_per_extract UNIQUE (country, tax_id, extract_date)
);

-- Synthetic HR extract, used only for the employee-supplier cross-match (K10).
CREATE TABLE IF NOT EXISTS source.hr_employees (
    employee_ref TEXT NOT NULL,
    extract_date DATE NOT NULL,
    iban TEXT,
    street_std TEXT,
    postal_code TEXT,
    city TEXT,
    phone_std TEXT,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (employee_ref, extract_date),
    CONSTRAINT hr_employees_ref_format CHECK (employee_ref ~ '^E-[0-9]{4}$')
);

-- =========================================================
-- 8. Rule exceptions (K03 exceptions, K10 clearances)
-- =========================================================

CREATE TABLE IF NOT EXISTS governance.rule_exceptions (
    exception_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id TEXT NOT NULL,
    bp_id TEXT NOT NULL REFERENCES hub.business_partners (bp_id),
    reason TEXT NOT NULL,
    detail JSONB,
    approved_by TEXT NOT NULL REFERENCES config.staff (staff_id),
    valid_period config.valid_period NOT NULL,
    request_id TEXT REFERENCES governance.change_requests (request_id),
    CONSTRAINT rule_exceptions_rule_id_format CHECK (rule_id ~ '^[CVUKT][0-9]{2}$'),
    CONSTRAINT rule_exceptions_reason_not_blank CHECK (btrim(reason) <> ''),
    CONSTRAINT rule_exceptions_one_at_a_time
        EXCLUDE USING gist (rule_id WITH =, bp_id WITH =, valid_period WITH &&)
);

-- =========================================================
-- 9. Suppression list (I21, rule U04)
-- =========================================================

-- Only a hash of the lower-cased email is kept: enough to recognise the person, not to read it.
CREATE TABLE IF NOT EXISTS governance.suppression_list (
    email_sha256 config.sha256_hex PRIMARY KEY,
    reason TEXT NOT NULL,
    request_id TEXT REFERENCES governance.change_requests (request_id),
    added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT suppression_list_reason_valid CHECK (reason IN ('erased', 'opted_out')),
    CONSTRAINT suppression_list_erasure_request CHECK (reason <> 'erased' OR request_id IS NOT NULL)
);

DROP TRIGGER IF EXISTS suppression_list_append_only ON governance.suppression_list;
CREATE TRIGGER suppression_list_append_only BEFORE UPDATE OR DELETE ON governance.suppression_list
    FOR EACH ROW EXECUTE FUNCTION governance.refuse_change();

-- I21: a suppressed person cannot be stored again as a contact, whatever the letter case.
CREATE OR REPLACE FUNCTION hub.refuse_suppressed_contact() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.work_email IS NOT NULL AND EXISTS (
        SELECT 1 FROM governance.suppression_list
        WHERE email_sha256 = encode(sha256(convert_to(lower(NEW.work_email), 'UTF8')), 'hex')) THEN
        RAISE EXCEPTION 'I21: this contact is on the suppression list (U04); tell the DPO';
    END IF;
    RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS contact_persons_not_suppressed ON hub.contact_persons;
CREATE TRIGGER contact_persons_not_suppressed
    BEFORE INSERT OR UPDATE OF work_email ON hub.contact_persons
    FOR EACH ROW EXECUTE FUNCTION hub.refuse_suppressed_contact();

-- The erasure function now also puts the person on the suppression list.
CREATE OR REPLACE FUNCTION governance.erase_contact(p_contact_id UUID, p_request_id TEXT, p_staff_id TEXT)
RETURNS UUID
LANGUAGE plpgsql AS $$
DECLARE
    v_email TEXT;
    v_bp TEXT;
    v_count INTEGER;
    v_systems TEXT[];
    v_erasure UUID;
BEGIN
    SELECT work_email, bp_id INTO v_email, v_bp
    FROM hub.contact_persons WHERE contact_id = p_contact_id AND status <> 'erased'
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Contact % does not exist or is already erased', p_contact_id;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM governance.change_requests
                   WHERE request_id = p_request_id AND request_type = 'erase_contact'
                     AND status IN ('approved', 'applied')) THEN
        RAISE EXCEPTION 'Request % is not an approved erasure request', p_request_id;
    END IF;

    PERFORM set_config('mdh.erasure_in_progress', 'on', TRUE);

    WITH changed AS (
        UPDATE source.source_records
        SET payload = governance.redact_jsonb(payload, v_email),
            redacted_at = now(),
            redaction_request_id = p_request_id
        WHERE strpos(lower(payload::TEXT), lower(v_email)) > 0
          AND governance.redact_jsonb(payload, v_email) <> payload
        RETURNING system_code
    )
    SELECT count(*), coalesce(array_agg(DISTINCT system_code), '{}') INTO v_count, v_systems
    FROM changed;

    PERFORM set_config('mdh.erasure_in_progress', 'off', TRUE);

    UPDATE hub.contact_persons
    SET status = 'erased', first_name = NULL, last_name = NULL, work_email = NULL,
        role_title = NULL, legal_basis = NULL, last_verified_at = NULL, last_contact_at = NULL,
        erased_at = now(), erasure_request_id = p_request_id
    WHERE contact_id = p_contact_id;

    INSERT INTO governance.suppression_list (email_sha256, reason, request_id)
    VALUES (encode(sha256(convert_to(lower(v_email), 'UTF8')), 'hex'), 'erased', p_request_id)
    ON CONFLICT (email_sha256) DO NOTHING;

    INSERT INTO governance.erasure_proofs
        (request_id, contact_id, bp_id, source_records_redacted, systems_affected, completed_by)
    VALUES (p_request_id, p_contact_id, v_bp, v_count, v_systems, p_staff_id)
    RETURNING erasure_id INTO v_erasure;

    RETURN v_erasure;
END
$$;

-- =========================================================
-- 10. Current and former names, for matching (rules v1.3)
-- =========================================================

CREATE OR REPLACE VIEW hub.partner_names AS
    SELECT bp_id, legal_name AS name, 'legal' AS name_type, TRUE AS is_current
    FROM hub.business_partners WHERE legal_name IS NOT NULL
  UNION
    SELECT bp_id, trading_name, 'trading', TRUE
    FROM hub.business_partners WHERE trading_name IS NOT NULL
  UNION
    SELECT h.bp_id, h.old_value,
           CASE h.field_name WHEN 'legal_name' THEN 'legal' ELSE 'trading' END, FALSE
    FROM hub.field_history h
    JOIN hub.business_partners p USING (bp_id)
    WHERE h.field_name IN ('legal_name', 'trading_name') AND h.old_value IS NOT NULL
      AND h.old_value IS DISTINCT FROM p.legal_name AND h.old_value IS DISTINCT FROM p.trading_name;

COMMENT ON VIEW hub.partner_names IS
    'Current legal and trading names plus former names from field history; matching compares all of them (rules v1.3).';

-- =========================================================
-- 11. Access for reporting (A01-A03 extended)
-- =========================================================

GRANT SELECT ON hub.partner_names TO mdh_reporting;
GRANT SELECT (payee_type, holder_match) ON hub.bank_accounts TO mdh_reporting;
GRANT SELECT (last_verified_at, last_contact_at) ON hub.contact_persons TO mdh_reporting;
GRANT SELECT (exception_id, rule_id, bp_id, reason, approved_by, valid_period, request_id)
    ON governance.rule_exceptions TO mdh_reporting;
-- No grant on governance.suppression_list (hashes of personal data) or on the source extracts.

DO $$
BEGIN
    IF to_regclass('source.registry_entries') IS NULL OR to_regclass('source.hr_employees') IS NULL
       OR to_regclass('governance.rule_exceptions') IS NULL OR to_regclass('governance.suppression_list') IS NULL
       OR to_regclass('hub.partner_names') IS NULL THEN
        RAISE EXCEPTION 'Migration 004 incomplete in %', current_database();
    END IF;
    RAISE NOTICE 'Migration 004 OK in %: rules v1.3 fields, extracts, exceptions and suppression list.',
        current_database();
END
$$;

COMMIT;
