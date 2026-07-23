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

$tests = @(
    "BalanceTest",
    "CombatEventTest",
    "CombatFeedbackTest",
    "DamageTest",
    "ProjectilePickupTest",
    "RateTest",
    "DashTest",
    "MovementTest",
    "WaveTest",
    "PortalTest",
	"Phase5CombatTest",
	"BossTest",
	"BossHealthBarTest",
	"BossTentacleTest",
	"BossPatternTest",
	"BossDirectorTest",
	"SnapshotTest",
	"ContinueTest",
    "OverdriveTest",
    "EnemyBehaviorTest",
    "UpgradeTest",
    "StateTest",
    "GateFailureTest",
    "UITest",
    "SettlementUITest",
    "PerformanceTest",
    "SmokeTest"
)
$totalAssertions = 0
$failures = [System.Collections.Generic.List[string]]::new()
$forbidden = "SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use"

foreach ($test in $tests) {
	$logPath = Join-Path ([System.IO.Path]::GetTempPath()) ("five-minute-overdrive-{0}-{1}.log" -f $test, [guid]::NewGuid().ToString("N"))
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $godot
    $startInfo.WorkingDirectory = $projectRoot
    # The Dummy driver prevents Windows audio playback handles from keeping a
    # finished headless child process alive after its pass marker is emitted.
	$startInfo.Arguments = "--headless --audio-driver Dummy --path . --log-file `"$logPath`" --script res://scripts/tests/$test.gd --quit-after 120"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    if (-not $process.WaitForExit(120000)) {
		# Process.Kill(Boolean) is unavailable in Windows PowerShell 5.1.
		$process.Kill()
        $failures.Add("${test}: timed out after 120 seconds")
		if (Test-Path -LiteralPath $logPath) {
			Remove-Item -LiteralPath $logPath -Force
		}
        continue
    }
	$output = ""
	if (Test-Path -LiteralPath $logPath) {
		$output = Get-Content -Raw -LiteralPath $logPath
		Remove-Item -LiteralPath $logPath -Force
	}
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

if ($failures.Count -gt 0) {
    Write-Host "`nTEST RUN FAILED ($($failures.Count) violations)" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "- $_" }
    exit 1
}

Write-Host "`nTEST RUN PASS: $($tests.Count) suites, $totalAssertions assertions" -ForegroundColor Green
exit 0
