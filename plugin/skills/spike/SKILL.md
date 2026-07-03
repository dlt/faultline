---
description: Find Faultline error groups that have been active recently, ranked by occurrence count.
argument-hint: "[duration like 1h, 4h, 1d — default 1h]"
---

Surface error groups that are firing right now.

1. Parse `$ARGUMENTS` as the lookback window. Default to `1h`. Convert to an ISO 8601 timestamp for "now minus duration".
2. Call `list_error_groups` with `since: <iso-timestamp>` and the default limit. Note: `since` filters by `last_seen_at`, so this returns groups that have been hit at least once in the window — not strictly groups that "spiked", but it's the closest available signal.
3. Sort the response by `occurrences_count` descending and render: `id | exception_class | count | first_seen_at | last_seen_at`.
4. Flag any group whose `first_seen_at` is **inside** the window — those are brand-new errors that only started appearing now, which is the strongest spike signal.
5. Offer to drill into the top one with `/debug <id>`.

If you also want a global volume picture, suggest `/stats <period>` — that one shows time-bucketed counts across the whole instance.
