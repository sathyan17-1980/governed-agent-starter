#!/usr/bin/env pwsh
# shell-guard.ps1 — a pre-execution guardrail for AI coding agents (Layer 5).
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
#   stdin  -> JSON payload with .tool_input.command
#   exit 2 -> BLOCK the tool call; stderr is surfaced to the agent
#   exit 0 -> ALLOW
#
# Fail direction: FAIL-OPEN. A bug in the guard must not halt all your work,
# so unexpected failures allow. Flip to fail-closed by changing the catch
# block to `exit 2` if your risk profile calls for it.

$ErrorActionPreference = 'Stop'

try {
    $raw = [Console]::In.ReadToEnd()

    $cmd = ''
    try { $cmd = ($raw | ConvertFrom-Json).tool_input.command } catch { $cmd = '' }
    if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

    # Tune these deny rules to YOUR irreversible actions.
    $rules = @(
        @{ p = 'rm\b.*(\.env(\.[a-z0-9]+)?|secret|\.pem|id_rsa)';   why = 'attempt to delete an env/secret file' },
        @{ p = 'rm\b\s+-[a-z]*(rf|fr)[a-z]*\b';                      why = 'recursive force delete (rm -rf)' },
        @{ p = 'Remove-Item\b.*-Recurse.*-Force|Remove-Item\b.*-Force.*-Recurse'; why = 'Remove-Item -Recurse -Force' },
        @{ p = 'git\b.*\bpush\b.*(--force|--force-with-lease|\s-f\b)'; why = 'git force push' },
        @{ p = 'git\b.*(reset\s+--hard|clean\s+-[a-z]*f)';           why = 'destructive git (hard reset / clean -f)' },
        @{ p = '(curl|wget)\b.*\|\s*(sudo\s+)?(ba|z)?sh\b';          why = 'curl/wget piped into a shell' },
        @{ p = 'dd\b.*\sof=/dev/';                                   why = 'dd writing to a /dev/ device' }
    )

    foreach ($r in $rules) {
        if ($cmd -imatch $r.p) {
            [Console]::Error.WriteLine("BLOCKED by shell-guard: $($r.why)")
            [Console]::Error.WriteLine("Command: $cmd")
            [Console]::Error.WriteLine("If this was truly intended, run it yourself outside the agent.")
            exit 2
        }
    }

    exit 0
}
catch {
    # Fail-open: a bug in the guard must never halt all work.
    exit 0
}
