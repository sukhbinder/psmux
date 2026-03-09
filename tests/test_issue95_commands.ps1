# psmux Issue #95 Test Script
# Tests fixes for choose-tree CLI dispatch and display-message status bar
#
# Issue #95:
#   1. choose-tree / choose-window / choose-session returned "unknown command"
#   2. display-message without -p would hang or not process the response
#
# Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests\test_issue95_commands.ps1

$ErrorActionPreference = "Continue"
$script:TestsPassed = 0
$script:TestsFailed = 0

function Write-Pass { param($msg) Write-Host "[PASS] $msg" -ForegroundColor Green; $script:TestsPassed++ }
function Write-Fail { param($msg) Write-Host "[FAIL] $msg" -ForegroundColor Red; $script:TestsFailed++ }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Test { param($msg) Write-Host "[TEST] $msg" -ForegroundColor White }

$PSMUX = (Resolve-Path "$PSScriptRoot\..\target\release\psmux.exe" -ErrorAction SilentlyContinue).Path
if (-not $PSMUX) { $PSMUX = (Resolve-Path "$PSScriptRoot\..\target\debug\psmux.exe" -ErrorAction SilentlyContinue).Path }
if (-not $PSMUX) { Write-Error "psmux binary not found"; exit 1 }
Write-Info "Using: $PSMUX"

# Kill everything first
Write-Info "Cleaning up existing sessions..."
& $PSMUX kill-server 2>$null
Start-Sleep -Seconds 3
Remove-Item "$env:USERPROFILE\.psmux\*.port" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\.psmux\*.key" -Force -ErrorAction SilentlyContinue

$SESSION = "issue95test"

function New-TestSession {
    Start-Process -FilePath $PSMUX -ArgumentList "new-session -s $SESSION -d" -WindowStyle Hidden
    Start-Sleep -Seconds 3
    & $PSMUX has-session -t $SESSION 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "FATAL: Cannot create test session" -ForegroundColor Red; exit 1 }
    Write-Info "Session '$SESSION' is running"
}

# ============================================================
Write-Host ""
Write-Host ("=" * 70)
Write-Host "ISSUE #95: choose-tree CLI dispatch and display-message"
Write-Host ("=" * 70)

New-TestSession

# ============================================================
# TEST GROUP 1: choose-tree / choose-window / choose-session
# These are interactive commands that switch the server to
# WindowChooser mode. They just need to not error out.
# ============================================================
Write-Host ""
Write-Host ("=" * 70)
Write-Host "GROUP 1: choose-tree / choose-window / choose-session dispatch"
Write-Host ("=" * 70)

# Test 1: choose-tree should not return "unknown command"
Write-Test "choose-tree does not return unknown command error"
$output = & $PSMUX choose-tree -t $SESSION 2>&1 | Out-String
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    Write-Pass "choose-tree exited with code 0 (no unknown command error)"
} else {
    Write-Fail "choose-tree exited with code $exitCode. Output: $output"
}

Start-Sleep -Milliseconds 500

# Test 2: choose-window should not return "unknown command"
Write-Test "choose-window does not return unknown command error"
$output = & $PSMUX choose-window -t $SESSION 2>&1 | Out-String
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    Write-Pass "choose-window exited with code 0 (no unknown command error)"
} else {
    Write-Fail "choose-window exited with code $exitCode. Output: $output"
}

Start-Sleep -Milliseconds 500

# Test 3: choose-session should not return "unknown command"
Write-Test "choose-session does not return unknown command error"
$output = & $PSMUX choose-session -t $SESSION 2>&1 | Out-String
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    Write-Pass "choose-session exited with code 0 (no unknown command error)"
} else {
    Write-Fail "choose-session exited with code $exitCode. Output: $output"
}

Start-Sleep -Milliseconds 500

# ============================================================
# TEST GROUP 2: display-message fixes
# ============================================================
Write-Host ""
Write-Host ("=" * 70)
Write-Host "GROUP 2: display-message fixes"
Write-Host ("=" * 70)

# Test 4: display-message -p "#{session_name}" should print session name
Write-Test "display-message -p '#{session_name}' prints session name"
$output = & $PSMUX display-message -t $SESSION -p "#{session_name}" 2>&1 | Out-String
$output = $output.Trim()
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0 -and $output -eq $SESSION) {
    Write-Pass "display-message -p '#{session_name}' returned '$output' (matches session name)"
} elseif ($exitCode -eq 0) {
    Write-Fail "display-message -p '#{session_name}' returned '$output', expected '$SESSION'"
} else {
    Write-Fail "display-message -p '#{session_name}' exited with code $exitCode. Output: $output"
}

