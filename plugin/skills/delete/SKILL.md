---
description: Permanently delete a Faultline error group and all of its occurrences. Destructive and irreversible.
argument-hint: <error-group-id>
---

Delete Faultline error group `$ARGUMENTS`. **This is destructive — the group and all of its occurrences will be gone.** Almost always prefer `/resolve` or `/ignore` instead; reserve delete for genuine garbage (test errors, errors from a since-removed code path).

1. Call `get_error_group` with the id and show: `exception_class`, `message`, `file_path:line_number`, `occurrences_count`, `first_seen_at`, `last_seen_at`, current `status`.
2. **Strongly recommend resolving or ignoring instead** unless the user has a clear reason to delete (e.g., test data, removed code path, group was created by mistake). Ask them why they want to delete rather than ignore.
3. Require an explicit confirmation. Spell out: "this will permanently delete the group and N occurrences. Type 'yes delete' to confirm."
4. Only on the explicit confirmation, call `delete_error_group` with `id`.
5. Report the response: `id`, `occurrences_deleted`.

If the tool returns `error: "Tool disabled: mcp_readonly is true"`, tell the user to set `c.mcp_readonly = false` in their Faultline initializer.
