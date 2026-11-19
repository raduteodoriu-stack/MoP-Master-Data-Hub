# Test cases (MDH-004)

Hand-written cases with the outcome the hub must produce, written before the engine exists.
Each batch is reviewed before it is used; corrections are recorded in the batch's review notes.
The generator (MDH-004 phase B) puts every case into the synthetic dataset unchanged, and the
engine tests (MDH-005 onwards) check the engine against these outcomes.

| Batch | Cases | Proves | Status |
|---|---|---|---|
| Q | Q-01 to Q-30 | The 30 quality rules of v1.2 (C, V, U, K, T); the nine new v1.3 rules are in batch C | Reviewed |
| M | M-01 to M-18 | Matching rules M1 to M6 and the four duplicate patterns | Reviewed |
| C | C-01 to C-17 | Company lifecycle, fraud and privacy (rules v1.3) | Reviewed |
| S | S-01 to S-09 | Survivorship | Reviewed |
| T | T-01 to T-10 | Customer tier | Reviewed |
| H | H-01 to H-06 | Hierarchy | Reviewed |
| R | R-01 to R-23 | Requests, approvals, SLA and request KPIs | Reviewed |
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

## Batch M: Matching (M-01 to M-18)

**Status:** reviewed. Rules: MDH-RULES-v1.3. All names, domains, tax IDs and IBANs are synthetic.

**Name standardisation:** Upper case, accents removed, punctuation removed, legal forms (SL, SLU, SA, SAU, SCOOP, LDA, UNIPESSOAL, SAS, SASU, SARL, EURL) removed, spaces collapsed.  
**Similarity:** difflib.SequenceMatcher ratio on the standardised names, rounded to 3 decimals (G1).

**Review notes.** Agreed as drafted, with the five rule fixes below (released in
`MDH-RULES-v1.3.json`) and the known limit for subsidiaries abroad.

### Rule gaps found while writing this batch (fixed in rules v1.3)

Writing the cases showed five places where rules v1.2 was silent or gave the wrong answer.

| # | Gap in v1.2 | Fix in v1.3 | Cases |
|---|---|---|---|
| G1 | "Similarity 0 to 1" does not say how it is measured, so the thresholds cannot be tested | `difflib.SequenceMatcher` ratio on the standardised names (Python standard library), rounded to 3 decimals | all |
| G2 | M6 sits last in a "first rule decides" list, so a shared IBAN between two companies with different tax IDs is never flagged (M2 decides first) | Bank-risk check M6 runs on every pair, independently of M1–M5 | M-13 |
| G3 | One company with an account per office often has the city in the name ("Estudios Faro Madrid"); similarity 0.788 misses it | M3 also applies when one standardised name starts with the other (whole words), with the same domain and country | M-16, M-17 |
| G4 | Not stated what happens when two records share an *invalid* tax ID | A tax ID that fails V01 is treated as missing for matching | M-07 |
| G5 | M5 covers similarity 0.75–0.85 only, so a pair at 0.90 in the same city but with no shared postal code or phone gets no suggestion at all | M5: similarity 0.75 or more (no upper limit) and the same city | M-10, M-11, M-14 |

**Known limit kept on purpose:** a subsidiary in another country, with the mother company's name
and no tax ID (pattern 3 abroad), gets no suggestion: M3 requires the same country, so the
subsidiary is not merged into its mother company, but it is not grouped either. The steward
links it in the hierarchy (batch H).

The machine-readable version is `tests/fixtures/cases/m_matching.json`. Every pair of records in
every case was also run through a reference matcher with rules v1.3: no pair gets a
suggestion that is not listed.

### M-01 M1: duplicate inside one system

- `crm C-300101`, **Mercats Test S.L.**, ES, tax ID B27164532, domain mercats-test.example, city Barcelona
- `crm C-300102`, **MERCATS TEST, SL**, ES, tax ID B27164532, city Barcelona

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| crm C-300101 ~ crm C-300102 | 1.0 | M1: auto_link | Same valid NIF, names equal after standardisation |

**Partners at the end:** {crm C-300101, crm C-300102}.

### M-02 M1: the same company in two systems

- `crm C-300201`, **Opiniões Teste Lda.**, PT, tax ID 517349060, domain opinioes-teste.example
- `erp E-300201`, **OPINIOES TESTE LDA**, PT, tax ID 517349060

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| crm C-300201 ~ erp E-300201 | 1.0 | M1: auto_link | Same valid NIPC, names equal after standardisation |

**Partners at the end:** {crm C-300201, erp E-300201}.

### M-03 M1: a customer that is also a supplier becomes one partner with two roles

- `erp E-300301`, **Études Essai SAS**, FR, tax ID 812436053, role customer
- `procurement_sheet P-300301`, **Etudes Essai**, FR, tax ID 812436053, role supplier

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| erp E-300301 ~ procurement_sheet P-300301 | 1.0 | M1: auto_link | Same valid SIREN, names equal after standardisation |

**Partners at the end:** {erp E-300301, procurement_sheet P-300301}.

*One partner with a customer role and a supplier role*

### M-04 M1 and M1B either side of the 0.90 name threshold

- `erp E-300401`, **Cifras Norte S.L.**, ES, tax ID B44730216
- `crm C-300401`, **Cifra Norte S.L.**, ES, tax ID B44730216
- `erp E-300402`, **Muestra Clara S.L.**, ES, tax ID B66201948
- `crm C-300402`, **Muestra Claris**, ES, tax ID B66201948

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| erp E-300401 ~ crm C-300401 | 0.957 | M1: auto_link | Same NIF, similarity 0.957 (at least 0.90) |
| erp E-300402 ~ crm C-300402 | 0.889 | M1B: suggestion: tax_conflict | Same NIF, similarity 0.889 (below 0.90) |

**Steward decision:** M1B pair confirmed: a typo of the same company.  
**Partners at the end:** {erp E-300401, crm C-300401}; {erp E-300402, crm C-300402}.

### M-05 M1B confirmed: a trading name of the same legal entity

- `erp E-300501`, **Grupo Ensayo S.A.**, ES, tax ID A55204176, domain grupo-ensayo.example, city Madrid
- `crm C-300501`, **Grupo Ensayo Iberia**, ES, tax ID A55204176, domain grupo-ensayo.example, city Madrid

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| erp E-300501 ~ crm C-300501 | 0.774 | M1B: suggestion: tax_conflict | Same NIF, similarity 0.774 |

**Steward decision:** Confirmed: 'Grupo Ensayo Iberia' is a trading name; kept as trading name on the partner.  
**Partners at the end:** {erp E-300501, crm C-300501}.

### M-06 M1B rejected: a subsidiary carrying its mother company's tax ID

*Duplicate pattern 1: subsidiary with the mother's tax ID*

- `erp E-300601`, **Grupo Ensayo S.A.**, ES, tax ID A55204176, domain grupo-ensayo.example, city Madrid
- `crm C-300601`, **Ensayo Portugal**, PT, tax ID A55204176, domain grupo-ensayo.example, city Lisboa

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| erp E-300601 ~ crm C-300601 | 0.444 | M1B: suggestion: tax_conflict | Same NIF, similarity 0.444; an M1-only rule would have merged them |

**Steward decision:** Rejected: different legal entities.  
**Partners at the end:** {erp E-300601}; {crm C-300601}.

