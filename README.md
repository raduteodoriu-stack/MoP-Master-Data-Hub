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
| MDH-002 Data standards and quality rules v1 | Rules file and documents in this repo; customer tier added in rules v1.1; same-tax-ID review (M1B) and rule K09 in v1.2 |
| MDH-003 Data foundation (PostgreSQL) | 25 tables, 20 integrity rules, 13 test files |
| MDH-004 to MDH-010 | Backlog |

## Documentation

| Document | What it covers |
|---|---|
| [docs/scope.md](docs/scope.md) | Business context, stakeholders, key terms, decisions, card map, scope boundary |
| [docs/governance.md](docs/governance.md) | Roles, data ownership, lifecycle per role, decision rights, separation of duties |
| [docs/data_standards.md](docs/data_standards.md) | Record structure, field standards, mandatory fields by stage |
| [docs/quality_rules.md](docs/quality_rules.md) | 30 quality rules, matching rules, survivorship |
| [docs/kpi_definitions.md](docs/kpi_definitions.md) | Every KPI with numerator and denominator |
| [docs/database_design.md](docs/database_design.md) | Tables, relationships, history, integrity and access rules |
| [docs/data_dictionary.md](docs/data_dictionary.md) | Every table and column |
| [docs/work_instructions/](docs/work_instructions/README.md) | One page per request type (steps completed in MDH-007) |
| [rules/MDH-RULES-v1.2.json](rules/MDH-RULES-v1.2.json) | The versioned rules the engine reads (current). [v1.0](rules/MDH-RULES-v1.0.json) and [v1.1](rules/MDH-RULES-v1.1.json) are kept for history |

## Setup

Requires PostgreSQL 16 or later (developed on 18), with the `btree_gist` extension available
(it ships with PostgreSQL). Connection settings come from the usual PostgreSQL environment
(`PGUSER`, `PGHOST`, `~/.pgpass`).

Create the database, apply the schema and run all constraint tests in one step:

```
SQL/tests/run_all_tests.sh --rebuild
```

The runner recreates `mop_mdh`, applies `SQL/001_create_schema.sql` and later migrations in
order, runs every test file in `SQL/tests/` and writes a log to `docs/evidence/`. A
`mop_mdh_test` database is used by the Python tests from MDH-005 on.

## Stack

PostgreSQL now; Python (standard library + psycopg 3), dbt, Power BI and pytest in later cards,
the same as LeadFlow EU.

## Licence

MIT. See [LICENSE](LICENSE).
