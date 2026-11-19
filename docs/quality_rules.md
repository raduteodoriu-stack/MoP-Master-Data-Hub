# Quality, matching and survivorship rules (MDH-002)

How each record is checked, when two records are the same company, and which value goes on the
golden record. Rule IDs are stable: every result stored by the engine names the rule ID and the
rules version that produced it.

## 4. Quality rules
Each rule is checked per record and stored as pass, fail or not applicable, with the rules version. Rules v1.3 has 39 rules.

| ID | Dimension | Rule | Severity |
|---|---|---|---|
| C01 | Completeness | Every field that is mandatory for the record's stage is filled | Error |
| C02 | Completeness | A customer's industry and employee band are not `unknown` | Warning |
| C03 | Completeness | A customer or approved supplier has at least one contact person with a role | Warning |
| V01 | Validity | Tax ID has the right format and check digit for its country | Error |
| V02 | Validity | VAT number agrees with the tax ID and country | Error |
| V03 | Validity | Country is a valid ISO code | Error |
| V04 | Validity | Postal code fits the country's pattern | Error |
| V05 | Validity | Web domain is clean and is not a free email domain | Error |
| V06 | Validity | Email addresses have a valid format | Error |
| V07 | Validity | Phone is in international format | Warning |
| V08 | Validity | Payment terms are in the allowed list | Error |
| V09 | Validity | IBAN has the right length and check digits | Error |
| V10 | Validity | Legal form is in the country's list and agrees with the ending of the legal name | Warning |
| V11 | Validity | Legal name is not a placeholder | Error |
| V12 | Validity | An approved supplier has a physical registered address, not only a PO box (rules v1.3) | Error |
| V13 | Validity | An intra-EU partner (registered outside Spain) at customer or approved-supplier stage has VIES status valid, checked within the last 12 months and after its last tax ID change (rules v1.3) | Error |
| U01 | Uniqueness | A tax ID belongs to only one active partner | Error |
| U02 | Uniqueness | Every source record is linked to exactly one partner | Error |
| U03 | Uniqueness | An IBAN belongs to only one supplier, unless the suppliers are in the same group or the IBAN is a documented factoring company or alternative payee; sent to review (rules v1.3) | Warning, sent to review |
| U04 | Uniqueness | A source record does not bring back a contact on the suppression list (erased or opted out); the contact is not loaded and the DPO is told (rules v1.3) | Error |
| K01 | Consistency | The tax ID's country is the country of registration | Error |
| K02 | Consistency | Bank account holder name compared with the legal name: match passes; close match (similarity 0.85 or more) is a warning for review; no match fails unless a factoring company or alternative payee is documented (rules v1.3) | Warning (close match) / Error (no match) |
| K03 | Consistency | The IBAN's country is the country of registration, or an exception is recorded | Warning |
| K04 | Consistency | The bill-to party exists, is active and is not blocked | Error |
| K05 | Consistency | The parent exists and is not blocked; the hierarchy has no loop and at most five levels | Error |
| K06 | Consistency | Each governed field has the same value in every source system as in the golden record | Warning |
| K07 | Consistency | A blocked partner has a reason and an approver; an unblocked partner has neither | Error |
| K08 | Consistency | A contact person's email domain is the partner's web domain | Warning |
| K09 | Consistency | A source record carries a tax ID that belongs to another partner (for example a subsidiary holding its mother company's tax ID); reported back to the source system's owner (rules v1.2) | Warning |
| K10 | Consistency | A supplier's IBAN, address or phone does not match an employee in the HR extract, unless the Finance Controller has cleared it; matches go to the Finance Controller (rules v1.3) | Error |
| K11 | Consistency | A partner with an active role is not shown as ceased, in insolvency proceedings or absorbed in the latest registry extract, unless it already has the matching block; a hit becomes a steward task within one working day (rules v1.3) | Error |
| K12 | Consistency | A bank-details change is verified through a contact who is active and was verified within the last 12 months, and never through the message that asked for the change (rules v1.3) | Error |
| K13 | Consistency | Bank details are not changed back to a previous IBAN within 90 days, nor changed twice within 30 days; a hit goes to the Finance Controller (rules v1.3) | Warning |
| T01 | Timeliness | A customer or approved supplier was reviewed in the last 12 months | Warning |
| T02 | Timeliness | Supplier bank details were verified after their last change and within the last 24 months | Warning |
| T03 | Timeliness | A change in a source system reaches the hub within one working day | Warning |
| T04 | Timeliness | A match suggestion is decided within five working days | Warning |
| T05 | Timeliness | An approved supplier with no ERP activity for 12 months is flagged for deactivation; reactivation needs a reactivate_supplier request (rules v1.3) | Warning |
| T06 | Timeliness | A contact of a prospect with no contact for 3 years is anonymised (CNIL guideline) (rules v1.3) | Warning |

In the clean-up phase nothing is deleted or corrected automatically because of a failed rule. Failures are reported and become work for the steward.

## 5. Matching: when are two records the same company?
**Standardised names.** Upper case, accents removed, punctuation removed, legal forms removed (SL, SLU, SA, SAU, SCOOP, LDA, UNIPESSOAL, SAS, SASU, SARL, EURL), spaces collapsed.

**Similarity (G1).** `difflib.SequenceMatcher` ratio on the standardised names, from 0 to 1, rounded to 3 decimals. Each record is compared with its current legal and trading names and with its **former names** (kept after an approved rename); the highest similarity counts, so a renamed company is not created again as a duplicate.

**Tax IDs (G4).** A tax ID that fails V01 is treated as missing: it can never cause an automatic link.

**Why M1 needs matching names too (rules v1.2).** A tax ID identifies one legal entity, but source systems do not always hold the right one: sales often copies the mother company's tax ID onto a subsidiary's account. Linking on the tax ID alone would merge the subsidiary into its mother company without anyone noticing. So a shared tax ID with clearly different names goes to the steward instead (M1B).

Rules M1 to M5 are applied in this order, and the first that applies decides. M6 is checked on every pair, whatever M1 to M5 decided (G2).

| ID | Evidence | Outcome |
|---|---|---|
| M1 | Same valid tax ID **and** standardised names at least 0.90 similar | Same partner. Linked automatically, logged, reversible. Applies across roles, so a customer record and a supplier record become one partner with two roles |
| M1B | Same valid tax ID but names less than 0.90 similar | High-priority steward review. *Confirmed:* same legal entity (an office or trading name), one partner, with the differing name or address kept as a trading name or branch address. *Rejected:* different companies (for example a subsidiary carrying its mother company's tax ID), kept apart, and the wrong tax ID is flagged by K09 and reported to the source owner |
| M2 | Different valid tax IDs | Never the same partner. If the web domain also matches or the name similarity is 0.85 or more, a *group suggestion* goes to the steward (possible parent and subsidiary) |
| M3 | At least one side has no valid tax ID; same web domain, same country; name similarity 0.92 or more, **or one standardised name starts with the other as whole words** (G3: "ESTUDIOS FARO" and "ESTUDIOS FARO MADRID") | Strong suggestion (never linked automatically) |
| M4 | Name similarity 0.85 or more, and the same postal code or phone | Suggestion |
| M5 | Name similarity 0.75 or more (no upper limit, G5), and the same city | Weak suggestion, low priority |
| M6 | Same IBAN on two different partners, checked on every pair (G2); a documented factoring company or alternative payee is not flagged | Bank-risk review, high priority |
| – | Anything else | No match |

A shared contact email supports a suggestion but never creates one. Every suggestion stores its rule, score, the values compared and the rules version, and ends as *confirmed*, *rejected* or *group*. A rejected pair is not suggested again unless one of the records changes. Chains (A~B and B~C) are decided pair by pair; the engine never links A and C on its own.

**Known limit.** A subsidiary in another country with its mother company's name and no tax ID gets no suggestion (M3 needs the same country). It cannot be merged by mistake; the steward places it in the hierarchy.

Matching quality is reported as a test result against the answer key: **precision** (of the links the engine made, the share that are right) and **recall** (of the true links, the share the engine found).

## 6. Survivorship: which value goes on the golden record?
Applied per field, in this order:
1. A value set through an approved request wins, until a later approved request changes it.
2. Otherwise the valid value from the winning source for that field group (MDH-001).
3. If that source has no valid value, the most recently changed valid value from another source. **Not for bank details** (G8, rules v1.4): they come only from the ERP or from a verified, approved bank-change request.
4. An empty value never replaces a filled one, and an invalid value never replaces a valid one.

**Clarifications (rules v1.4).** "Most recently changed" uses the change time stated by the source; if the source gives none, the time the hub received the record (G6). Two sources changed at the same moment are ranked ERP, CRM, procurement spreadsheet, support desk (G7). A value that fails a validity rule counts as no value.

The golden record stores, for each field, which source record the value came from and which rule chose it.
