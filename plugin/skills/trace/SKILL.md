---
description: Inspect Faultline APM traces — slow endpoints or a specific request's span breakdown.
argument-hint: "[endpoint | trace-id]"
---

Investigate APM traces using `list_traces` and `get_trace`.

Decide which mode from `$ARGUMENTS`:

- **No args or an endpoint string** (e.g. `UsersController#show`):
  1. Call `list_traces` with `slow_only: true` and the `endpoint` filter if one was given.
  2. Render a short table: `id | endpoint | duration_ms | db_runtime_ms | db_query_count | created_at`.
  3. Ask which trace the user wants to drill into, or call `get_trace` directly on the slowest one if a single result.

- **A numeric trace id**:
  1. Call `get_trace` with `id`.
  2. Group the spans by category (SQL / view / HTTP / Redis). Surface the top N spans by duration.
  3. Flag patterns: many similar SQL spans (likely N+1), a single span dominating total duration, or external HTTP that exceeds the rest combined.

If either tool returns `"APM is disabled. Set enable_apm = true to use trace tools."`, tell the user to set `c.enable_apm = true` in their Faultline initializer. If it returns `"APM tables not present"`, the migration hasn't been run yet.
