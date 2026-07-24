# Cleanup (legacy name: “Smart Cleanup”)

Honest status: the CLI still ships a cleanup surface, but **it is not a
confidence-scored semantic cleanup engine**. Treat marketing that talks about
95% confidence scoring and automatic obsolete-file deletion as **aspirational
docs debt**, not current product behavior.

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
   `npm test` / `claudux doctor` as needed

Example:

```bash
claudux update -m "List obsolete pages that reference deleted APIs; do not delete yet"
# review, then delete intentionally
```

## Why this page stays

Older releases and screenshots referred to “Smart Cleanup.” Renaming the nav
overnight breaks links. This page remains as the honest stub until a real
cleanup product exists.

## Related

- [Content Protection](/features/content-protection)
- [Two-Phase Generation](/features/two-phase-generation)
- [Deterministic Generation](/technical/deterministic-generation)
