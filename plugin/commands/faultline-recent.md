---
description: List recent unresolved errors from your Faultline instance.
---

Call the `list_error_groups` MCP tool with `status: "unresolved"` and the default limit.

Format the result as a short table — one line per group with: `id | exception_class | count | last_seen` (relative time like "5m ago"). After the table, ask the user which one they want to investigate. If the user picks one, follow the faultline-debugging skill to dig in.
