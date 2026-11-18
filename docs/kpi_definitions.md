# KPI definitions (MDH-002)

Each KPI is defined once here. The reporting layer (MDH-009, dbt) computes every one of them
the same way, and the Power BI dashboard uses those results.

**Conventions**

- **Working time:** Monday to Friday, 09:00–18:00, Europe/Madrid, no public holidays, the same
  calendar as LeadFlow.
- **As of:** every number describes one moment. Ages and backlogs are measured to it.
- **Active** means not blocked and not inactive.
- **Ratios** are shown with numerator and denominator, so a percentage is never shown without
  its base.
- **Net and gross time:** the SLA clock stops while a request is Returned to the requester.
  Net time excludes that wait and is used for the SLA; gross time includes it.

All KPIs are calculated on a stated as-of date. "Active" means not blocked and not inactive.

| # | KPI | Definition |
|---|---|---|
| KPI01 | Data Quality Score | Rule checks passed ÷ rule checks applicable, on active golden records. Reported in total and per dimension. Error and warning rules count equally; the error-only score is shown beside it |
| KPI02 | Completeness | Mandatory fields filled ÷ mandatory fields required for each record's stage |
| KPI03 | Duplicate Rate (per source system) | Source records that share a partner with another record from the same system ÷ source records in that system |
| KPI04 | Golden Record Coverage | Source records linked to a partner with no open suggestion ÷ all source records |
| KPI05 | Cross-System Consistency | Governed field values in source systems that equal the golden value ÷ governed field values present in source systems |
| KPI06 | Match Review Backlog | Open suggestions on the as-of date. Age = median working hours open |
| KPI07 | Request Turnaround Time | Median working hours from Submitted to Closed, by request type. **Net** excludes time spent Returned; **gross** includes it |
| KPI08 | Request SLA Attainment | Requests closed within target, measured on net time ÷ (requests closed + requests still open past their target) |
| KPI09 | First-Time-Right Rate | Requests approved without ever being Returned ÷ requests approved or rejected |
| KPI10 | Verified Bank Details Rate | Approved suppliers passing T02 ÷ approved suppliers |
| KPI11 | Match precision and recall | Test data only, against the MDH-004 answer key (see [quality_rules.md](quality_rules.md), matching) |
