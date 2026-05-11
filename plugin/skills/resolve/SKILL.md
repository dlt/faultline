---
description: Resolve a Faultline error group by id, with an optional note.
argument-hint: <error-group-id> [note]
---

Resolve Faultline error group from `$ARGUMENTS`. The first token is the group id; the rest (if any) is the note.

1. Call `get_error_group` with the id and show the user: `exception_class`, `message`, `occurrence_count`, `last_seen_at`, and current `status`.
2. If `status` is already `resolved` or `ignored`, stop and tell the user — don't re-resolve.
3. Ask the user to confirm before mutating.
4. On confirmation, call `resolve_error_group` with `id` and `note` (omit `note` if none was given).
5. Report the new status from the tool response.

If the tool returns `error: "Tool disabled: mcp_readonly is true"`, tell the user to set `c.mcp_readonly = false` in their Faultline initializer — this is a mutating tool and is off by default.
