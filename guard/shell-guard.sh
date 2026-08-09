#!/usr/bin/env bash
# shell-guard.sh — a pre-execution guardrail for AI coding agents (Layer 5).
#
# Wire this as a Claude Code `PreToolUse` hook (matcher: "Bash"). Before the
# agent's shell command runs, this script inspects it and BLOCKS the
# irreversible ones by returning exit 2 — *before* anything executes.
#
# HONEST CAVEAT — READ THIS:
#   This is an ACCIDENT SAFETY-NET, not a security boundary. It stops an
#   over-eager agent from fat-fingering something destructive. A deliberately
#   obfuscated command can still get past a regex. Build it for the over-eager
#   assistant, not an adversary.
#
# Hook contract (Claude Code):
#   stdin  -> JSON payload with .tool_input.command for the Bash tool
#   exit 2 -> BLOCK the tool call; stderr is surfaced to the agent
#   exit 0 -> ALLOW
#
# Fail direction: FAIL-OPEN. If the guard itself errors, it must not halt all
# your work, so unexpected failures allow. Set ALLOW_ON_ERROR=0 for fail-closed
# ("when in doubt, block") if your risk profile calls for it.

set -uo pipefail
ALLOW_ON_ERROR=1

# --- Read the hook payload ---------------------------------------------------
payload="$(cat 2>/dev/null || true)"

# Extract the proposed command. Prefer jq; fall back to a permissive parse.
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
else
  cmd="$(printf '%s' "$payload" | tr '\n' ' ' | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p')"
fi

# Nothing to inspect -> allow.
[ -z "${cmd:-}" ] && exit 0

block() {
  {
    echo "BLOCKED by shell-guard: $1"
    echo "Command: $cmd"
    echo "If this was truly intended, run it yourself outside the agent."
  } >&2
  exit 2
}

# --- Deny rules --------------------------------------------------------------
# Tune these to YOUR irreversible actions. Each is a single, boring, testable
# pattern. Boring and deterministic beats smart and hopeful.

# 1. Deleting env / secret files
printf '%s' "$cmd" | grep -Eiq '\brm\b.*(\.env(\.[a-z0-9]+)?|secret|\.pem|id_rsa)' \
  && block "attempt to delete an env/secret file"

# 2. Recursive force delete (rm -rf, rm -fr)
printf '%s' "$cmd" | grep -Eiq '\brm\b[[:space:]]+-[a-z]*(rf|fr)[a-z]*\b' \
  && block "recursive force delete (rm -rf)"

# 3. Force-push
printf '%s' "$cmd" | grep -Eiq '\bgit\b.*\bpush\b.*(--force\b|--force-with-lease\b|[[:space:]]-f\b)' \
  && block "git force push"

# 4. Destructive git (hard reset / clean -fd)
printf '%s' "$cmd" | grep -Eiq '\bgit\b.*(reset[[:space:]]+--hard|clean[[:space:]]+-[a-z]*f)' \
  && block "destructive git (hard reset / clean -f)"

# 5. Piping the internet straight into a shell
printf '%s' "$cmd" | grep -Eiq '(curl|wget)\b.*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z)?sh\b' \
  && block "curl/wget piped into a shell"

# 6. Writing to a raw disk device
printf '%s' "$cmd" | grep -Eiq '\bdd\b.*[[:space:]]of=/dev/' \
  && block "dd writing to a /dev/ device"

# --- Default: allow ----------------------------------------------------------
exit 0
