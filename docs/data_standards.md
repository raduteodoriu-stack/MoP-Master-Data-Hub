# Data standards (MDH-002)

What a correct business partner record looks like: its parts, how each field is written, and
which fields are mandatory at each lifecycle stage. The machine-readable version is
[`rules/MDH-RULES-v1.5.json`](../rules/MDH-RULES-v1.5.json); if the two ever disagree, the
rules file is what the engine applies and this page must be corrected.

## Decisions

| # | Decision |
|---|---|
| D1 | The hub issues its own ID (`BP-000001`). It is never reused and never changes, even after a merge |
| D2 | Values are stored as received **and** in a standardised form. Matching uses the standardised form only |
| D3 | Two severities. **Error**: the record is not fit for use and a request cannot be approved. **Warning**: reported and queued, but does not block |
| D4 | Two records with different valid tax IDs are never merged. They may be suggested as members of one group |
| D5 | Thresholds in section 5 are starting values. They are tuned in MDH-006 against the MDH-004 answer key, and each change is a new rules version |
| D6 | SLA time is counted in working hours on LeadFlow's calendar (Mon–Fri 09:00–18:00 Europe/Madrid) |
| D7 | The SLA clock stops while a request is Returned to the requester. Turnaround is reported net (steward time, used for the SLA) and gross (what the requester experienced) |
| D8 | Only an exact tax ID match (M1) is linked automatically. Every other match is decided by the steward |
| D9 | Individuals (freelancers) are out of scope as suppliers |
| D10 | Review periods: customers and approved suppliers every 12 months (T01); supplier bank details every 24 months (T02). Request targets per request type are in the rules file (`request_types`) and in [work_instructions/README.md](work_instructions/README.md) |
| D11 | Customer tier replaces *segment*: calculated from industry and employee band with LeadFlow's fit points, rolled up to the company group, overridable only through a request approved by the Sales Director (rules v1.1) |
| D12 | M1 links on a shared tax ID only when the names also agree (0.90 or more); otherwise the new suggestion rule M1B sends the pair to the steward, and warning rule K09 flags a source record carrying another partner's tax ID (rules v1.2) |
| D13 | Rules v1.3: matching fixes G1–G5 (defined similarity, independent bank-risk check, prefix names, invalid tax IDs ignored, no upper limit on M5); former names used in matching; corporate events and supplier reactivation as requests; insolvency and absorbed blocks with a successor link; contact status; holder-name check with match, close match and no match; factoring and alternative payees as documented exceptions; simulated VIES status; employee–supplier cross-match; GDPR retention and suppression list |
| D14 | Rules v1.4: survivorship clarifications found while writing the MDH-004 survivorship cases. The change time is the one stated by the source (G6); ties are broken in the order ERP, CRM, procurement spreadsheet, support desk (G7); bank details are never filled from a non-winning source (G8) |
| D15 | Rules v1.5: a partner whose own customer tier is unknown keeps group tier unknown until its industry and employee band are known (G9, from the MDH-004 customer-tier review); the database enforces it (migration 005) |
| D16 | Requests (MDH-004 batch R review): an erasure request is raised by the steward on the DPO's instruction and approved by the DPO; the approver must hold the required role on the decision date (I25, MDH-007); each data-owner role has a standing deputy, and temporary delegations are dated and recorded as on behalf of; a mass upload is approved or rejected as a whole after a pre-load row report; request KPIs are counted as in [kpi_definitions.md](kpi_definitions.md) |

## 1. What a business partner record contains
| Part | Holds | One per partner? |
|---|---|---|
| General data | Identity shared by every role: names (current and former), legal form, country, tax ID, VIES status, web domain, registered address | Yes |
| Customer role | Customer tier (calculated, group and override), account owner, industry, employee band, billing address, bill-to party, payment terms, invoice email, billing block | At most one |
| Supplier role | Category, internal contact, payment terms, remittance email, bank details with payee type and their verification, last ERP activity, payment block | At most one |
| Contact persons | Name, work email, role, legal basis, status (active, left the company, email bouncing, erased) and date last verified | Many |
| Relationships | Parent partner (`subsidiary_of`) and, after a merger, the successor (`successor_of`) | At most one of each at a time |
| Cross-reference | The source records that make up this partner | Many |

