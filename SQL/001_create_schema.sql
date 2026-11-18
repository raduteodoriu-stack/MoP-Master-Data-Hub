-- MoP Master Data Hub: PostgreSQL schema
-- MDH-003: data foundation
--
-- Creates the four schemas (config, source, hub, governance), 25 tables, the integrity
-- rules I01-I20 and the access rules A01-A03 described in docs/database_design.md.
-- Every column is described in docs/data_dictionary.md.
--
-- The database enforces structure and integrity. Check digits, matching, survivorship and
-- mandatory fields per lifecycle stage are applied by the engine, which reads
-- rules/MDH-RULES-v1.1.json.
--
-- Run against an EMPTY mop_mdh or mop_mdh_test database:
--   psql -d mop_mdh -v ON_ERROR_STOP=1 -f SQL/001_create_schema.sql
-- Later migrations (002, ...) are applied after this one, in number order.
-- The final section checks that all 25 tables exist.

BEGIN;

-- I01: stop if connected to the wrong database.
DO $$
BEGIN
    IF current_database() NOT IN ('mop_mdh', 'mop_mdh_test') THEN
        RAISE EXCEPTION 'I01: wrong database %. Connect to mop_mdh or mop_mdh_test.',
            current_database();
    END IF;
END
$$;

-- Equality inside EXCLUDE constraints on text and uuid columns (D5).
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE SCHEMA config;
CREATE SCHEMA source;
CREATE SCHEMA hub;
CREATE SCHEMA governance;

COMMENT ON SCHEMA config IS 'Rules versions, source systems, staff and their roles (MDH-003).';
COMMENT ON SCHEMA source IS 'Source records exactly as received, never changed (MDH-003).';
COMMENT ON SCHEMA hub IS 'Golden business partners, their roles and the links to source records (MDH-003).';
COMMENT ON SCHEMA governance IS 'Quality, matching, merges, requests, approvals and erasure (MDH-003).';

-- =========================================================
-- 0. Reusable value types (domains)
-- =========================================================

CREATE DOMAIN config.country_code AS TEXT
    CONSTRAINT country_code_format CHECK (VALUE ~ '^[A-Z]{2}$');

