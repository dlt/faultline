---
description: Diff several occurrences of the same Faultline error group to see what varies between them.
argument-hint: <error-group-id> [count, default 3]
---

Compare occurrences of the same group to spot which inputs vary between successes and failures.

1. Parse `$ARGUMENTS`: first token is the group id, optional second token is how many occurrences to compare (default 3, max 10).
2. Call `recent_occurrences` with `group_id: <id>` and `limit: <count>` to get a list of occurrence ids.
3. For each id, call `get_occurrence` to pull the full payload (backtrace, locals, request params, headers).
4. Diff across the occurrences and surface what changes:
   - **request_params** — which keys are present, which values differ
   - **local_variables** — same: which keys, which values
   - **request_url** / `request_method` — different endpoints hitting the same fingerprint?
   - **user_identifier** — same user repeatedly, or many distinct users?
   - **backtrace** — should be near-identical; flag if a frame differs (means the fingerprint may be over-grouping).
5. Render a compact comparison: per varying field, show the value from each occurrence.
6. Lead with the highest-signal difference. Captured locals usually beat request params for diagnosing what triggers the bug.

If only one occurrence exists for the group, say so — there's nothing to compare. Filtered values will appear as `[FILTERED]` and shouldn't be flagged as differences (`Rails.application.config.filter_parameters` + `config.sanitize_fields`).