A *branch* (same legal entity, another address) is an extra address on the same partner. A *subsidiary* (its own tax ID) is its own partner with a parent.

### Lifecycle events and new fields in rules v1.3

| Topic | Standard |
|---|---|
| Corporate events | A rename, legal form change or merger is a `corporate_event` request with a registry extract as evidence. After a rename the old name is kept as a former name and used in matching. After a merger the absorbed partner gets block reason `absorbed`, its roles become inactive, and it is linked to the surviving partner with `successor_of` |
| Registry status | A simulated registry extract gives each company's status by tax ID: active, ceased, insolvency proceedings or absorbed. A partner with an active role and a non-active registry status becomes a steward task (K11); insolvency is blocked with reason `insolvency`, approved by the Finance Controller |
| Dormant suppliers | The ERP's last purchase order or invoice date is kept as the supplier's last activity. After 12 months without activity the supplier is flagged for deactivation (T05); bringing it back needs a `reactivate_supplier` request, which includes verifying the bank details again |
| Bank details | Payee type `own_account`, `factoring_company` or `alternative_payee`; anything but own account needs an assignment letter. The holder name check returns match, close match (similarity 0.85 or more) or no match, like the payee-name check banks run on euro transfers (K02). Changing back to a previous IBAN within 90 days, or two changes within 30 days, alerts the Finance Controller (K13) |
| Contact status | `active`, `left_company`, `bounced` or `erased`, with the date last verified. A bank change may only be verified through an active contact verified in the last 12 months (K12) |
| VIES status | For partners registered outside Spain (intra-EU for MoP Cloud): `valid`, `not_registered` or `invalid`, with the check date and an evidence reference. Checked again every 12 months and after a tax ID change (V13). Simulated: no live service is called |
| Employees | A synthetic HR extract (IBAN, address, phone) is compared with suppliers; a match goes to the Finance Controller, who may clear it (K10). The extract is never visible to reporting |
| Retention | Prospect contacts with no contact for 3 years are anonymised (T06); customer contacts are kept for the relationship plus 3 years. Erased or opted-out emails are kept only as a SHA-256 hash on a suppression list, so a source cannot bring the person back (U04) |
| Physical address | An approved supplier needs a street address, not only a PO box (V12) |
| Address standardisation | Upper case, accents removed, abbreviations expanded (`C/` and `Cl` → CALLE, `Avda.` → AVENIDA, `R.` → RUA, `Bd` → BOULEVARD), ordinal marks and punctuation removed. Used by the employee cross-match, matching and K06 |

## 2. Field standards
| Field | Standard | Risk |
|---|---|---|
| Legal name | As on the tax registration, with the legal form written the standard way for the country (for example `S.L.`, `S.A.`, `Lda.`, `SAS`, `SARL`). No placeholders (`test`, `n/a`, `tbc`) | High |
| Trading name | The name the company is known by. Used for prospects when the legal name is not yet known | Low |
| Legal form | From a fixed list per country | High |
| Country of registration | ISO two-letter code (`ES`, `PT`, `FR`) | High |
| Tax ID | ES: NIF for companies, one letter + seven digits + control character. PT: NIPC, nine digits with check digit. FR: SIREN, nine digits with check digit. Stored without spaces, dots or dashes | High |
| VAT number | Derived from the tax ID: country prefix + tax ID (for FR, prefix + two-digit key + SIREN). Never typed by hand | High |
| Web domain | Lower case, the registrable domain only (no `www`, no `https://`, no path). Free email domains are not allowed | Low |
| Addresses | Street, postal code, city, region, country as separate fields. Postal code: ES five digits starting 01–52, PT `NNNN-NNN`, FR five digits | High |
| Phone | International format, `+` and digits only | Low |
| Industry, employee band | LeadFlow's existing lists. `unknown` is allowed for prospects | Low |
| Account owner | A LeadFlow owner ID that exists and is active | Low |
| Payment terms | One of `NET15`, `NET30`, `NET45`, `NET60`. Anything else needs the Finance Controller | High |
| Invoice and remittance email | Valid format. A shared mailbox is preferred to a person's address | High |
| Bank details (suppliers) | IBAN with valid length for its country (ES 24, PT 25, FR 27) and valid check digits; account holder name; date, method and person of the last verification | High |
| Supplier category | `panel_sample_provider`, `software`, `professional_services`, `facilities`, `other` | Low |
| Contact person | First name, last name, work email, role, legal basis. No private email addresses, no other personal data | Personal data |
| Parent partner | An existing, unblocked partner. No loops. At most five levels | High |

