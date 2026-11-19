# Test cases (MDH-004)

Hand-written cases with the outcome the hub must produce, written before the engine exists.
Each batch is reviewed before it is used; corrections are recorded in the batch's review notes.
The generator (MDH-004 phase B) puts every case into the synthetic dataset unchanged, and the
engine tests (MDH-005 onwards) check the engine against these outcomes.

| Batch | Cases | Proves | Status |
|---|---|---|---|
| Q | Q-01 to Q-30 | Every quality rule (C, V, U, K, T) | Reviewed |
| M | M-01 to M-18 | Matching rules M1 to M6 and the four duplicate patterns | To do |
| S | S-01 to S-07 | Survivorship | To do |
| T | T-01 to T-09 | Customer tier | To do |
| H | H-01 to H-05 | Hierarchy | To do |
| R | R-01 to R-18 | Requests | To do |
| E | E-01 to E-03 | Erasure | To do |
| L | L-01 to L-03 | Coupling with LeadFlow | To do |

## Batch Q: Quality rules (Q-01 to Q-30)

**Status:** reviewed, no corrections. Rules version `MDH-RULES-v1.2`. As-of moment for timeliness rules: Fri 27 Nov 2026 18:00 (Madrid).

Synthetic data only. Tax IDs are random numbers with valid (or deliberately wrong) check digits; IBANs use the invented bank code 9999/99999.

Each case proves one rule with a record that passes and one that fails (and, where useful, one where the rule does not apply). The machine-readable version, with the full input records, is `tests/fixtures/cases/q_quality_rules.json`.

**Review notes.** Agreed as drafted, including these choices: values that standardisation can fix
pass (country names, website URLs, local phone numbers, free-text payment terms such as "45 días");
U01 and K07 are checked on requests, because the database already prevents them in golden
records; a shared IBAN inside one company group passes U03; K03 passes when an exception is
recorded; K06 ignores letter case and punctuation; "one working day" in T03 is 540 working minutes.

