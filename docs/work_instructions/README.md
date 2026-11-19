# Work instructions

How the steward handles each request type. The decision rights are in
[governance.md](../governance.md); the evidence and targets come from
the latest rules file in [`rules/`](../../rules/) (`request_types`, `requests`).

> Skeleton pages (MDH-002). The step-by-step procedures are written in MDH-007, when the request workflow is built.

## Request types

| Request | Target (working hours) | Page |
|---|---|---|
| Create customer (promote a prospect) | 16 h | [create-customer.md](create-customer.md) |
| Create supplier (request) | 8 h | [create-supplier.md](create-supplier.md) |
| Approve supplier for payment | 16 h | [approve-supplier.md](approve-supplier.md) |
| Change low-risk field | 8 h | [change-low-risk.md](change-low-risk.md) |
| Override customer tier | 8 h | [override-customer-tier.md](override-customer-tier.md) |
| Change high-risk field | 16 h | [change-high-risk.md](change-high-risk.md) |
| Change supplier bank details | 16 h | [change-bank-details.md](change-bank-details.md) |
| Corporate event (rename, legal form change, merger or absorption) | 16 h | [corporate-event.md](corporate-event.md) |
| Reactivate a dormant supplier | 16 h | [reactivate-supplier.md](reactivate-supplier.md) |
| Block or unblock | 4 h | [block-unblock.md](block-unblock.md) |
| Merge, undo merge, hierarchy change | 16 h | [merge-hierarchy.md](merge-hierarchy.md) |
| Mass upload | 24 h | [mass-upload.md](mass-upload.md) |
| Erase a contact person | 40 h, and never more than one calendar month | [erase-contact.md](erase-contact.md) |

## Statuses

Draft → Submitted → In review → Awaiting approval → Approved → Applied → Closed. A request
can also be Returned (sent back to the requester for information), Rejected or Cancelled.
Every status change records who and when.

The SLA clock starts at Submitted and stops at Closed. It pauses while a request is Returned
and restarts when it is resubmitted. The SLA is measured on this net time; the gross time
(including Returned) is reported beside it.
