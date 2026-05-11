---
description: Find Faultline error groups that started appearing after a given deploy timestamp — a regression check.
argument-hint: <iso-timestamp or relative like "2h ago">
---

Identify groups that began firing after a deploy or release.

1. Resolve `$ARGUMENTS` to an ISO 8601 timestamp.
   - If the user gave an ISO timestamp, use it directly.
   - If they gave a relative phrase (`30m ago`, `2h ago`, `yesterday at 3pm`), convert it.
   - If they gave nothing, ask: what's the deploy timestamp or commit time?
2. Call `list_error_groups` with `since: <timestamp>` and the default limit.
3. **Filter the response** to groups where `first_seen_at >= <timestamp>` — these are new groups, not just groups that were also hit before the deploy. This is the regression signal.
4. Render: `id | exception_class | message | first_seen_at | occurrences_count`. Sort by `first_seen_at` ascending so the earliest regression is first.
5. If any candidates are found, suggest investigating the earliest one with `/debug <id>` — its backtrace will point at the code introduced by the deploy.

If the result is empty, the deploy looks clean from Faultline's perspective. Mention that errors filtered by `ignored_exceptions` won't show up here either.