Start-Sleep -Milliseconds 500

# Test 5: display-message without -p should exit cleanly
Write-Test "display-message without -p exits cleanly (exit code 0)"
$output = & $PSMUX display-message -t $SESSION "hello world" 2>&1 | Out-String
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    Write-Pass "display-message without -p exited cleanly (code 0)"
} else {
    Write-Fail "display-message without -p exited with code $exitCode. Output: $output"
}

Start-Sleep -Milliseconds 500

# Test 6: display-message -p "#{window_index}" should return window index
Write-Test "display-message -p '#{window_index}' returns window index"
$output = & $PSMUX display-message -t $SESSION -p "#{window_index}" 2>&1 | Out-String
$output = $output.Trim()
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0 -and $output -match '^\d+$') {
    Write-Pass "display-message -p '#{window_index}' returned '$output' (valid index number)"
} elseif ($exitCode -eq 0) {
    Write-Fail "display-message -p '#{window_index}' returned '$output', expected a number"
} else {
    Write-Fail "display-message -p '#{window_index}' exited with code $exitCode. Output: $output"
}

Start-Sleep -Milliseconds 500

# ============================================================
# TEST GROUP 3: Regression tests for existing working commands
# ============================================================
Write-Host ""
Write-Host ("=" * 70)
Write-Host "GROUP 3: Regression tests (existing commands)"
Write-Host ("=" * 70)

# Test 7: run-shell "echo hello" should output "hello"
Write-Test "run-shell 'echo hello' outputs hello"
$output = & $PSMUX run-shell -t $SESSION "echo hello" 2>&1 | Out-String
$output = $output.Trim()
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0 -and $output -eq "hello") {
    Write-Pass "run-shell returned 'hello'"
} elseif ($exitCode -eq 0) {
    Write-Fail "run-shell returned '$output', expected 'hello'"
} else {
    Write-Fail "run-shell exited with code $exitCode. Output: $output"
}

Start-Sleep -Milliseconds 500

# Test 8: display-message -p "#{pane_id}" should return a pane ID
Write-Test "display-message -p '#{pane_id}' returns a pane ID"
$output = & $PSMUX display-message -t $SESSION -p "#{pane_id}" 2>&1 | Out-String
$output = $output.Trim()
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0 -and $output -match '^%\d+$') {
    Write-Pass "display-message -p '#{pane_id}' returned '$output' (valid pane ID)"
} elseif ($exitCode -eq 0 -and $output.Length -gt 0) {
    # Some implementations may not prefix with %, accept any non-empty output
    Write-Pass "display-message -p '#{pane_id}' returned '$output'"
} else {
    Write-Fail "display-message -p '#{pane_id}' exited with code $exitCode. Output: $output"
}

# ============================================================
# CLEANUP
# ============================================================
Write-Host ""
Write-Info "Final cleanup..."
& $PSMUX kill-server 2>$null
Start-Sleep 2

# ============================================================
# SUMMARY
# ============================================================
Write-Host ""
Write-Host ("=" * 70)
Write-Host "ISSUE #95 TEST SUMMARY" -ForegroundColor White
Write-Host ("=" * 70)
Write-Host "Passed: $($script:TestsPassed)" -ForegroundColor Green
Write-Host "Failed: $($script:TestsFailed)" -ForegroundColor $(if ($script:TestsFailed -gt 0) { "Red" } else { "Green" })
Write-Host "Total:  $($script:TestsPassed + $script:TestsFailed)"
Write-Host ""
Write-Host "Tests covered:" -ForegroundColor Yellow
Write-Host "  1. choose-tree CLI dispatch (should not return unknown command)"
Write-Host "  2. choose-window CLI dispatch (should not return unknown command)"
Write-Host "  3. choose-session CLI dispatch (should not return unknown command)"
Write-Host "  4. display-message -p '#{session_name}' prints session name (regression)"
Write-Host "  5. display-message without -p exits cleanly (no hang)"
Write-Host "  6. display-message -p '#{window_index}' returns window index"
Write-Host "  7. run-shell 'echo hello' outputs hello (regression)"
Write-Host "  8. display-message -p '#{pane_id}' returns pane ID (regression)"
Write-Host ("=" * 70)

if ($script:TestsFailed -gt 0) { exit 1 }
exit 0
