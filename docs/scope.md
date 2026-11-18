# Scope (MDH-001)

The MoP Master Data Hub (MDH) keeps one agreed record for every organisation MoP Cloud does
business with, as a customer, a supplier or both. It decides which records in the CRM, the
ERP, the support desk and the procurement spreadsheet describe the same company, keeps a
named owner for every field and a trail for every change, and reports data quality.

MDH is the third part of the MoP Cloud story. [LeadFlow EU](https://github.com/raduteodoriu-stack/leadflow-eu)
gets a lead to the right salesperson; Revenue Leak Radar watches the deal. Both assume they
know *which company* they are dealing with. MDH is where that is decided.

> All company, person, tax and bank data in this repo is synthetic.

Roles, data ownership, lifecycle and decision rights are in [governance.md](governance.md).
Field standards and rules are in [data_standards.md](data_standards.md) and
[quality_rules.md](quality_rules.md).

## Company
 MoP Cloud, a Barcelona-based B2B research-technology SaaS company selling in Spain, Portugal and France. It buys from panel and sample providers, software vendors and professional-services firms, some of which are also its customers.

## The problem
- The same customer exists two or three times, spelled differently in the CRM, the billing system and the support desk. Nobody can say how many customers MoP Cloud has.
- Invoices go to the wrong legal entity or carry an invalid tax ID, so they are rejected and reissued.
- A lead from a subsidiary is routed to a different salesperson than the one who owns the parent, because the systems do not know the two belong together. LeadFlow recognises a company by its web domain only.
- Suppliers live in a spreadsheet and in the ERP, with different names and bank details. A bank-detail change arrives by email and is typed in by whoever receives it.
- A company that is both customer and supplier is two unrelated records, so nobody sees the full relationship.
- Anyone can create or change a business partner, with no approval and no record of who changed what.
- Reports "by customer" or "by supplier" give different totals depending on the system they come from.

## Stakeholders
| Stakeholder | Question MDH answers |
|---|---|
| Finance Controller / CFO | Are we invoicing the right legal entity, and paying the right supplier into a verified bank account? |
| Sales Director / CRO | How many customers do we really have, who owns each one, and which belong to the same group? |
| Head of Operations | Which suppliers are approved, what do we buy from each, and which are also our customers? |
| Master data steward | What is waiting for me, what is oldest, and where is quality worst? |
| Requesters (Sales, Finance, Operations, Customer Success) | How do I get a customer or supplier created or corrected, and how long will it take? |
| RevOps / IT | Do the source systems agree with the hub? Are the rules working? |
| Data Protection Officer | Can we find a person in every system and erase them when asked? |

## Key terms
| Term | Meaning here |
|---|---|
| Master data | The stable facts about a company that many processes reuse: who they are, where they are, how they pay or get paid. Not transactions (leads, deals, invoices, purchase orders) |
| Business partner | Any organisation MoP Cloud does business with. *Customer* and *supplier* are roles, and one partner can hold both |
| Source record | One system's version of a business partner |
| Golden record | The single agreed version of a business partner, built from its source records |
| Cross-reference | The list of source records that belong to one golden record. It makes a merge reversible |
| Survivorship | The rule that says which source wins for each field when sources disagree |
| Steward | The person who looks after the data day to day: the Master Data Specialist |
| Four-eyes approval | The person who approves a change is not the person who asked for it |

## Decisions

| # | Decision |
|---|---|
| D1 | Name: **MoP Master Data Hub**, short name MDH, card prefix `MDH-` |
| D2 | Same simulated vendor (**MoP Cloud**), markets (ES, PT, FR), time zone (Europe/Madrid) and working calendar as LeadFlow |
| D3 | Domain: **business partner master, covering customers and suppliers**. One organisation is one business partner and can hold both roles. Contact persons are dependent data |
| D4 | MDH is built before RLR continues. RLR is paused after RLR-002, and RLR-003 will use the golden business partner ID as its account key |
| D5 | Two phases: a one-off **clean-up** of what the source systems already hold, then a governed **run** phase where creations and changes go through requests |
| D6 | One steward. The data owner is the second approver on high-risk changes. Nobody approves a request they raised |
| D7 | Full scope: MDH-001 to MDH-010. MDH-011 stays optional |
| D8 | Four simulated sources: CRM (HubSpot, LeadFlow's `companies`), finance/ERP (customer and supplier accounts), support desk, and a procurement spreadsheet of suppliers |
| D9 | Supplier data ownership is split: the Finance Controller owns tax, bank and payment data; the Head of Operations owns commercial supplier data |
| D10 | Suppliers in scope are organisations. Individuals (freelancers, survey participants) are out |
| D11 | Own repo, `mop-master-data-hub`. LeadFlow's code and tests are not changed |
| D12 | Stack: Python (standard library + psycopg 3), PostgreSQL, dbt, Power BI, pytest, the same as LeadFlow |
| D13 | Volume: about 1,800 source records resolving to about 800 customers and 150 suppliers (about 25 hold both roles), with about 60 corporate groups of 2 to 4 levels. Final numbers in MDH-004 |
| D14 | Synthetic data only. No real company, person, tax ID or bank account. No live system |

## Approach

1. **Standards first.** Field definitions, mandatory fields per stage, formats and quality rules are versioned in `rules/` (MDH-002; current version `MDH-RULES-v1.1.json`), not hidden in code.
2. **Answer keys first.** Hand-written cases with expected outcomes (MDH-004) are reviewed before the engine is built.
3. **One partner, several roles.** A customer that is also a supplier is one partner with shared legal data and separate role data.
4. **Never lose a source record.** Every source record is kept as received. The golden record is derived from source records plus the cross-reference, so it can be rebuilt and any merge undone.
5. **Explainable matching.** Exact tax ID matches are linked automatically. Everything else is a suggestion with a score, reason codes and the rules version.
6. **People decide the unclear cases.** Uncertain matches go to the steward's queue. Nothing uncertain is merged automatically.
7. **History.** Every governed field keeps what was true and when, so a report can be rebuilt as of any date.
8. **Clean-up, then run.** Phase 1 loads and reconciles the four sources (a migration). Phase 2 handles new requests under the decision rights above.
9. **Privacy by design.** Contact persons hold the minimum needed. An erasure reaches every source record and leaves proof without keeping the erased data.
10. **Coupling to LeadFlow and RLR.** MDH publishes a golden business partner ID per source company, and a list of known supplier domains, through a defined contract.

## Core KPIs

Defined in [kpi_definitions.md](kpi_definitions.md): Data Quality Score (by dimension) ·
Duplicate Rate · Golden Record Coverage · Cross-System Consistency · Match Review Backlog and
Age · Request Turnaround Time and SLA Attainment · First-Time-Right Rate · Verified Bank
Details Rate.

## Card map

| Stage | Cards |
|---|---|
| Define | MDH-001 Scope and governance · MDH-002 Data standards and quality rules v1 · MDH-003 Data foundation (PostgreSQL) |
| Test data | MDH-004 Hand-written cases, answer keys and synthetic dataset |
| Engine | MDH-005 Standardise and validate · MDH-006 Match, merge, survivorship and steward queue · MDH-007 Change requests, approvals, SLA and mass upload · MDH-008 Hierarchy and publishing to LeadFlow and RLR |
| Reporting | MDH-009 dbt data quality model and Power BI dashboard |
| Portfolio | MDH-010 README, work instructions, architecture, pitch |
| Optional | MDH-011 LLM-drafted match explanation for the steward (never merges) |

## Scope boundary

**In:** customer and supplier organisations in ES, PT and FR, as one business partner with roles; their contact persons; four simulated sources; data standards and quality rules; matching, golden record, cross-reference, reversible merges; steward review queue; create, change and block requests with risk-based approval and a working-hours SLA; supplier bank details with verification evidence; mass upload with pre-load checks; parent-child hierarchy; dated history of governed fields; erasure of contact persons; dbt and Power BI; publishing golden IDs and supplier domains to LeadFlow and RLR.

**Out:** product/material and finance master data (ledger accounts, cost centres); individuals as suppliers; purchase orders, invoices and payment release; any real SAP, Dynamics 365, Salesforce or other live system; live tax-ID or bank lookups (format and check-digit validation only); paid enrichment data; machine-learning matching; real-time synchronisation; credit management and pricing; partners registered outside ES, PT and FR, except as a parent company with minimal data; any real company, personal or bank data; any claim of revenue or cash impact. MDH reports technical results only.
