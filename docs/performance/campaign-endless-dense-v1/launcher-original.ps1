param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z_][A-Za-z0-9_]{0,49}$')][string]$EvidencePrefix,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z_][A-Za-z0-9_]{0,49}$')][string]$ParentPrefix
)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskEvidence=Join-Path $taskRoot 'build/diagnostics/campaign-goal'
$taskEngine='C:/Users/21604/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe'
$taskPython='C:/ProgramData/miniconda3/python.exe'
$taskFixtureRoot='docs/performance/campaign-endless-dense-v1/'
$taskCases=@(@{chapter=1;stage=7;probe='ProbeNursery';marker='VerifyNurseryChapterFlow'},@{chapter=2;stage=8;probe='ProbeFoundry';marker='VerifyFoundryChapterFlow'},@{chapter=5;stage=11;probe='ProbeEcho';marker='VerifyEchoChapterFlow'})
foreach($case in $taskCases) {
    $id=$EvidencePrefix+'_c'+$case.chapter
    foreach($path in @((Join-Path $taskEvidence $id),(Join-Path $taskEvidence ($id+'.stdout.log')),(Join-Path $taskEvidence ($id+'.stderr.log')))) {
        if(Test-Path -LiteralPath $path) {throw ('Refusing existing supplementary evidence: '+$path)}
    }
    if(-not (Test-Path -LiteralPath (Join-Path $taskEvidence ($ParentPrefix+'_s'+($case.stage-1)+'/exit-report.json')))) {throw 'Accepted actual predecessor required'}
}
foreach($case in $taskCases) {
    if(@(Get-CimInstance Win32_Process -Filter "Name='Godot_v4.7-stable_win64.exe'").Count) {throw 'Another Godot engine would contaminate the real profile'}
    $id=$EvidencePrefix+'_c'+$case.chapter
    $parent=$ParentPrefix+'_s'+($case.stage-1)
    $folder=Join-Path $taskEvidence $id
    $stdout=Join-Path $taskEvidence ($id+'.stdout.log'); $stderr=Join-Path $taskEvidence ($id+'.stderr.log')
    $fixture=$taskFixtureRoot+$case.probe+'.gd'
    $bank=[ordered]@{}
    foreach($path in @($fixture,($taskFixtureRoot+'DenseInputGate.gd'),'scripts/tests/run_endless_dense_probes.ps1')) { $bank[$path]=(Get-FileHash -LiteralPath (Join-Path $taskRoot $path)).Hash.ToLowerInvariant() }
    $routeArg=if($case.chapter -gt 2) {'risk '} else {''}
    $arguments='--max-fps 120 --path "'+$taskRoot+'" --script "res://'+$fixture+'" --quit-after 150000 -- '+$id+' '+$routeArg+'journey_profile=1 journey_route=risk journey='+$parent
    Write-Output ('DENSE SUPPLEMENT RUN: chapter='+$case.chapter+' actual_parent='+$parent+'; NOT part of the 12-leg chain')
    $process=Start-Process -FilePath $taskEngine -ArgumentList $arguments -WorkingDirectory $taskRoot -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    $ownedHandle=$process.Handle
    $observed=[System.Collections.Generic.HashSet[long]]::new(); [void]$observed.Add($process.Id)
    $childSeen=$false; $deadline=[DateTime]::UtcNow.AddMinutes(30)
    while(-not $process.WaitForExit(250)) {
        if(-not $childSeen) {
            foreach($child in Get-CimInstance Win32_Process -Filter ('ParentProcessId='+$process.Id)) {
                if($child.Name -ceq 'Godot_v4.7-stable_win64.exe' -and $child.CommandLine.Contains($id)) {
                    [void]$observed.Add($child.ProcessId); $childSeen=$true
                    Write-Output ('DENSE LIVE ENGINE: launcher='+$process.Id+' engine='+$child.ProcessId)
                }
            }
        }
        if([DateTime]::UtcNow -gt $deadline) { $process.Kill(); throw ('Owned supplement timed out: '+$id) }
    }
    $process.WaitForExit(); $actualExit=$process.ExitCode
    $text=[IO.File]::ReadAllText($stdout)+"`n"+[IO.File]::ReadAllText($stderr)
    if(-not (Test-Path -LiteralPath $folder -PathType Container)) {throw ('No actual supplementary report: '+$id)}
    [IO.File]::WriteAllText((Join-Path $folder 'driver.log'),$text,[Text.UTF8Encoding]::new($false))
    $passes=[regex]::Matches($text,'(?m)^TEST PASS: '+$case.marker+' ([1-9][0-9]*)\r?$')
    if($actualExit -ne 0 -or $passes.Count -ne 1 -or $text -match 'SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use') {throw ('Actual supplement failed: '+$id+' exit='+$actualExit)}
    $reportPath=Join-Path $folder 'report.json'
    $report=Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if(-not $observed.Contains([long]$report.endless.process_id)) {throw 'Unobserved engine identity'}
    & $taskPython (Join-Path $PSScriptRoot 'check_endless_campaign_report.py') --root $taskRoot --id $id --stage $case.stage --actual-exit $actualExit --process-id $report.endless.process_id --parent $parent
    if($LASTEXITCODE -ne 0) {throw ('Independent supplementary file/state gate failed: '+$id)}
    if($report.performance.dense_coverage_available -isnot [bool] -or -not $report.performance.dense_coverage_available -or $report.dense_input_probe.completed -isnot [bool] -or -not $report.dense_input_probe.completed -or $report.dense_input_probe.held_seconds -lt 10 -or $report.dense_input_probe.suppressed_physics_ticks -lt 300) {throw ('Supplement did not actually cover the planned input-only load: '+$id)}
    foreach($path in $bank.Keys) {
        if((Get-FileHash -LiteralPath (Join-Path $taskRoot $path)).Hash.ToLowerInvariant() -cne $bank[$path]) {throw ('Supplement fixture drift: '+$path)}
        if($path.EndsWith('.gd') -and $report.sources.$path -cne $bank[$path]) {throw ('Auxiliary source missing from real report: '+$path)}
    }
    $receipt=[ordered]@{schema=1;actual_exit=$actualExit;report_sha256=(Get-FileHash -LiteralPath $reportPath).Hash.ToLowerInvariant();log_sha256=(Get-FileHash -LiteralPath (Join-Path $folder 'driver.log')).Hash.ToLowerInvariant();engine_process_id=$report.endless.process_id;launcher_process_id=$process.Id;observed_engine_process_ids=@($observed);supplement_only=$true;auxiliary_source_bank=$bank}
    [IO.File]::WriteAllText((Join-Path $folder 'exit-report.json'),($receipt | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
    Write-Output ('DENSE SUPPLEMENT ACCEPTED: chapter='+$case.chapter+' dense_seconds='+$report.performance.longest_contiguous_dense_seconds+' actual_exit='+$actualExit)
}
Write-Output 'TEST PASS: EndlessDenseSupplements 3'
