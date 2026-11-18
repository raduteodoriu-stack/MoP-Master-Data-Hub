# Governance (MDH-001)

Who owns which business partner data, which source wins by default, what must be complete at
each stage, and who may approve what. The rules that put this into practice are in
[quality_rules.md](quality_rules.md) and the request process in
[work_instructions/](work_instructions/README.md).

## Roles
| Role | Who at MoP Cloud | Responsible for |
|---|---|---|
| Data owner, legal and financial data | Finance Controller | Standard for legal name, tax ID, addresses, payment terms and bank details. Approves high-risk changes to them |
| Data owner, commercial customer data | Sales Director | Standard for customer tier, industry, account owner and company hierarchy. Approves hierarchy changes and tier overrides |
| Data owner, commercial supplier data | Head of Operations | Standard for supplier category and internal contact. Approves supplier onboarding from the business side |
| Master data steward | Master Data Specialist | Processes requests, reviews possible duplicates, monitors quality, proposes rule changes, writes work instructions |
| Requester | Sales, Finance (receivables and payables), Operations, Customer Success | Raises create, change and block requests, with evidence |
| System custodian | RevOps / IT | Keeps the hub and its connections running. No say on content |
| Data Protection Officer | DPO | Consulted on personal data. Owns erasure requests |

## Data ownership and default winning source

Field-level standards are in [data_standards.md](data_standards.md).
| Field group | Examples | Owner | Source that wins |
|---|---|---|---|
| Legal identity | Legal name, legal form, tax ID, country of registration | Finance | ERP |
| Addresses | Registered address, billing address | Finance | ERP |
| Customer payment | Payment terms, bill-to party, invoice email, billing block | Finance | ERP |
| Customer commercial | Trading name, web domain, industry, employee band, account owner, customer tier override | Sales | CRM (tier override: hub) |
| Supplier payment | Bank details, payment terms, remittance email, payment block | Finance | ERP |
| Supplier commercial | Supplier category, internal contact | Operations | Procurement spreadsheet until migrated, then the hub |
| Relationships | Parent company, top company of the group | Sales | Hub (kept by the steward) |
| Lifecycle | Stage per role, blocks | Sales for customers, Operations for suppliers, Finance for blocks | Hub |
| Contact persons | Name, work email, role, consent | Sales or Operations, DPO consulted | CRM |

## Lifecycle per role

Required data grows with the stage, so Sales is not asked for a tax ID before there is a deal.
| Role | Stage | Meaning | Must be complete |
|---|---|---|---|
| Customer | Prospect | Known company, no contract | Name, country, web domain, account owner |
| Customer | Customer | Has a signed contract | Everything needed to invoice: legal name, valid tax ID, billing address, payment terms, bill-to party |
| Supplier | Requested | Someone wants to buy from them | Name, country, category, internal contact |
| Supplier | Approved | May be ordered from and paid | Everything needed to pay: legal name, valid tax ID, registered address, payment terms, verified bank details |
| Both | Inactive | No active contract | Unchanged. Kept for history |
| Both | Blocked | Must not be used: duplicate, credit, payment or compliance block | Block reason and who decided |

## Decision rights

Above every row: nobody approves a request they raised.
| Activity | Raised by | Prepared by | Approved by |
|---|---|---|---|
| Create a prospect | Sales, or LeadFlow automatically | Automatic checks | Rules only |
| Promote a prospect to customer | Sales or Finance | Steward | Finance Controller |
| Request a new supplier | Operations or any budget holder | Steward | Head of Operations |
| Approve a supplier for payment | Operations | Steward (checks tax ID and bank evidence) | Finance Controller |
| Change a low-risk field (web domain, industry, employee band, phone, supplier category) | Any requester | Steward | Steward |
| Override a customer tier | Sales | Steward | Sales Director |
| Change a high-risk field (legal name, tax ID, addresses, payment terms, bill-to) | Finance, Sales or Operations | Steward | Finance Controller |
| Change supplier bank details | Finance (payables) | Steward, after independent verification with the supplier | Finance Controller |
| Merge: exact match on tax ID | System | Automatic | Rules. Logged and reversible |
| Merge: probable match | System or any requester | Steward | Steward. Data owner if the records have different account owners, or legal or bank data would change |
| Undo a merge | Any requester | Steward | Data owner |
| Change the company hierarchy | Sales or steward | Steward | Sales Director |
| Block or deactivate | Finance, Sales or Operations | Steward | Finance Controller for credit, payment or compliance; Sales Director or Head of Operations for inactive |
| Mass upload | Any requester | Steward, after pre-load checks | The approver of the highest-risk change in the file |
| Erase a contact person | DPO | Steward | DPO |
| Change a standard or rule | Steward or data owner | Steward | The owning data owner. Released as a new rules version |

## Separation of duties

The steward maintains supplier bank details but never releases payments, and the people who release payments cannot change bank details. Payment release is outside MDH; the hub proves that every bank change was verified and approved by someone else.
