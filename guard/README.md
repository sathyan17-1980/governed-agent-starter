# The guard (Layer 5)

A pre-execution guardrail: a `PreToolUse` hook that inspects the command your AI coding agent wants to run and **blocks the irreversible ones with exit 2 before they execute.**

> **Accident safety-net, not a security boundary.** It stops an over-eager agent, not a determined adversary. Say that out loud to anyone you hand it to.

## Prerequisites

- **An agent with a pre-execution hook.** This guard targets **Claude Code**'s `PreToolUse` hook (`exit 2` = block, JSON on stdin). Other agents (Cursor, Aider, Copilot, …) don't expose the same contract — you'd adapt the *idea*, not drop in this file.
- **`jq` or `python3`** for robust JSON parsing (either is fine; `python3` ships on most macOS/Linux dev machines). Without both, the guard falls back to scanning the raw payload — it still blocks, but over-matches. Install one.

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

`exit 2` is the Claude Code contract for "block this tool call and show the agent why." `exit 0` allows. The guard **composes with** other hooks — it doesn't replace them; any hook returning exit 2 blocks.

## Install

1. Copy the script into your project (keep it version-controlled).
2. Make it executable (bash): `chmod +x guard/shell-guard.sh`.
   - *(The documented `bash <script>` / `pwsh -File <script>` invocations don't strictly need the +x bit, but set it anyway.)*
3. **Register it as a hook** by merging `../examples/settings.hooks.example.json` into your Claude Code settings. Use an **absolute path** to the script.
   - **Where settings live** (pick one): project `.claude/settings.json` (shared, committed) · project `.claude/settings.local.json` (personal, git-ignored) · user `~/.claude/settings.json` (global). Project settings take precedence.
4. **Windows only:** PowerShell's default execution policy blocks unsigned local scripts. Invoke via `pwsh -ExecutionPolicy Bypass -File C:\abs\path\guard\shell-guard.ps1` (the example includes this), or sign the script.
5. **Verify it fires** (see below). If you do **not** see exit 2 on a command that should block, your hook path is wrong — **a missing block is not proof the command was safe** (fail-open means a broken hook looks identical to "allowed").

## Test it (no agent needed)

Pipe a fake payload straight in. Test **both** a realistic multi-key payload and, if you can, a no-`jq` run:

```bash
# minimal
echo '{"tool_input":{"command":"rm .env"}}' | bash guard/shell-guard.sh ; echo "exit=$?"   # -> 2
echo '{"tool_input":{"command":"ls -la"}}'  | bash guard/shell-guard.sh ; echo "exit=$?"   # -> 0

# realistic: command is NOT the last key (matches real PreToolUse payloads)
echo '{"session_id":"x","cwd":"/p","tool_name":"Bash","tool_input":{"command":"rm -r -f build"}}' \
  | bash guard/shell-guard.sh ; echo "exit=$?"                                              # -> 2
```

```powershell
'{"tool_input":{"command":"rm .env"}}' | pwsh -ExecutionPolicy Bypass -File ./guard/shell-guard.ps1 ; "exit=$LASTEXITCODE"   # -> 2
```

> ⚠️ **The `rm .env` self-test through your live agent can mislead:** many agents refuse `rm .env` on their own, so the command never reaches the hook and you see no block — that's the *agent* stopping it, not the guard. Trust the `echo … | bash` test above for proof the guard itself fires.

## What ships vs. what you must add

Ships with these example rules: delete/unlink env-secret-key files · recursive force delete (`rm -rf`, `-r -f`, `--recursive --force`) · force-push · destructive git (hard reset, `clean -f`, discard working tree `checkout -- .` / `restore .`) · `curl|wget` piped into a shell/interpreter · `dd of=/dev/…` · `shred` · `find … -delete/-exec rm` of secrets · `>` overwrite of a secret file.

**Deliberately NOT covered by default** — add them if they're *your* irreversible action:

```bash
# database drops / destructive migrations
printf '%s' "$cmd" | grep -Eiq '(drop[[:space:]]+database|dropdb|truncate[[:space:]]+table)' \
  && block "database drop / truncate"
# truncate a file to empty
printf '%s' "$cmd" | grep -Eiq '\btruncate\b.*-s[[:space:]]*0' \
  && block "truncate to zero"
```

## Tune the deny rules

Edit the list to match *your* irreversible actions. Keep each rule **boring, single-purpose, and testable**, and **re-run the tests after editing** — a broken regex fails open silently (the guard is fail-open by design). A clever rule you can't reason about is worse than three simple ones.

## Known limitations (be honest with your team)

- **Substring matching:** a command that only *mentions* a dangerous token can be blocked — e.g. `git commit -m "add rm -rf guard"` or `rm .env.example`. Conservative false positives; the trade for "boring and deterministic."
- **`--force-with-lease` is blocked** alongside `--force`, even though it's the safer variant — intentional conservative default; loosen rule 3 if it gets in your way.
- **Indirection is invisible:** `$VAR`, command substitution, and aliases hide the real command from a text scan, so they're not caught. Chained commands (`a && rm -rf b`) are only caught by the literal token, not as a category.
- **bash vs PowerShell parity is approximate:** `shell-guard.ps1` uses a real JSON parser (`ConvertFrom-Json`) and adds a `Remove-Item -Recurse -Force` rule; `shell-guard.sh` uses jq/python3/raw-fallback. Same intent, not line-for-line identical — mirror any rule you add.
