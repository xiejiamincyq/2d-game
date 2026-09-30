# Pre-push verification for Wasteland Protocol.
#
# Implements the pre-push checks documented in docs/testing.md:
#   1. whitespace errors via git diff --check (worktree and staged),
#   2. SceneTree.paused ownership (only scripts/Main.gd may assign),
#   3. a secret scan over changes relative to HEAD,
#   4. the strict test suite (skippable with -SkipTests for docs-only changes).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/tests/prepush.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/tests/prepush.ps1 -SkipTests
#
# Exits 0 when every check passes, 1 otherwise.

param(
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$failures = [System.Collections.Generic.List[string]]::new()

# --- Check 1: whitespace errors -------------------------------------------
foreach ($scope in @(@("worktree", @("diff", "--check")), @("staged", @("diff", "--cached", "--check")))) {
    $scopeName = $scope[0]
    $scopeArgs = $scope[1]
    $output = (& git -C $projectRoot @scopeArgs | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $output.Length -gt 0) {
        $failures.Add("whitespace ($scopeName): $output")
    } else {
        Write-Host "CHECK PASS: whitespace ($scopeName)" -ForegroundColor Green
    }
}

# --- Check 2: SceneTree.paused ownership ---------------------------------
# Only scripts/Main.gd may assign get_tree().paused. String literals (such as
# the scanner inside StateTest.gd) are stripped before matching so the meta
# check does not flag itself.
$pausedPattern = 'get_tree\(\)\.paused\s*='
$pausedMatches = @()
$rg = Get-Command rg -ErrorAction SilentlyContinue
if ($null -ne $rg) {
    Push-Location $projectRoot
    $raw = & rg -n --no-heading $pausedPattern scripts -g '*.gd' 2>$null
    Pop-Location
    if ($LASTEXITCODE -eq 0) {
        $pausedMatches = @($raw)
    } elseif ($LASTEXITCODE -gt 1) {
        $failures.Add("paused check: rg failed with exit code $LASTEXITCODE")
    }
} else {
    $raw = & git -C $projectRoot grep -n -E $pausedPattern -- "scripts/*.gd" "scripts/*/*.gd"
    if ($LASTEXITCODE -eq 0) {
        $pausedMatches = @($raw)
    }
}
foreach ($match in $pausedMatches) {
    $parts = ("$match") -split ":", 3
    if ($parts.Count -lt 3) {
        continue
    }
    $path = $parts[0] -replace "\\", "/"
    $code = $parts[2] -replace '"[^"]*"', "" -replace "'[^']*'", ""
    if ($code -match $pausedPattern -and $path -ne "scripts/Main.gd") {
        $failures.Add("paused check: $path assigns SceneTree.paused; only scripts/Main.gd may do so")
    }
}
if (-not ($failures | Where-Object { $_ -like "paused check:*" })) {
    Write-Host "CHECK PASS: SceneTree.paused ownership" -ForegroundColor Green
}

# --- Check 3: secret scan ------------------------------------------------
# High-confidence credential shapes abort; loose key/value shapes only warn.
$diff = (& git -C $projectRoot diff HEAD -- | Out-String)
$secretPatterns = @(
    "-----BEGIN [A-Z ]*PRIVATE KEY-----",
    "\bAKIA[0-9A-Z]{16}\b",
    "\bgh[pousr]_[A-Za-z0-9]{36}\b",
    "\bgithub_pat_[A-Za-z0-9_]{22,}\b",
    "\bxox[baprs]-[A-Za-z0-9-]{10,}\b",
    "\bsk-[A-Za-z0-9_-]{20,}\b"
)
$secretHit = $false
foreach ($pattern in $secretPatterns) {
    if ($diff -match $pattern) {
        $failures.Add("secret scan: staged/unstaged changes match credential pattern '$pattern'")
        $secretHit = $true
    }
}
if (-not $secretHit) {
    Write-Host "CHECK PASS: secret scan" -ForegroundColor Green
}
if ($diff -match "(api[_-]?key|secret|password|token|credential)\s*[:=]") {
    Write-Host "CHECK WARN: changes contain key/value words (api_key, secret, password, token, credential); review before pushing" -ForegroundColor Yellow
}

# --- Check 4: strict test suite ------------------------------------------
if ($SkipTests) {
    Write-Host "CHECK SKIP: strict test suite (-SkipTests)" -ForegroundColor Yellow
} else {
    $runner = Join-Path $PSScriptRoot "run_tests.ps1"
    $hostExe = Get-Command powershell -ErrorAction SilentlyContinue
    if ($null -eq $hostExe) {
        $hostExe = Get-Command pwsh -ErrorAction SilentlyContinue
    }
    if ($null -eq $hostExe) {
        $failures.Add("strict test suite: neither powershell nor pwsh was found on PATH")
    } else {
        & $hostExe.Source -ExecutionPolicy Bypass -File $runner
        if ($LASTEXITCODE -ne 0) {
            $failures.Add("strict test suite: run_tests.ps1 exited with $LASTEXITCODE")
        }
    }
}

# --- Summary -------------------------------------------------------------
Write-Host ""
Write-Host "git status --short:" -ForegroundColor Cyan
& git -C $projectRoot status --short
Write-Host ""

if ($failures.Count -gt 0) {
    Write-Host "PRE-PUSH FAILED ($($failures.Count) violations)" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" }
    exit 1
}

Write-Host "PRE-PUSH PASS" -ForegroundColor Green
exit 0
