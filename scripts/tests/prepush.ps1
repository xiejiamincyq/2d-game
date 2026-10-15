# Pre-push verification for Wasteland Protocol.
#
# Implements the pre-push checks documented in docs/testing.md:
#   1. whitespace errors via git diff --check (worktree and staged),
#   2. SceneTree.paused ownership (Main and shared ChapterRun only),
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
    # Exact-byte Godot resources intentionally retain CRLF. Keep all whitespace
    # guards while recognizing CR at EOL, rather than normalizing signed files.
    $output = (& git -C $projectRoot -c core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol @scopeArgs | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $output.Length -gt 0) {
        $failures.Add("whitespace ($scopeName): $output")
    } else {
        Write-Host "CHECK PASS: whitespace ($scopeName)" -ForegroundColor Green
    }
}

# --- Check 2: SceneTree.paused ownership ---------------------------------
$pauseOutput = & (Join-Path $PSScriptRoot 'check_pause_ownership.ps1') -ProjectRoot $projectRoot
if ($LASTEXITCODE -ne 0) { $failures.Add('paused check: '+($pauseOutput -join '; ')) }
else { $pauseOutput | ForEach-Object { Write-Host $_ -ForegroundColor Green } }

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
