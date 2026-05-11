---
description: Open a GitHub issue for a Faultline error group using its most recent occurrence as context.
argument-hint: <error-group-id>
---

File a GitHub issue for Faultline error group `$ARGUMENTS`.

1. Call `get_error_group` with the id and show: `exception_class`, `message`, `file_path:line_number`, `occurrence_count`, `last_seen_at`, current `status`.
2. Ask the user to confirm before opening the issue. Mention that the most recent occurrence's backtrace, captured locals, and request context will be attached.
3. On confirmation, call `create_github_issue` with `id`.
4. If the response includes `issue_number` and `issue_url`, surface both so the user can open it.

Possible errors the tool may return:
- `"GitHub is not configured. Set github_repo and github_token."` — tell the user to set these on `Faultline.configure` in their initializer.
- `"Tool disabled: mcp_readonly is true"` — this is a mutating tool; user needs `c.mcp_readonly = false`.
- `"Error group #N has no occurrences to attach to the issue."` — the group exists but has nothing to file against. Nothing to do.
