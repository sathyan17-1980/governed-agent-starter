# CONTEXT.md — rules loaded as law (Layer 1)

> This is an **example** context file. Your agent loads it every run. It is a
> versioned artifact, not memory — edit it, diff it, review it like code.
> Replace the rules below with your own; keep them plain and testable.

## Non-negotiables
1. **Type safety / correctness first.** Every function is typed; the strict checker must pass before anything is "done."
2. **Structured logging, not print debugging.** Log events with structured fields, never string-concatenated messages.
3. **Small, reversible changes.** Prefer the smallest diff that solves the problem. If a change is hard to reverse, stop and confirm first.
4. **No secrets in code or logs.** Load secrets from the environment at runtime only. Never echo a key, even truncated, into a log or an artifact.

## Self-audit before any architectural change
Any change to schema, data flow, interfaces, or control flow must be checked against this list *before* it's proposed:

1. **Active vs deferred harm** — is something broken right now, or only in theory?
2. **Data-flow trace** — where does this value end up downstream? Walk every consumer.
3. **False positive / false negative** — for any rule or heuristic, what good input gets rejected? What bad input slips through?
4. **Bypass paths** — what other code reaches this state without the protection?
5. **Locale / accessibility** — does this assume one language, region, or input device?
6. **Backward compatibility** — which existing callers break? Grep before claiming "safe."
7. **Honesty** — does this hide a problem instead of fixing it?
8. **Deferral integrity** — if you're filing something as later-work, confirm no live harm happens in the meantime.

## How this file is enforced
- Loaded into the agent's context at the start of every session.
- This is **strong behavioral discipline — not a mechanical hard-stop.** A model *can* skip a file instruction.
- Therefore: **anything you can't undo does not rely on this file.** Irreversible actions are stopped by the pre-execution guard (Layer 5), which the model can't route around.
