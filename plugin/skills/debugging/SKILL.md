---
name: debugging
description: Investigate Rails production errors using the Faultline MCP server. Use when the user mentions a production exception, asks to look at recent errors, debugs a specific error group/occurrence, or wants to trace a slow endpoint.
---

When the user wants to debug a production error, diagnose it using the Faultline MCP tools — don't ask them to paste a stack trace from the dashboard.

## Investigation order

Follow these steps; skip any that don't apply.

1. **Find the error group.** If the user named an error class or message, call `list_error_groups` with `search:` and pick the most plausible match. If they gave a numeric id, skip to step 2.
2. **Get group context.** Call `get_error_group` with the id. The response includes a summary of the 10 most recent occurrences (no backtraces or locals — those are intentionally omitted to keep the response small).
3. **Pull a full occurrence.** Call `get_occurrence` with the most recent occurrence id to get the full backtrace, captured local variables, filtered request params, request headers, and source context. **This is the step that actually lets you fix the bug** — don't propose a fix without seeing the locals.
4. **Optional: trace performance.** If the error looks performance-related (timeouts, ConnectionTimeoutError, slow queries), call `list_traces` with the relevant `endpoint`, then `get_trace` for span detail.
5. **Propose a fix.** Cite specific files and line numbers from the backtrace. Use the local variables to ground claims about what data flowed in.

## Tools available

Read-only:
- `list_error_groups` — recent groups, filter by status/since/search
- `get_error_group` — single group + recent occurrence summary
- `get_occurrence` — full occurrence with backtrace, locals, request data
- `recent_occurrences` — paginate occurrences for a group
- `error_stats` — time-bucketed counts
- `list_traces` / `get_trace` — APM data (only when enable_apm is set on the host app)

Mutating (only available when the Faultline app sets `mcp_readonly: false`):
- `resolve_error_group` — mark resolved
- `ignore_error_group` — mark ignored
- `create_github_issue` — open a GitHub issue with full context

## Common pitfalls

- **Don't fetch the occurrence first.** Fetching the group first gives you the right id and lets you rule out resolved or ignored groups before deep-diving.
- **Don't ignore captured locals.** They are the highest-signal data Faultline provides over a raw stack trace — the actual variable values at the moment the exception fired.
- **Mutating tools may return `error: "Tool disabled: mcp_readonly is true"`.** That's expected on production-default installs. If the user wants you to resolve/ignore/file issues directly, tell them to set `c.mcp_readonly = false` in their Faultline initializer.
- **Filtered params are filtered.** Faultline applies `Rails.application.config.filter_parameters` plus `config.sanitize_fields`. If you see `[FILTERED]` in `request_params`, that's by design — don't ask the user for the underlying value.
