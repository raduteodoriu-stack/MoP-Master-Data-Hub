# Data dictionary (MDH-003)

Every table and column of the MoP Master Data Hub database. The design, relationships and
integrity rules are explained in [database_design.md](database_design.md); rule IDs such as
I07 refer to its integrity rules, and IDs such as V01 or K05 to the quality rules in
[quality_rules.md](quality_rules.md).

**Conventions**

- Times are `timestamptz` and shown in Europe/Madrid.
- Unknown controlled values are stored as `'unknown'`, never NULL.
- Periods (`valid_period`) are `tstzrange` with an inclusive start and exclusive end; an open end means *current*.
- `FK` = foreign key. Where a column holds a controlled value, the allowed values are listed.
- All data is synthetic. Emails of MoP Cloud staff end in `.example`.

## Tables

| Schema | Table | Columns |
|---|---|---|
| `config` | [`rule_versions`](#configrule_versions) | 4 |
| `config` | [`source_systems`](#configsource_systems) | 4 |
| `config` | [`staff`](#configstaff) | 7 |
| `config` | [`staff_roles`](#configstaff_roles) | 4 |
| `source` | [`load_batches`](#sourceload_batches) | 10 |
| `source` | [`source_records`](#sourcesource_records) | 12 |
| `source` | [`standardised_records`](#sourcestandardised_records) | 14 |
| `hub` | [`business_partners`](#hubbusiness_partners) | 18 |
| `hub` | [`customer_roles`](#hubcustomer_roles) | 22 |
| `hub` | [`supplier_roles`](#hubsupplier_roles) | 14 |
| `hub` | [`addresses`](#hubaddresses) | 10 |
| `hub` | [`bank_accounts`](#hubbank_accounts) | 13 |
| `hub` | [`contact_persons`](#hubcontact_persons) | 13 |
| `hub` | [`partner_relationships`](#hubpartner_relationships) | 6 |
| `hub` | [`source_links`](#hubsource_links) | 10 |
| `hub` | [`field_history`](#hubfield_history) | 13 |
| `governance` | [`quality_runs`](#governancequality_runs) | 8 |
| `governance` | [`quality_results`](#governancequality_results) | 8 |
| `governance` | [`match_suggestions`](#governancematch_suggestions) | 17 |
| `governance` | [`merge_events`](#governancemerge_events) | 11 |
| `governance` | [`change_requests`](#governancechange_requests) | 13 |
| `governance` | [`request_status_history`](#governancerequest_status_history) | 7 |
| `governance` | [`request_approvals`](#governancerequest_approvals) | 8 |
| `governance` | [`request_evidence`](#governancerequest_evidence) | 7 |
| `governance` | [`erasure_proofs`](#governanceerasure_proofs) | 8 |
| `source` | [`registry_entries`](#sourceregistry_entries) | 9 |
| `source` | [`hr_employees`](#sourcehr_employees) | 8 |
| `governance` | [`rule_exceptions`](#governancerule_exceptions) | 8 |
| `governance` | [`suppression_list`](#governancesuppression_list) | 4 |
| `hub` | [`partner_names`](#hubpartner_names-view) (view) | 4 |

## Schema `config`

### config.rule_versions

One loaded version of the rules file. Every result names the version that produced it (I20).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `rules_version` | text | no |  | Primary key, e.g. `MDH-RULES-v1.2`; must equal `rules_version` inside the file |
| `file_sha256` | text | no |  | SHA-256 of the rules file as loaded; 64 lower-case hex characters |
| `loaded_at` | timestamptz | no | `now()` | When the version was loaded |
| `notes` | text | yes |  | What changed compared with the previous version |

### config.source_systems

The four simulated source systems.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `system_code` | text | no |  | Primary key: `crm`, `erp`, `support`, `procurement_sheet` |
| `system_name` | text | no |  | Display name |
| `description` | text | no |  | What the system holds and who uses it |
| `active` | boolean | no | `true` | False when a system is retired (the procurement spreadsheet after migration) |

### config.staff

One MoP Cloud person who raises, prepares or approves requests, owns accounts, or is an internal supplier contact. Synthetic people only.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `staff_id` | text | no |  | Primary key, format `ST-NNN` |
| `full_name` | text | no |  | Synthetic name |
| `email` | text | no |  | Work email; must end in `.example` (synthetic only). Unique |
| `department` | text | no |  | `sales`, `finance`, `operations`, `customer_success`, `revops`, `legal` |
| `sales_owner_id` | text | yes |  | Owner ID used by LeadFlow and RLR (for example `ES-01`, `AE-ES-01`); unique when filled. Target of `customer_roles.account_owner_id` |
| `active` | boolean | no | `true` | False after the person leaves; history keeps the ID |
| `created_at` | timestamptz | no | `now()` | Row creation time |

### config.staff_roles

One period in which a person holds a governance role (I19). Used to check, at the time of a decision, that the approver held the right role.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `staff_role_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `staff_id` | text | no |  | Person (FK `config.staff`) |
| `role` | text | no |  | `finance_controller`, `sales_director`, `head_of_operations`, `steward`, `requester`, `system_custodian`, `dpo` |
| `valid_period` | tstzrange | no |  | When the role was held; open upper bound = current. No overlap for the same person and role |

## Schema `source`

### source.load_batches

One extract or file load from a source system. The basis for reconciling what each system sent with what was stored.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `batch_id` | uuid | no |  | Primary key, deterministic from system and file checksum (loading the same file twice is refused) |
| `system_code` | text | no |  | Source system (FK) |
| `file_name` | text | no |  | Name of the extract file |
| `file_sha256` | text | no |  | Checksum of the file; unique per system |
| `extracted_at` | timestamptz | no |  | When the source system produced the extract |
| `loaded_at` | timestamptz | no | `now()` | When the hub stored it |
| `rows_received` | integer | no |  | Rows in the file |
| `rows_stored` | integer | no |  | Rows stored as new record versions |
| `rows_unchanged` | integer | no |  | Rows identical to a version already stored (I03) |
| `rows_rejected` | integer | no |  | Rows that could not be stored (no source key, unreadable); listed in the load report. Received = stored + unchanged + rejected |

### source.source_records

One version of one record in one source system, exactly as received. Insert-only (I02); a changed record arrives as a new version.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `source_record_id` | uuid | no |  | Primary key, deterministic from system, source key and content hash |
| `system_code` | text | no |  | Source system (FK) |
| `source_key` | text | no |  | The record's ID in its own system (for example the HubSpot company ID or ERP account number) |
| `record_version` | integer | no |  | 1, 2, 3… per system and source key, in order of receipt. Unique with system and key |
| `content_sha256` | text | no |  | Hash of the payload as received. Unique with system and key (I03). Kept after redaction, so an old extract cannot bring erased data back |
| `payload` | jsonb | no |  | The record exactly as the system sent it |
| `batch_id` | uuid | no |  | Load it came in (FK) |
| `source_updated_at` | timestamptz | yes |  | Last-changed time stated by the source, if it provides one |
| `deleted_in_source` | boolean | no | `false` | True when the source reports the record deleted (stored as a version, never by deleting rows) |
| `received_at` | timestamptz | no | `now()` | When the hub stored this version |
| `redacted_at` | timestamptz | yes |  | Set only by `governance.erase_contact()` when personal data was removed from the payload |
| `redaction_request_id` | text | yes |  | Erasure request that caused the redaction (FK `governance.change_requests`). Filled together with `redacted_at` |

### source.standardised_records

The standardised values of one source record version, written by the engine (MDH-005). Matching uses these columns only (MDH-002 D2).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `source_record_id` | uuid | no |  | Primary key and FK to `source.source_records` |
| `rules_version` | text | no |  | Rules used to standardise (FK) |
| `role_hint` | text | no | `'unknown'` | What the source says the company is to MoP Cloud: `customer`, `supplier`, `both`, `unknown` |
| `name_std` | text | yes |  | Name in matching form: upper case, no accents, punctuation or legal form |
| `legal_form_std` | text | yes |  | Legal form in the country's standard spelling, if recognised |
| `country` | text | yes |  | Country as standardised (normally an ISO code). Not format-checked here, so invalid values can be reported by the quality rules |
| `tax_id_std` | text | yes |  | Tax ID without spaces, dots or dashes |
| `web_domain_std` | text | yes |  | Registrable domain, lower case |
| `street_std` | text | yes |  | Street line, standardised |
| `postal_code_std` | text | yes |  | Postal code, standardised |
| `city_std` | text | yes |  | City, upper case, no accents |
| `phone_std` | text | yes |  | International format |
| `iban_std` | text | yes |  | IBAN without spaces, upper case |
| `standardised_at` | timestamptz | no | `now()` | When the values were written |

## Schema `hub`

### hub.business_partners

One golden business partner: the general data shared by every role. Never deleted (I05); a merged partner keeps its ID and points to the survivor (I06).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `bp_id` | text | no | 'BP-' + 6-digit sequence | Primary key, format `BP-NNNNNN`, never reused (MDH-002 D1) |
| `status` | text | no | `'active'` | `active` or `merged` |
| `merged_into_bp_id` | text | yes |  | Survivor of the merge; filled only when status is `merged`, never itself (I06) |
| `merged_at` | timestamptz | yes |  | When it was merged; filled together with `merged_into_bp_id` |
| `legal_name` | text | yes |  | Legal name as on the tax registration. Mandatory for customers and approved suppliers (checked by C01) |
| `trading_name` | text | yes |  | Name the company is known by. Legal or trading name must be present |
| `legal_form` | text | yes |  | Legal form, standard spelling for the country (checked by V10) |
| `country` | text | no |  | Country of registration, ISO code (I09) |
| `tax_id` | text | yes |  | Tax ID; format per country (I09), check digit by the engine (V01). One active partner per country and tax ID (I07) |
| `vat_number` | text | yes | generated | Derived from country and tax ID, never typed (I08) |
| `web_domain` | text | yes |  | Registrable domain, lower case (I09) |
| `phone` | text | yes |  | International format (I09) |
| `last_reviewed_at` | timestamptz | yes |  | Last full review by the steward (rule T01, 12 months) |
| `vies_status` | text | yes |  | `valid`, `not_registered` or `invalid`, from a simulated VIES check; for partners registered outside Spain (V13, rules v1.3) |
| `vies_checked_at` | timestamptz | yes |  | When the VIES status was checked |
| `vies_evidence_ref` | text | yes |  | Reference of the stored check result. The three VIES columns are filled together (I23) |
| `created_at` | timestamptz | no | `now()` | When the partner was created |
| `updated_at` | timestamptz | no | `now()` | Last change to this row |

### hub.customer_roles

The customer role of one partner (at most one, I10). A block sits on top of the stage, so unblocking returns to the stage the partner had.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `bp_id` | text | no |  | Primary key and FK to the partner |
| `stage` | text | no | `'prospect'` | `prospect`, `customer`, `inactive`. MDH-001's *Blocked* stage = a block on top of one of these |
| `stage_changed_at` | timestamptz | no | `now()` | When the stage last changed |
| `tier_calculated` | text | no | `'unknown'` | `tier_1`, `tier_2`, `tier_3`, `unknown`, from industry and employee band (rules v1.1 `customer_tier`) |
| `tier_score` | smallint | yes |  | 0–60; empty when the tier is `unknown` |
| `tier_reason_codes` | text[] | no | `'{}'` | Reason codes behind the calculated and group tier (for example `TIER_INDUSTRY_CORE`, `TIER_GROUP_ROLLUP`) |
| `tier_group` | text | no | `'unknown'` | Highest calculated tier in the partner's company group; equal to `tier_calculated` when it has no group. Never lower than the partner's own known tier; unknown while the partner's own tier is unknown (G9) |
| `tier_override` | text | yes |  | `tier_1`, `tier_2` or `tier_3`, set only by an approved override request |
| `tier_override_request_id` | text | yes |  | Request that set the override (FK). Filled exactly when `tier_override` is filled |
| `tier_effective` | text | no | generated | `tier_override` if filled, otherwise `tier_group` |
| `tier_rules_version` | text | yes |  | Rules version that calculated the tier (FK) |
| `tier_calculated_at` | timestamptz | yes |  | When the tier was last calculated |
| `account_owner_id` | text | yes |  | Owner ID (FK `config.staff.sales_owner_id`): the SDR for prospects (`ES-01`), an Account Executive for customers (`AE-ES-01`). Mandatory for both stages (C01) |
| `industry_code` | text | no | `'unknown'` | LeadFlow industry list |
| `employee_band` | text | no | `'unknown'` | LeadFlow employee bands |
| `bill_to_bp_id` | text | yes |  | Partner invoiced for this customer (FK); itself or another partner (K04) |
| `payment_terms` | text | yes |  | `NET15`, `NET30`, `NET45`, `NET60` |
| `invoice_email` | text | yes |  | Email format (I09) |
| `block_reason` | text | yes |  | `duplicate`, `credit`, `payment`, `compliance` |
| `blocked_by` | text | yes |  | Approver of the block (FK staff) |
| `blocked_at` | timestamptz | yes |  | When blocked. Reason, approver and time are all filled or all empty (I11) |
| `block_request_id` | text | yes |  | Request that set the block (FK) |

### hub.supplier_roles

The supplier role of one partner (at most one, I10).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `bp_id` | text | no |  | Primary key and FK to the partner |
| `stage` | text | no | `'requested'` | `requested`, `approved`, `inactive`. *Blocked* = a block on top |
| `stage_changed_at` | timestamptz | no | `now()` | When the stage last changed |
| `category` | text | no |  | `panel_sample_provider`, `software`, `professional_services`, `facilities`, `other` |
| `internal_contact_id` | text | no |  | MoP Cloud person responsible for the supplier (FK staff) |
| `payment_terms` | text | yes |  | `NET15`, `NET30`, `NET45`, `NET60` |
| `remittance_email` | text | yes |  | Email format (I09) |
| `approved_at` | timestamptz | yes |  | When approved for payment |
| `approved_by` | text | yes |  | Who approved it (FK staff). Filled together with `approved_at` |
| `last_activity_at` | timestamptz | yes |  | Last purchase order or invoice in the ERP (T05: dormant after 12 months) |
| `block_reason` | text | yes |  | `duplicate`, `credit`, `payment`, `compliance` |
| `blocked_by` | text | yes |  | Approver of the block (FK staff) |
| `blocked_at` | timestamptz | yes |  | All three block columns filled or all empty (I11) |
| `block_request_id` | text | yes |  | Request that set the block (FK) |

### hub.addresses

One address of one partner for one period. At most one current registered and one current billing address per partner.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `address_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `bp_id` | text | no |  | Partner (FK) |
| `address_type` | text | no |  | `registered`, `billing`, `branch` |
| `street` | text | no |  | Street and number |
| `postal_code` | text | no |  | Pattern per country (I09) |
| `city` | text | no |  | City |
| `region` | text | yes |  | Province, district or département |
| `country` | text | no |  | ISO code |
| `valid_period` | tstzrange | no |  | When the address applied. No overlap per partner for `registered` and for `billing` |
| `request_id` | text | yes |  | Request that set it, if any (FK) |

### hub.bank_accounts

One period in which a supplier uses one bank account (I13). Only partners with a supplier role.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `bank_account_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `bp_id` | text | no |  | Supplier (FK `hub.supplier_roles`) |
| `iban` | text | no |  | Upper case, no spaces; length per country (ES 24, PT 25, FR 27); check digits by the engine (V09) |
| `iban_country` | text | no | generated | First two characters of the IBAN (rule K03) |
| `account_holder_name` | text | no |  | As on the bank certificate (rule K02) |
| `valid_period` | tstzrange | no |  | When the account was used. No overlap per supplier |
| `verified_at` | timestamptz | yes |  | Independent verification time (rule T02) |
| `verification_method` | text | yes |  | `callback_known_contact`, `bank_letter`, `supplier_portal` |
| `verified_by` | text | yes |  | Who verified (FK staff). The three verification columns are filled together (I13) |
| `request_id` | text | yes |  | Request that set it (FK) |
| `payee_type` | text | no | `'own_account'` | `own_account`, `factoring_company` or `alternative_payee` (rules v1.3) |
| `assignment_evidence_ref` | text | yes |  | Assignment letter for a factoring company or alternative payee; filled exactly when the payee is not the supplier itself (I22) |
| `holder_match` | text | yes |  | Holder-name check outcome: `match`, `close_match` or `no_match` (K02) |

### hub.contact_persons

One contact person of one partner. Personal data, minimised; erasure clears it and keeps only the ID (I14).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `contact_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `bp_id` | text | no |  | Partner (FK) |
| `status` | text | no | `'active'` | `active`, `left_company`, `bounced` or `erased` (rules v1.3) |
| `first_name` | text | yes |  | Filled while active; empty once erased |
| `last_name` | text | yes |  | Filled while active; empty once erased |
| `work_email` | text | yes |  | Filled while active (email format); empty once erased |
| `role_title` | text | yes |  | Role at the company (for example `Head of Insights`); empty once erased |
| `legal_basis` | text | yes |  | `contract`, `legitimate_interest`, `consent`; empty once erased |
| `last_verified_at` | timestamptz | yes |  | When the contact was last confirmed as current (K12: bank call-backs need 12 months or less); empty once erased |
| `last_contact_at` | timestamptz | yes |  | Last contact with the person (T06: prospect contacts anonymised after 3 years); empty once erased |
| `source_record_id` | uuid | yes |  | Source record it was taken from (FK) |
| `erased_at` | timestamptz | yes |  | Filled only when erased |
| `erasure_request_id` | text | yes |  | Erasure request (FK). Filled together with `erased_at` |

### hub.partner_relationships

One period in which a partner has a parent (I12): the company hierarchy.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `relationship_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `child_bp_id` | text | no |  | Subsidiary (FK) |
| `parent_bp_id` | text | no |  | Parent (FK); never the child itself |
| `relationship_type` | text | no | `'subsidiary_of'` | `subsidiary_of` (hierarchy) or `successor_of` (after a merger; the parent column holds the successor). One link of each type at a time (I24) |
| `valid_period` | tstzrange | no |  | When it applied. One parent at a time per child; no loop; at most five levels |
| `request_id` | text | yes |  | Request that set it (FK) |

### hub.source_links

The cross-reference: one period in which a source record (its system and key, all versions) belongs to one partner (I04).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `link_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `system_code` | text | no |  | Source system (FK) |
| `source_key` | text | no |  | Record ID in that system; at least one stored version must exist (trigger) |
| `bp_id` | text | no |  | Partner (FK) |
| `valid_period` | tstzrange | no |  | When the link held. No overlap per system and key |
| `link_method` | text | no |  | `new_partner` (no match, partner created), `rule_m1` (same tax ID), `steward_confirmed`, `merge`, `undo_merge`, `request` |
| `match_suggestion_id` | uuid | yes |  | Suggestion confirmed by the steward (FK) |
| `merge_event_id` | uuid | yes |  | Merge or undo that moved the link (FK) |
| `linked_by` | text | yes |  | Person who confirmed it (FK staff); empty when automatic |
| `rules_version` | text | no |  | Rules used (FK) |

### hub.field_history

One change of one governed field of one partner (D10). Append-only (I15). Lineage is mandatory (I16).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `history_id` | bigint | no | identity | Primary key |
| `bp_id` | text | no |  | Partner (FK) |
| `field_name` | text | no |  | Governed field from the rules file (for example `legal_name`, `customer_payment_terms`, `iban`) |
| `old_value` | text | yes |  | Value before the change; empty for the first value |
| `new_value` | text | yes |  | Value after the change; empty when the value was removed |
| `valid_from` | timestamptz | no |  | Business time from which the new value applies |
| `recorded_at` | timestamptz | no | `now()` | When the hub recorded the change |
| `source_record_id` | uuid | yes |  | Source record version the value came from (FK) |
| `request_id` | text | yes |  | Approved request that set the value (FK) |
| `merge_event_id` | uuid | yes |  | Merge or undo that caused the change (FK). At least one of the three lineage columns is filled |
| `survivorship_step` | smallint | yes |  | Which survivorship step chose the value (1–4, MDH-002 section 6) |
| `changed_by` | text | yes |  | Person, when not automatic (FK staff) |
| `rules_version` | text | no |  | Rules used (FK) |

## Schema `governance`

### governance.quality_runs

One run of the quality rules.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `run_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `rules_version` | text | no |  | Rules used (FK) |
| `scope` | text | no |  | `full` (all partners and source records) or `request` (one request's proposed values) |
| `request_id` | text | yes |  | Request checked; filled only when scope is `request` |
| `as_of` | timestamptz | no |  | Moment the data was checked as of |
| `started_at` | timestamptz | no | `now()` | Start |
| `finished_at` | timestamptz | yes |  | End; empty while running |
| `subjects_checked` | integer | yes |  | Partners and source records checked |

### governance.quality_results

One rule checked on one partner or one source record in one run. Append-only (I15).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `result_id` | bigint | no | identity | Primary key |
| `run_id` | uuid | no |  | Run (FK) |
| `rule_id` | text | no |  | Rule ID from the rules file (for example `K09`), pattern `^[CVUKT][0-9]{2}$` |
| `severity` | text | no |  | `error` or `warning`, copied from the rules version |
| `bp_id` | text | yes |  | Partner checked (FK) |
| `source_record_id` | uuid | yes |  | Source record checked (FK). Exactly one of the two is filled |
| `outcome` | text | no |  | `pass`, `fail`, `not_applicable` |
| `details` | jsonb | yes |  | Values that decided the outcome |

### governance.match_suggestions

One pair of source records the engine thinks may be the same company (rules M1B–M6). M1 links directly and creates no suggestion.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `suggestion_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `a_system_code` | text | no |  | First record's system |
| `a_source_key` | text | no |  | First record's key. The pair is stored in a fixed order: (a system, a key) < (b system, b key) (I17) |
| `a_content_sha256` | text | no |  | Version of the first record compared; a rejected pair is suggested again only if a version changes |
| `b_system_code` | text | no |  | Second record's system |
| `b_source_key` | text | no |  | Second record's key |
| `b_content_sha256` | text | no |  | Version of the second record compared |
| `rule_id` | text | no |  | `M1B` (same tax ID, different names; migration 003), `M2` (group), `M3`, `M4`, `M5`, `M6` (bank risk) |
| `strength` | text | no |  | `tax_conflict` (M1B), `strong`, `normal`, `weak`, `group`, `bank_risk` |
| `score` | numeric(4,3) | no |  | Name similarity or rule score, 0–1 |
| `compared_values` | jsonb | no |  | The values compared and how each matched |
| `status` | text | no | `'open'` | `open`, `confirmed`, `rejected`, `group`. At most one open suggestion per pair (I17) |
| `created_at` | timestamptz | no | `now()` | When suggested |
| `decided_at` | timestamptz | yes |  | When decided; filled together with `decided_by` once status is not `open` |
| `decided_by` | text | yes |  | Steward or data owner (FK staff) |
| `decision_reason` | text | yes |  | Why |
| `rules_version` | text | no |  | Rules used (FK) |

### governance.merge_events

One merge of two partners, or the undo of one. Append-only (I15).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `merge_event_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `event_type` | text | no |  | `merge` or `undo` |
| `survivor_bp_id` | text | no |  | Partner that remains (FK) |
| `absorbed_bp_id` | text | no |  | Partner merged into the survivor, or restored by the undo (FK); never the survivor |
| `undoes_merge_event_id` | uuid | yes |  | For an undo: the merge it reverses (FK); empty for a merge |
| `reason` | text | no |  | Why |
| `match_suggestion_id` | uuid | yes |  | Suggestion that led to it (FK) |
| `request_id` | text | yes |  | Request that led to it (FK) |
| `approved_by` | text | yes |  | Approver (FK staff); empty only for an automatic M1 merge |
| `occurred_at` | timestamptz | no | `now()` | When it happened |
| `rules_version` | text | no |  | Rules used (FK) |

### governance.change_requests

One create, change, block, merge, upload or erasure request.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `request_id` | text | no | 'RQ-' + 6-digit sequence | Primary key, format `RQ-NNNNNN` |
| `request_type` | text | no |  | One of the 13 types in the rules file (for example `change_bank_details`, `corporate_event`, `reactivate_supplier`) |
| `risk` | text | no |  | `low` or `high`, from the fields affected |
| `target_bp_id` | text | yes |  | Partner concerned (FK); empty for a create until applied |
| `status` | text | no | `'draft'` | `draft`, `submitted`, `in_review`, `awaiting_approval`, `approved`, `applied`, `closed`, `returned`, `rejected`, `cancelled` |
| `requested_by` | text | no |  | Requester (FK staff). Unique together with `request_id`, for the approval check (I18) |
| `proposed_values` | jsonb | no | `'{}'` | Fields and the values asked for |
| `reason` | text | yes |  | Why the change is needed |
| `target_working_hours` | integer | no |  | Target from the rules file |
| `created_at` | timestamptz | no | `now()` | Draft created |
| `submitted_at` | timestamptz | yes |  | First submission; the SLA clock starts here |
| `closed_at` | timestamptz | yes |  | Filled exactly when status is `closed`, `rejected` or `cancelled` |
| `rules_version` | text | no |  | Rules used (FK) |

### governance.request_status_history

One status change of one request. Append-only (I15). Net and gross SLA time are calculated from these rows.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `request_id` | text | no |  | Request (FK); part of the primary key |
| `seq` | integer | no |  | 1, 2, 3… per request; part of the primary key |
| `from_status` | text | yes |  | Status before; empty for the first row |
| `to_status` | text | no |  | Status after |
| `changed_by` | text | no |  | Who (FK staff) |
| `changed_at` | timestamptz | no | `now()` | When |
| `note` | text | yes |  | Comment, for example what was missing when Returned |

### governance.request_approvals

One approval decision on one request. Append-only (I15).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `approval_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `request_id` | text | no |  | Request; with `requested_by` a composite FK to `change_requests` (I18) |
| `requested_by` | text | no |  | Copy of the requester, guaranteed equal by the composite FK |
| `approver_id` | text | no |  | Approver (FK staff); never equal to `requested_by` (I18) |
| `approver_role` | text | no |  | Role the approver acted in (for example `finance_controller`) |
| `decision` | text | no |  | `approved` or `rejected` |
| `reason` | text | yes |  | Mandatory in practice for rejections (checked by the engine) |
| `decided_at` | timestamptz | no | `now()` | When |

### governance.request_evidence

One piece of evidence attached to a request. Only references and checksums; no documents are stored.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `evidence_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `request_id` | text | no |  | Request (FK) |
| `evidence_type` | text | no |  | Type from the rules file (for example `bank_certificate`, `independent_verification_via_contact_on_file`) |
| `reference` | text | no |  | Where the document is kept (synthetic reference) |
| `document_sha256` | text | yes |  | Checksum of the document |
| `added_by` | text | no |  | Who added it (FK staff) |
| `added_at` | timestamptz | no | `now()` | When |

### governance.erasure_proofs

One completed erasure of a contact person: proof that it was done, without any of the erased data. Append-only (I15).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `erasure_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `request_id` | text | no |  | Erasure request (FK); unique |
| `contact_id` | uuid | no |  | Contact erased (FK); the row remains with no personal data |
| `bp_id` | text | no |  | Partner the contact belonged to (FK) |
| `source_records_redacted` | integer | no |  | Source record versions redacted |
| `systems_affected` | text[] | no |  | Source systems that held the person |
| `completed_by` | text | no |  | Who ran it (FK staff) |
| `completed_at` | timestamptz | no | `now()` | When |

### source.registry_entries

One company's status in one simulated registry extract (SIRENE-, official-gazette- or Citius-style). Reference data: not linked to partners, compared by country and tax ID (K11). Not visible to reporting (A01).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `registry_entry_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `country` | text | no |  | ISO code |
| `tax_id` | text | no |  | Tax ID as in the registry |
| `registry_status` | text | no |  | `active`, `ceased`, `insolvency_proceedings` or `absorbed` |
| `event_date` | date | yes |  | Date of the event; required unless active |
| `notice_ref` | text | yes |  | Official notice reference (synthetic) |
| `successor_tax_id` | text | yes |  | For an absorbed company, the tax ID of the company that absorbed it |
| `extract_date` | date | no |  | Date of the extract. A company appears once per extract |
| `loaded_at` | timestamptz | no | `now()` | When it was loaded |

### source.hr_employees

One employee in one synthetic HR extract, used only for the employee–supplier cross-match (K10). Restricted: not visible to reporting (A01).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `employee_ref` | text | no |  | Employee reference, format `E-NNNN`; part of the primary key |
| `extract_date` | date | no |  | Date of the extract; part of the primary key |
| `iban` | text | yes |  | Salary account |
| `street_std` | text | yes |  | Home street, standardised |
| `postal_code` | text | yes |  | Home postal code |
| `city` | text | yes |  | Home city |
| `phone_std` | text | yes |  | Phone, international format |
| `loaded_at` | timestamptz | no | `now()` | When it was loaded |

### governance.rule_exceptions

One approved exception to a rule for one partner, for a period: an IBAN registered in another country (K03) or a cleared employee–supplier match (K10).

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `exception_id` | uuid | no | `gen_random_uuid()` | Primary key |
| `rule_id` | text | no |  | Rule the exception applies to, pattern `^[CVUKT][0-9]{2}$` |
| `bp_id` | text | no |  | Partner (FK) |
| `reason` | text | no |  | Why the exception is acceptable |
| `detail` | jsonb | yes |  | Values concerned (not visible to reporting) |
| `approved_by` | text | no |  | Approver (FK staff); the right role is checked by the engine |
| `valid_period` | tstzrange | no |  | When it applies. One exception per rule and partner at a time |
| `request_id` | text | yes |  | Request it came from (FK) |

### governance.suppression_list

One erased or opted-out email, kept only as a hash so that no source can bring the person back (U04, I21). Append-only (I15). Not visible to reporting.

| Column | Type | Null | Default | Description |
|---|---|---|---|---|
| `email_sha256` | text | no |  | Primary key: SHA-256 of the lower-cased email |
| `reason` | text | no |  | `erased` or `opted_out` |
| `request_id` | text | yes |  | Erasure request (FK); required when the reason is `erased` |
| `added_at` | timestamptz | no | `now()` | When it was added |

### hub.partner_names (view)

Current legal and trading names of every partner, plus former names taken from field history. Matching compares all of them (rules v1.3).

| Column | Type | Description |
|---|---|---|
| `bp_id` | text | Partner |
| `name` | text | The name |
| `name_type` | text | `legal` or `trading` |
| `is_current` | boolean | False for a former name |
