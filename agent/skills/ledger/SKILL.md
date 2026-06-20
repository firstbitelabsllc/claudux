---
name: ledger
description: Emit append-only receipts for Claudux Eve receiver work without rewriting history.
---

# Ledger Receiver Skill

Use the shared ledger emitter:

```sh
/Users/leokwan/Development/ai/hooks/ledger-emit.sh
```

Receipts must be append-only and scoped to the real repo path. Include branch,
worktree, commit, PR URL, proof commands, and non-claims.

Do not edit old ledger rows. If a row is incomplete, append a correction row.
Never include secrets, env values, tokens, private raw transcripts, or customer
messages in a ledger summary.
