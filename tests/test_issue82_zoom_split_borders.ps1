# psmux Issue #82 — Zoom: split should unzoom first, borders should be hidden
#
# Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests\test_issue82_zoom_split_borders.ps1

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

& $PSMUX kill-server 2>$null
Start-Sleep -Seconds 3
Remove-Item "$env:USERPROFILE\.psmux\*.port" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\.psmux\*.key" -Force -ErrorAction SilentlyContinue

$SESSION = "test_82"

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

function Get-PaneCount {
    param($session)
    $panes = & $PSMUX list-panes -t $session 2>&1
    return ($panes | Measure-Object -Line).Lines
}

function Get-ZoomFlag {
    param($session)
    $flag = & $PSMUX display-message -t $session -p '#{window_zoomed_flag}' 2>&1
    return ($flag | Out-String).Trim()
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
Write-Host "ISSUE #82: Zoom — split unzooms, borders hidden"
Write-Host ("=" * 60)
# ══════════════════════════════════════════════════════════════════════

# --- Test 1: Split while zoomed → unzooms first, 3 panes visible ---
Write-Test "1: Split while zoomed unzooms first (Repro 1)"
try {
    if (-not (New-TestSession $SESSION)) { throw "skip" }

    # Step 1: Create left/right split
    & $PSMUX split-window -h -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    $count1 = Get-PaneCount $SESSION
    Write-Info "  After first split: $count1 panes"

    # Step 2: Zoom the focused pane
    & $PSMUX resize-pane -Z -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500
    $zoomed = Get-ZoomFlag $SESSION
    Write-Info "  After zoom: zoomed=$zoomed"

    # Step 3: Split while zoomed
    & $PSMUX split-window -v -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 3

    # After split: should be unzoomed with 3 panes
    $zoomed2 = Get-ZoomFlag $SESSION
    $count2 = Get-PaneCount $SESSION
    Write-Info "  After split-while-zoomed: panes=$count2 zoomed=$zoomed2"

    if ($count2 -eq 3 -and $zoomed2 -eq "0") {
        Write-Pass "1: Split while zoomed → unzoomed, 3 panes visible"
    } elseif ($count2 -eq 3) {
        Write-Fail "1: 3 panes but still zoomed ($zoomed2)"
    } else {
        Write-Fail "1: Expected 3 panes unzoomed. Got panes=$count2 zoomed=$zoomed2"
    }
} catch {
    if ($_.ToString() -ne "skip") { Write-Fail "1: Exception: $_" }
} finally {
    Cleanup-Session $SESSION
}

# --- Test 2: Split-h while zoomed → 3 panes, unzoomed ---
Write-Test "2: Horizontal split while zoomed"
try {
    if (-not (New-TestSession $SESSION)) { throw "skip" }

    & $PSMUX split-window -v -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 3

    & $PSMUX resize-pane -Z -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500

    # Split horizontal while zoomed
    & $PSMUX split-window -h -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 3

    $zoomed = Get-ZoomFlag $SESSION
    $count = Get-PaneCount $SESSION

    if ($count -eq 3 -and $zoomed -eq "0") {
        Write-Pass "2: H-split while zoomed → unzoomed, 3 panes"
    } else {
        Write-Fail "2: Expected 3 panes unzoomed. Got panes=$count zoomed=$zoomed"
    }
} catch {
    if ($_.ToString() -ne "skip") { Write-Fail "2: Exception: $_" }
} finally {
    Cleanup-Session $SESSION
}

# --- Test 3: Zoom flag is correct ---
Write-Test "3: Zoom flag toggles correctly"
try {
    if (-not (New-TestSession $SESSION)) { throw "skip" }

    & $PSMUX split-window -h -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 3

    $before = Get-ZoomFlag $SESSION

    & $PSMUX resize-pane -Z -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500
    $during = Get-ZoomFlag $SESSION

    & $PSMUX resize-pane -Z -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500
    $after = Get-ZoomFlag $SESSION

    if ($before -eq "0" -and $during -eq "1" -and $after -eq "0") {
        Write-Pass "3: Zoom flag: off→on→off"
    } else {
        Write-Fail "3: Zoom flag: before=$before during=$during after=$after"
    }
} catch {
    if ($_.ToString() -ne "skip") { Write-Fail "3: Exception: $_" }
} finally {
    Cleanup-Session $SESSION
}

# --- Test 4: After unzoom from split, all panes accept input ---
Write-Test "4: All panes functional after split-while-zoomed"
try {
    if (-not (New-TestSession $SESSION)) { throw "skip" }

    & $PSMUX split-window -h -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 3

    & $PSMUX resize-pane -Z -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500

    & $PSMUX split-window -v -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 3

    # Should be unzoomed with 3 panes, send-keys to active
    & $PSMUX send-keys -t $SESSION 'Write-Output "ZOOM_SPLIT_OK"' Enter
    Start-Sleep -Seconds 2
    $cap = & $PSMUX capture-pane -t $SESSION -p 2>&1 | Out-String

    if ($cap -match "ZOOM_SPLIT_OK") {
        Write-Pass "4: Active pane functional after split-while-zoomed"
    } else {
        Write-Fail "4: Active pane not functional. Got:`n$cap"
    }
} catch {
    if ($_.ToString() -ne "skip") { Write-Fail "4: Exception: $_" }
} finally {
    Cleanup-Session $SESSION
}

# --- Test 5: Navigation after zoom+split works ---
Write-Test "5: Navigation works after zoom+split"
try {
    if (-not (New-TestSession $SESSION)) { throw "skip" }

    & $PSMUX split-window -h -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 3

    & $PSMUX resize-pane -Z -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500

    & $PSMUX split-window -v -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 3

    $p1 = (& $PSMUX display-message -t $SESSION -p '#{pane_id}' 2>&1 | Out-String).Trim()

    # Navigate left
    & $PSMUX select-pane -t $SESSION -L 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500
    $p2 = (& $PSMUX display-message -t $SESSION -p '#{pane_id}' 2>&1 | Out-String).Trim()

    if ($p1 -ne $p2) {
        Write-Pass "5: Navigation works after zoom+split ($p1 → $p2)"
    } else {
        Write-Fail "5: Navigation stuck at $p1"
    }
} catch {
    if ($_.ToString() -ne "skip") { Write-Fail "5: Exception: $_" }
} finally {
    Cleanup-Session $SESSION
}

# --- Test 6: Zoom with 4+ panes, split unzooms ---
Write-Test "6: 4-pane zoom+split → 5 panes, unzoomed"
try {
    if (-not (New-TestSession $SESSION)) { throw "skip" }

    # Create 4 panes
    & $PSMUX split-window -h -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    & $PSMUX split-window -v -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    & $PSMUX select-pane -t $SESSION -L 2>&1 | Out-Null
    Start-Sleep -Milliseconds 300
    & $PSMUX split-window -v -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 3

    $count1 = Get-PaneCount $SESSION
    Write-Info "  Before zoom: $count1 panes"

    # Zoom
    & $PSMUX resize-pane -Z -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Milliseconds 500

    # Split while zoomed
    & $PSMUX split-window -h -t $SESSION 2>&1 | Out-Null
    Start-Sleep -Seconds 3

    $zoomed = Get-ZoomFlag $SESSION
    $count2 = Get-PaneCount $SESSION

    if ($count2 -eq 5 -and $zoomed -eq "0") {
        Write-Pass "6: 4→5 panes after zoom+split, unzoomed"
    } else {
        Write-Fail "6: Expected 5 panes unzoomed. Got panes=$count2 zoomed=$zoomed"
    }
} catch {
    if ($_.ToString() -ne "skip") { Write-Fail "6: Exception: $_" }
} finally {
    Cleanup-Session $SESSION
}

# ══════════════════════════════════════════════════════════════════════
& $PSMUX kill-server 2>$null

Write-Host ""
Write-Host ("=" * 60)
$total = $script:TestsPassed + $script:TestsFailed
Write-Host "RESULTS: $($script:TestsPassed) passed, $($script:TestsFailed) failed, $($script:TestsSkipped) skipped (of $total run)" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ("=" * 60)

exit $script:TestsFailed
