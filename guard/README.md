# The guard (Layer 5)

A pre-execution guardrail: a `PreToolUse` hook that inspects the command your AI coding agent wants to run and **blocks the irreversible ones with exit 2 before they execute.**

> **Accident safety-net, not a security boundary.** It stops an over-eager agent, not a determined adversary. Say that out loud to anyone you hand it to.

## How it works

```
agent proposes a shell command
        │
        ▼
  PreToolUse hook  ──►  shell-guard.(sh|ps1)  reads the command from stdin (JSON)
        │                        │
        │                        ├─ matches a deny rule ─► exit 2  ► BLOCKED (command never runs)
        │                        └─ no match            ─► exit 0  ► ALLOWED
        ▼
  command runs (only if allowed)
```

`exit 2` is the Claude Code contract for "block this tool call and show the agent why." `exit 0` allows.

## Install

1. Copy the script into your project (keep it version-controlled).
2. Register it as a hook — see [`../examples/settings.hooks.example.json`](../examples/settings.hooks.example.json). Use an **absolute path**.
3. Make it executable (bash): `chmod +x guard/shell-guard.sh`.
4. **Verify it fires.** In a throwaway dir, have your agent attempt `rm .env` *through its tool call*. You want to see the block message + exit 2, and the file still there.
   - The block only fires on a command issued **through the agent's tool call** — not one you hand-type into a bare terminal (that never reaches the hook).

## Tune the deny rules

The rules ship deliberately small. Edit the list to match *your* irreversible actions. Good candidates:
- deleting env/secret files, keys, or credentials
- `rm -rf`, `Remove-Item -Recurse -Force`
- force-push / history rewrite on a shared branch
- writing to raw disk devices (`dd of=/dev/...`)
- dropping a production database / destructive migrations
- piping the internet into a shell (`curl ... | sh`)

Keep each rule **boring, single-purpose, and testable.** A clever rule you can't reason about is worse than three simple ones.

## Fail-open vs fail-closed

- **Fail-open (default):** if the guard itself errors, it allows — a bug in the guard must never halt all your work. Best when the guard is a convenience net over a low-stakes flow.
- **Fail-closed:** if the guard errors, it blocks — "when in doubt, stop." Best when the cost of one bad command dwarfs the cost of a false block.

Pick per risk. The scripts default to fail-open and document the one line to change.

## Test it (no agent needed)

Pipe a fake payload straight in:

```bash
echo '{"tool_input":{"command":"rm .env"}}'      | bash guard/shell-guard.sh ; echo "exit=$?"   # -> exit=2
echo '{"tool_input":{"command":"ls -la"}}'       | bash guard/shell-guard.sh ; echo "exit=$?"   # -> exit=0
```

```powershell
'{"tool_input":{"command":"rm .env"}}' | pwsh ./guard/shell-guard.ps1 ; "exit=$LASTEXITCODE"    # -> exit=2
```
