# Cleanup

The CLI still contains a legacy cleanup helper, but `claudux update` does not
run an automatic semantic cleanup pass.

## What exists today

`lib/cleanup.sh` provides:

- `cleanup_docs` — an interactive Claude prompt path that asks the model to
  look for obsolete docs (model-judged, not a deterministic scorer)
- `cleanup_docs_silent` — a **no-op** used during the main update path
  (explicitly empty so update does not silently delete files)

There is **no** built-in confidence threshold, no automatic file deletion
pipeline with dry-run scoring, and no guarantee that obsolete pages are
removed on every `claudux update`.

## What to use instead

Prefer the write-boundary path Claudux actually ships:

1. Keep docs structure under the **docs structure manifest**
2. Prefer **section-level** updates with hash guards / source-boundary checks
3. Delete obsolete pages yourself (or ask the model via `-m`) and re-run
   `npm test` / `claudux check` as needed

Example:

```bash
claudux update -m "List obsolete pages that reference deleted APIs; do not delete yet"
# review, then delete intentionally
```

## Why this page stays

The route remains `/features/smart-cleanup` so existing links keep working.
The visible label is now simply **Cleanup**.

## Related

- [Content Protection](/features/content-protection)
- [Generation Pipeline](/features/two-phase-generation)
- [Deterministic Generation](/technical/deterministic-generation)
