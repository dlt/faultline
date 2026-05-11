---
description: Walk through recent unresolved Faultline error groups one at a time, asking what to do with each.
---

Batch-groom the unresolved error queue.

1. Call `list_error_groups` with `status: "unresolved"` and the default limit. If the list is empty, say so and stop.
2. Render a numbered summary so the user has the lay of the land: `id | exception_class | count | last_seen`.
3. Walk the list one entry at a time. For each group:
   a. Show: `exception_class`, `message`, `file_path:line_number`, `occurrence_count`, `last_seen_at`.
   b. Ask which of these to do: `investigate` / `resolve` / `ignore` / `file-issue` / `skip` / `stop`.
   c. Act on the user's choice:
      - `investigate` — follow the `faultline:debugging` skill (`get_occurrence` for the latest), then return to the next group.
      - `resolve` — call `resolve_error_group` (optionally prompt for a note).
      - `ignore` — call `ignore_error_group`.
      - `file-issue` — call `create_github_issue`.
      - `skip` — move on without mutating.
      - `stop` — exit the loop.
4. At the end, summarize what was done: counts of resolved/ignored/issues-filed/investigated/skipped.

If any mutating call returns `"Tool disabled: mcp_readonly is true"`, stop the loop and tell the user to set `c.mcp_readonly = false` — there is no point continuing without mutation rights.
