# Corporate event (rename, legal form change, merger or absorption)

**Request type:** `corporate_event` · **Target:** 16 h (net working time)

## Who
| Raised by | Prepared by | Approved by |
|---|---|---|
| Finance, Sales or Operations | Steward, with the registry extract | Finance Controller |

The approver is never the person who raised the request.

## Evidence required
- registry extract
- event document (for example the merger deed or the new articles)

## What changes
- **Rename:** new legal or trading name; the old name is kept as a former name and used in matching.
- **Legal form change:** new legal form and name ending; the tax ID does not change.
- **Merger or absorption:** the absorbed partner gets block reason `absorbed`, its roles become inactive, and it is linked to the surviving partner with `successor_of`. The steward reviews its contacts and hierarchy.

## Checks before approval
Quality rules: V10, V11, K11. A request with a failed error-level rule or missing evidence cannot be submitted.

## Steps
To be written in MDH-007.

## Common reasons to return the request
To be written in MDH-007.
