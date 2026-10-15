# Serial natural-input journey: two rounds, real Bosses, real inheritance,
# real tent restore, fresh process per leg. Fixed 60Hz simulation is NOT FPS data.
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z_][A-Za-z0-9_]{0,49}$')][string]$EvidenceId,
    [ValidateRange(1,12)][int]$StartStage=1,
    [ValidateRange(1,12)][int]$StopAfterStage=12,
    [ValidateSet('alternating','supply','risk')][string]$RouteMode='alternating',
    [ValidateSet('second','all','none')][string]$ProfileMode='second'
)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskEvidence=Join-Path $taskRoot 'build/diagnostics/campaign-goal'
$taskEngine='C:/Users/21604/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe'
$taskPython='C:/ProgramData/miniconda3/python.exe'
$taskDrivers=@('VerifyNativePlayerChapter','VerifyFoundryChapterFlow','VerifySaltChapterFlow','VerifyArchiveChapterFlow','VerifyEchoChapterFlow','VerifyRiftChapterFlow')
$taskMarkers=@('VerifyNurseryChapterFlow','VerifyFoundryChapterFlow','VerifySaltChapterFlow','VerifyArchiveChapterFlow','VerifyEchoChapterFlow','VerifyRiftChapterFlow')
if($StartStage -gt $StopAfterStage) { throw 'StartStage must not exceed StopAfterStage' }
foreach($taskStage in $StartStage..$StopAfterStage) {
    $taskId=$EvidenceId+'_s'+$taskStage
    foreach($taskPath in @((Join-Path $taskEvidence $taskId),(Join-Path $taskEvidence ($taskId+'.stdout.log')),(Join-Path $taskEvidence ($taskId+'.stderr.log')))) {
        if(Test-Path -LiteralPath $taskPath) { throw ('Refusing existing evidence: '+$taskPath) }
    }
}
foreach($taskStage in $StartStage..$StopAfterStage) {
    $taskChapter=1+(($taskStage-1)%6)
    $taskLoop=1+[math]::Floor(($taskStage-1)/6)
    $taskId=$EvidenceId+'_s'+$taskStage
    $taskPrevious=if($taskStage -eq 1) {''} else {$EvidenceId+'_s'+($taskStage-1)}
    $taskParentArg=if($taskStage -eq 1) {'FRESH'} else {$taskPrevious}
    if($taskStage -gt 1 -and -not (Test-Path -LiteralPath (Join-Path $taskEvidence ($taskPrevious+'/exit-report.json')))) { throw 'Verified preceding natural leg required' }
    $taskRoute=if($RouteMode -eq 'alternating') {if($taskLoop -eq 1) {'supply'} else {'risk'}} else {$RouteMode}
    $taskRouteArg=if($taskChapter -gt 2) {$taskRoute+' '} else {''}
    $taskFolder=Join-Path $taskEvidence $taskId
    $taskStdout=Join-Path $taskEvidence ($taskId+'.stdout.log')
    $taskStderr=Join-Path $taskEvidence ($taskId+'.stderr.log')
    $taskProfile=$ProfileMode -eq 'all' -or ($ProfileMode -eq 'second' -and $taskLoop -gt 1)
    $taskClockArgs=if($taskProfile) {''} else {'--audio-driver Dummy --fixed-fps 60 '}
    $taskArguments=$taskClockArgs+'--max-fps 120 --path "'+$taskRoot+'" --script scripts/art/'+$taskDrivers[$taskChapter-1]+'.gd --quit-after 150000 -- '+$taskId+' '+$taskRouteArg+'journey_profile='+[int]$taskProfile+' journey_route='+$taskRoute+' journey='+$taskParentArg
    Write-Output ('ENDLESS LEG RUN: stage='+$taskStage+' loop='+$taskLoop+' chapter='+$taskChapter+' route='+$taskRoute+' real_profile='+$taskProfile)
    $taskProcess=Start-Process -FilePath $taskEngine -ArgumentList $taskArguments -WorkingDirectory $taskRoot -WindowStyle Hidden -RedirectStandardOutput $taskStdout -RedirectStandardError $taskStderr -PassThru
    $taskOwnedHandle=$taskProcess.Handle
    $taskObserved=[System.Collections.Generic.HashSet[long]]::new()
    [void]$taskObserved.Add($taskProcess.Id)
    $taskChildObserved=$false
    $taskDeadline=[DateTime]::UtcNow.AddMinutes(30)
    while(-not $taskProcess.WaitForExit(250)) {
        if(-not $taskChildObserved) {
            # The installed *_console.exe is a small wrapper. Accept its live
            # engine child only after observing the actual Windows parent link.
            foreach($taskChild in Get-CimInstance Win32_Process -Filter ('ParentProcessId='+$taskProcess.Id)) {
                if($taskChild.Name -ceq 'Godot_v4.7-stable_win64.exe' -and $taskChild.CommandLine.Contains($taskId)) {
                    [void]$taskObserved.Add($taskChild.ProcessId)
                    $taskChildObserved=$true
                    Write-Output ('ENDLESS LIVE ENGINE: launcher='+$taskProcess.Id+' engine='+$taskChild.ProcessId)
                }
            }
        }
        if([DateTime]::UtcNow -gt $taskDeadline) {
            $taskProcess.Kill()
            throw ('Owned engine process timed out, preserving evidence: '+$taskId)
        }
    }
    $taskProcess.WaitForExit()
    $taskExit=$taskProcess.ExitCode
    $taskText=[IO.File]::ReadAllText($taskStdout)+"`n"+[IO.File]::ReadAllText($taskStderr)
    if(-not (Test-Path -LiteralPath $taskFolder -PathType Container)) { throw ('No real driver evidence: '+$taskId+' exit='+$taskExit) }
    [IO.File]::WriteAllText((Join-Path $taskFolder 'driver.log'),$taskText,[Text.UTF8Encoding]::new($false))
    $taskPasses=[regex]::Matches($taskText,'(?m)^TEST PASS: '+$taskMarkers[$taskChapter-1]+' ([1-9][0-9]*)\r?$')
    if($taskExit -ne 0 -or $taskPasses.Count -ne 1 -or $taskText -match 'SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use') {
        throw ('Actual natural journey failed, do not advance: '+$taskId+' exit='+$taskExit)
    }
    $taskReportPath=Join-Path $taskFolder 'report.json'
    $taskReport=Get-Content -Raw -LiteralPath $taskReportPath | ConvertFrom-Json
    if(-not $taskObserved.Contains([long]$taskReport.endless.process_id)) { throw 'Reported engine was not observed as the owned launcher or its actual child' }
    & $taskPython (Join-Path $PSScriptRoot 'check_endless_campaign_report.py') --root $taskRoot --id $taskId --stage $taskStage --actual-exit $taskExit --process-id $taskReport.endless.process_id --parent $taskPrevious
    if($LASTEXITCODE -ne 0) { throw ('Independent journey file/state gate failed: '+$taskId) }
    if($taskReport.route -cne $taskRoute) { throw 'Actual selected route differs from requested route' }
    if($taskProfile -and ($null -eq $taskReport.performance -or $taskReport.performance.sampled -isnot [bool] -or -not $taskReport.performance.sampled)) { throw 'Requested actual profile was not sampled' }
    $taskReceipt=[ordered]@{schema=1;actual_exit=$taskExit;report_sha256=(Get-FileHash -LiteralPath $taskReportPath).Hash.ToLowerInvariant();log_sha256=(Get-FileHash -LiteralPath (Join-Path $taskFolder 'driver.log')).Hash.ToLowerInvariant();engine_process_id=$taskReport.endless.process_id;launcher_process_id=$taskProcess.Id;observed_engine_process_ids=@($taskObserved)}
    [IO.File]::WriteAllText((Join-Path $taskFolder 'exit-report.json'),($taskReceipt | ConvertTo-Json),[Text.UTF8Encoding]::new($false))
    Write-Output ('ENDLESS LEG ACCEPTED: stage='+$taskStage+' actual_exit='+$taskExit+' coins='+$taskReport.endless.saved_state.coins)
}
if($StopAfterStage -eq 12) {
    # Check EVERY leg again against its immutable parent and current source bank.
    foreach($taskStage in 1..12) {
        $taskId=$EvidenceId+'_s'+$taskStage
        $taskFolder=Join-Path $taskEvidence $taskId
        $taskReceipt=Get-Content -Raw -LiteralPath (Join-Path $taskFolder 'exit-report.json') | ConvertFrom-Json
        $taskPrevious=if($taskStage -eq 1) {''} else {$EvidenceId+'_s'+($taskStage-1)}
        if($taskReceipt.actual_exit -isnot [long] -and $taskReceipt.actual_exit -isnot [int]) { throw 'Numeric actual exit required' }
        if($taskReceipt.actual_exit -ne 0 -or $taskReceipt.report_sha256 -cne (Get-FileHash -LiteralPath (Join-Path $taskFolder 'report.json')).Hash.ToLowerInvariant() -or $taskReceipt.log_sha256 -cne (Get-FileHash -LiteralPath (Join-Path $taskFolder 'driver.log')).Hash.ToLowerInvariant()) { throw 'Final leg receipt drift' }
        if(@($taskReceipt.observed_engine_process_ids) -notcontains $taskReceipt.engine_process_id -or @($taskReceipt.observed_engine_process_ids) -notcontains $taskReceipt.launcher_process_id) { throw 'Owned process provenance missing' }
        & $taskPython (Join-Path $PSScriptRoot 'check_endless_campaign_report.py') --root $taskRoot --id $taskId --stage $taskStage --actual-exit 0 --process-id $taskReceipt.engine_process_id --parent $taskPrevious
        if($LASTEXITCODE -ne 0) { throw 'Final 12-leg journey gate failed' }
    }
    Write-Output 'TEST PASS: EndlessCampaignNaturalChain 12'
} else {
    Write-Output ('ENDLESS PARTIAL: stages '+$StartStage+'..'+$StopAfterStage+' verified, NOT two full rounds')
}