CREATE DOMAIN config.email_address AS TEXT
    CONSTRAINT email_address_format
        CHECK (VALUE ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$');

CREATE DOMAIN config.sha256_hex AS TEXT
    CONSTRAINT sha256_hex_format CHECK (VALUE ~ '^[0-9a-f]{64}$');

CREATE DOMAIN config.customer_tier AS TEXT
    CONSTRAINT customer_tier_value CHECK (VALUE IN ('tier_1', 'tier_2', 'tier_3', 'unknown'));

-- A valid period has a start and is not empty; an open end means "current".
CREATE DOMAIN config.valid_period AS TSTZRANGE
    CONSTRAINT valid_period_bounded_start CHECK (NOT isempty(VALUE) AND NOT lower_inf(VALUE));

-- =========================================================
-- 1. config
-- =========================================================

CREATE TABLE config.rule_versions (
    rules_version TEXT PRIMARY KEY,
    file_sha256 config.sha256_hex NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes TEXT,
    CONSTRAINT rule_versions_name_not_blank CHECK (btrim(rules_version) <> '')
);

CREATE TABLE config.source_systems (
    system_code TEXT PRIMARY KEY,
    system_name TEXT NOT NULL,
    description TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT source_systems_code_valid
        CHECK (system_code IN ('crm', 'erp', 'support', 'procurement_sheet'))
);

INSERT INTO config.source_systems (system_code, system_name, description) VALUES
    ('crm', 'CRM (HubSpot)', 'Companies and contacts used by Sales; LeadFlow''s companies'),
    ('erp', 'Finance / ERP', 'Customer and supplier accounts used for invoicing and payment'),
    ('support', 'Support desk', 'Organisations and contacts raising support tickets'),
    ('procurement_sheet', 'Procurement spreadsheet', 'Suppliers kept by Operations until migrated to the hub');

CREATE TABLE config.staff (
    staff_id TEXT PRIMARY KEY,
    full_name TEXT NOT NULL,
    email config.email_address NOT NULL,
    department TEXT NOT NULL,
    sales_owner_id TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT staff_id_format CHECK (staff_id ~ '^ST-[0-9]{3}$'),
    CONSTRAINT staff_email_unique UNIQUE (email),
    CONSTRAINT staff_email_synthetic CHECK (email ~ '\.example$'),
    CONSTRAINT staff_department_valid
        CHECK (department IN ('sales', 'finance', 'operations', 'customer_success', 'revops', 'legal')),
    CONSTRAINT staff_sales_owner_id_unique UNIQUE (sales_owner_id),
    CONSTRAINT staff_sales_owner_id_format
        CHECK (sales_owner_id ~ '^((ES|PT|FR)-[0-9]{2}|SM-[0-9]{2}|AE-(ES|PT|FR)-[0-9]{2}|AM-[0-9]{2})$')
);

CREATE TABLE config.staff_roles (
    staff_role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id TEXT NOT NULL REFERENCES config.staff (staff_id),
    role TEXT NOT NULL,
    valid_period config.valid_period NOT NULL,
    CONSTRAINT staff_roles_role_valid
        CHECK (role IN ('finance_controller', 'sales_director', 'head_of_operations', 'steward',
                        'requester', 'system_custodian', 'dpo')),
    -- I19: the same person holds the same role in non-overlapping periods only.
    CONSTRAINT staff_roles_no_overlap
        EXCLUDE USING gist (staff_id WITH =, role WITH =, valid_period WITH &&)
);

-- =========================================================
-- 2. hub.business_partners (created early: many tables refer to it)
-- =========================================================

CREATE SEQUENCE hub.bp_id_seq MINVALUE 1 MAXVALUE 999999 NO CYCLE;

CREATE TABLE hub.business_partners (
    bp_id TEXT PRIMARY KEY DEFAULT 'BP-' || lpad(nextval('hub.bp_id_seq')::TEXT, 6, '0'),
    status TEXT NOT NULL DEFAULT 'active',
    merged_into_bp_id TEXT REFERENCES hub.business_partners (bp_id),
    merged_at TIMESTAMPTZ,
    legal_name TEXT,
    trading_name TEXT,
    legal_form TEXT,
    country config.country_code NOT NULL,
    tax_id TEXT,
    -- I08: derived from country and tax ID, never typed.
    vat_number TEXT GENERATED ALWAYS AS (
        CASE
            WHEN tax_id IS NULL THEN NULL
            WHEN country IN ('ES', 'PT') THEN country || tax_id
            WHEN country = 'FR' AND tax_id ~ '^[0-9]{9}$'
                THEN 'FR' || lpad(((12 + 3 * (tax_id::BIGINT % 97)) % 97)::TEXT, 2, '0') || tax_id
            ELSE NULL
        END
    ) STORED,
    web_domain TEXT,
    phone TEXT,
    last_reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- I05
    CONSTRAINT business_partners_id_format CHECK (bp_id ~ '^BP-[0-9]{6}$'),
    -- I06
    CONSTRAINT business_partners_status_valid CHECK (status IN ('active', 'merged')),
    CONSTRAINT business_partners_merge_pointer CHECK (
        (status = 'active' AND merged_into_bp_id IS NULL AND merged_at IS NULL)
        OR (status = 'merged' AND merged_into_bp_id IS NOT NULL AND merged_at IS NOT NULL
            AND merged_into_bp_id <> bp_id)
    ),
    CONSTRAINT business_partners_has_name CHECK (num_nonnulls(legal_name, trading_name) >= 1),
    CONSTRAINT business_partners_names_not_blank CHECK (
        (legal_name IS NULL OR btrim(legal_name) <> '')
        AND (trading_name IS NULL OR btrim(trading_name) <> '')
    ),
    -- I09: formats. Check digits are verified by the engine (V01).
    CONSTRAINT business_partners_tax_id_format CHECK (
        tax_id IS NULL
        OR (country = 'ES' AND tax_id ~ '^[ABCDEFGHJNPQRSUVW][0-9]{7}[0-9A-J]$')
        OR (country = 'PT' AND tax_id ~ '^[5-9][0-9]{8}$')
        OR (country = 'FR' AND tax_id ~ '^[0-9]{9}$')
        OR (country NOT IN ('ES', 'PT', 'FR') AND tax_id ~ '^[A-Z0-9]{2,20}$')
    ),
    CONSTRAINT business_partners_web_domain_format CHECK (
        web_domain ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'
        AND web_domain !~ '^www\.'
    ),
    CONSTRAINT business_partners_phone_format CHECK (phone ~ '^\+[0-9]{6,15}$')
);

-- I07 (rule U01): one active partner per country and tax ID.
CREATE UNIQUE INDEX business_partners_one_active_per_tax_id
    ON hub.business_partners (country, tax_id)
    WHERE status = 'active' AND tax_id IS NOT NULL;

CREATE INDEX business_partners_merged_into_idx ON hub.business_partners (merged_into_bp_id);

-- I05, I06: partners are never deleted, the ID never changes, a merge points to an active
-- survivor, and a partner that others were merged into cannot itself be merged.
CREATE FUNCTION hub.guard_business_partner() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'I05: business partner % cannot be deleted; merge it instead', OLD.bp_id;
    END IF;
    IF TG_OP = 'UPDATE' THEN
        IF NEW.bp_id <> OLD.bp_id THEN
            RAISE EXCEPTION 'I05: business partner ID % cannot change', OLD.bp_id;
        END IF;
        NEW.updated_at := now();
    END IF;
    IF NEW.status = 'merged' AND NEW.merged_into_bp_id IS NOT NULL THEN  -- a missing pointer is left to the CHECK
        IF NOT EXISTS (SELECT 1 FROM hub.business_partners
                       WHERE bp_id = NEW.merged_into_bp_id AND status = 'active') THEN
            RAISE EXCEPTION 'I06: % must be merged into an active partner (got %)',
                NEW.bp_id, NEW.merged_into_bp_id;
        END IF;
        IF EXISTS (SELECT 1 FROM hub.business_partners WHERE merged_into_bp_id = NEW.bp_id) THEN
            RAISE EXCEPTION 'I06: % is a merge survivor and cannot itself be merged; re-point its absorbed partners first',
                NEW.bp_id;
        END IF;
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER business_partners_guard
    BEFORE INSERT OR UPDATE OR DELETE ON hub.business_partners
    FOR EACH ROW EXECUTE FUNCTION hub.guard_business_partner();

-- =========================================================
-- 3. governance.change_requests (created early: hub and source refer to it)
-- =========================================================

CREATE SEQUENCE governance.request_id_seq MINVALUE 1 MAXVALUE 999999 NO CYCLE;

CREATE TABLE governance.change_requests (
    request_id TEXT PRIMARY KEY DEFAULT 'RQ-' || lpad(nextval('governance.request_id_seq')::TEXT, 6, '0'),
    request_type TEXT NOT NULL,
    risk TEXT NOT NULL,
    target_bp_id TEXT REFERENCES hub.business_partners (bp_id),
    status TEXT NOT NULL DEFAULT 'draft',
    requested_by TEXT NOT NULL REFERENCES config.staff (staff_id),
    proposed_values JSONB NOT NULL DEFAULT '{}'::JSONB,
    reason TEXT,
    target_working_hours INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    submitted_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    rules_version TEXT NOT NULL REFERENCES config.rule_versions (rules_version),

    CONSTRAINT change_requests_id_format CHECK (request_id ~ '^RQ-[0-9]{6}$'),
    CONSTRAINT change_requests_type_valid CHECK (request_type IN (
        'create_customer', 'create_supplier', 'approve_supplier', 'change_low_risk',
        'override_customer_tier', 'change_high_risk', 'change_bank_details', 'block_unblock',
        'merge_hierarchy', 'mass_upload', 'erase_contact')),
    CONSTRAINT change_requests_risk_valid CHECK (risk IN ('low', 'high')),
    CONSTRAINT change_requests_status_valid CHECK (status IN (
        'draft', 'submitted', 'in_review', 'awaiting_approval', 'approved', 'applied',
        'closed', 'returned', 'rejected', 'cancelled')),
    CONSTRAINT change_requests_values_object CHECK (jsonb_typeof(proposed_values) = 'object'),
    CONSTRAINT change_requests_target_positive CHECK (target_working_hours > 0),
    CONSTRAINT change_requests_submitted_unless_draft
        CHECK (status IN ('draft', 'cancelled') OR submitted_at IS NOT NULL),
    CONSTRAINT change_requests_closed_time
        CHECK ((status IN ('closed', 'rejected', 'cancelled')) = (closed_at IS NOT NULL)),
    CONSTRAINT change_requests_time_order CHECK (
        (submitted_at IS NULL OR submitted_at >= created_at)
        AND (closed_at IS NULL OR closed_at >= coalesce(submitted_at, created_at))
    ),
    -- Target of the composite foreign key that enforces I18.
    CONSTRAINT change_requests_request_requester_unique UNIQUE (request_id, requested_by)
);

CREATE INDEX change_requests_target_idx ON governance.change_requests (target_bp_id);
CREATE INDEX change_requests_open_idx ON governance.change_requests (status)
    WHERE status NOT IN ('closed', 'rejected', 'cancelled');

-- =========================================================
-- 4. source
-- =========================================================

CREATE TABLE source.load_batches (
    batch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    system_code TEXT NOT NULL REFERENCES config.source_systems (system_code),
    file_name TEXT NOT NULL,
    file_sha256 config.sha256_hex NOT NULL,
    extracted_at TIMESTAMPTZ NOT NULL,
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    rows_received INTEGER NOT NULL,
    rows_stored INTEGER NOT NULL,
    rows_unchanged INTEGER NOT NULL,
    rows_rejected INTEGER NOT NULL,
    -- I03: the same file is loaded once per system.
    CONSTRAINT load_batches_file_once UNIQUE (system_code, file_sha256),
    CONSTRAINT load_batches_counts_not_negative
        CHECK (rows_received >= 0 AND rows_stored >= 0 AND rows_unchanged >= 0 AND rows_rejected >= 0),
    CONSTRAINT load_batches_counts_balance
        CHECK (rows_received = rows_stored + rows_unchanged + rows_rejected),
    CONSTRAINT load_batches_batch_system_unique UNIQUE (batch_id, system_code)
);

CREATE TABLE source.source_records (
    source_record_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    system_code TEXT NOT NULL REFERENCES config.source_systems (system_code),
    source_key TEXT NOT NULL,
    record_version INTEGER NOT NULL,
    content_sha256 config.sha256_hex NOT NULL,
    payload JSONB NOT NULL,
    batch_id UUID NOT NULL,
    source_updated_at TIMESTAMPTZ,
    deleted_in_source BOOLEAN NOT NULL DEFAULT FALSE,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    redacted_at TIMESTAMPTZ,
    redaction_request_id TEXT REFERENCES governance.change_requests (request_id),

    CONSTRAINT source_records_key_not_blank CHECK (btrim(source_key) <> ''),
    CONSTRAINT source_records_version_positive CHECK (record_version >= 1),
    CONSTRAINT source_records_version_unique UNIQUE (system_code, source_key, record_version),
    -- I03: the same version of a record is stored once.
    CONSTRAINT source_records_content_once UNIQUE (system_code, source_key, content_sha256),
    CONSTRAINT source_records_payload_object CHECK (jsonb_typeof(payload) = 'object'),
    CONSTRAINT source_records_redaction_pair
        CHECK (num_nulls(redacted_at, redaction_request_id) IN (0, 2)),
    -- A record comes from a batch of the same system.
    CONSTRAINT source_records_batch_same_system FOREIGN KEY (batch_id, system_code)
        REFERENCES source.load_batches (batch_id, system_code)
);

CREATE INDEX source_records_batch_idx ON source.source_records (batch_id);

-- I02: source records are insert-only. The only exception is redaction by
-- governance.erase_contact(), which sets mdh.erasure_in_progress for its own transaction
-- and may change nothing but the payload and the two redaction columns.
CREATE FUNCTION source.guard_source_record() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'I02: source records are insert-only (delete refused for %)', OLD.source_record_id;
    END IF;
    IF coalesce(current_setting('mdh.erasure_in_progress', TRUE), '') <> 'on' THEN
        RAISE EXCEPTION 'I02: source records are insert-only (update refused for %)', OLD.source_record_id;
    END IF;
    IF (NEW.source_record_id, NEW.system_code, NEW.source_key, NEW.record_version,
        NEW.content_sha256, NEW.batch_id, NEW.source_updated_at, NEW.deleted_in_source,
        NEW.received_at)
       IS DISTINCT FROM
       (OLD.source_record_id, OLD.system_code, OLD.source_key, OLD.record_version,
        OLD.content_sha256, OLD.batch_id, OLD.source_updated_at, OLD.deleted_in_source,
        OLD.received_at) THEN
        RAISE EXCEPTION 'I02: an erasure may change only the payload and redaction columns of %',
            OLD.source_record_id;
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER source_records_insert_only
    BEFORE UPDATE OR DELETE ON source.source_records
    FOR EACH ROW EXECUTE FUNCTION source.guard_source_record();

-- Standardised values are written by the engine. They are NOT format-checked here: a value
-- can be standardised and still invalid, and the quality rules must be able to report it.
CREATE TABLE source.standardised_records (
    source_record_id UUID PRIMARY KEY REFERENCES source.source_records (source_record_id),
    rules_version TEXT NOT NULL REFERENCES config.rule_versions (rules_version),
    role_hint TEXT NOT NULL DEFAULT 'unknown',
    name_std TEXT,
    legal_form_std TEXT,
    country TEXT,
    tax_id_std TEXT,
    web_domain_std TEXT,
    street_std TEXT,
    postal_code_std TEXT,
    city_std TEXT,
    phone_std TEXT,
    iban_std TEXT,
    standardised_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT standardised_records_role_hint_valid
        CHECK (role_hint IN ('customer', 'supplier', 'both', 'unknown'))
);

CREATE INDEX standardised_records_tax_idx ON source.standardised_records (country, tax_id_std);
CREATE INDEX standardised_records_domain_idx ON source.standardised_records (web_domain_std);

-- =========================================================
-- 5. hub: roles, addresses, bank accounts, contacts, hierarchy
-- =========================================================

CREATE TABLE hub.customer_roles (
    bp_id TEXT PRIMARY KEY REFERENCES hub.business_partners (bp_id),
    stage TEXT NOT NULL DEFAULT 'prospect',
    stage_changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    account_owner_id TEXT REFERENCES config.staff (sales_owner_id),
    industry_code TEXT NOT NULL DEFAULT 'unknown',
    employee_band TEXT NOT NULL DEFAULT 'unknown',
    tier_calculated config.customer_tier NOT NULL DEFAULT 'unknown',
    tier_score SMALLINT,
    tier_reason_codes TEXT[] NOT NULL DEFAULT '{}',
    tier_group config.customer_tier NOT NULL DEFAULT 'unknown',
    tier_override config.customer_tier,
    tier_override_request_id TEXT REFERENCES governance.change_requests (request_id),
    tier_effective TEXT GENERATED ALWAYS AS (coalesce(tier_override, tier_group)) STORED,
    tier_rules_version TEXT REFERENCES config.rule_versions (rules_version),
    tier_calculated_at TIMESTAMPTZ,
    bill_to_bp_id TEXT REFERENCES hub.business_partners (bp_id),
    payment_terms TEXT,
    invoice_email config.email_address,
    block_reason TEXT,
    blocked_by TEXT REFERENCES config.staff (staff_id),
    blocked_at TIMESTAMPTZ,
    block_request_id TEXT REFERENCES governance.change_requests (request_id),

    -- I10
    CONSTRAINT customer_roles_stage_valid CHECK (stage IN ('prospect', 'customer', 'inactive')),
    CONSTRAINT customer_roles_industry_valid CHECK (industry_code IN (
        'market_research', 'polling', 'research_consultancy', 'panel_sample_provider',
        'research_technology', 'advertising_media_pr_agency', 'ux_research_agency',
        'management_consultancy', 'consumer_goods', 'retail_ecommerce', 'technology_telecoms',
        'financial_services', 'automotive_mobility', 'healthcare_pharma', 'travel_hospitality',
        'media_entertainment_gaming', 'energy_utilities', 'public_academic_nonprofit',
        'other', 'unknown')),
    CONSTRAINT customer_roles_employee_band_valid
        CHECK (employee_band IN ('1-10', '11-49', '50-249', '250-999', '1000_plus', 'unknown')),
    CONSTRAINT customer_roles_tier_score_range CHECK (tier_score BETWEEN 0 AND 60),
    CONSTRAINT customer_roles_tier_score_when_known
        CHECK ((tier_calculated = 'unknown') = (tier_score IS NULL)),
    -- The group tier is never lower than the partner's own known tier ('tier_1' is highest).
    CONSTRAINT customer_roles_group_tier_not_lower CHECK (
        tier_calculated = 'unknown' OR (tier_group <> 'unknown' AND tier_group <= tier_calculated)
    ),
    CONSTRAINT customer_roles_override_not_unknown CHECK (tier_override <> 'unknown'),
    CONSTRAINT customer_roles_override_pair
        CHECK (num_nulls(tier_override, tier_override_request_id) IN (0, 2)),
    CONSTRAINT customer_roles_payment_terms_valid
        CHECK (payment_terms IN ('NET15', 'NET30', 'NET45', 'NET60')),
    -- I11 (rule K07)
    CONSTRAINT customer_roles_block_reason_valid
        CHECK (block_reason IN ('duplicate', 'credit', 'payment', 'compliance')),
    CONSTRAINT customer_roles_block_complete
        CHECK (num_nulls(block_reason, blocked_by, blocked_at) IN (0, 3)),
    CONSTRAINT customer_roles_block_request_only_when_blocked
        CHECK (block_request_id IS NULL OR block_reason IS NOT NULL)
);

CREATE INDEX customer_roles_owner_idx ON hub.customer_roles (account_owner_id);

CREATE TABLE hub.supplier_roles (
    bp_id TEXT PRIMARY KEY REFERENCES hub.business_partners (bp_id),
    stage TEXT NOT NULL DEFAULT 'requested',
    stage_changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    category TEXT NOT NULL,
    internal_contact_id TEXT NOT NULL REFERENCES config.staff (staff_id),
    payment_terms TEXT,
    remittance_email config.email_address,
    approved_at TIMESTAMPTZ,
    approved_by TEXT REFERENCES config.staff (staff_id),
    block_reason TEXT,
    blocked_by TEXT REFERENCES config.staff (staff_id),
    blocked_at TIMESTAMPTZ,
    block_request_id TEXT REFERENCES governance.change_requests (request_id),

    -- I10
    CONSTRAINT supplier_roles_stage_valid CHECK (stage IN ('requested', 'approved', 'inactive')),
    CONSTRAINT supplier_roles_category_valid CHECK (category IN (
        'panel_sample_provider', 'software', 'professional_services', 'facilities', 'other')),
    CONSTRAINT supplier_roles_payment_terms_valid
        CHECK (payment_terms IN ('NET15', 'NET30', 'NET45', 'NET60')),
    CONSTRAINT supplier_roles_approval_pair CHECK (num_nulls(approved_at, approved_by) IN (0, 2)),
    CONSTRAINT supplier_roles_approved_has_approval
        CHECK (stage <> 'approved' OR approved_at IS NOT NULL),
    -- I11 (rule K07)
    CONSTRAINT supplier_roles_block_reason_valid
        CHECK (block_reason IN ('duplicate', 'credit', 'payment', 'compliance')),
    CONSTRAINT supplier_roles_block_complete
        CHECK (num_nulls(block_reason, blocked_by, blocked_at) IN (0, 3)),
    CONSTRAINT supplier_roles_block_request_only_when_blocked
        CHECK (block_request_id IS NULL OR block_reason IS NOT NULL)
);

CREATE TABLE hub.addresses (
    address_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bp_id TEXT NOT NULL REFERENCES hub.business_partners (bp_id),
    address_type TEXT NOT NULL,
    street TEXT NOT NULL,
    postal_code TEXT NOT NULL,
    city TEXT NOT NULL,
    region TEXT,
    country config.country_code NOT NULL,
    valid_period config.valid_period NOT NULL,
    request_id TEXT REFERENCES governance.change_requests (request_id),

    CONSTRAINT addresses_type_valid CHECK (address_type IN ('registered', 'billing', 'branch')),
    CONSTRAINT addresses_lines_not_blank CHECK (btrim(street) <> '' AND btrim(city) <> ''),
    -- I09: postal code per country.
    CONSTRAINT addresses_postal_code_format CHECK (
        (country = 'ES' AND postal_code ~ '^(0[1-9]|[1-4][0-9]|5[0-2])[0-9]{3}$')
        OR (country = 'PT' AND postal_code ~ '^[0-9]{4}-[0-9]{3}$')
        OR (country = 'FR' AND postal_code ~ '^[0-9]{5}$')
        OR (country NOT IN ('ES', 'PT', 'FR') AND btrim(postal_code) <> '')
    ),
    -- One registered and one billing address at a time; branches may overlap.
    CONSTRAINT addresses_one_current_per_type
        EXCLUDE USING gist (bp_id WITH =, address_type WITH =, valid_period WITH &&)
        WHERE (address_type IN ('registered', 'billing'))
);

CREATE TABLE hub.bank_accounts (
    bank_account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bp_id TEXT NOT NULL REFERENCES hub.supplier_roles (bp_id),
    iban TEXT NOT NULL,
    iban_country TEXT GENERATED ALWAYS AS (left(iban, 2)) STORED,
    account_holder_name TEXT NOT NULL,
    valid_period config.valid_period NOT NULL,
    verified_at TIMESTAMPTZ,
    verification_method TEXT,
    verified_by TEXT REFERENCES config.staff (staff_id),
    request_id TEXT REFERENCES governance.change_requests (request_id),

    -- I09: structure and length per country. Check digits are verified by the engine (V09).
    CONSTRAINT bank_accounts_iban_format CHECK (iban ~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$'),
    CONSTRAINT bank_accounts_iban_length CHECK (
        (left(iban, 2) = 'ES' AND length(iban) = 24)
        OR (left(iban, 2) = 'PT' AND length(iban) = 25)
        OR (left(iban, 2) = 'FR' AND length(iban) = 27)
        OR left(iban, 2) NOT IN ('ES', 'PT', 'FR')
    ),
    CONSTRAINT bank_accounts_holder_not_blank CHECK (btrim(account_holder_name) <> ''),
    -- I13
    CONSTRAINT bank_accounts_verification_method_valid
        CHECK (verification_method IN ('callback_known_contact', 'bank_letter', 'supplier_portal')),
    CONSTRAINT bank_accounts_verification_complete
        CHECK (num_nulls(verified_at, verification_method, verified_by) IN (0, 3)),
    CONSTRAINT bank_accounts_one_current
        EXCLUDE USING gist (bp_id WITH =, valid_period WITH &&)
);

CREATE INDEX bank_accounts_iban_idx ON hub.bank_accounts (iban);

CREATE TABLE hub.contact_persons (
    contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bp_id TEXT NOT NULL REFERENCES hub.business_partners (bp_id),
    status TEXT NOT NULL DEFAULT 'active',
    first_name TEXT,
    last_name TEXT,
    work_email config.email_address,
    role_title TEXT,
    legal_basis TEXT,
    source_record_id UUID REFERENCES source.source_records (source_record_id),
    erased_at TIMESTAMPTZ,
    erasure_request_id TEXT REFERENCES governance.change_requests (request_id),

    CONSTRAINT contact_persons_status_valid CHECK (status IN ('active', 'erased')),
    CONSTRAINT contact_persons_legal_basis_valid
        CHECK (legal_basis IN ('contract', 'legitimate_interest', 'consent')),
    -- I14
    CONSTRAINT contact_persons_erasure_state CHECK (
        (status = 'active'
            AND first_name IS NOT NULL AND last_name IS NOT NULL AND work_email IS NOT NULL
            AND erased_at IS NULL AND erasure_request_id IS NULL)
        OR (status = 'erased'
            AND num_nonnulls(first_name, last_name, work_email, role_title, legal_basis) = 0
            AND erased_at IS NOT NULL AND erasure_request_id IS NOT NULL)
    )
);

CREATE INDEX contact_persons_bp_idx ON hub.contact_persons (bp_id);

CREATE TABLE hub.partner_relationships (
    relationship_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_bp_id TEXT NOT NULL REFERENCES hub.business_partners (bp_id),
    parent_bp_id TEXT NOT NULL REFERENCES hub.business_partners (bp_id),
    relationship_type TEXT NOT NULL DEFAULT 'subsidiary_of',
    valid_period config.valid_period NOT NULL,
    request_id TEXT REFERENCES governance.change_requests (request_id),

    CONSTRAINT partner_relationships_type_valid CHECK (relationship_type IN ('subsidiary_of')),
    -- I12
    CONSTRAINT partner_relationships_not_self CHECK (child_bp_id <> parent_bp_id),
    CONSTRAINT partner_relationships_one_parent
        EXCLUDE USING gist (child_bp_id WITH =, valid_period WITH &&)
);

CREATE INDEX partner_relationships_parent_idx ON hub.partner_relationships (parent_bp_id);

-- I12 (rule K05): for a current link, both partners are active, there is no loop, and the
-- chain from the top parent down to the deepest descendant is at most five levels.
CREATE FUNCTION hub.check_hierarchy() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    ancestors INTEGER;
    loop_found BOOLEAN;
    below INTEGER;
BEGIN
    IF NOT upper_inf(NEW.valid_period) OR NEW.child_bp_id = NEW.parent_bp_id THEN
        RETURN NEW;  -- closed (historic) links are not checked; a self-link is left to the CHECK
    END IF;

    IF EXISTS (SELECT 1 FROM hub.business_partners
               WHERE bp_id IN (NEW.child_bp_id, NEW.parent_bp_id) AND status <> 'active') THEN
        RAISE EXCEPTION 'I12: both partners of a current hierarchy link must be active (% under %)',
            NEW.child_bp_id, NEW.parent_bp_id;
    END IF;

    -- Walk up from the new parent through current links.
    WITH RECURSIVE up AS (
        SELECT NEW.parent_bp_id AS bp_id, 0 AS steps
      UNION ALL
        SELECT r.parent_bp_id, up.steps + 1
        FROM hub.partner_relationships r
        JOIN up ON r.child_bp_id = up.bp_id
        WHERE upper_inf(r.valid_period)
          AND r.relationship_id <> NEW.relationship_id
          AND up.steps < 10
    )
    SELECT max(steps), bool_or(bp_id = NEW.child_bp_id) INTO ancestors, loop_found FROM up;

    IF loop_found THEN
        RAISE EXCEPTION 'I12: % cannot be placed under % because that would create a loop',
            NEW.child_bp_id, NEW.parent_bp_id;
    END IF;

    -- Walk down from the child through current links.
    WITH RECURSIVE down AS (
        SELECT NEW.child_bp_id AS bp_id, 0 AS steps
      UNION ALL
        SELECT r.child_bp_id, down.steps + 1
        FROM hub.partner_relationships r
        JOIN down ON r.parent_bp_id = down.bp_id
        WHERE upper_inf(r.valid_period)
          AND r.relationship_id <> NEW.relationship_id
          AND down.steps < 10
    )
    SELECT max(steps) INTO below FROM down;

    -- Levels = ancestors of the parent + the parent + the child + levels below the child.
    IF ancestors + 2 + below > 5 THEN
        RAISE EXCEPTION 'I12: hierarchy would have % levels (at most 5)', ancestors + 2 + below;
    END IF;

    RETURN NEW;
END
$$;

CREATE TRIGGER partner_relationships_check
    BEFORE INSERT OR UPDATE ON hub.partner_relationships
    FOR EACH ROW EXECUTE FUNCTION hub.check_hierarchy();

-- =========================================================
-- 6. governance: matching and merges
-- =========================================================

CREATE TABLE governance.match_suggestions (
    suggestion_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    a_system_code TEXT NOT NULL REFERENCES config.source_systems (system_code),
    a_source_key TEXT NOT NULL,
    a_content_sha256 config.sha256_hex NOT NULL,
    b_system_code TEXT NOT NULL REFERENCES config.source_systems (system_code),
    b_source_key TEXT NOT NULL,
    b_content_sha256 config.sha256_hex NOT NULL,
    rule_id TEXT NOT NULL,
    strength TEXT NOT NULL,
    score NUMERIC(4, 3) NOT NULL,
    compared_values JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'open',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    decided_at TIMESTAMPTZ,
    decided_by TEXT REFERENCES config.staff (staff_id),
    decision_reason TEXT,
    rules_version TEXT NOT NULL REFERENCES config.rule_versions (rules_version),

    -- I17
    CONSTRAINT match_suggestions_pair_ordered
        CHECK (ROW(a_system_code, a_source_key) < ROW(b_system_code, b_source_key)),
    CONSTRAINT match_suggestions_rule_strength_valid CHECK (
        (rule_id, strength) IN (('M2', 'group'), ('M3', 'strong'), ('M4', 'normal'),
                                ('M5', 'weak'), ('M6', 'bank_risk'))
    ),
    CONSTRAINT match_suggestions_score_range CHECK (score BETWEEN 0 AND 1),
    CONSTRAINT match_suggestions_compared_object CHECK (jsonb_typeof(compared_values) = 'object'),
    CONSTRAINT match_suggestions_status_valid
        CHECK (status IN ('open', 'confirmed', 'rejected', 'group')),
    CONSTRAINT match_suggestions_decision_complete CHECK (
        (status = 'open') = (decided_at IS NULL) AND (status = 'open') = (decided_by IS NULL)
    )
);

-- I17: at most one open suggestion per pair.
CREATE UNIQUE INDEX match_suggestions_one_open_per_pair
    ON governance.match_suggestions (a_system_code, a_source_key, b_system_code, b_source_key)
    WHERE status = 'open';

CREATE TABLE governance.merge_events (
    merge_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type TEXT NOT NULL,
    survivor_bp_id TEXT NOT NULL REFERENCES hub.business_partners (bp_id),
    absorbed_bp_id TEXT NOT NULL REFERENCES hub.business_partners (bp_id),
    undoes_merge_event_id UUID,
    reason TEXT NOT NULL,
    match_suggestion_id UUID REFERENCES governance.match_suggestions (suggestion_id),
    request_id TEXT REFERENCES governance.change_requests (request_id),
    approved_by TEXT REFERENCES config.staff (staff_id),
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    rules_version TEXT NOT NULL REFERENCES config.rule_versions (rules_version),

    CONSTRAINT merge_events_type_valid CHECK (event_type IN ('merge', 'undo')),
    CONSTRAINT merge_events_two_partners CHECK (survivor_bp_id <> absorbed_bp_id),
    CONSTRAINT merge_events_undo_pointer
        CHECK ((event_type = 'undo') = (undoes_merge_event_id IS NOT NULL)),
    -- Only an automatic M1 merge (no suggestion, no request) has no approver.
    CONSTRAINT merge_events_approver_required CHECK (
        approved_by IS NOT NULL
        OR (event_type = 'merge' AND match_suggestion_id IS NULL AND request_id IS NULL)
    ),
    CONSTRAINT merge_events_reason_not_blank CHECK (btrim(reason) <> ''),
    -- A merge is undone at most once, by an undo naming the same two partners.
    CONSTRAINT merge_events_undone_once UNIQUE (undoes_merge_event_id),
    CONSTRAINT merge_events_event_partners_unique UNIQUE (merge_event_id, survivor_bp_id, absorbed_bp_id),
    CONSTRAINT merge_events_undo_same_partners
        FOREIGN KEY (undoes_merge_event_id, survivor_bp_id, absorbed_bp_id)
        REFERENCES governance.merge_events (merge_event_id, survivor_bp_id, absorbed_bp_id)
);

-- An undo must point to a merge, not to another undo.
CREATE FUNCTION governance.check_undo_target() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.event_type = 'undo' AND EXISTS (
        SELECT 1 FROM governance.merge_events
        WHERE merge_event_id = NEW.undoes_merge_event_id AND event_type <> 'merge') THEN
        RAISE EXCEPTION 'An undo must reverse a merge, not another undo';
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER merge_events_undo_target
    BEFORE INSERT ON governance.merge_events
    FOR EACH ROW EXECUTE FUNCTION governance.check_undo_target();

-- =========================================================
-- 7. hub: cross-reference and field history
-- =========================================================

CREATE TABLE hub.source_links (
    link_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    system_code TEXT NOT NULL REFERENCES config.source_systems (system_code),
    source_key TEXT NOT NULL,
    bp_id TEXT NOT NULL REFERENCES hub.business_partners (bp_id),
    valid_period config.valid_period NOT NULL,
    link_method TEXT NOT NULL,
    match_suggestion_id UUID REFERENCES governance.match_suggestions (suggestion_id),
    merge_event_id UUID REFERENCES governance.merge_events (merge_event_id),
    linked_by TEXT REFERENCES config.staff (staff_id),
    rules_version TEXT NOT NULL REFERENCES config.rule_versions (rules_version),

    CONSTRAINT source_links_method_valid CHECK (link_method IN (
        'new_partner', 'rule_m1', 'steward_confirmed', 'merge', 'undo_merge', 'request')),
    CONSTRAINT source_links_steward_evidence CHECK (
        link_method <> 'steward_confirmed' OR (match_suggestion_id IS NOT NULL AND linked_by IS NOT NULL)
    ),
    CONSTRAINT source_links_merge_evidence
        CHECK (link_method NOT IN ('merge', 'undo_merge') OR merge_event_id IS NOT NULL),
    -- I04 (rule U02): a source record belongs to exactly one partner at any moment.
    CONSTRAINT source_links_one_partner_at_a_time
        EXCLUDE USING gist (system_code WITH =, source_key WITH =, valid_period WITH &&)
);

CREATE INDEX source_links_bp_idx ON hub.source_links (bp_id);
CREATE INDEX source_links_merge_idx ON hub.source_links (merge_event_id);

-- I04: a link names a stored source record, and a current link points to an active partner.
CREATE FUNCTION hub.check_source_link() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM source.source_records
                   WHERE system_code = NEW.system_code AND source_key = NEW.source_key) THEN
        RAISE EXCEPTION 'I04: no stored source record % / %', NEW.system_code, NEW.source_key;
    END IF;
    IF upper_inf(NEW.valid_period) AND EXISTS (
        SELECT 1 FROM hub.business_partners WHERE bp_id = NEW.bp_id AND status <> 'active') THEN
        RAISE EXCEPTION 'I04: a current link must point to an active partner (% is not)', NEW.bp_id;
    END IF;
    RETURN NEW;
END
$$;

CREATE TRIGGER source_links_check
    BEFORE INSERT OR UPDATE ON hub.source_links
    FOR EACH ROW EXECUTE FUNCTION hub.check_source_link();

CREATE TABLE hub.field_history (
    history_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bp_id TEXT NOT NULL REFERENCES hub.business_partners (bp_id),
    field_name TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    valid_from TIMESTAMPTZ NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_record_id UUID REFERENCES source.source_records (source_record_id),
    request_id TEXT REFERENCES governance.change_requests (request_id),
    merge_event_id UUID REFERENCES governance.merge_events (merge_event_id),
    survivorship_step SMALLINT,
    changed_by TEXT REFERENCES config.staff (staff_id),
    rules_version TEXT NOT NULL REFERENCES config.rule_versions (rules_version),

    CONSTRAINT field_history_field_name_format CHECK (field_name ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT field_history_value_changed CHECK (old_value IS DISTINCT FROM new_value),
    CONSTRAINT field_history_step_range CHECK (survivorship_step BETWEEN 1 AND 4),
    -- I16: every change names where it came from.
    CONSTRAINT field_history_lineage
        CHECK (num_nonnulls(source_record_id, request_id, merge_event_id) >= 1)
);

CREATE INDEX field_history_lookup_idx ON hub.field_history (bp_id, field_name, valid_from);

-- =========================================================
-- 8. governance: quality, requests, erasure
-- =========================================================

CREATE TABLE governance.quality_runs (
    run_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rules_version TEXT NOT NULL REFERENCES config.rule_versions (rules_version),
    scope TEXT NOT NULL,
    request_id TEXT REFERENCES governance.change_requests (request_id),
    as_of TIMESTAMPTZ NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at TIMESTAMPTZ,
    subjects_checked INTEGER,
    CONSTRAINT quality_runs_scope_valid CHECK (scope IN ('full', 'request')),
    CONSTRAINT quality_runs_request_scope CHECK ((scope = 'request') = (request_id IS NOT NULL)),
    CONSTRAINT quality_runs_time_order CHECK (finished_at IS NULL OR finished_at >= started_at),
    CONSTRAINT quality_runs_subjects_not_negative CHECK (subjects_checked >= 0)
);

CREATE TABLE governance.quality_results (
    result_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id UUID NOT NULL REFERENCES governance.quality_runs (run_id),
    rule_id TEXT NOT NULL,
    severity TEXT NOT NULL,
    bp_id TEXT REFERENCES hub.business_partners (bp_id),
    source_record_id UUID REFERENCES source.source_records (source_record_id),
    outcome TEXT NOT NULL,
    details JSONB,
    CONSTRAINT quality_results_rule_id_format CHECK (rule_id ~ '^[CVUKT][0-9]{2}$'),
    CONSTRAINT quality_results_severity_valid CHECK (severity IN ('error', 'warning')),
    CONSTRAINT quality_results_outcome_valid CHECK (outcome IN ('pass', 'fail', 'not_applicable')),
    CONSTRAINT quality_results_one_subject CHECK (num_nonnulls(bp_id, source_record_id) = 1),
    CONSTRAINT quality_results_once_per_run
        UNIQUE NULLS NOT DISTINCT (run_id, rule_id, bp_id, source_record_id)
);

CREATE TABLE governance.request_status_history (
    request_id TEXT NOT NULL REFERENCES governance.change_requests (request_id),
    seq INTEGER NOT NULL,
    from_status TEXT,
    to_status TEXT NOT NULL,
    changed_by TEXT NOT NULL REFERENCES config.staff (staff_id),
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    note TEXT,
    PRIMARY KEY (request_id, seq),
    CONSTRAINT request_status_history_seq_positive CHECK (seq >= 1),
    CONSTRAINT request_status_history_first_row CHECK ((seq = 1) = (from_status IS NULL)),
    CONSTRAINT request_status_history_status_valid CHECK (
        to_status IN ('draft', 'submitted', 'in_review', 'awaiting_approval', 'approved', 'applied',
                      'closed', 'returned', 'rejected', 'cancelled')
        AND (from_status IS NULL OR from_status IN (
            'draft', 'submitted', 'in_review', 'awaiting_approval', 'approved', 'applied',
            'closed', 'returned', 'rejected', 'cancelled'))
    ),
    CONSTRAINT request_status_history_changes CHECK (from_status IS DISTINCT FROM to_status)
);

CREATE TABLE governance.request_approvals (
    approval_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id TEXT NOT NULL,
    requested_by TEXT NOT NULL,
    approver_id TEXT NOT NULL REFERENCES config.staff (staff_id),
    approver_role TEXT NOT NULL,
    decision TEXT NOT NULL,
    reason TEXT,
    decided_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- I18: the requester is copied from the request (guaranteed by the composite key) and
    -- can never be the approver.
    CONSTRAINT request_approvals_request_requester
        FOREIGN KEY (request_id, requested_by)
        REFERENCES governance.change_requests (request_id, requested_by),
    CONSTRAINT request_approvals_four_eyes CHECK (approver_id <> requested_by),
    CONSTRAINT request_approvals_role_valid CHECK (approver_role IN (
        'finance_controller', 'sales_director', 'head_of_operations', 'steward', 'dpo')),
    CONSTRAINT request_approvals_decision_valid CHECK (decision IN ('approved', 'rejected'))
);

CREATE TABLE governance.request_evidence (
    evidence_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id TEXT NOT NULL REFERENCES governance.change_requests (request_id),
    evidence_type TEXT NOT NULL,
    reference TEXT NOT NULL,
    document_sha256 config.sha256_hex,
    added_by TEXT NOT NULL REFERENCES config.staff (staff_id),
    added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT request_evidence_type_format CHECK (evidence_type ~ '^[a-z][a-z0-9_]*$'),
    CONSTRAINT request_evidence_reference_not_blank CHECK (btrim(reference) <> '')
);

CREATE TABLE governance.erasure_proofs (
    erasure_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id TEXT NOT NULL REFERENCES governance.change_requests (request_id),
    contact_id UUID NOT NULL REFERENCES hub.contact_persons (contact_id),
    bp_id TEXT NOT NULL REFERENCES hub.business_partners (bp_id),
    source_records_redacted INTEGER NOT NULL,
    systems_affected TEXT[] NOT NULL,
    completed_by TEXT NOT NULL REFERENCES config.staff (staff_id),
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT erasure_proofs_one_per_request UNIQUE (request_id),
    CONSTRAINT erasure_proofs_count_not_negative CHECK (source_records_redacted >= 0)
);

-- =========================================================
-- 9. I15: append-only history tables
-- =========================================================

CREATE FUNCTION governance.refuse_change() RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'I15: %.% is append-only (% refused)', TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP;
END
$$;

CREATE TRIGGER field_history_append_only BEFORE UPDATE OR DELETE ON hub.field_history
    FOR EACH ROW EXECUTE FUNCTION governance.refuse_change();
CREATE TRIGGER request_status_history_append_only BEFORE UPDATE OR DELETE ON governance.request_status_history
    FOR EACH ROW EXECUTE FUNCTION governance.refuse_change();
CREATE TRIGGER request_approvals_append_only BEFORE UPDATE OR DELETE ON governance.request_approvals
    FOR EACH ROW EXECUTE FUNCTION governance.refuse_change();
CREATE TRIGGER merge_events_append_only BEFORE UPDATE OR DELETE ON governance.merge_events
    FOR EACH ROW EXECUTE FUNCTION governance.refuse_change();
CREATE TRIGGER quality_results_append_only BEFORE UPDATE OR DELETE ON governance.quality_results
    FOR EACH ROW EXECUTE FUNCTION governance.refuse_change();
CREATE TRIGGER erasure_proofs_append_only BEFORE UPDATE OR DELETE ON governance.erasure_proofs
    FOR EACH ROW EXECUTE FUNCTION governance.refuse_change();

-- =========================================================
-- 10. Erasure of a contact person (D11)
-- =========================================================

-- Replace every JSON object that holds the e-mail address with a redaction marker.
CREATE FUNCTION governance.redact_jsonb(doc JSONB, email TEXT) RETURNS JSONB
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    k TEXT;
    v JSONB;
    result JSONB;
BEGIN
    CASE jsonb_typeof(doc)
    WHEN 'object' THEN
        IF EXISTS (SELECT 1 FROM jsonb_each(doc) AS e
                   WHERE jsonb_typeof(e.value) = 'string' AND lower(e.value #>> '{}') = lower(email)) THEN
            RETURN '{"redacted": true}'::JSONB;
        END IF;
        result := '{}'::JSONB;
        FOR k, v IN SELECT key, value FROM jsonb_each(doc) LOOP
            result := result || jsonb_build_object(k, governance.redact_jsonb(v, email));
        END LOOP;
        RETURN result;
    WHEN 'array' THEN
        SELECT coalesce(jsonb_agg(governance.redact_jsonb(e, email) ORDER BY n), '[]'::JSONB)
        INTO result
        FROM jsonb_array_elements(doc) WITH ORDINALITY AS a (e, n);
        RETURN result;
    ELSE
        RETURN doc;
    END CASE;
END
$$;

-- Erase one contact person in one transaction: clear the hub row, redact every stored source
-- record version that holds the person, and write the proof. Returns the erasure ID.
CREATE FUNCTION governance.erase_contact(p_contact_id UUID, p_request_id TEXT, p_staff_id TEXT)
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
    FROM hub.contact_persons WHERE contact_id = p_contact_id AND status = 'active'
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
        role_title = NULL, legal_basis = NULL, erased_at = now(), erasure_request_id = p_request_id
    WHERE contact_id = p_contact_id;

    INSERT INTO governance.erasure_proofs
        (request_id, contact_id, bp_id, source_records_redacted, systems_affected, completed_by)
    VALUES (p_request_id, p_contact_id, v_bp, v_count, v_systems, p_staff_id)
    RETURNING erasure_id INTO v_erasure;

    RETURN v_erasure;
END
$$;

-- =========================================================
-- 11. Access for reporting (A01-A03)
-- =========================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mdh_reporting') THEN
        CREATE ROLE mdh_reporting NOLOGIN;
    END IF;
END
$$;

-- A01: read config, hub and governance; nothing in source; no writes.
GRANT USAGE ON SCHEMA config, hub, governance TO mdh_reporting;
GRANT SELECT ON ALL TABLES IN SCHEMA config TO mdh_reporting;
GRANT SELECT ON hub.business_partners, hub.customer_roles, hub.supplier_roles, hub.addresses,
                hub.partner_relationships, hub.source_links, hub.field_history
    TO mdh_reporting;
GRANT SELECT ON governance.quality_runs, governance.merge_events,
                governance.request_status_history, governance.request_approvals,
                governance.request_evidence, governance.erasure_proofs
    TO mdh_reporting;

-- A02: no personal or bank details, including where they can appear inside JSON
-- (proposed values, compared values, quality details).
GRANT SELECT (contact_id, bp_id, status, legal_basis, source_record_id, erased_at, erasure_request_id)
    ON hub.contact_persons TO mdh_reporting;
GRANT SELECT (bank_account_id, bp_id, iban_country, valid_period, verified_at, verification_method,
              verified_by, request_id)
    ON hub.bank_accounts TO mdh_reporting;
GRANT SELECT (request_id, request_type, risk, target_bp_id, status, requested_by, reason,
              target_working_hours, created_at, submitted_at, closed_at, rules_version)
    ON governance.change_requests TO mdh_reporting;
GRANT SELECT (suggestion_id, a_system_code, a_source_key, a_content_sha256, b_system_code,
              b_source_key, b_content_sha256, rule_id, strength, score, status, created_at,
              decided_at, decided_by, decision_reason, rules_version)
    ON governance.match_suggestions TO mdh_reporting;
GRANT SELECT (result_id, run_id, rule_id, severity, bp_id, source_record_id, outcome)
    ON governance.quality_results TO mdh_reporting;

-- A03: the history of bank fields is hidden from reporting. The table owner is not affected.
ALTER TABLE hub.field_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY field_history_reporting ON hub.field_history
    FOR SELECT TO mdh_reporting
    USING (field_name NOT IN ('iban', 'account_holder_name'));

-- =========================================================
-- 12. Check that every table exists
-- =========================================================

DO $$
DECLARE
    expected TEXT[] := ARRAY[
        'config.rule_versions', 'config.source_systems', 'config.staff', 'config.staff_roles',
        'source.load_batches', 'source.source_records', 'source.standardised_records',
        'hub.business_partners', 'hub.customer_roles', 'hub.supplier_roles', 'hub.addresses',
        'hub.bank_accounts', 'hub.contact_persons', 'hub.partner_relationships',
        'hub.source_links', 'hub.field_history',
        'governance.quality_runs', 'governance.quality_results', 'governance.match_suggestions',
        'governance.merge_events', 'governance.change_requests',
        'governance.request_status_history', 'governance.request_approvals',
        'governance.request_evidence', 'governance.erasure_proofs'];
    missing TEXT[];
BEGIN
    SELECT array_agg(t) INTO missing FROM unnest(expected) AS t WHERE to_regclass(t) IS NULL;
    IF missing IS NOT NULL THEN
        RAISE EXCEPTION 'Schema incomplete, missing: %', missing;
    END IF;
    RAISE NOTICE 'MDH schema OK in %: % tables.', current_database(), cardinality(expected);
END
$$;

COMMIT;
