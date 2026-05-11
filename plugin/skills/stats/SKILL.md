---
description: Show time-bucketed error occurrence counts for the Faultline instance.
argument-hint: [period]
---

Show error volume over a time window using the `error_stats` MCP tool.

1. Parse `$ARGUMENTS` as the period. Valid values: `1h`, `2h`, `4h`, `1d`, `2d`, `1w`, `1m`, `all`. Default to `1d` if empty or invalid.
2. Call `error_stats` with the chosen `period`.
3. Render the response as a short table or sparkline-style summary: `bucket | count`. Lead with the `total` and `granularity` fields from the response so the user knows the resolution.
4. If any bucket is dramatically above the others, call it out. Suggest running `/spike` for per-group attribution.

This tool is global (across all error groups). For per-group time series, the user should open the group in the dashboard or run `/debug <id>`.