## 3. Mandatory fields by stage
M = mandatory, O = optional, – = not applicable.

| Field | Prospect | Customer | Supplier requested | Supplier approved |
|---|---|---|---|---|
| Trading name or legal name | M | M | M | M |
| Country | M | M | M | M |
| Web domain | M | M | O | O |
| Legal name, legal form | O | M | O | M |
| Tax ID | O | M | O | M |
| Registered address | O | M | O | M |
| Account owner | M | M | – | – |
| Industry, employee band | O | M | – | – |
| Billing address, bill-to party, invoice email | – | M | – | – |
| Payment terms | – | M | O | M |
| Supplier category, internal contact | – | – | M | M |
| Bank details and verification | – | – | O | M |
| Remittance email | – | – | O | M |
| At least one contact person | O | M | O | M |

## Customer tier (rules v1.1)

Every customer role (prospects included) gets a tier, scored the same way as LeadFlow's fit
score: points per attribute, added into a score, and fixed thresholds that turn the score into
a tier. Only the two stable company attributes count. LeadFlow's research need, frequency and
readiness change with every sales conversation, so they belong to the lead, not to master data.

| Attribute | Points (same as LeadFlow) |
|---|---|
| Industry | Core research (`market_research`, `polling`, `research_consultancy`, `panel_sample_provider`) 40 · research-adjacent (`research_technology`, `advertising_media_pr_agency`, `ux_research_agency`, `management_consultancy`) 30 · other named industries 20 · `other` 0 |
| Employee band | 1–10: 0 · 11–49: 5 · 50–249: 10 · 250–999: 15 · 1000+: 20 |

| Tier | Score (0–60) | Typical customers |
|---|---|---|
| `tier_1` Strategic | 50 or more | Core research companies with 50+ employees; research-adjacent companies with 1000+ |
| `tier_2` Core | 30–49 | Smaller core research firms; most research-adjacent companies; companies in other named industries with 50+ |
| `tier_3` Standard | below 30 | Small companies in other named industries; industry `other` |
| `unknown` | – | Industry or employee band is `unknown`; no tier is guessed |

**Three tiers are kept for each customer:**

1. **Calculated tier:** from the partner's own industry and employee band, with its score and
   reason codes (for example `TIER_INDUSTRY_CORE`, `TIER_SIZE_50_249`).
2. **Group tier:** the highest calculated tier among all current members of the partner's
   company group (`TIER_GROUP_ROLLUP` when it is higher than its own). A partner with no group
   has a group tier equal to its calculated tier. A partner whose own tier is unknown keeps
   group tier unknown until its own data is complete (G9, rules v1.5); its unknown tier is
   ignored when the other members' group tier is calculated.
3. **Override:** set only through an `override_customer_tier` request approved by the Sales
   Director. The calculated and group tiers are kept beside it.

The **effective tier** is the override if there is one, otherwise the group tier. Tiers are
recalculated when industry, employee band or the hierarchy changes, and when a new rules version
is loaded. KPI12 (Tier Override Rate) shows how often Sales disagrees with the rules.

## Controlled values kept in the rules file

Some lists are too long for these tables and live only in
[`rules/MDH-RULES-v1.5.json`](../rules/MDH-RULES-v1.5.json) under `controlled_values` and
`countries`: legal forms per country, free email domains (rule V05), name placeholders (rule
V11), legal bases for contact persons, block reasons, industry codes and employee bands (the
same lists as LeadFlow).
