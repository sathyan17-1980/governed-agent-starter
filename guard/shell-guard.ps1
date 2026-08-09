#!/usr/bin/env pwsh
# shell-guard.ps1 — a pre-execution guardrail for AI coding agents (Layer 5).
#
# Wire this as a Claude Code `PreToolUse` hook (matcher: "Bash"). Before the
# agent's shell command runs, this script inspects it and BLOCKS the
# irreversible ones by returning exit 2 — *before* anything executes.
#
# HONEST CAVEAT — READ THIS:
#   This is an ACCIDENT SAFETY-NET, not a security boundary. It stops an
#   over-eager agent, not an adversary. It substring-matches command text, so it
#   can over-block (e.g. a commit message mentioning "rm -rf"), and indirection
#   ($env vars, aliases) is invisible to it. See guard/README.md "Known limits".
#
# Windows: PowerShell's default execution policy blocks unsigned local scripts.
# Invoke via:  pwsh -ExecutionPolicy Bypass -File C:\abs\path\shell-guard.ps1
#
# Hook contract (Claude Code):
#   stdin  -> JSON payload with .tool_input.command
#   exit 2 -> BLOCK the tool call; stderr is surfaced to the agent
#   exit 0 -> ALLOW
#
# Fail direction: FAIL-OPEN. A bug in the guard must not halt all your work, so
# unexpected failures allow. Flip to fail-closed by changing the catch block to
# `exit 2` if your risk profile calls for it.
#
# Parity note: this mirrors shell-guard.sh's intent with a real JSON parser
# (ConvertFrom-Json) and adds a Remove-Item rule. It is APPROXIMATE parity, not
# line-for-line identical — mirror any rule you add on both sides.

$ErrorActionPreference = 'Stop'

try {
    $raw = [Console]::In.ReadToEnd()

    $cmd = ''
    try { $cmd = ($raw | ConvertFrom-Json).tool_input.command } catch { $cmd = '' }
    if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

    function Block([string]$why) {
        [Console]::Error.WriteLine("BLOCKED by shell-guard: $why")
        [Console]::Error.WriteLine("Command: $cmd")
        [Console]::Error.WriteLine("If this was truly intended, run it yourself outside the agent.")
        exit 2
    }

    # 1. Delete / unlink an env / secret / key file
    if ($cmd -imatch '\b(rm|unlink|Remove-Item|ri|del)\b.*(\.env(\.[a-z0-9]+)?|secret|\.pem|id_rsa)') {
        Block 'attempt to delete an env/secret/key file'
    }

    # 2. Recursive force delete — rm with BOTH recursive and force, any order/form,
    #    OR PowerShell's Remove-Item -Recurse -Force.
    if ($cmd -imatch '\brm\b' -and
        $cmd -imatch '(-[rfvid]*r[rfvid]*\b|--recursive\b)' -and
        $cmd -imatch '(-[rfvid]*f[rfvid]*\b|--force\b)') {
        Block 'recursive force delete (rm -rf / -r -f / --recursive --force)'
    }
    if ($cmd -imatch '(Remove-Item|ri|rmdir|rd)\b' -and
        $cmd -imatch '-Rec' -and $cmd -imatch '-For') {
        Block 'Remove-Item -Recurse -Force'
    }

    # 3. Force-push (--force and --force-with-lease both blocked, intentionally)
    if ($cmd -imatch '\bgit\b.*\bpush\b.*(--force|--force-with-lease|\s-f\b)') {
        Block 'git force push'
    }

    # 4. Destructive git (hard reset / clean -f / discard working tree)
    if ($cmd -imatch '\bgit\b.*(reset\s+--hard|clean\s+-[a-z]*f|checkout\s+--\s|checkout\s+\.|restore\s+\.|stash\s+drop|branch\s+-D)') {
        Block 'destructive git (hard reset / clean -f / discard working tree)'
    }

    # 5. Piping the internet into a shell / interpreter
    if ($cmd -imatch '(curl|wget|iwr|Invoke-WebRequest)\b.*\|\s*(sudo\s+)?((ba|z)?sh|pwsh|powershell|python[0-9.]*|node|perl|ruby)\b') {
        Block 'download piped into a shell or interpreter'
    }

    # 6. Writing to a raw disk device
    if ($cmd -imatch '\bdd\b.*\sof=/dev/') {
        Block 'dd writing to a /dev/ device'
    }

    # 7. shred / secure-delete
    if ($cmd -imatch '\bshred\b') {
        Block 'shred (irreversible secure-delete)'
    }

    # 8. find ... -delete / -exec rm of env/secret files
    if ($cmd -imatch '\bfind\b.*(\.env|\.pem|id_rsa|secret).*(-delete\b|-exec\s+(rm|unlink)\b)') {
        Block 'find deleting env/secret files'
    }

    # 9. Redirect (>) overwriting an env/secret file (not >>)
    if ($cmd -imatch '(^|[^>])>\s*("?)([^\s"]*\.env\b|[^\s"]*\.pem\b|[^\s"]*id_rsa\b|[^\s"]*secret[^\s"]*)') {
        Block 'redirect overwriting an env/secret file'
    }

    # --- NOT covered by default: DB drops, chmod -R, truncate. Add your own.
    #     (Live-attendee companion ships a copy-paste cheat sheet for these.)

    exit 0
}
catch {
    # Fail-open: a bug in the guard must never halt all work.
    exit 0
}
