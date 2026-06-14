# Regression test: a session's first pane must come up even when psmux is slow
# to drain the pseudoconsole's startup cursor-position request.
#
# ROOT CAUSE: psmux created every ConPTY with PSEUDOCONSOLE_INHERIT_CURSOR.
# Per Microsoft's CreatePseudoConsole docs, that flag makes conhost emit an
# ESC[6n cursor-position request at startup and the host must answer it
# asynchronously on a background thread, or it "may cause the calling
# application to hang while making another request of the pseudoconsole
# system." psmux answered only from the server's main loop (not yet running
# when a session's first window is created), so under load the request went
# unanswered and the pane's child process hung during startup in
# ConsoleCreateConnectionObject -- a live pane that never ran. The fix removes
# the flag (a multiplexer pane renders into its own fresh screen, so cursor
# inheritance buys nothing); conhost then issues no startup request.
#
# DETERMINISTIC RED via reader-start latency injection: the pane's output-pipe
# reader sleeps PSMUX_TEST_READER_DELAY_MS before its first read. The reader is
# what drains conhost's startup ESC[6n; with INHERIT_CURSOR present conhost will
# not service the child's console connection until that request is read and
# answered, so the child stays blocked for the whole delay. Without the flag
# conhost issues no request, so the child connects and runs its command
# immediately while the reader harmlessly sleeps. The hook sits inside the reader
# thread, not create_window, so new-session -d returns promptly on both builds;
# the discriminator is TIME-TO-FIRST-OUTPUT, a liveness file the initial command
# writes:
#   - pre-fix : liveness file appears no earlier than ~PSMUX_TEST_READER_DELAY_MS
#               (child blocked on the unanswered cursor request).
#   - post-fix: liveness file appears promptly, well under the delay.
# Launched via Start-Process (not a background job) so the measured time is the
# pane's real liveness, not job spin-up. Removal recipe: when the
# PSMUX_TEST_READER_DELAY_MS hook is deleted from src/pane.rs, delete this test.

$ErrorActionPreference = "Stop"
# Prefer the local build under test; the injection hook exists only in
# debug_assertions builds, so do NOT fall back to a psmux on PATH (an installed
# release binary would make the injection a no-op and the test pass for free).
$PSMUX = $env:PSMUX_EXE
if (-not $PSMUX -or -not (Test-Path $PSMUX)) { $PSMUX = "$PSScriptRoot\..\target\debug\psmux.exe" }
if (-not (Test-Path $PSMUX)) { $PSMUX = "$PSScriptRoot\..\target\release\psmux.exe" }
if (-not (Test-Path $PSMUX)) { Write-Host "FATAL: could not resolve psmux ($PSMUX)" -ForegroundColor Red; exit 1 }
$PSMUX = (Resolve-Path -LiteralPath $PSMUX).Path   # absolute, so the straggler backstop's ExecutablePath match is reliable

$DELAY_MS = 10000                  # injected reader-start delay (reader thread sleeps this long)
$MAX_LIVENESS_MS = $DELAY_MS / 2   # post-fix the pane must come up well under the delay;
                                   # wide margin so a loaded machine's shell cold-start cannot cross it

