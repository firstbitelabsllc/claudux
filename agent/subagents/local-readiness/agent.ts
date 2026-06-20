import { defineAgent } from "eve";

export default defineAgent({
  description: "Read-only Claudux readiness check for local files, manifest state, branch state, and safe proof surfaces.",
  model: process.env.EVE_MODEL ?? "anthropic/claude-sonnet-4.6",
  compaction: {
    thresholdPercent: 0.7,
  },
});
