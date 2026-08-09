#!/usr/bin/env bash
# shell-guard.sh — a pre-execution guardrail for AI coding agents (Layer 5).
#
# Wire this as a Claude Code `PreToolUse` hook (matcher: "Bash"). Before the
# agent's shell command runs, this script inspects it and BLOCKS the
# irreversible ones by returning exit 2 — *before* anything executes.
#
# HONEST CAVEAT — READ THIS:
#   This is an ACCIDENT SAFETY-NET, not a security boundary. It stops an
#   over-eager agent from fat-fingering something destructive. It does NOT stop
#   an adversary, and it is deliberately simple, so it has real limits:
#     * It substring-matches the command text. A command that only *mentions* a
#       dangerous token (e.g. `git commit -m "add rm -rf guard"`) can be blocked
#       — a conservative false positive. Boring beats clever.
#     * Indirection is invisible to it: `$VAR`, command substitution, and shell
#       aliases hide the real command, so they are NOT caught.
#     * It ships with a SMALL set of example rules. Many irreversible actions
#       (DB drops, `git checkout -- .` discarding work, migrations) are NOT
#       covered by default — add them below. See guard/README.md.
#
# Hook contract (Claude Code):
#   stdin  -> JSON payload with .tool_input.command (for the Bash tool)
#   exit 2 -> BLOCK the tool call; stderr is surfaced to the agent
#   exit 0 -> ALLOW
#
# Requirements: `jq` OR `python3` for robust JSON parsing (either is fine). If
# neither is present it falls back to scanning the raw payload, which errs
# toward *over*-blocking (safe direction) but is imprecise — install one.
#
# Fail direction: FAIL-OPEN. If the guard itself errors, it must not halt all
# your work, so unexpected failures allow. Set ALLOW_ON_ERROR=0 for fail-closed
# ("when in doubt, block") if your risk profile calls for it.

set -uo pipefail
ALLOW_ON_ERROR=1

# --- Read the hook payload ---------------------------------------------------
payload="$(cat 2>/dev/null || true)"

# Extract the proposed command. Prefer jq, then python3, then a raw fallback.
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
elif command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$payload" | python3 -c 'import sys, json
try:
    print((json.load(sys.stdin).get("tool_input") or {}).get("command") or "")
except Exception:
    pass' 2>/dev/null || true)"
else
  # Last resort: no JSON parser available. Scan the whole payload. This
  # over-matches (may block on text in sibling fields) — install jq or python3.
  cmd="$(printf '%s' "$payload" | tr '\n' ' ')"
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

# 1. Deleting / unlinking an env / secret / key file
printf '%s' "$cmd" | grep -Eiq '\b(rm|unlink)\b.*(\.env(\.[a-z0-9]+)?|secret|\.pem|id_rsa)' \
  && block "attempt to delete an env/secret/key file"

# 2. Recursive force delete — fused (-rf/-fr), split (-r -f), or long
#    (--recursive --force). Requires rm AND a recursive flag AND a force flag.
if printf '%s' "$cmd" | grep -Eiq '\brm\b' \
   && printf '%s' "$cmd" | grep -Eiq -- '(-[rfvid]*r[rfvid]*\b|--recursive\b)' \
   && printf '%s' "$cmd" | grep -Eiq -- '(-[rfvid]*f[rfvid]*\b|--force\b)'; then
  block "recursive force delete (rm -rf / -r -f / --recursive --force)"
fi

# 3. Force-push
printf '%s' "$cmd" | grep -Eiq '\bgit\b.*\bpush\b.*(--force\b|--force-with-lease\b|[[:space:]]-f\b)' \
  && block "git force push (--force / --force-with-lease intentionally both blocked)"

# 4. Destructive git (hard reset / clean -fd / discard working tree)
printf '%s' "$cmd" | grep -Eiq '\bgit\b.*(reset[[:space:]]+--hard|clean[[:space:]]+-[a-z]*f|checkout[[:space:]]+--[[:space:]]|restore[[:space:]]+\.|checkout[[:space:]]+\.)' \
  && block "destructive git (hard reset / clean -f / discard working tree)"

# 5. Piping the internet straight into an interpreter
printf '%s' "$cmd" | grep -Eiq '(curl|wget)\b.*\|[[:space:]]*(sudo[[:space:]]+)?((ba|z)?sh|python[0-9.]*|node|perl|ruby)\b' \
  && block "curl/wget piped into a shell or interpreter"

# 6. Writing to a raw disk device
printf '%s' "$cmd" | grep -Eiq '\bdd\b.*[[:space:]]of=/dev/' \
  && block "dd writing to a /dev/ device"

# 7. shred / secure-delete (irreversible)
printf '%s' "$cmd" | grep -Eiq '\bshred\b' \
  && block "shred (irreversible secure-delete)"

# 8. find ... -delete / -exec rm targeting env/secret files (token may precede rm)
printf '%s' "$cmd" | grep -Eiq '\bfind\b.*(\.env|\.pem|id_rsa|secret).*(-delete\b|-exec[[:space:]]+(rm|unlink)\b)' \
  && block "find deleting env/secret files"

# 9. Redirect (>) overwriting an env/secret file (truncate-to-empty; not >>)
printf '%s' "$cmd" | grep -Eiq '(^|[^>])>[[:space:]]*("?)([^[:space:]"]*\.env\b|[^[:space:]"]*\.pem\b|[^[:space:]"]*id_rsa\b|[^[:space:]"]*secret[^[:space:]"]*)' \
  && block "redirect overwriting an env/secret file"

# --- NOT covered by default (add your own if these are your irreversibles) ----
#   psql -c 'DROP DATABASE ...' / dropdb / destructive migrations
#   chmod -R on sensitive trees
#   truncate -s 0 <file>
# See guard/README.md "Tune the deny rules" for copy-paste snippets.

# --- Default: allow ----------------------------------------------------------
exit 0
