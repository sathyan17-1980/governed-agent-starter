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
Any change to schema, data flow, interfaces, or control flow should be checked against a short, explicit list *before* it's proposed. **The list itself is yours to write** — the discipline is that it's written down and repeatable, not that you use these exact prompts. Two generic starters to seed your own:

1. **Blast radius** — what's the worst thing this change can break, and is that bounded?
2. **Backward compatibility** — which existing callers break? Check before claiming "safe."

> Keep the list short and specific to *your* domain — data flow, failure modes, locale, whatever bites you. The value is that "did you think about X?" becomes a written, repeatable step you own, not a checklist copied from someone else.

## How this file is enforced
- Loaded into the agent's context at the start of every session.
- This is **strong behavioral discipline — not a mechanical hard-stop.** A model *can* skip a file instruction.
- Therefore: **anything you can't undo does not rely on this file.** Irreversible actions are stopped by the pre-execution guard (Layer 5), which the model can't route around.
