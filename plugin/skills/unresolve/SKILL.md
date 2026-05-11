---
description: Reopen a previously resolved Faultline error group.
argument-hint: <error-group-id>
---

Unresolve Faultline error group `$ARGUMENTS`.

1. Call `get_error_group` with the id and show: `exception_class`, `message`, `occurrence_count`, `last_seen_at`, current `status`, `resolved_at`.
2. If `status` is already `unresolved`, stop and tell the user — nothing to do.
3. If `status` is `ignored`, mention that unresolving will move it back to active triage. Ask the user to confirm.
4. Ask the user to confirm before mutating.
5. On confirmation, call `unresolve_error_group` with `id`.
6. Report the new status — `resolved_at` should be cleared in the response.

Common reasons to unresolve: a regression brought the error back, or the group was resolved by mistake. If the user mentions a new occurrence, Faultline auto-reopens resolved groups when they reoccur (`ErrorGroup.find_or_create_from_exception`), so explicit unresolve is rarely needed for active errors — verify before mutating.

If the tool returns `error: "Tool disabled: mcp_readonly is true"`, tell the user to set `c.mcp_readonly = false` in their Faultline initializer.
