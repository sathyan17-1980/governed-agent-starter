# The Five-Layer Skeleton — Copy-able Checklist

Put even **one** layer onto your own agent this week. None of these is a prompt.

---

## Layer 1 — Context as law
- [ ] Rules live in a **versioned file** (e.g. `CONTEXT.md`), loaded every run — not memory, not re-typed.
- [ ] The file states **non-negotiables** (type safety, logging, review gates) in plain, testable language.
- [ ] Any architectural change triggers a **self-audit checklist** the agent must complete before proposing.
- [ ] You can diff the rules over time — they're a tracked artifact, not a chat.

> Honest limit: this is strong *behavioral* discipline, not a hard stop. A model *can* skip a file instruction. So the stuff you can't undo does **not** live here — it lives in Layer 5.

## Layer 2 — Prohibited-action personas
- [ ] Work is split into **single-responsibility roles**, each with its own contract.
- [ ] Every contract declares **Inputs** (may read), **Outputs** (may write), and **Prohibited Actions** (must not do).
- [ ] A role can only touch state it was explicitly handed — it can't corrupt what it never had a handle to.
- [ ] Prohibited actions are enforced by the harness, not by hoping the model complies.

> The single most defensible idea here: a sharper prompt improves the **average** case; a prohibited action changes the **worst** case — it shrinks the blast radius by construction.

## Layer 3 — Governed loops
- [ ] The agent runs inside a loop whose **control points are code** (git/tests/lint run first).
- [ ] **Hard caps** park the loop instead of letting it spin forever.
- [ ] Durable **state lives in files**, not chat memory.
- [ ] Each control point has an explicit **fail direction**: fail-closed (when in doubt, block) vs fail-open (when in doubt, allow) — chosen per real risk.

## Layer 4 — Quality-gated pipeline
- [ ] "Done" is a **score that clears a threshold**, not the agent's opinion.
- [ ] Output is scored against an **explicit, versioned rubric** before anything ships.
- [ ] The gate is trustworthy only because the rubric is explicit and gated — not because the model "has an opinion."
- [ ] A failing score **blocks the ship**, automatically.

> This gate is *behavioral* (a model scoring against a rubric). Trustworthy, but a different trust level than a mechanical block. Know which one you're relying on.

## Layer 5 — Pre-execution guardrail
- [ ] A **`PreToolUse` hook** inspects every shell command *before* it runs.
- [ ] Irreversible commands (delete env/secrets, `rm -rf`, force-push, disk writes) return **exit 2 → blocked**.
- [ ] The block is **mechanical** — the model can't route around an exit code.
- [ ] It's **fail-open** so a bug in the guard never halts all your work (flip to fail-closed if your risk says so).
- [ ] You've verified it actually fires with a throwaway blocked command.

> The only purely mechanical layer. Reserve it for the actions you can't undo. Boring and deterministic beats smart and hopeful.

---

## The whole skeleton, one line each
**context as law · prohibited-action personas · governed loops · quality-gated pipeline · pre-execution guardrail**

Advisory discipline for taste (1–4) + a hard block for damage (5). That combination *is* the harness.