*C-300601 fails K09 (its NIF belongs to the mother company's partner) and K01 (Spanish NIF on a Portuguese record); both are reported to the CRM owner*

### M-07 An invalid tax ID is ignored for matching

- `crm C-300701`, **Cifras Norte**, ES, tax ID B44730219, city Bilbao, phone +34944000001
- `support S-300701`, **Cifras Norte S.L.**, ES, tax ID B44730219, city Bilbao, phone +34944000001

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| crm C-300701 ~ support S-300701 | 1.0 | M4: suggestion: normal | Same NIF but it fails V01, so it is treated as missing; similarity 1.0 and the same phone |

**Steward decision:** Confirmed.  
**Partners at the end:** {crm C-300701, support S-300701}.

*Both records fail V01. Without fix G4 they would have been linked automatically on a wrong NIF*

### M-08 M2: a subsidiary with its own tax ID sharing the mother's domain

- `erp E-300801`, **Grupo Ensayo S.A.**, ES, tax ID A55204176, domain grupo-ensayo.example
- `erp E-300802`, **Ensayo Portugal Lda.**, PT, tax ID 509812333, domain grupo-ensayo.example

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| erp E-300801 ~ erp E-300802 | 0.444 | M2: suggestion: group | Different valid tax IDs, same web domain |

**Steward decision:** Group: hierarchy link Ensayo Portugal under Grupo Ensayo (batch H).  
**Partners at the end:** {erp E-300801}; {erp E-300802}.

### M-09 M2: a subsidiary with the same name as its mother company

*Duplicate pattern 3: subsidiary with the mother's name*

- `erp E-300901`, **Grupo Ensayo S.A.**, ES, tax ID A55204176, domain grupo-ensayo.example
- `support S-300901`, **Grupo Ensayo, Lda.**, PT, tax ID 510994806

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| erp E-300901 ~ support S-300901 | 1.0 | M2: suggestion: group | Different valid tax IDs, similarity 1.0: never the same partner |

**Steward decision:** Group.  
**Partners at the end:** {erp E-300901}; {support S-300901}.

### M-10 M3 strong suggestion, and a near miss that falls through to M4

- `erp E-301001`, **Painel Atlântico Lda.**, PT, tax ID 506301273, domain painel-atlantico.example, city Lisboa, postal 1000-001
- `crm C-301001`, **Painel Atlântico**, PT, domain painel-atlantico.example, city Lisboa
- `crm C-301002`, **Paineis Atlanticos**, PT, domain painel-atlantico.example, city Lisboa, postal 1000-001

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| erp E-301001 ~ crm C-301001 | 1.0 | M3: suggestion: strong | No tax ID on one side, same domain and country, similarity 1.0 |
| erp E-301001 ~ crm C-301002 | 0.882 | M4: suggestion: normal | Similarity 0.882 is below 0.92 and neither name starts with the other, so not M3; 0.882 and the same postal code |
| crm C-301001 ~ crm C-301002 | 0.882 | M5: suggestion: weak | Similarity 0.882, same domain but below 0.92 and no prefix, no shared postal code or phone, same city (G5) |

**Steward decision:** Confirmed (all three).  
**Partners at the end:** {erp E-301001, crm C-301001, crm C-301002}.

### M-11 M4: same phone; and a high-similarity pair in the same city

- `crm C-301101`, **Sondages Rivière SARL**, FR, domain sondages-riviere.example, city Paris, postal 75010, phone +33140000001
- `support S-301101`, **Sondages Riviere**, FR, city Paris, phone +33140000001
- `support S-301102`, **Sondages Rivieras**, FR, city Paris, postal 75011

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| crm C-301101 ~ support S-301101 | 1.0 | M4: suggestion: normal | Support record has no domain, so not M3; similarity 1.0 and the same phone |
| crm C-301101 ~ support S-301102 | 0.909 | M5: suggestion: weak | Similarity 0.909, no shared postal code or phone, same city (G5) |
| support S-301101 ~ support S-301102 | 0.909 | M5: suggestion: weak | Similarity 0.909, same city; both from the support desk |

**Steward decision:** S-301101 confirmed; both S-301102 pairs rejected (a different shop).  
**Partners at the end:** {crm C-301101, support S-301101}; {support S-301102}.

### M-12 M5 weak suggestion, and a near miss with no match

- `crm C-301201`, **Sondages Rivière SARL**, FR, city Lyon, postal 69002
- `support S-301201`, **Sondage Riv**, FR, city Lyon
- `support S-301202`, **Sondaje Riviera Conseil**, FR, city Lyon

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| crm C-301201 ~ support S-301201 | 0.815 | M5: suggestion: weak | Similarity 0.815 (0.75 or more) and the same city |
| crm C-301201 ~ support S-301202 | 0.718 | –: no match | Similarity 0.718 is below 0.75 |

**Steward decision:** S-301201 confirmed.  
**Partners at the end:** {crm C-301201, support S-301201}; {support S-301202}.

### M-13 M6: two unrelated suppliers with the same IBAN

- `erp E-301301`, **Paneles Prueba S.L.**, ES, tax ID B31488208, IBAN ES2299990003000555666777, role supplier
- `procurement_sheet P-301301`, **Logiciels Essai SAS**, FR, tax ID 793155201, IBAN ES2299990003000555666777, role supplier

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| erp E-301301 ~ procurement_sheet P-301301 | 0.345 | M6: suggestion: bank_risk | M2 says they are never the same partner, but the shared IBAN is still flagged (G2) |

**Steward decision:** Bank-risk review: the procurement sheet IBAN was typed from the wrong supplier; corrected by a bank-details request.  
**Partners at the end:** {erp E-301301}; {procurement_sheet P-301301}.

*Both also fail U03*

### M-14 One company spelled three ways in three systems

*Duplicate pattern 2: different spellings*

- `crm C-301401`, **Inqueritos Douro**, PT, domain inqueritos-douro.example, city Porto
- `support S-301401`, **Inquéritos do Douro**, PT, city Porto, phone +351220000001
- `erp E-301401`, **Inquéritos Douro Lda.**, PT, tax ID 513220194, domain inqueritos-douro.example, city Porto, phone +351220000001

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| crm C-301401 ~ erp E-301401 | 1.0 | M3: suggestion: strong | Same domain and country, similarity 1.0 |
| support S-301401 ~ erp E-301401 | 0.914 | M4: suggestion: normal | Similarity 0.914 and the same phone |
| crm C-301401 ~ support S-301401 | 0.914 | M5: suggestion: weak | Similarity 0.914, same city, nothing else shared (G5) |

**Steward decision:** All confirmed.  
**Partners at the end:** {crm C-301401, support S-301401, erp E-301401}.

### M-15 One company with a CRM account per office (identical names)

*Duplicate pattern 4: one account per office*

- `crm C-301501`, **Estudios Faro S.L.**, ES, domain estudios-faro.example, city Barcelona, postal 08002
- `crm C-301502`, **Estudios Faro**, ES, domain estudios-faro.example, city Madrid, postal 28010

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| crm C-301501 ~ crm C-301502 | 1.0 | M3: suggestion: strong | Same domain and country, similarity 1.0 |

**Steward decision:** Confirmed: one partner; the Madrid office becomes a branch address.  
**Partners at the end:** {crm C-301501, crm C-301502}.

### M-16 Office or subsidiary named after the company plus a suffix

*Duplicate pattern 4 and 3*

- `erp E-301601`, **Estudios Faro S.L.**, ES, tax ID B70583166, domain estudios-faro.example, city Barcelona
- `crm C-301601`, **Estudios Faro Madrid**, ES, domain estudios-faro.example, city Madrid
- `erp E-301602`, **Grupo Ensayo S.A.**, ES, tax ID A55204176, domain grupo-ensayo.example, city Madrid
- `crm C-301602`, **Grupo Ensayo Servicios**, ES, domain grupo-ensayo.example, city Sevilla

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| erp E-301601 ~ crm C-301601 | 0.788 | M3: suggestion: strong | Similarity 0.788, but one standardised name starts with the other, same domain and country (G3) |
| erp E-301602 ~ crm C-301602 | 0.706 | M3: suggestion: strong | Same as above: 'GRUPO ENSAYO' starts 'GRUPO ENSAYO SERVICIOS' (G3) |

**Steward decision:** C-301601 confirmed (the Madrid office); C-301602 marked group (a separate Spanish subsidiary with no tax ID yet).  
**Partners at the end:** {erp E-301601, crm C-301601}; {erp E-301602}; {crm C-301602}.

### M-17 A chain: A~B and B~C, but not A~C

- `erp E-301701`, **Estudios Faro S.L.**, ES, tax ID B70583166, domain estudios-faro.example, city Barcelona
- `crm C-301701`, **Estudios Faro Madrid**, ES, domain estudios-faro.example, city Madrid, phone +34910000001
- `support S-301701`, **Estudios Faro Madrid**, ES, city Madrid, phone +34910000001

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| erp E-301701 ~ crm C-301701 | 0.788 | M3: suggestion: strong | One name starts with the other, same domain and country (G3) |
| crm C-301701 ~ support S-301701 | 1.0 | M4: suggestion: normal | Similarity 1.0 and the same phone |
| erp E-301701 ~ support S-301701 | 0.788 | –: no match | Support has no domain; similarity 0.788 below 0.85; different cities |

**Steward decision:** Both confirmed; the three records end in one partner only through the two confirmed links.  
**Partners at the end:** {erp E-301701, crm C-301701, support S-301701}.

*The engine never links A and C on its own: chains are decided pair by pair*

### M-18 A rejected pair is not suggested again until a record changes

- `crm C-301801`, **Sondages Rivière SARL**, FR, city Paris, phone +33140000099
- `support S-301801`, **Sondages Riviere**, FR, city Paris, phone +33140000099

| Pair | Similarity | Expected | Why |
|---|---|---|---|
| crm C-301801 ~ support S-301801 | 1.0 | M4: suggestion: normal | Similarity 1.0 and the same phone |

**Steward decision:** Rejected. Next run with the same versions: no new suggestion. Support sends version 2 (new address): suggested again.  
**Partners at the end:** {crm C-301801}; {support S-301801}.

## Batch C: Company lifecycle, fraud and privacy (C-01 to C-17)

**Status:** reviewed, no corrections. Rules version `MDH-RULES-v1.3`. As-of moment: Fri 27 Nov 2026 18:00 (Madrid).

**Review notes.** Agreed as drafted, including these choices: a source that keeps using an
absorbed partner is a K06 warning to the source owner, and its record is not moved to the
successor automatically; insolvency is a block approved by the Finance Controller, and a ceased
company whose roles are already inactive needs no action; an employee–supplier match (K10) is an
error that blocks approval until the Finance Controller clears it; the factoring exception needs
an assignment letter; a close holder-name match is a warning, only no match blocks; VIES is
checked only for partners registered outside Spain, at customer or approved-supplier stage, and a
tax ID change invalidates the check; the 3-year retention applies to prospect contacts only; a
new duplicate CRM account is linked by M1 and counted in KPI03.

Synthetic data only. Registry and HR extracts are simulated files; IBANs use the invented bank code 9999/99999.

These cases come from the research on what companies most often run into after a partner is created: mergers, renames, insolvency, dormant suppliers, employee fraud, bank-change fraud, VIES and GDPR retention. The machine-readable version is `tests/fixtures/cases/c_lifecycle.json`.

| Case | Rules | Variant | Given | Expected | Why |
|---|---|---|---|---|---|
| C-01 Rename: the old name is kept and still matches | corporate_event, matching: former names | event | Request `corporate_event` (rename) for BP-900401 'Cifras Norte S.L.' (NIF B44730216) → 'Norte Analytics S.L.', registry extract attached, approved by the Finance Controller | ✔ applied | Legal name changed; field history row old → new with the request as lineage; 'CIFRAS NORTE' kept as a former name; tax ID unchanged |
|  |  | pass | Delta CRM record 'Cifras Norte' (no tax ID, domain cifras-norte.example, ES) after the rename | 🔎 suggestion | M3 strong to BP-900401: similarity 1.0 against the former name, same domain and country. Without former names it would score 0.37 and become a new partner |
| C-02 Legal form change: SARL becomes SAS, SIREN unchanged | corporate_event, V10, M1 | fail | ERP sends 'Études Essai SAS' (SIREN 812436053) before the event is recorded; golden legal form is still SARL | ❌ fail | V10 warning: name ends SAS, legal form SARL. Matching is unaffected (legal forms are removed): M1 links the record to the same partner, no duplicate |
|  |  | pass | Request `corporate_event` (legal_form_change) approved: legal form SAS | ✅ pass | V10 passes; SIREN and VAT number unchanged |
| C-03 Merger: the absorbed supplier is closed and linked to its successor | corporate_event, K11 | fail | Registry extract: 'Paneles Prueba S.L.' (NIF B31488208) absorbed on 10 Nov 2026; BP-900402 still has an approved supplier role and no block | ❌ fail | K11 error: steward task due within one working day of the extract load |
|  |  | event | Request `corporate_event` (merger_absorption): BP-900402 absorbed by BP-900403 'Grupo Ensayo S.A.', merger deed attached, approved by the Finance Controller | ✔ applied | BP-900402: block reason absorbed, supplier role inactive, `successor_of` link to BP-900403; steward reviews its contacts and hierarchy |
|  |  | pass | Next K11 run | ✅ pass | Absorbed in the registry and blocked as absorbed in the hub |
| C-04 The source keeps using an absorbed supplier | K06 | fail | Delta ERP extract: supplier account of BP-900402 still active, new purchase on 18 Nov 2026 | ❌ fail | K06 warning: the golden record is blocked (absorbed) but the ERP account is active; reported to the ERP owner. The record stays linked to BP-900402: it is not moved to the successor automatically |
| C-05 Insolvency and ceased companies from the registry extract | K11, block_unblock | fail | Registry extract: 'Muestra Clara S.L.' (NIF B66201948) in insolvency proceedings (official gazette notice 12 Nov 2026); BP-900404 is an active customer, no block | ❌ fail | K11 error: steward task within one working day; the Finance Controller approves block reason insolvency |
|  |  | pass | After the block | ✅ pass | Insolvency in the registry, insolvency block in the hub |
|  |  | pass | Registry extract: French company SIREN 855021903 ceased; its partner BP-900405 already has customer stage inactive and a compliance block | ✅ pass | No active role, so nothing to act on |
| C-06 Dormant suppliers (as of 27 Nov 2026) | T05 | fail | Approved supplier BP-900406, last ERP activity 15 Oct 2025 | ❌ fail | T05 warning: 13 months without activity, flagged for deactivation; the steward sets the supplier stage to inactive |
|  |  | pass | Approved supplier, last ERP activity 20 May 2026 | ✅ pass |  |
|  |  | n/a | Requested supplier with no activity yet | – not applicable | Rule applies to approved suppliers |
| C-07 Reactivating a dormant supplier needs fresh bank verification | reactivate_supplier, T02, K12 | returned | Request `reactivate_supplier` for BP-900406; bank details last verified 3 Mar 2024 | ↩ returned | T02 fails (more than 24 months): the steward returns it; the SLA clock pauses |
|  |  | approved | Bank details verified again on 24 Nov 2026 through an active contact verified on 10 Jun 2026; resubmitted | ✔ approved | Finance Controller approves; supplier stage approved again |
| C-08 Employee–supplier cross-match against the synthetic HR extract | K10 | fail | Supplier BP-900407 has IBAN ES5999990007000123123123; the same IBAN is on employee E-0042 in the HR extract | ❌ fail | K10 error: sent to the Finance Controller; the supplier cannot be approved |
|  |  | fail | Supplier address 'C/ Mallorca 120, 3º 2ª, 08036 Barcelona' vs employee address 'Calle Mallorca 120 3 2, 08036 Barcelona' | ❌ fail | Equal after address standardisation (C/ → CALLE, ordinals and punctuation removed) |
|  |  | pass | Supplier with no IBAN, address or phone in common with any employee | ✅ pass |  |
|  |  | pass | The IBAN match above, cleared by the Finance Controller (an employee's company with a documented conflict-of-interest declaration) | ✅ pass | Clearance recorded with approver and reason |
| C-09 Bank changes are verified only through a reliable contact | K12 | fail | Call-back to a contact with status left_company | ❌ fail | K12 error: request returned |
|  |  | fail | Call-back to an active contact last verified 20 Aug 2025 | ❌ fail | Verified more than 12 months ago |
|  |  | fail | 'Verified' by replying to the email that asked for the change | ❌ fail | Never through the requesting message |
|  |  | pass | Call-back to an active contact verified on 10 Jun 2026, using the phone number already on file | ✅ pass |  |
| C-10 Change-back and rapid bank changes | K13 | fail | IBAN ES3899990004000111222333 → ES4099990005000444555666 on 2 Nov 2026, then back to ES3899990004000111222333 on 20 Nov 2026 | ❌ fail | K13 warning: back to a previous IBAN within 90 days; sent to the Finance Controller |
|  |  | fail | ES3899990004000111222333 → ES4099990005000444555666 on 5 Nov 2026, then ES4099990005000444555666 → ES4299990006000777888999 on 25 Nov 2026 | ❌ fail | Two changes within 30 days |
|  |  | pass | One change on 12 May 2026, none since | ✅ pass |  |
| C-11 Factoring company as a documented exception | K02, U03, M6 | pass | Supplier 'Logiciels Essai SAS' (SIREN 793155201) paid to 'Affacturage Test SA', IBAN FR9899999000200009876543217, payee type factoring_company, assignment letter attached | ✅ pass | K02 passes by the documented exception; the same IBAN on two other suppliers of the same factor passes U03 and is not flagged by M6 |
|  |  | fail | The same bank details with payee type own_account and no assignment letter | ❌ fail | K02 no match (similarity 0.323), U03 fails, M6 bank-risk suggestion |
| C-12 Holder-name check with three outcomes, like the payee-name check banks run on euro transfers | K02 | pass | Legal name 'Paneles Prueba S.L.', holder 'PANELES PRUEBA SL' | ✅ pass | Match: equal after standardisation |
|  |  | warning | Holder 'Panels Prueba' | ❌ fail | Close match (0.963): warning, sent to review |
|  |  | fail | Holder 'Jordi Exemple' | ❌ fail | No match (0.222): error |
| C-13 VIES status for partners registered outside Spain (as of 27 Nov 2026) | V13 | fail | PT customer BP-900408, NIPC 514503726 valid (V01 passes), VIES status not_registered | ❌ fail | Cannot be invoiced without VAT as an intra-EU sale |
|  |  | pass | FR customer, SIREN 881400212, VIES valid, checked 2 Apr 2026 | ✅ pass |  |
|  |  | fail | FR customer, VIES valid, checked 1 Sep 2025 | ❌ fail | Checked more than 12 months ago |
|  |  | fail | PT approved supplier, VIES valid on 1 Mar 2026, tax ID corrected on 15 Jul 2026 | ❌ fail | Tax ID changed after the last check |
|  |  | n/a | ES customer (NIF B27164532) | – not applicable | Domestic: VIES not needed |
|  |  | n/a | FR prospect | – not applicable | Rule applies to customers and approved suppliers |
| C-14 GDPR retention of prospect contacts (as of 27 Nov 2026) | T06 | fail | Contact of a prospect, last contact 1 Oct 2023 | ❌ fail | T06 warning: more than 3 years; anonymised |
|  |  | pass | Contact of a prospect, last contact 15 Jan 2024 | ✅ pass | 2 years 10 months |
|  |  | n/a | Contact of a customer, last contact 2022 | – not applicable | Customer contacts are kept for the relationship plus 3 years |
| C-15 A suppressed person cannot come back through a source | U04 | fail | Contact erased on request RQ-990601 (hash of ana.test@client-a.example on the suppression list); the CRM delta extract contains 'Ana.Test@Client-A.example' | ❌ fail | U04 error: compared case-insensitively by hash; the contact is not loaded and the DPO is told |
|  |  | pass | CRM delta extract contains luis.test@client-a.example (not suppressed) | ✅ pass |  |
| C-16 An approved supplier needs a physical address | V12 | fail | Registered address 'Apartado de Correos 1234, 28080 Madrid' | ❌ fail | PO box only |
|  |  | fail | Registered address 'BP 45, 69002 Lyon' | ❌ fail | French PO box (boîte postale) |
|  |  | pass | Registered address 'Calle Prueba 5, 28001 Madrid' | ✅ pass |  |
|  |  | n/a | Requested supplier with a PO box | – not applicable | Rule applies to approved suppliers |
| C-17 A merged-away record comes back from the source | U02, M1 | pass | After M-01 (C-300101 and C-300102 linked to one partner), the CRM delta extract sends C-300102 version 2 | ✅ pass | Linked to the same partner through the cross-reference: no new partner, no suggestion |
|  |  | pass | Sales creates a new CRM account C-399999 'Mercats Test SL' with NIF B27164532 | 🔗 linked | M1 links it to the same partner; it counts as a CRM duplicate in KPI03 and is reported to the CRM owner |

## Batch S: Survivorship (S-01 to S-09)

**Status:** reviewed, no corrections. Rules: `MDH-RULES-v1.4` (clarifications G6–G8 released). All values are synthetic.

The survivorship steps, in order: **1** a value set by an approved request wins until a later approved request changes it; **2** otherwise the winning source for the field group (ERP for legal identity, addresses and payment data; CRM for commercial customer data); **3** if that source has no valid value, the most recently changed valid value from another source; **4** an empty value never replaces a filled one, and an invalid value never replaces a valid one.

### Gaps found while writing this batch (fixed in rules v1.4)

| # | Gap in v1.3 | Clarification in v1.4 | Cases |
|---|---|---|---|
| G6 | "Most recently changed" does not say which time is used | The change time stated by the source (`source_updated_at`); if the source gives none, the time the hub received the record | S-03 |
| G7 | Two sources changed at the same moment with different values | A fixed order breaks the tie: ERP, CRM, procurement spreadsheet, support desk | S-09 |
| G8 | Step 3 would copy an IBAN typed into the procurement spreadsheet onto the golden record, without any verification | Step 3 never applies to bank details: they come only from the ERP or from a verified, approved `change_bank_details` request | S-07, S-08 |

Each expected result below was also computed by a small reference implementation of these steps; all nine agree.

| Case | Field (winning source) | Golden before | Source values | Expected | Step | Why |
|---|---|---|---|---|---|---|
| S-01 Step 2: the winning source decides (legal identity → ERP) | `legal_name` (erp) | (none) | erp E-500101 v1: Mercats Test S.L. · 2026-11-02 08:00<br>crm C-500101 v1: Mercats Test SL Barcelona · 2026-11-05 10:00 | **Mercats Test S.L.** | 2 | The ERP owns legal identity; the CRM value is newer but does not count. The CRM disagreeing is a K06 warning to the CRM owner |
| S-02 Step 2 for commercial data (customer commercial → CRM) | `industry_code` (crm) | (none) | crm C-500201 v1: market_research · 2026-10-20 09:00<br>erp E-500201 v1: other · 2026-11-02 08:00 | **market_research** | 2 | Sales owns commercial data, so the CRM wins even though the ERP value is newer |
| S-03 Step 3: the winning source is empty, so the most recently changed valid value wins | `web_domain` (crm) | (none) | crm C-500301 v1: (empty) · 2026-11-02 08:00<br>erp E-500301 v1: mercatstest.example · 2025-03-01 10:00<br>support S-500301 v1: mercats-test.example · 2026-11-03 12:00 | **mercats-test.example** | 3 | CRM has no domain; the support desk changed it most recently (source change time, G6) |
| S-04 Rule 4: an empty value never replaces a filled one | `invoice_email` (erp) | factures@mercats-test.example | erp E-500401 v2: (empty) · 2026-11-16 08:00 | **factures@mercats-test.example** | 4 | The ERP's version 2 has the field empty: the golden value is kept, no history row is written, and K06 does not fire (it compares values that are present) |
| S-05 Rule 4: an invalid value never replaces a valid one | `registered_address.postal_code` (erp) | 08001 | erp E-500501 v2: 60123 (invalid) · 2026-11-16 08:00<br>crm C-500501 v1: 08001 · 2026-10-01 09:00 | **08001** | 3 | The ERP's new postal code fails V04, so it counts as no value; the CRM's valid value is used (step 3), and V04 fails on the ERP record for its owner to fix |
| S-06 Step 1: an approved request beats a later source change | `payment_terms` (erp) | NET30 | erp E-500601 v2: NET30 · 2026-11-16 08:00<br>approved request RQ-500601: NET45 | **NET45** | 1 | Request RQ-500601 (change_high_risk, approved 10 Nov by the Finance Controller) set NET45. The ERP extract of 16 Nov still says NET30: the golden value stays NET45 and K06 tells the ERP owner to update it |
| S-07 Customer and supplier accounts with different bank details (G8) | `iban` (erp) | (none) | erp E-500701 v1: ES3899990004000111222333 · 2026-11-02 08:00<br>procurement_sheet P-500701 v1: ES4099990005000444555666 · 2026-11-04 15:00 | **ES3899990004000111222333** | 2 | After M1 links the ERP account and the spreadsheet row (same SIREN), the ERP's IBAN wins; the spreadsheet's different IBAN is a K06 warning and can only be changed through a verified change_bank_details request |
| S-08 Bank details are never filled from a non-winning source (G8) | `iban` (erp) | (none) | erp E-500801 v1: (empty) · 2026-11-02 08:00<br>procurement_sheet P-500801 v1: ES4299990006000777888999 · 2026-11-04 15:00 | **(none)** | 4 | The ERP has no IBAN and step 3 does not apply to bank details: the supplier stays without bank details until a verified change_bank_details request (C01 fails for an approved supplier) |
| S-09 A tie in step 3 is broken by a fixed source order (G7) | `registered_address.street` (erp) | (none) | erp E-500901 v1: (empty) · 2026-11-02 08:00<br>crm C-500901 v1: Carrer de Prova 1 · 2026-11-05 10:00<br>support S-500901 v1: Carrer Prova, 1 · 2026-11-05 10:00 | **Carrer de Prova 1** | 3 | CRM and support changed it at the same moment: the order ERP, CRM, procurement spreadsheet, support desk picks the CRM |

## Batch T: Customer tier (T-01 to T-10)

**Status:** reviewed. Rules version `MDH-RULES-v1.5` (customer tier from v1.1, G9 from v1.5). All companies are synthetic.

**Review notes.** One correction: in T-07 a partner whose own tier is unknown now keeps group tier unknown until its own data is complete, instead of taking the group's tier. Released as G9 in rules v1.5 and enforced by migration 005. Agreed as drafted: overrides can lower a tier as well as raise it (T-08); a successor link from a merger is not a group link (T-10).

Score = industry points (core research 40, research-adjacent 30, other named 20, `other` 0) + employee-band points (1–10: 0, 11–49: 5, 50–249: 10, 250–999: 15, 1000+: 20). Tier 1 from 50, tier 2 from 30, tier 3 below. Group tier = the best known calculated tier among the current members of the company group (`subsidiary_of` links only); a partner whose own tier is unknown keeps group tier unknown (G9). Effective tier = the override if there is one, otherwise the group tier.

Every row was computed by a reference implementation of these rules.

| Case | Partner | Industry · band | Score | Calculated | Group | Override | Effective | Reason codes |
|---|---|---|---|---|---|---|---|---|
| T-01 Lower threshold (30, inclusive) | BP-900601 Retail Prova S.L. | retail_ecommerce · 11-49 | 25 | Tier 3 | Tier 3 | – | **Tier 3** | TIER_INDUSTRY_OTHER_NAMED, TIER_SIZE_11_49 |
|  | BP-900602 Banca Prova S.A. | financial_services · 50-249 | 30 | Tier 2 | Tier 2 | – | **Tier 2** | TIER_INDUSTRY_OTHER_NAMED, TIER_SIZE_50_249 |
| T-02 Upper threshold (50, inclusive) | BP-900603 Sondeos Prova S.L. | market_research · 11-49 | 45 | Tier 2 | Tier 2 | – | **Tier 2** | TIER_INDUSTRY_CORE, TIER_SIZE_11_49 |
|  | BP-900604 Panel Prova S.L. | panel_sample_provider · 50-249 | 50 | Tier 1 | Tier 1 | – | **Tier 1** | TIER_INDUSTRY_CORE, TIER_SIZE_50_249 |
|  | BP-900605 UX Prova SAS | ux_research_agency · 1000_plus | 50 | Tier 1 | Tier 1 | – | **Tier 1** | TIER_INDUSTRY_ADJACENT, TIER_SIZE_1000_PLUS |
| T-03 Industry 'other' never passes tier 3 | BP-900606 Outros Teste Lda. | other · 1000_plus | 20 | Tier 3 | Tier 3 | – | **Tier 3** | TIER_INDUSTRY_OTHER, TIER_SIZE_1000_PLUS |
| T-04 Unknown industry gives an unknown tier | BP-900607 Sem Setor Lda. | unknown · 250-999 | – | unknown | unknown | – | **unknown** | TIER_UNKNOWN_INDUSTRY |
| T-05 Unknown employee band gives an unknown tier | BP-900608 Sans Taille SAS | market_research · unknown | – | unknown | unknown | – | **unknown** | TIER_UNKNOWN_SIZE |
| T-06 Group roll-up raises small subsidiaries | BP-900609 Grupo Prova S.A. | market_research · 1000_plus | 60 | Tier 1 | Tier 1 | – | **Tier 1** | TIER_INDUSTRY_CORE, TIER_SIZE_1000_PLUS |
|  | BP-900610 Prova Retail S.L. (under BP-900609) | retail_ecommerce · 11-49 | 25 | Tier 3 | Tier 1 | – | **Tier 1** | TIER_INDUSTRY_OTHER_NAMED, TIER_SIZE_11_49, TIER_GROUP_ROLLUP |
|  | BP-900611 Prova UX Lda. (under BP-900609) | ux_research_agency · 250-999 | 45 | Tier 2 | Tier 1 | – | **Tier 1** | TIER_INDUSTRY_ADJACENT, TIER_SIZE_250_999, TIER_GROUP_ROLLUP |
|  | BP-900612 Prova Lisboa Lda. (under BP-900611) | other · 1-10 | 0 | Tier 3 | Tier 1 | – | **Tier 1** | TIER_INDUSTRY_OTHER, TIER_SIZE_1_10, TIER_GROUP_ROLLUP |
| T-07 A partner with an unknown tier stays unknown (G9) | BP-900613 Holding Teste SGPS | unknown · unknown | – | unknown | unknown | – | **unknown** | TIER_UNKNOWN_INDUSTRY, TIER_UNKNOWN_SIZE |
|  | BP-900614 Teste Norte Lda. (under BP-900613) | other · 11-49 | 5 | Tier 3 | Tier 3 | – | **Tier 3** | TIER_INDUSTRY_OTHER, TIER_SIZE_11_49 |
|  | BP-900615 Teste Sul Lda. (under BP-900613) | unknown · 50-249 | – | unknown | unknown | – | **unknown** | TIER_UNKNOWN_INDUSTRY |
| T-08 A Sales Director override, upwards and downwards | BP-900616 Analytics Prova S.L. | research_technology · 11-49 | 35 | Tier 2 | Tier 2 | Tier 1 | **Tier 1** | TIER_INDUSTRY_ADJACENT, TIER_SIZE_11_49, TIER_OVERRIDE |
|  | BP-900617 Grupo Ensaio S.A. | market_research · 1000_plus | 60 | Tier 1 | Tier 1 | – | **Tier 1** | TIER_INDUSTRY_CORE, TIER_SIZE_1000_PLUS |
|  | BP-900618 Ensaio Dormente Lda. (under BP-900617) | market_research · 50-249 | 50 | Tier 1 | Tier 1 | Tier 3 | **Tier 3** | TIER_INDUSTRY_CORE, TIER_SIZE_50_249, TIER_OVERRIDE |
| T-09 Recalculation after the employee band changes | BP-900619 Comercio Prova S.L. | retail_ecommerce · 250-999 | 35 | Tier 2 | Tier 2 | – | **Tier 2** | TIER_INDUSTRY_OTHER_NAMED, TIER_SIZE_250_999 |
| T-10 Successor links are not a group; leaving a group lowers the group tier | BP-900620 Absorbente Prova S.A. | market_research · 1000_plus | 60 | Tier 1 | Tier 1 | – | **Tier 1** | TIER_INDUSTRY_CORE, TIER_SIZE_1000_PLUS |
|  | BP-900621 Absorbida Prova S.L. | consumer_goods · 1-10 | 20 | Tier 3 | Tier 3 | – | **Tier 3** | TIER_INDUSTRY_OTHER_NAMED, TIER_SIZE_1_10 |
|  | BP-900622 Ex-Filial Prova S.L. | consumer_goods · 11-49 | 25 | Tier 3 | Tier 3 | – | **Tier 3** | TIER_INDUSTRY_OTHER_NAMED, TIER_SIZE_11_49 |

**Why, case by case**

- **T-01** Other named industry is 20 points: 20 + 5 = 25 is tier 3; 20 + 10 = 30 reaches tier 2 (30 counts).
- **T-02** Core research is 40 points: 40 + 5 = 45 is tier 2, 40 + 10 = 50 is tier 1; research-adjacent 30 + 20 = 50 is tier 1.
- **T-03** 0 + 20 = 20: even a very large company stays tier 3 when its industry is 'other'.
- **T-04** No tier is guessed: score empty, reason TIER_UNKNOWN_INDUSTRY; C02 also fails for a customer.
- **T-05** Even with 40 industry points the tier stays unknown: reason TIER_UNKNOWN_SIZE.
- **T-06** The mother company is tier 1 (60), so every member of the group, including the grandchild, gets group tier 1 and effective tier 1; their own calculated tiers are kept.
- **T-07** Only Teste Norte has a known tier (tier 3), so its group tier is tier 3. The holding and Teste Sul keep group and effective tier unknown until their own industry and employee band are known (G9, rules v1.5).
- **T-08** BP-900616 (calculated tier 2, 35) is raised to tier 1 by request RQ-900616, approved by the Sales Director; BP-900618 (group tier 1) is lowered to tier 3 because it no longer trades. Calculated and group tiers are kept beside the override; both count in KPI12. RQ-900616 override_customer_tier raised by AE-ES-01, approved by the Sales Director (four-eyes); RQ-900618 override_customer_tier raised by AE-PT-01, approved by the Sales Director.
- **T-09** An approved change_low_risk request moves the band from 11-49 (25, tier 3) to 250-999 (35, tier 2): the tier is recalculated at once and the change is recorded with the request as lineage. Before: band 11-49, score 25, tier 3; RQ-900619 change_low_risk employee_band 11-49 → 250-999, approved by the steward; After: score 35, tier 2.
- **T-10** BP-900621 was absorbed by BP-900620 (successor_of): that link is not a hierarchy link, so BP-900621 keeps its own tier 3. BP-900622's subsidiary_of link to BP-900620 was closed on 1 Nov 2026: from then its group tier is its own tier 3. Both stay tier 3 with no TIER_GROUP_ROLLUP.

## Batch H: Hierarchy (H-01 to H-06)

**Status:** reviewed, no corrections. Rules version `MDH-RULES-v1.5`. All companies and tax IDs are synthetic.

**Review notes.** Agreed as drafted, including a new steward routine for H-06: a weekly review of newly created partners, to place subsidiaries that matching cannot group (written into the work instructions in MDH-007).

Hierarchy changes are `merge_hierarchy` requests, prepared by the steward and approved by the Sales Director. Links are effective-dated (`subsidiary_of`, one parent at a time, at most five levels, no loops: I12), so the group as it was on any date can be rebuilt. The machine-readable version is `tests/fixtures/cases/h_hierarchy.json`.

| Case | Rules | Variant | Given | Expected | Why |
|---|---|---|---|---|---|
| H-01 A group suggestion becomes a hierarchy link | M2, merge_hierarchy, I12, customer tier | request | After M-08 (group suggestion), Sales raises `merge_hierarchy`: BP-900701 'Ensayo Portugal Lda.' (NIPC 509812333) subsidiary_of BP-900702 'Grupo Ensayo S.A.' (NIF A55204176) from 1 Dec 2026 | ✔ approved | Approved by the Sales Director; link stored with the request; the steward prepared it |
|  |  | result | Effect on the customer tier | ✔ applied | BP-900701 (own tier 3) gets group tier 1 from its mother company (tier 1); reason TIER_GROUP_ROLLUP |
| H-02 Five levels are allowed, a sixth is refused | I12 | pass | Chain Holding → Grupo → Ibérica → Norte → Bilbao (5 levels) | ✅ pass | Accepted |
|  |  | fail | Request to place 'Bilbao Office S.L.' under Bilbao (a sixth level) | ❌ refused | Refused by the database (I12); the steward returns the request: the office is a branch address, not a subsidiary |
| H-03 A loop is refused | I12 | fail | Request to place the Holding under Norte (Norte is already below the Holding) | ❌ refused | Refused by the database (I12): it would create a loop |
| H-04 A top parent registered outside Spain, Portugal and France | hierarchy, K05, C01 | pass | BP-900703 'Ensayo Holding GmbH', country DE, name only, no role; Grupo Ensayo S.A. placed under it | ✅ pass | Allowed as a parent with minimal data: no customer or supplier role, so the stage checks (C01) do not apply, and country-specific tax ID and postal code formats are not checked |
|  |  | fail | Someone tries to give the German holding a customer role | ↩ returned | Out of scope: partners registered outside ES, PT and FR are parents only; the request is returned |
| H-05 Reorganisation: a subsidiary is sold to another group | I12, history, customer tier | event | 'Prova UX Lda.' (BP-900611, own tier 2) leaves Grupo Prova (tier 1) and joins Grupo Norte (tier 2) on 1 Nov 2026: the old link is closed on 31 Oct, a new link opens on 1 Nov, both through approved `merge_hierarchy` requests | ✔ applied | Effective-dated: nothing is overwritten |
|  |  | as-of | Hierarchy read as of 15 Oct 2026, and as of 27 Nov 2026 | ✅ pass | 15 Oct: under Grupo Prova, group tier 1. 27 Nov: under Grupo Norte, group tier 2. Reports can show either moment |
| H-06 A subsidiary abroad with its mother company's name and no tax ID | known limit from batch M, merge_hierarchy | pass | Support desk record 'Grupo Ensayo, Lda.' (PT, no tax ID) gets no match suggestion (M3 needs the same country) | ✅ pass | Becomes its own partner, as agreed in batch M; it cannot be merged into its mother company by mistake |
|  |  | request | The steward finds it in the weekly review of new partners and raises `merge_hierarchy` to place it under Grupo Ensayo S.A.; the NIPC 510994806 is added later through a high-risk change request | ✔ approved | Approved by the Sales Director; the subsidiary now rolls up to the group's tier once its own tier is known (G9) |

## Batch R: Requests (R-01 to R-23)

**Status:** reviewed. Rules version `MDH-RULES-v1.5`. As-of moment: Fri 27 Nov 2026 18:00 (Madrid). Working time: Mon–Fri 09:00–18:00. All companies, people and values are synthetic.

**Review notes.** Cases agreed as drafted. Decisions taken in review: (1) an erasure request is raised by the steward with the DPO reference and approved by the DPO, because nobody approves their own request; (2) the approver must hold the role the request type requires on the decision date, enforced by the database from MDH-007 (I25); (3) KPI counting follows the usual service-desk approach (see kpi_definitions.md): rejected requests count in KPI07 and KPI08 and as not first time right, cancelled and blocked requests are left out, open requests past target count as missed, only the requester can cancel, and the number of cancelled requests is shown beside KPI08; (4) each data-owner role has a standing deputy, and temporary delegations have start and end dates and are recorded as on behalf of (R-23 added); (5) a mass upload is approved or rejected as a whole, and its pre-load check returns a row report (row, column, value, rule, severity, message).

Every request type appears at least once, with the people who raise, prepare and approve it, and the SLA arithmetic the hub must reproduce: net time (the clock pauses while Returned, D7) and gross time, both in working hours from the first submission. The full status timelines are in `tests/fixtures/cases/r_requests.json`.

**Staff used:** ST-901 steward; ST-902 Finance Controller; ST-903 Sales Director; ST-904 SDR; ST-905 Account Executive; ST-906 DPO; ST-907 buyer (Operations); ST-908 Head of Operations; ST-909 deputy Finance Controller; ST-910 finance clerk (receivables and payables); ST-911 Operations team lead (holiday delegate). ST-907 to ST-911 are new test staff.

| Case | Type | Raised by → approved by | Submitted → ended | Net / gross (target) | Expected | KPI07 · KPI08 · KPI09 | Why |
|---|---|---|---|---|---|---|---|
| R-01 A prospect becomes a customer | `create_customer` | ST-905 → ST-902 | Mon 02 Nov 10:00 → Tue 03 Nov 15:10 | 14h10 / 14h10 (16h) | ✔ approved | counted · met · first time right | Signed contract reference and tax registration attached; customer-stage fields complete (C01). The Account Executive raises, the steward prepares, the Finance Controller approves |
| R-02 A new supplier is requested | `create_supplier` | ST-907 → ST-908 | Wed 04 Nov 16:00 → Thu 05 Nov 14:00 | 7h / 7h (8h) | ✔ approved | counted · met · first time right | Business reason and internal contact attached; the Head of Operations approves. The supplier is now Requested and cannot be paid yet |
| R-03 Approval for payment across a weekend | `approve_supplier` | ST-907 → ST-902 | Thu 05 Nov 14:30 → Mon 09 Nov 11:00 | 14h30 / 14h30 (16h) | ✔ approved | counted · met · first time right | Tax registration, bank certificate and verification record attached. Thursday 14:30 to Monday 11:00 is 92h30 on the calendar but 14h30 of working time: weekends do not count |
| R-04 Submitted on a Saturday: the clock starts on Monday at 09:00 | `change_low_risk` | ST-904 → ST-901 | Sat 07 Nov 10:30 → Mon 09 Nov 10:15 | 1h15 / 1h15 (8h) | ✔ approved | counted · met · first time right | Web domain change; the steward approves alone (low risk), and is not the requester. No Awaiting approval step for steward-approved types |
| R-05 A tier override approved by the Sales Director | `override_customer_tier` | ST-905 → ST-903 | Tue 10 Nov 09:00 → Tue 10 Nov 16:00 | 7h / 7h (8h) | ✔ approved | counted · met · first time right | Calculated tier 2, override tier 1 with a written reason. Effective tier becomes 1, the calculated tier is kept beside it, and the role now counts in KPI12 (Tier Override Rate) |
| R-06 Closed exactly on the target | `change_high_risk` | ST-910 → ST-902 | Tue 10 Nov 10:00 → Wed 11 Nov 17:00 | 16h / 16h (16h) | ✔ approved | counted · met · first time right | Billing address change with a supporting document. Net time is exactly 16h: a request closed on the target counts as met (≤ target) |
| R-07 A bank change verified through the contact on file | `change_bank_details` | ST-910 → ST-902 | Wed 11 Nov 09:00 → Thu 12 Nov 12:00 | 12h / 12h (16h) | ✔ approved | counted · met · first time right | The steward calls the supplier's finance contact (active, verified in the last 12 months) on the number held in the hub, not the one in the change letter (K12). Approved by the Finance Controller; the verification date is set, so T02 passes. The clerk who raised it and the steward who prepared it cannot approve it |
| R-08 A rename backed by a registry extract | `corporate_event` | ST-910 → ST-902 | Thu 12 Nov 10:00 → Fri 13 Nov 16:00 | 15h / 15h (16h) | ✔ approved | counted · met · first time right | 'Ensayo Logística S.L.' becomes 'Ensayo Supply Chain S.L.'. The old name is kept as a former name, so a support-desk record still using it keeps matching (as in batch C) |
| R-09 Returned once: net time meets the SLA, but it is not first time right | `reactivate_supplier` | ST-907 → ST-902 | Mon 16 Nov 09:00 → Thu 19 Nov 14:00 | 15h / 32h (16h) | ✔ approved | counted (net and gross) · met · not first time right | Returned because the bank holder name was only a close match and needed an explanation from the buyer. The clock pauses for the 17 working hours the request sat with the requester |
| R-10 A credit block across a weekend, on the shortest target | `block_unblock` | ST-910 → ST-902 | Fri 13 Nov 17:00 → Mon 16 Nov 11:30 | 3h30 / 3h30 (4h) | ✔ approved | counted · met · first time right | Block reason credit, approved by the Finance Controller; the block carries the request (K07). Friday 17:00 to Monday 11:30 is 3h30 of working time, within 4h |
| R-11 A probable merge of two records with different account owners | `merge_hierarchy` | ST-901 → ST-903 | Mon 16 Nov 14:00 → Wed 18 Nov 10:00 | 14h / 14h (16h) | ✔ approved | counted · met · first time right | The steward raises it from an M4 suggestion. The steward could approve a probable merge alone, but the two records have different account owners, so the Sales Director must approve. The steward is the requester here, which is allowed: only approving one's own request is not |
| R-12 A mass upload: pre-load checks, then the highest-risk approver | `mass_upload` | ST-905 → ST-902 | Wed 18 Nov 09:00 → Thu 19 Nov 17:00 | 17h / 17h (24h) | ✔ approved | counted · met · first time right (a blocked draft is not a return) | First file (43 rows: 40 industry changes, 3 payment-term changes): rows 12 and 31 carry an industry that is not in the controlled list, so the submission is blocked with a row report and stays a draft (no SLA clock). The corrected file is submitted the next day. Because 3 rows are high-risk, the Finance Controller approves the whole file; the steward's approval alone is not enough |
| R-13 An erasure request within 40 working hours and one calendar month | `erase_contact` | ST-901 → ST-906 | Mon 02 Nov 12:00 → Fri 06 Nov 12:00 | 36h / 36h (40h) | ✔ approved | counted · met · first time right | The data subject's request reached the DPO on Fri 30 Oct; the calendar limit runs from that day (until 30 Nov), the working-hour target from the submission. Raised by the steward with the DPO reference, approved by the DPO (the DPO cannot both raise and approve: decided in review) |
| R-14 A late request: waiting for the approver counts | `change_high_risk` | ST-905 → ST-902 | Mon 16 Nov 10:00 → Thu 19 Nov 11:00 | 28h / 28h (16h) | ✔ approved | counted · missed · first time right | Payment-terms change. It waited three days for the Finance Controller. The clock only pauses while Returned, so Awaiting approval counts: 28h net against 16h, missed |
| R-15 The Finance Controller raises a high-risk change | `change_high_risk` | ST-902 → ST-909 | Tue 17 Nov 09:00 → Tue 17 Nov 16:30 | 7h30 / 7h30 (16h) | ✔ approved | counted · met · first time right | Fail variant: the Finance Controller (ST-902) tries to approve their own request; the database refuses it (I18). Pass variant: the deputy Finance Controller (ST-909, who holds the finance_controller role) approves |
| R-16 Approval by someone without the required role | `change_high_risk` | ST-910 → ST-902 | Wed 18 Nov 09:00 → Wed 18 Nov 14:30 | 5h30 / 5h30 (16h) | ✔ approved | counted · met · first time right | Fail variants, all refused: the steward approves a high-risk change; the Sales Director approves it; a former Finance Controller whose role ended on 13 Nov approves it on 18 Nov. The approval must come from the role the request type requires, held on the decision date (I25, enforced by the database from MDH-007). Pass variant: the Finance Controller approves |
| R-17 Submission blocked: required evidence missing | `approve_supplier` | ST-907 | never submitted | no clock | ⛔ blocked at submission | excluded · excluded · excluded | No verification record attached. The request cannot be submitted, so it stays a draft: no SLA clock, not in any request KPI |
| R-18 Submission blocked: an error rule fails | `create_customer` | ST-905 | never submitted | no clock | ⛔ blocked at submission | excluded · excluded · excluded | The tax ID has a wrong check digit (V01, error). Same as R-17: stays a draft, outside the KPIs |
| R-19 A bank change verified only by replying to the email that asked for it | `change_bank_details` | ST-910 → ST-902 | Thu 19 Nov 09:00 → Thu 19 Nov 16:00 | 7h / 7h (16h) | ✖ rejected | counted · met · not first time right | The only verification is a reply to the sender of the change email (K12, error). The Finance Controller rejects it. A rejected request ends the clock and counts in KPI08; in KPI09 it is in the denominator but not the numerator |
| R-20 Cancelled by the requester | `change_low_risk` | ST-904 | Fri 20 Nov 10:00 → Fri 20 Nov 15:00 | 5h / 5h (8h) | – cancelled | excluded · excluded · excluded | The SDR withdraws it: the phone number was already right. Excluded from all three request KPIs; it appears in the count of cancelled requests shown beside KPI08. Only the requester can cancel |
| R-21 Still open past its target on the as-of date | `change_low_risk` | ST-904 | Tue 24 Nov 09:00 → open at as-of | 36h / 36h (8h) | … open | excluded (open) · missed (open past target) · excluded (open) | 36h net at Fri 27 Nov 18:00 against 8h. Counted as missed in KPI08 even though it is not closed; not in KPI07 (no close yet) or KPI09 |
| R-22 Open and waiting for the requester on the as-of date | `create_supplier` | ST-907 | Mon 23 Nov 09:00 → open at as-of | 2h / 45h (8h) | … open | excluded (open) · not counted (not past target) · excluded (open) | Returned on Monday and not answered. Net time stays at 2h while it waits, so it is not past its 8h target and not a miss; gross time keeps growing (45h) |
| R-23 Approved by a holiday delegate | `create_supplier` | ST-907 → ST-911 | Thu 26 Nov 09:00 → Thu 26 Nov 14:30 | 5h30 / 5h30 (8h) | ✔ approved | counted · met · first time right | The Head of Operations (ST-908) is on holiday 23-27 Nov and delegated the role to ST-911 for exactly those dates. ST-911 approves, recorded as on behalf of ST-908. Fail variant: the delegation ran 23-25 Nov only, so an approval on 26 Nov is refused (I25) |
