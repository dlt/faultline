---
description: Apply one action (resolve/unresolve/ignore/delete) to many Faultline error groups in a single call.
argument-hint: <action> <id1,id2,...>
---

Bulk-update Faultline error groups via the `bulk_update_error_groups` MCP tool.

1. Parse `$ARGUMENTS`:
   - First token: `action` — one of `resolve`, `unresolve`, `ignore`, `delete`.
   - Remaining tokens: a comma-separated list of integer ids. Strip whitespace.
   - If either is missing, ask the user to clarify before calling the tool.
2. Show the user what's about to happen: `action: <action>`, `ids: [<list>]`, count.
3. Ask for confirmation. For `delete`, require an explicit `"yes delete"` — same standard as the `delete` skill, because this is irreversible and acts on N groups at once.
4. On confirmation, call `bulk_update_error_groups` with `ids` (array of ints) and `action`.
5. Report the response:
   - `affected` — how many groups were actually updated.
   - `missing_ids` — ids the user supplied that don't exist. Flag these so they know which ones were skipped.

If many ids are involved, suggest running `/triage` instead — that walks the user through one group at a time with per-group context.

If the tool returns `error: "Tool disabled: mcp_readonly is true"`, tell the user to set `c.mcp_readonly = false` in their Faultline initializer.
