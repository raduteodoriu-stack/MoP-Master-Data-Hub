# Mass upload

**Request type:** `mass_upload` · **Target:** 24 h (net working time)

## Who
| Raised by | Prepared by | Approved by |
|---|---|---|
| Any requester | Steward, after pre-load checks | The approver of the highest-risk change in the file |

The approver is never the person who raised the request.

## Evidence required
- upload template passing preload checks

## Checks before approval
Quality rules: Every rule that applies to each row. A request with a failed error-level rule or missing evidence
cannot be submitted.

The pre-load check runs the same quality rules as the hub on every row and returns a row
report: row, column, value, rule, severity and message. Errors stop the submission; warnings
are shown but do not. The approver sees which rows are high-risk. The file is approved or
rejected as a whole: if the approver objects to some rows, the file is rejected and the
requester splits it.

## Steps
To be written in MDH-007.

## Common reasons to return the request
To be written in MDH-007.