# Isolate into a throwaway HOME so the run never touches the real ~/.psmux.
# Set in THIS process so the launched psmux inherits it AND cleanup below
# resolves the session inside the throwaway home. Each session is its own
# server; we tear it down by name (never a bare kill-server).
$tmpHome = Join-Path $env:TEMP ("psmux_cpr_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path (Join-Path $tmpHome ".psmux") -Force | Out-Null
$env:USERPROFILE = $tmpHome
$env:HOME = $tmpHome
$env:PSMUX_NO_WARM = "1"
$env:PSMUX_CONFIG_FILE = "NUL"
$env:PSMUX_TEST_READER_DELAY_MS = "$DELAY_MS"
foreach ($v in 'PSMUX_SESSION', 'PSMUX_TARGET_SESSION', 'PSMUX_NAMESPACE', 'TMUX', 'TMUX_PANE') {
    Remove-Item "Env:\$v" -ErrorAction SilentlyContinue
}
$session = "cpr_$($PID)_$(Get-Random -Maximum 99999)"
$liveFile = Join-Path $tmpHome "live.txt"

$pass = 0; $fail = 0
function Write-Result($name, $ok, $msg) {
    if ($ok) { Write-Host "  [PASS] $name" -ForegroundColor Green; $script:pass++ }
    else { Write-Host "  [FAIL] $name : $msg" -ForegroundColor Red; $script:fail++ }
}

Write-Host ""
Write-Host "=== first-pane startup must survive a slow ESC[6n drain ===" -ForegroundColor Cyan
Write-Host "  psmux  : $PSMUX" -ForegroundColor DarkGray
Write-Host "  home   : $tmpHome" -ForegroundColor DarkGray

try {
    # Launch new-session -d with an initial command that writes a liveness file,
    # then poll for that file to time when the pane's child actually ran. The hook
    # delays only the reader thread, so new-session returns promptly; Start-Process
    # (not Start-Job) keeps the measured time free of background-job spin-up.
    $cmd = "Set-Content -LiteralPath '$liveFile' -Value ok; Start-Sleep 30"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $p = Start-Process -FilePath $PSMUX `
            -ArgumentList @("new-session", "-d", "-s", $session, $cmd) `
            -PassThru -WindowStyle Hidden

    $fileMs = $null; $retMs = $null
    while ($sw.Elapsed.TotalMilliseconds -lt ($DELAY_MS + 4000)) {
        if (-not $retMs -and $p.HasExited) { $retMs = [int]$sw.Elapsed.TotalMilliseconds }
        if (Test-Path $liveFile) { $fileMs = [int]$sw.Elapsed.TotalMilliseconds; break }
        Start-Sleep -Milliseconds 25
    }
    if (-not $retMs -and $p.WaitForExit(3000)) { $retMs = [int]$sw.Elapsed.TotalMilliseconds }

    Write-Host ("  new-session returned: {0}" -f $(if ($retMs) { "${retMs}ms" } else { "?" })) -ForegroundColor DarkGray
    Write-Host ("  liveness file after : {0}" -f $(if ($null -ne $fileMs) { "${fileMs}ms" } else { "NEVER" })) -ForegroundColor DarkGray
    Write-Host ("  injected delay      : ${DELAY_MS}ms  (liveness threshold ${MAX_LIVENESS_MS}ms)") -ForegroundColor DarkGray

    # THE assertion: the pane's child ran well before the injected reader delay
    # would force it -- it connected to its console without waiting on the
    # (delayed) cursor-request drain, so INHERIT_CURSOR is gone. Pre-fix the child
    # stays blocked until the reader wakes at ~$DELAY_MS, so the liveness file
    # appears no earlier than the delay.
    Write-Result "first pane ran well before the injected reader delay (not blocked on the cursor request)" `
        (($null -ne $fileMs) -and ($fileMs -lt $MAX_LIVENESS_MS)) "liveness ${fileMs}ms >= ${MAX_LIVENESS_MS}ms (pane stayed blocked until the reader drained the cursor request)"
}
finally {
    & $PSMUX kill-session -t $session 2>&1 | Out-Null   # session-scoped; never a bare kill-server
    if ($p -and -not $p.HasExited) { try { $p.Kill() } catch {} }
    # Backstop: kill only a straggler that is BOTH this exact binary AND carries
    # our unique session name. Never an image-name kill.
    Get-CimInstance Win32_Process -Filter "Name='psmux.exe'" -EA SilentlyContinue |
        Where-Object { $_.ExecutablePath -eq $PSMUX -and $_.CommandLine -match $session } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -EA SilentlyContinue }
    Start-Sleep -Milliseconds 300
    Remove-Item -Recurse -Force $tmpHome -EA SilentlyContinue
}

Write-Host ""
Write-Host "  $pass passed, $fail failed" -ForegroundColor $(if ($fail -gt 0) { "Red" } else { "Green" })
exit $(if ($fail -gt 0) { 1 } else { 0 })
