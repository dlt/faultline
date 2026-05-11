---
description: Ignore a Faultline error group so it stops surfacing in unresolved lists.
argument-hint: <error-group-id>
---

Ignore Faultline error group `$ARGUMENTS`.

1. Call `get_error_group` with the id and show: `exception_class`, `message`, `occurrence_count`, `last_seen_at`, current `status`.
2. If `status` is already `ignored`, stop and tell the user.
3. If `status` is `resolved`, mention that ignoring an already-resolved group is unusual but ask the user if they still want to proceed.
4. Ask the user to confirm before mutating.
5. On confirmation, call `ignore_error_group` with `id`.
6. Report the new status from the tool response.

If the tool returns `error: "Tool disabled: mcp_readonly is true"`, tell the user to set `c.mcp_readonly = false` in their Faultline initializer — this is a mutating tool and is off by default.
