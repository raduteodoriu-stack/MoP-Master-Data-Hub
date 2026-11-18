# Quality, matching and survivorship rules (MDH-002)

How each record is checked, when two records are the same company, and which value goes on the
golden record. Rule IDs are stable: every result stored by the engine names the rule ID and the
rules version that produced it.

## 4. Quality rules
Each rule is checked per record and stored as pass, fail or not applicable, with the rules version.

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
| U01 | Uniqueness | A tax ID belongs to only one active partner | Error |
| U02 | Uniqueness | Every source record is linked to exactly one partner | Error |
| U03 | Uniqueness | An IBAN belongs to only one supplier, unless the suppliers are in the same group | Warning, sent to review |
| K01 | Consistency | The tax ID's country is the country of registration | Error |
| K02 | Consistency | The bank account holder's name matches the legal name | Warning, sent to review |
| K03 | Consistency | The IBAN's country is the country of registration, or an exception is recorded | Warning |
| K04 | Consistency | The bill-to party exists, is active and is not blocked | Error |
| K05 | Consistency | The parent exists and is not blocked; the hierarchy has no loop and at most five levels | Error |
| K06 | Consistency | Each governed field has the same value in every source system as in the golden record | Warning |
| K07 | Consistency | A blocked partner has a reason and an approver; an unblocked partner has neither | Error |
| K08 | Consistency | A contact person's email domain is the partner's web domain | Warning |
| T01 | Timeliness | A customer or approved supplier was reviewed in the last 12 months | Warning |
| T02 | Timeliness | Supplier bank details were verified after their last change and within the last 24 months | Warning |
| T03 | Timeliness | A change in a source system reaches the hub within one working day | Warning |
| T04 | Timeliness | A match suggestion is decided within five working days | Warning |

In the clean-up phase nothing is deleted or corrected automatically because of a failed rule. Failures are reported and become work for the steward.

## 5. Matching: when are two records the same company?
Names are compared in standardised form: upper case, accents and punctuation removed, legal form removed. Similarity is a score from 0 to 1.

Rules are applied in this order, and the first that applies decides.

| ID | Evidence | Outcome |
|---|---|---|
| M1 | Same valid tax ID | Same partner. Linked automatically, logged, reversible. Applies across roles, so a customer record and a supplier record become one partner with two roles |
| M2 | Different valid tax IDs | Never the same partner. If the web domain also matches or the name similarity is 0.85 or more, a *group suggestion* goes to the steward (possible parent and subsidiary) |
| M3 | At least one side has no tax ID; same web domain, same country, name similarity 0.92 or more | Strong suggestion (never linked automatically, D8) |
| M4 | Name similarity 0.85 or more, and the same postal code or phone | Suggestion |
| M5 | Name similarity 0.75 to 0.85, and the same city | Weak suggestion, low priority |
| M6 | Same IBAN on two different partners | Bank-risk review, high priority |
| – | Anything else | No match |

A shared contact email supports a suggestion but never creates one. Every suggestion stores its rule, score, the values compared and the rules version, and ends as *confirmed*, *rejected* or *group*. A rejected pair is not suggested again unless one of the records changes.

Matching quality is reported as a test result against the answer key: **precision** (of the links the engine made, the share that are right) and **recall** (of the true links, the share the engine found).

## 6. Survivorship: which value goes on the golden record?
Applied per field, in this order:
1. A value set through an approved request wins, until a later approved request changes it.
2. Otherwise the value from the winning source for that field group (MDH-001).
3. If that source has no value, the most recently changed valid value from another source.
4. An empty value never replaces a filled one, and an invalid value never replaces a valid one.

The golden record stores, for each field, which source record the value came from and which rule chose it.
