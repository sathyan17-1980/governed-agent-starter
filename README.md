# Governed Agent Starter

A copy-able skeleton for wrapping an AI coding agent in **deterministic guardrails it can't argue with** — so it can't wreck a repo when nothing's supposed to be at stake.

> **A prompt is a request. A harness is a rule.**
> You don't keep an AI coding agent in line with a sharper prompt — you keep it in line with scaffolding *around* the model that decides what it can actually do, regardless of what the prompt says.

This repo is the free starter template. It gives you the **five-layer skeleton** and a **working pre-execution guard** you can drop onto your own agent this week. It is intentionally minimal — a starting point, not a framework.

> **Prerequisites.** The runnable guard (Layer 5) targets **Claude Code**'s `PreToolUse` hook and needs **`jq` or `python3`** on your machine. If your agent is a different tool, you'll adapt the *pattern* rather than drop in the script — the five-layer skeleton itself is agent-agnostic.

---

## The five-layer skeleton

Reliability isn't a prompt you write; it's an architecture you decide on before the first prompt. Five layers, each a real artifact — not a vibe:

| # | Layer | What it does | In this repo |
|---|-------|--------------|--------------|
| 1 | **Context as law** | Rules live in a versioned file the agent reads every run — not memory, not re-explained each time. | [`examples/CONTEXT.md`](examples/CONTEXT.md) |
| 2 | **Prohibited-action personas** | Each role is a contract with declared Inputs, Outputs, and *Prohibited Actions* — shrink the **worst** case by construction, not the average case. | [`examples/persona-contract.example.md`](examples/persona-contract.example.md) |
| 3 | **Governed loops** | Control points are code: deterministic checks run first, hard caps *park* instead of spinning forever, state lives in files. | checklist only — no code in free tier |
| 4 | **Quality-gated pipeline** | "Done" is a score that clears a gate — a threshold, not a gut call. | checklist only — no code in free tier |
| 5 | **Pre-execution guardrail** | An exit-code block that stops the irreversible command *before it runs*. The only purely mechanical layer. | [`guard/`](guard/) |

**Layers 1–4 make the *average* case reliable — that's most of the day-to-day value.** They're advisory: a model *can*, in theory, route around them. **Layer 5 is the only mechanical one, and it's reserved for the ~5% that's irreversible** — the actions you can't undo. A harness is advisory discipline for taste **and** a hard block for damage. You need both, doing different jobs.

---

## Quickstart: install the guard (Layer 5) in 2 minutes

The guard is a `PreToolUse` hook. Before your agent runs a shell command, the hook inspects it and returns **exit 2 to block** (or exit 0 to allow) — *before* the command executes.

1. **Copy the guard** into your project:
   ```
   cp guard/shell-guard.sh   /path/to/your/project/guard/     # macOS / Linux
   cp guard/shell-guard.ps1  \path\to\your\project\guard\      # Windows / PowerShell
   ```
2. **Wire it as a hook.** Merge [`examples/settings.hooks.example.json`](examples/settings.hooks.example.json) into your Claude Code settings (`.claude/settings.json` in your project, or `~/.claude/settings.json` globally), using an **absolute path** to the script. On Windows, invoke via `pwsh -ExecutionPolicy Bypass -File …`.
3. **Prove it blocks — the reliable way.** Run the deterministic test (no agent needed): `echo '{"tool_input":{"command":"rm .env"}}' | bash guard/shell-guard.sh` → expect **exit 2**. *(Asking your live agent to `rm .env` is unreliable — many agents refuse it themselves, so the command never reaches the hook and you can't tell the guard fired.)* If a should-block command shows **no** exit 2, your hook path is wrong — a missing block is **not** proof the command was safe.
4. **Tune the deny rules** in the script to *your* irreversible actions, and see what's covered vs. not (see [`guard/README.md`](guard/README.md)).

> ⚠️ **Be straight about what this is:** the guard is an **accident safety-net, not a security boundary.** It stops an over-eager agent from fat-fingering something destructive. A deliberately obfuscated command can still slip past a regex. Build it for the over-eager assistant, not an adversary.

---

## Repo layout

```
governed-agent-starter/
├── README.md                          # you are here
├── SKELETON-CHECKLIST.md              # the copy-able five-layer checklist
├── LICENSE                            # PolyForm Perimeter 1.0.0 + plain-English (NOT MIT)
├── guard/
│   ├── shell-guard.sh                 # pre-execution guard (bash)
│   ├── shell-guard.ps1                # pre-execution guard (PowerShell)
│   └── README.md                      # wiring, deny-rule tuning, fail-open vs fail-closed
└── examples/
    ├── CONTEXT.md                     # Layer 1 — context loaded as law
    ├── persona-contract.example.md    # Layer 2 — a role with prohibited actions
    └── settings.hooks.example.json    # how to register the guard as a PreToolUse hook
```

---

## Going further

This starter is the mechanism, not the whole method. Governing agent **memory** so it won't overshare, agent **output** so it won't ship junk, and composing these layers into a repeatable lifecycle all go beyond this starter — more on that soon.

## License

Licensed under the **PolyForm Perimeter License 1.0.0** (full legal text + a plain-English summary in [`LICENSE`](LICENSE)). Use and modify it anywhere, including your own commercial work — you just can't repackage it into a product that competes with it (e.g. reselling it, or bundling it into a paid course whose value comes substantially from this software).
