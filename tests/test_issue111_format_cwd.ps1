# psmux Issue #111 — #{pane_current_path} in split-window -c
#
# Tests that format variables like #{pane_current_path} are expanded
# when used in -c arguments to split-window and new-window.
#
# Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests\test_issue111_format_cwd.ps1

$ErrorActionPreference = "Continue"
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0

function Write-Pass { param($msg) Write-Host "[PASS] $msg" -ForegroundColor Green; $script:TestsPassed++ }
function Write-Fail { param($msg) Write-Host "[FAIL] $msg" -ForegroundColor Red; $script:TestsFailed++ }
function Write-Skip { param($msg) Write-Host "[SKIP] $msg" -ForegroundColor Yellow; $script:TestsSkipped++ }
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Test { param($msg) Write-Host "[TEST] $msg" -ForegroundColor White }

$PSMUX = (Resolve-Path "$PSScriptRoot\..\target\release\psmux.exe" -ErrorAction SilentlyContinue).Path
if (-not $PSMUX) { $PSMUX = (Resolve-Path "$PSScriptRoot\..\target\debug\psmux.exe" -ErrorAction SilentlyContinue).Path }
if (-not $PSMUX) { Write-Error "psmux binary not found"; exit 1 }
Write-Info "Using: $PSMUX"

# Clean slate
Write-Info "Cleaning up existing sessions..."
& $PSMUX kill-server 2>$null
Start-Sleep -Seconds 3
Remove-Item "$env:USERPROFILE\.psmux\*.port" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\.psmux\*.key" -Force -ErrorAction SilentlyContinue

$SESSION = "test_111"

