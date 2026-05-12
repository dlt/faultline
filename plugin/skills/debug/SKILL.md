---
description: Investigate a specific Faultline error group with full occurrence detail.
argument-hint: <error-group-id>
---

Investigate Faultline error group $ARGUMENTS using the `faultline:debugging` skill's investigation order:

1. Call `get_error_group` with `id: $ARGUMENTS`.
2. Pick the most recent occurrence id from the `recent_occurrences` array.
3. Call `get_occurrence` with that id for the full backtrace, captured local variables, and request context.
4. If the error looks performance-related (timeouts, slow queries, N+1), call `list_traces` filtered to the relevant endpoint, then `get_trace` for span detail.

After the investigation, propose a fix with citations to specific files and line numbers from the backtrace, grounded in the local variable values.
