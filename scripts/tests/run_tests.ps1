# Strict test runner for Wasteland Protocol.
#   -Group all (default) : gameplay + art Godot suites and Python pipeline suites
#   -Group gameplay      : gameplay Godot suites only (fast iteration)
#   -Group art           : art Godot suites and Python pipeline suites
#   -Group python         : Python art-pipeline suites only
#   -SkipPython          : skip the Python art-pipeline suites in constrained environments

param(
    [ValidateSet("all", "gameplay", "art", "python")]
    [string]$Group = "all",
    [switch]$SkipPython
)

$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$winGetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
$godot = $env:GODOT_BIN

if ([string]::IsNullOrWhiteSpace($godot)) {
    $console = Get-ChildItem -Path $winGetRoot -Filter "Godot_v4.7-stable_win64_console.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $console) {
        $godot = $console.FullName
    }
}
if ([string]::IsNullOrWhiteSpace($godot) -or -not (Test-Path -LiteralPath $godot)) {
    throw "Godot 4.7 console executable was not found. Set GODOT_BIN to its full path."
}

$gameplayTests = @(
    "BalanceTest",
    "DamageTest",
    "ProjectilePickupTest",
    "RateTest",
    "DashTest",
    "WaveTest",
    "UpgradeTest",
    "StateTest",
    "UITest",
    "PerformanceTest",
    "SmokeTest"
)
$artTests = @(
    "EnemyDasherArtTest",
    "PlayerM2RuntimeAnimationTest",
    "PlayerCardinalPreviewTest",
    "PlayerTurnaroundModelTest",
    "PlayerTurnaroundMVPreviewTest",
    "PlayerWeaponModelPreviewTest",
    "PlayerGripPosePreviewTest",
    "PlayerGripRigTest",
    "PlayerGripRigPreviewTest",
    "PlayerMotionRigTest",
    "PlayerMotionRecoilPreviewTest",
    "PlayerMotionRefinementRigTest",
    "PlayerMotionRefinementPreviewTest",
    "PlayerMotionRefinementA2MultiYawTest",
    "PlayerProductionTopologyMaterialPreviewTest",
    "PlayerM2Ready120YawBakeTest",
    "PlayerM2RuntimeAnimationBakeTest",
    "PlayerDirectionalArtTest"
)

if ($Group -eq "gameplay") {
    $tests = $gameplayTests
} elseif ($Group -eq "art") {
    $tests = $artTests
} elseif ($Group -eq "python") {
    $tests = @()
} else {
    $tests = $gameplayTests + $artTests
}
$totalAssertions = 0
$failures = [System.Collections.Generic.List[string]]::new()
$forbidden = "SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use"

foreach ($test in $tests) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $godot
    $startInfo.WorkingDirectory = $projectRoot
    $startInfo.Arguments = "--headless --path . --script res://scripts/tests/$test.gd --quit-after 120"
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(120000)) {
        $process.Kill()
        $failures.Add("${test}: timed out after 120 seconds")
        continue
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $output = "$stdout`n$stderr"
    $matches = [regex]::Matches($output, "TEST PASS: $test ([1-9][0-9]*)")
    if ($process.ExitCode -ne 0) {
        $failures.Add("${test}: exited with $($process.ExitCode)")
    }
    if ($matches.Count -ne 1) {
        $failures.Add("${test}: expected one pass marker, found $($matches.Count)")
    } else {
        $totalAssertions += [int]$matches[0].Groups[1].Value
    }
    if ($output -match $forbidden) {
        $failures.Add("${test}: output contained a forbidden error or leak marker")
    }
    if ($failures | Where-Object { $_ -like "${test}:*" }) {
        Write-Host "===== $test FAILED =====" -ForegroundColor Red
        Write-Host $output
    } else {
        Write-Host "TEST SUITE PASS: $test" -ForegroundColor Green
    }
}

# --- Python art-pipeline suites ------------------------------------------
# Each scripts/tests/test_*.py plus validate_art_pipeline_skill.py runs in its
# own interpreter process, mirroring the per-suite Godot isolation. The
# unittest summary line is the equivalent of the Godot TEST PASS marker.
$pythonSuites = @()
$pythonTestCount = 0
if ($Group -ne "gameplay" -and -not $SkipPython) {
    $pythonExe = $null
    $pythonExeArgs = ""
    if (-not [string]::IsNullOrWhiteSpace($env:PYTHON_BIN)) {
        $pythonExe = $env:PYTHON_BIN
    } elseif ($null -ne (Get-Command python -ErrorAction SilentlyContinue)) {
        $pythonExe = "python"
    } elseif ($null -ne (Get-Command py -ErrorAction SilentlyContinue)) {
        $pythonExe = "py"
        $pythonExeArgs = "-3 "
    }
    if ($null -eq $pythonExe) {
        $failures.Add("python: no interpreter found; set PYTHON_BIN or install Python 3.10+")
    } else {
        $pythonSuites = @(Get-ChildItem -Path $PSScriptRoot -Filter "test_*.py" | Sort-Object Name | ForEach-Object { $_.FullName })
        $skillValidator = Join-Path $PSScriptRoot "validate_art_pipeline_skill.py"
        if (Test-Path -LiteralPath $skillValidator) {
            $pythonSuites += $skillValidator
        }
    }
    foreach ($suite in $pythonSuites) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($suite)
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $pythonExe
        $startInfo.Arguments = "$pythonExeArgs`"$suite`""
        $startInfo.WorkingDirectory = $projectRoot
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true
        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(120000)) {
            $process.Kill()
            $failures.Add("python ${name}: timed out after 120 seconds")
            continue
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        $output = "$stdout`n$stderr"
        $countMatches = [regex]::Matches($output, "Ran ([0-9]+) tests?")
        if ($process.ExitCode -ne 0) {
            $failures.Add("python ${name}: exited with $($process.ExitCode)")
        }
        if ($countMatches.Count -ne 1) {
            $failures.Add("python ${name}: expected one test-run summary, found $($countMatches.Count)")
        } elseif ([int]$countMatches[0].Groups[1].Value -lt 1) {
            $failures.Add("python ${name}: ran zero tests")
        }
        if ($output -match "(?m)^FAILED" -or $output -match "Traceback \(most recent call last\)") {
            $failures.Add("python ${name}: output contained a failure or a traceback")
        }
        if ($failures | Where-Object { $_ -like "python ${name}:*" }) {
            Write-Host "===== python $name FAILED =====" -ForegroundColor Red
            Write-Host $output
        } else {
            $pythonTestCount += [int]$countMatches[0].Groups[1].Value
            Write-Host "TEST SUITE PASS: $name (python, $($countMatches[0].Groups[1].Value) tests)" -ForegroundColor Green
        }
    }
} elseif ($SkipPython) {
    Write-Host "PYTHON SUITE SKIP: -SkipPython" -ForegroundColor Yellow
}

if ($failures.Count -gt 0) {
    Write-Host "`nTEST RUN FAILED ($($failures.Count) violations)" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" }
    exit 1
}

Write-Host "`nTEST RUN PASS: $($tests.Count) godot suites ($totalAssertions assertions), $($pythonSuites.Count) python suites ($pythonTestCount tests)" -ForegroundColor Green
exit 0