function Wait-ForSession {
    param($name, $timeout = 10)
    for ($i = 0; $i -lt ($timeout * 2); $i++) {
        & $PSMUX has-session -t $name 2>$null
        if ($LASTEXITCODE -eq 0) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Cleanup-Session {
    param($name)
    & $PSMUX kill-session -t $name 2>$null
    Start-Sleep -Milliseconds 500
}

function Capture-Pane {
    param($target)
    $raw = & $PSMUX capture-pane -t $target -p 2>&1
    return ($raw | Out-String)
}

function New-TestSession {
    param($name)
    Start-Process -FilePath $PSMUX -ArgumentList "new-session -d -s $name" -WindowStyle Hidden
    if (-not (Wait-ForSession $name)) {
        Write-Fail "Could not create session $name"
        return $false
    }
    Start-Sleep -Seconds 3
    return $true
}

# ══════════════════════════════════════════════════════════════════════
Write-Host ""
Write-Host ("=" * 60)
Write-Host "ISSUE #111: #{pane_current_path} in split-window -c"
Write-Host ("=" * 60)
# ══════════════════════════════════════════════════════════════════════

# --- Test 1: split-window -h -c "#{pane_current_path}" preserves CWD ---
Write-Test "1: split-window -c #{pane_current_path} preserves CWD"
try {
    if (-not (New-TestSession $SESSION)) { throw "skip" }

    $testDir = Join-Path $env:TEMP "psmux_test_111_$(Get-Random)"
    New-Item -Path $testDir -ItemType Directory -Force | Out-Null

    # cd to testDir in the active pane
    & $PSMUX send-keys -t $SESSION "cd `"$testDir`"" Enter
    Start-Sleep -Seconds 2

    # Verify CWD changed
    & $PSMUX send-keys -t $SESSION 'Write-Output "CWD1=$($PWD.Path)"' Enter
    Start-Sleep -Seconds 2

    # Split with #{pane_current_path}
    & $PSMUX split-window -h -c '#{pane_current_path}' -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 4

    # Check CWD in the new pane
    & $PSMUX send-keys -t $SESSION 'Write-Output "NEWPANE_CWD=$($PWD.Path)"' Enter
    Start-Sleep -Seconds 2
    $cap = Capture-Pane $SESSION
    $capFlat = ($cap -replace "`r?`n", "")
    $dirName = Split-Path $testDir -Leaf

    if ($capFlat -match "NEWPANE_CWD=.*$([regex]::Escape($dirName))") {
        Write-Pass "1: split-window -c #{pane_current_path} preserved CWD"
    } else {
        Write-Fail "1: CWD not preserved. Expected '$dirName'. Got:`n$cap"
    }
} catch {
    if ($_.ToString() -ne "skip") { Write-Fail "1: Exception: $_" }
} finally {
    Cleanup-Session $SESSION
    Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Test 2: split-window -v -c "#{pane_current_path}" (vertical) ---
Write-Test "2: split-window -v -c #{pane_current_path} (vertical)"
try {
    if (-not (New-TestSession $SESSION)) { throw "skip" }

    $testDir = Join-Path $env:TEMP "psmux_test_111v_$(Get-Random)"
    New-Item -Path $testDir -ItemType Directory -Force | Out-Null

    & $PSMUX send-keys -t $SESSION "cd `"$testDir`"" Enter
    Start-Sleep -Seconds 2

    & $PSMUX split-window -v -c '#{pane_current_path}' -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 4

    & $PSMUX send-keys -t $SESSION 'Write-Output "VPANE=$($PWD.Path)"' Enter
    Start-Sleep -Seconds 2
    $cap = Capture-Pane $SESSION
    $capFlat = ($cap -replace "`r?`n", "")
    $dirName = Split-Path $testDir -Leaf

    if ($capFlat -match "VPANE=.*$([regex]::Escape($dirName))") {
        Write-Pass "2: split-window -v -c #{pane_current_path} preserved CWD"
    } else {
        Write-Fail "2: CWD not preserved. Got:`n$cap"
    }
} catch {
    if ($_.ToString() -ne "skip") { Write-Fail "2: Exception: $_" }
} finally {
    Cleanup-Session $SESSION
    Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Test 3: new-window -c "#{pane_current_path}" ---
Write-Test "3: new-window -c #{pane_current_path} preserves CWD"
try {
    if (-not (New-TestSession $SESSION)) { throw "skip" }

    $testDir = Join-Path $env:TEMP "psmux_test_111nw_$(Get-Random)"
    New-Item -Path $testDir -ItemType Directory -Force | Out-Null

    & $PSMUX send-keys -t $SESSION "cd `"$testDir`"" Enter
    Start-Sleep -Seconds 2

    & $PSMUX new-window -c '#{pane_current_path}' -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 4

    & $PSMUX send-keys -t $SESSION 'Write-Output "NWPANE=$($PWD.Path)"' Enter
    Start-Sleep -Seconds 2
    $cap = Capture-Pane $SESSION
    $capFlat = ($cap -replace "`r?`n", "")
    $dirName = Split-Path $testDir -Leaf

    if ($capFlat -match "NWPANE=.*$([regex]::Escape($dirName))") {
        Write-Pass "3: new-window -c #{pane_current_path} preserved CWD"
    } else {
        Write-Fail "3: CWD not preserved. Got:`n$cap"
    }
} catch {
    if ($_.ToString() -ne "skip") { Write-Fail "3: Exception: $_" }
} finally {
    Cleanup-Session $SESSION
    Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Test 4: bind-key with #{pane_current_path} via source-file ---
Write-Test "4: bind-key + split-window -c #{pane_current_path} via config"
try {
    if (-not (New-TestSession $SESSION)) { throw "skip" }

    $testDir = Join-Path $env:TEMP "psmux_test_111bind_$(Get-Random)"
    New-Item -Path $testDir -ItemType Directory -Force | Out-Null

    # Create a config that binds a key
    $configDir = Join-Path $env:TEMP "psmux_test_111_cfg_$(Get-Random)"
    New-Item -Path $configDir -ItemType Directory -Force | Out-Null
    $configFile = Join-Path $configDir ".psmux.conf"
    Set-Content -Path $configFile -Value 'bind-key V split-window -v -c "#{pane_current_path}"'

    & $PSMUX source-file -t $SESSION $configFile 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500

    # cd to test directory
    & $PSMUX send-keys -t $SESSION "cd `"$testDir`"" Enter
    Start-Sleep -Seconds 2

    # Use the bound key directly via command (simulates pressing prefix+V)
    & $PSMUX split-window -v -c '#{pane_current_path}' -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 4

    & $PSMUX send-keys -t $SESSION 'Write-Output "BINDPANE=$($PWD.Path)"' Enter
    Start-Sleep -Seconds 2
    $cap = Capture-Pane $SESSION
    $capFlat = ($cap -replace "`r?`n", "")
    $dirName = Split-Path $testDir -Leaf

    if ($capFlat -match "BINDPANE=.*$([regex]::Escape($dirName))") {
        Write-Pass "4: Config bind-key with #{pane_current_path} works"
    } else {
        Write-Fail "4: CWD not preserved. Got:`n$cap"
    }
} catch {
    if ($_.ToString() -ne "skip") { Write-Fail "4: Exception: $_" }
} finally {
    Cleanup-Session $SESSION
    Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item $configDir -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Test 5: Literal -c path still works (regression check) ---
Write-Test "5: Literal -c path still works (no format variable)"
try {
    if (-not (New-TestSession $SESSION)) { throw "skip" }

    $testDir = Join-Path $env:TEMP "psmux_test_111lit_$(Get-Random)"
    New-Item -Path $testDir -ItemType Directory -Force | Out-Null

    & $PSMUX split-window -h -c $testDir -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 4

    & $PSMUX send-keys -t $SESSION 'Write-Output "LITPANE=$($PWD.Path)"' Enter
    Start-Sleep -Seconds 2
    $cap = Capture-Pane $SESSION
    $capFlat = ($cap -replace "`r?`n", "")
    $dirName = Split-Path $testDir -Leaf

    if ($capFlat -match "LITPANE=.*$([regex]::Escape($dirName))") {
        Write-Pass "5: Literal -c path still works"
    } else {
        Write-Fail "5: Literal path broken. Got:`n$cap"
    }
} catch {
    if ($_.ToString() -ne "skip") { Write-Fail "5: Exception: $_" }
} finally {
    Cleanup-Session $SESSION
    Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Test 6: display-message #{pane_current_path} returns correct value ---
Write-Test "6: display-message resolves #{pane_current_path} correctly"
try {
    if (-not (New-TestSession $SESSION)) { throw "skip" }

    $testDir = Join-Path $env:TEMP "psmux_test_111dm_$(Get-Random)"
    New-Item -Path $testDir -ItemType Directory -Force | Out-Null

    & $PSMUX send-keys -t $SESSION "cd `"$testDir`"" Enter
    Start-Sleep -Seconds 2

    $result = & $PSMUX display-message -t $SESSION -p '#{pane_current_path}' 2>&1 | Out-String
    $result = $result.Trim()
    $dirName = Split-Path $testDir -Leaf

    if ($result -match [regex]::Escape($dirName)) {
        Write-Pass "6: display-message resolves #{pane_current_path} ($result)"
    } else {
        Write-Fail "6: display-message wrong. Expected '$dirName'. Got: $result"
    }
} catch {
    if ($_.ToString() -ne "skip") { Write-Fail "6: Exception: $_" }
} finally {
    Cleanup-Session $SESSION
    Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ══════════════════════════════════════════════════════════════════════
# Cleanup & summary
# ══════════════════════════════════════════════════════════════════════
& $PSMUX kill-server 2>$null

Write-Host ""
Write-Host ("=" * 60)
$total = $script:TestsPassed + $script:TestsFailed
Write-Host "RESULTS: $($script:TestsPassed) passed, $($script:TestsFailed) failed, $($script:TestsSkipped) skipped (of $total run)" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ("=" * 60)

exit $script:TestsFailed
