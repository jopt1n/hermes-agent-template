---
type: policy
title: Memory Policy
status: active
updated: 2026-05-11
---

# Memory Policy

## Current rule

Hermes should use GBrain as durable project memory, not as a dump of every message.

Search GBrain before answering questions about user-specific projects, prior decisions, people, companies, deals, vendors, tools, architecture, setup state, or previous troubleshooting.

Write to GBrain only when the information is notable, durable, source-backed, and likely useful later.

## Remember

- Final decisions
- Current project status
- Next steps
- Architecture choices
- Important configuration changes
- Commands that fixed a problem
- Known failure modes and fixes
- Durable user preferences
- Important project paths
- Important companies, people, deals, vendors, and tools
- Source-backed facts that matter later

## Do not remember

- Every casual message
- Repeated terminal noise
- Failed paste attempts
- Temporary debugging chatter
- Duplicate facts already captured elsewhere
- Secrets, API keys, tokens, passwords, or private credentials
- Raw logs unless a short sanitized excerpt is needed
- Low-value intermediate steps
- Speculation unless clearly marked as speculation

## Memory format

Prefer updating existing pages over creating duplicate pages.

Keep current truth near the top of each page.

Use a timeline or evidence section for historical details.

Add source context where possible, such as Slack message, terminal output, file path, Git commit, uploaded file, or external source.

Consolidate and prune noisy pages before enabling broad automatic memory writes.