| Case | Rule | Checked on | Variant | Given | Expected | Why |
|---|---|---|---|---|---|---|
| Q-01 | C01 | partner | pass | Customer with every field the customer stage needs | ✅ pass | All 15 customer-stage fields filled |
|  |  |  | fail | Same customer without billing address and payment terms | ❌ fail | Missing: billing_address, payment_terms |
|  |  |  | pass | Same record at prospect stage (billing data not yet required) | ✅ pass | Prospect needs only name, country, web domain, account owner |
| Q-02 | C02 | partner | pass | Customer: market_research, 50-249 | ✅ pass |  |
|  |  |  | fail | Customer: employee band unknown | ❌ fail | employee_band is unknown (tier is unknown too) |
|  |  |  | n/a | Prospect with unknown band | – not applicable | Rule applies to customers only |
| Q-03 | C03 | partner | pass | Approved supplier with contact 'Account Manager' | ✅ pass |  |
|  |  |  | fail | Approved supplier whose only contact has no role | ❌ fail | No contact with a role |
| Q-04 | V01 | partner | pass | ES NIF B27164532 | ✅ pass | Control digit correct |
|  |  |  | fail | ES NIF B27164535 (one digit off) | ❌ fail | Control digit should be 2 |
|  |  |  | pass | PT NIPC 517349060 | ✅ pass | Mod-11 check digit correct |
|  |  |  | fail | FR SIREN 812436050 | ❌ fail | Luhn check fails |
| Q-05 | V02 | source record | pass | ERP: NIF B27164532, VAT ESB27164532 | ✅ pass |  |
|  |  |  | fail | ERP: SIREN 812436053, VAT FR00812436053 | ❌ fail | Expected FR35812436053 |
| Q-06 | V03 | source record | pass | Support desk: 'Portugal' (standardised to PT) | ✅ pass | Standardised to PT |
|  |  |  | fail | Support desk: 'UK' (the ISO code is GB) | ❌ fail | Not an ISO 3166 code |
| Q-07 | V04 | partner | pass | FR address 69002 Lyon | ✅ pass |  |
|  |  |  | fail | ES address 60123 (no province 60) | ❌ fail | Spanish postal codes start 01-52 |
| Q-08 | V05 | source record | pass | CRM: 'https://www.mercats-test.example/ca' (standardised to mercats-test.example) | ✅ pass | Standardised to mercats-test.example |
|  |  |  | fail | CRM: 'gmail.com' typed as company website | ❌ fail | Free email domain |
| Q-09 | V06 | partner | pass | Invoice email factures@mercats-test.example | ✅ pass |  |
|  |  |  | fail | Invoice email facturas@@cliente-prueba.example | ❌ fail | Invalid email |
| Q-10 | V07 | source record | pass | PT record: '21 000 0000' (standardised to +351210000000) | ✅ pass | Standardised with the country prefix |
|  |  |  | fail | ES record: '12345' | ❌ fail | Too short to standardise |
| Q-11 | V08 | source record | pass | Procurement sheet: '45 días' (standardised to NET45) | ✅ pass | Standardised to NET45 |
|  |  |  | fail | ERP: 'NET90' | ❌ fail | Not in NET15/30/45/60; needs the Finance Controller |
| Q-12 | V09 | partner | pass | FR supplier IBAN FR8499999000100001234567821 | ✅ pass |  |
|  |  |  | fail | ES supplier IBAN ES1299990001000123456789 | ❌ fail | Check digits should be 98 |
| Q-13 | V10 | partner | pass | PT 'Opiniões Teste Lda.', legal form Lda. | ✅ pass |  |
|  |  |  | fail | ES 'Mercats Test S.L.', legal form S.A. | ❌ fail | Name ends S.L., legal form S.A. |
| Q-14 | V11 | partner | pass | Legal name 'Études Essai SAS' | ✅ pass |  |
|  |  |  | fail | Legal name 'TBC' | ❌ fail | Placeholder |
| Q-15 | U01 | request | pass | Create-customer request with a new NIF B31488208 | ✅ pass |  |
|  |  |  | fail | Create-customer request with NIF B27164532 (already BP-900001) | ❌ fail | Tax ID already belongs to BP-900001: request cannot be submitted |
| Q-16 | U02 | source record | pass | CRM C-100001 linked to BP-900001 | ✅ pass |  |
|  |  |  | fail | Support S-200001 with no link (waiting for a steward decision) | ❌ fail | Unlinked; open suggestion in the steward queue |
| Q-17 | U03 | partner | pass | Group mother and its subsidiary share ES5899990002000987654321 (cash pooling) | ✅ pass | Same group |
|  |  |  | fail | Two unrelated suppliers share ES9899990001000123456789 | ❌ fail | Sent to the steward (also M6 bank-risk review) |
| Q-18 | K01 | source record | pass | ERP: country PT, NIPC 517349060 | ✅ pass |  |
|  |  |  | fail | ERP: country PT, tax ID B27164532 (a Spanish NIF) | ❌ fail | Tax ID format is Spanish |
| Q-19 | K02 | partner | pass | Holder 'PANELES PRUEBA SL', legal name 'Paneles Prueba S.L.' | ✅ pass | Equal after standardisation |
|  |  |  | fail | Holder 'Jordi Exemple' (a person) | ❌ fail | Sent to the steward |
| Q-20 | K03 | partner | pass | FR supplier with ES IBAN, exception 'Spanish branch account' recorded | ✅ pass | Exception recorded |
|  |  |  | fail | FR supplier with PT IBAN, no exception | ❌ fail | IBAN country PT, registration FR |
| Q-21 | K04 | partner | pass | Bill-to is the customer itself | ✅ pass |  |
|  |  |  | fail | Bill-to BP-900008 has a credit block | ❌ fail | Bill-to party blocked |
| Q-22 | K05 | partner | pass | Subsidiary under active mother BP-900005 | ✅ pass |  |
|  |  |  | fail | Subsidiary under BP-900009, which has a compliance block | ❌ fail | Parent blocked (loops and depth are refused by the database, I12) |
| Q-23 | K06 | partner | pass | CRM 'MERCATS TEST SL' vs golden 'Mercats Test S.L.' | ✅ pass | Equal after standardisation |
|  |  |  | fail | CRM registered street 'Carrer Antic 3' vs golden 'Carrer de Prova 1' | ❌ fail | CRM disagrees; the CRM is reported to its owner |
| Q-24 | K07 | request | pass | Block request: reason 'credit', approver Finance Controller | ✅ pass |  |
|  |  |  | fail | Block request with no reason | ❌ fail | Request cannot be submitted (the database also refuses it, I11) |
| Q-25 | K08 | partner | pass | laia.prova@mercats-test.example on mercats-test.example | ✅ pass |  |
|  |  |  | fail | laia.prova@gmail.com on mercats-test.example | ❌ fail | Private email domain |
| Q-26 | K09 | source record | pass | CRM 'Ensayo Portugal Lda.' with its own NIPC 509812333, linked to BP-900006 | ✅ pass |  |
|  |  |  | fail | CRM 'Ensayo Portugal' carrying the mother's NIF A55204176, linked to BP-900006; the NIF belongs to BP-900005 | ❌ fail | Tax ID belongs to BP-900005: reported to the CRM owner |
| Q-27 | T01 | partner | pass | Customer last reviewed 15 Mar 2026 | ✅ pass |  |
|  |  |  | fail | Customer last reviewed 1 Oct 2025 | ❌ fail | Almost 14 months |
|  |  |  | n/a | Prospect never reviewed | – not applicable | Rule applies to customers and approved suppliers |
| Q-28 | T02 | partner | pass | Changed 4 May 2026, verified 5 May 2026 | ✅ pass |  |
|  |  |  | fail | Changed 4 May 2026, last verified 10 Jan 2026 | ❌ fail | Not verified since the change |
|  |  |  | fail | Unchanged since 2023, verified 1 Jun 2024 | ❌ fail | More than 24 months (almost 30) |
| Q-29 | T03 | source record | pass | CRM change Mon 16 Nov 15:00, loaded Tue 17 Nov 09:30 | ✅ pass | 210 working minutes |
|  |  |  | fail | CRM change Fri 13 Nov 17:00, loaded Tue 17 Nov 10:00 | ❌ fail | 660 working minutes |
| Q-30 | T04 | suggestion | pass | Suggested Mon 16 Nov 10:00, decided Thu 19 Nov 12:00 | ✅ pass | 1,740 working minutes |
|  |  |  | fail | Suggested Mon 2 Nov 10:00, still open at the as-of moment | ❌ fail | Open 10,740 working minutes |
