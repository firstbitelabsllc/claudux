---
name: local-boundary
description: Keep Claudux Eve receiver work local-only unless a plan explicitly authorizes a live action.
---

# Local Boundary

This receiver is local-only by default.

Allowed:

- Read repo files and local manifests.
- Write repo-local evidence, scripts, and agent files.
- Run local install, shell tests, secret scans, and Eve metadata commands.
- Open a draft PR for review.

Not allowed without explicit authorization:

- Create or modify credentials, env files, tokens, keychains, or provider config.
- Start paid model/API calls or model downloads.
- Publish to npm, deploy docs, mutate GitHub Pages, or run release actions.
- Mutate another Mac or persistent local service.
- Send external messages to humans or customers.
