# MoP Master Data Hub

**One agreed record for every customer and supplier, with an owner for every field and a trail
for every change.** The hub finds which records in the CRM, the ERP, the support desk and the
procurement spreadsheet describe the same company, builds one golden record from them, routes
every creation and change through approval, and reports data quality.

Built as a portfolio project for a simulated B2B research-technology vendor (**MoP Cloud**)
selling in Spain, Portugal and France. It is the master data layer behind
[LeadFlow EU](https://github.com/raduteodoriu-stack/leadflow-eu) (lead routing) and Revenue
Leak Radar (pipeline risk).

> All company, person, tax and bank data is synthetic. No real customer, supplier or personal
> information is used.

## The business problem

- The same customer exists two or three times across systems, so nobody can say how many
  customers MoP Cloud has.
- Invoices go to the wrong legal entity or carry an invalid tax ID, and are reissued.
- A subsidiary's lead goes to a different salesperson than its parent's, because the systems
  don't know the two belong together.
- Supplier bank details are changed by email, with no independent check.
- Anyone can create or change a customer or supplier, with no approval and no audit trail.

## Status

| Card | Status |
|---|---|
| MDH-001 Scope and governance | Documents in this repo |
| MDH-002 Data standards and quality rules v1 | Rules file and documents in this repo; customer tier added in rules v1.1 |
| MDH-003 Data foundation (PostgreSQL) | Next |
| MDH-004 to MDH-010 | Backlog |

## Documentation

| Document | What it covers |
|---|---|
| [docs/scope.md](docs/scope.md) | Business context, stakeholders, key terms, decisions, card map, scope boundary |
| [docs/governance.md](docs/governance.md) | Roles, data ownership, lifecycle per role, decision rights, separation of duties |
| [docs/data_standards.md](docs/data_standards.md) | Record structure, field standards, mandatory fields by stage |
| [docs/quality_rules.md](docs/quality_rules.md) | 29 quality rules, matching rules, survivorship |
| [docs/kpi_definitions.md](docs/kpi_definitions.md) | Every KPI with numerator and denominator |
| [docs/work_instructions/](docs/work_instructions/README.md) | One page per request type (steps completed in MDH-007) |
| [rules/MDH-RULES-v1.1.json](rules/MDH-RULES-v1.1.json) | The versioned rules the engine reads (current). [v1.0](rules/MDH-RULES-v1.0.json) is kept for history |

## Planned stack

Python (standard library + psycopg 3), PostgreSQL, dbt, Power BI, pytest, the same as LeadFlow EU.

## Licence

MIT. See [LICENSE](LICENSE).
