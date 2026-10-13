# Actual serial GPU campaign chain. Generated receipts record actual exits;
# synthetic unit reports cannot substitute for this run or human playtesting.
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z_][A-Za-z0-9_]{0,59}$')][string]$EvidenceId,
    [ValidateSet('supply','risk')][string]$Route = 'supply'
)
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskEvidence = Join-Path $taskRoot 'build/diagnostics/campaign-goal'
$taskEngine = 'C:/Users/21604/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe'
$taskPython = 'C:/ProgramData/miniconda3/python.exe'
$taskDrivers = @('VerifyNativePlayerChapter','VerifyFoundryChapterFlow','VerifySaltChapterFlow','VerifyArchiveChapterFlow','VerifyEchoChapterFlow','VerifyRiftChapterFlow')
$taskMarkers = @('VerifyNurseryChapterFlow','VerifyFoundryChapterFlow','VerifySaltChapterFlow','VerifyArchiveChapterFlow','VerifyEchoChapterFlow','VerifyRiftChapterFlow')
$taskSummary = Join-Path $taskEvidence ($EvidenceId+'-chain-summary.json')
$taskBank = $null
$taskPrevious = ''
$taskReceipts = @()
if(-not (Test-Path -LiteralPath $taskEngine -PathType Leaf) -or -not (Test-Path -LiteralPath $taskPython -PathType Leaf)) { throw 'Configured local runtime unavailable; no fallback installation' }
if(Test-Path -LiteralPath $taskSummary) { throw 'Fresh chain summary required' }
# Refuse ALL six existing outputs up front; never overwrite failed evidence.
foreach($taskNumber in 1..6) {
    $taskIdentifier = $EvidenceId+'_s'+$taskNumber
    foreach($taskPath in @((Join-Path $taskEvidence $taskIdentifier),(Join-Path $taskEvidence ($taskIdentifier+'.stdout.log')),(Join-Path $taskEvidence ($taskIdentifier+'.stderr.log')))) {
        if(Test-Path -LiteralPath $taskPath) { throw 'Fresh six-stage evidence paths required' }
    }
}
foreach($taskNumber in 1..6) {
    $taskIdentifier = $EvidenceId+'_s'+$taskNumber
    $taskFolder = Join-Path $taskEvidence $taskIdentifier
    $taskStdout = Join-Path $taskEvidence ($taskIdentifier+'.stdout.log')
    $taskStderr = Join-Path $taskEvidence ($taskIdentifier+'.stderr.log')
    $taskParentArg = if($taskNumber -eq 1) {'FRESH'} else {$taskPrevious}
    $taskRouteArg = if($taskNumber -gt 2) {$Route+' '} else {''}
    $taskArguments = '--audio-driver Dummy --rendering-method gl_compatibility --rendering-driver opengl3 --max-fps 120 --path "'+$taskRoot+'" --script scripts/art/'+$taskDrivers[$taskNumber-1]+'.gd --quit-after 150000 -- '+$taskIdentifier+' '+$taskRouteArg+'chain='+$taskParentArg
    Write-Host ('CHAIN LEG RUN: chapter='+$taskNumber+' id='+$taskIdentifier)
    $taskProcess = Start-Process -FilePath $taskEngine -ArgumentList $taskArguments -WorkingDirectory $taskRoot -WindowStyle Hidden -RedirectStandardOutput $taskStdout -RedirectStandardError $taskStderr -PassThru
    $taskOwnedHandle = $taskProcess.Handle # Retain this owned process's exit handle.
    if(-not $taskProcess.WaitForExit(1800000)) {
        # This exact process was created here; never terminate unrelated editors.
        $taskProcess.Kill()
        throw ('Owned chapter process timed out: '+$taskIdentifier)
    }
    $taskProcess.WaitForExit()
    $taskExit = $taskProcess.ExitCode
    $taskText = [IO.File]::ReadAllText($taskStdout)+"`n"+[IO.File]::ReadAllText($taskStderr)
    if(-not (Test-Path -LiteralPath $taskFolder -PathType Container)) { throw ('Driver never created fresh evidence: '+$taskIdentifier+' exit='+$taskExit) }
    $taskLog = Join-Path $taskFolder 'driver.log'
    [IO.File]::WriteAllText($taskLog,$taskText,[Text.UTF8Encoding]::new($false))
    $taskPasses = [regex]::Matches($taskText,'(?m)^TEST PASS: '+$taskMarkers[$taskNumber-1]+' ([1-9][0-9]*)\r?$')
    if($taskExit -ne 0 -or $taskPasses.Count -ne 1 -or $taskText -match 'SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use') {
        throw ('Actual chapter failed; preserve evidence: '+$taskIdentifier+' exit='+$taskExit)
    }
    $taskReportPath = Join-Path $taskFolder 'report.json'
    $taskReport = Get-Content -LiteralPath $taskReportPath -Raw | ConvertFrom-Json
    if($taskBank) {
        $taskPairs = @($taskReport.chain.source_bank.PSObject.Properties)
        if($taskPairs.Count -ne $taskBank.Count) { throw 'Six-leg source bank membership drift' }
        foreach($taskPair in $taskPairs) { if($taskBank[$taskPair.Name] -cne $taskPair.Value) { throw ('Six-leg source drift: '+$taskPair.Name) } }
    } else {
        $taskBank = @{}
        foreach($taskPair in $taskReport.chain.source_bank.PSObject.Properties) { $taskBank[$taskPair.Name]=$taskPair.Value }
    }
    & $taskPython (Join-Path $PSScriptRoot 'check_campaign_chain_report.py') --root $taskRoot --id $taskIdentifier --chapter $taskNumber --actual-exit $taskExit --parent $taskPrevious
    if($LASTEXITCODE -ne 0) { throw ('Independent actual report/file gate failed: '+$taskIdentifier) }
    # Only after terminal, current source, ordinary save/return and parent checks.
    $taskReceipt = [ordered]@{schema=1;actual_exit=$taskExit;report_sha256=(Get-FileHash -LiteralPath $taskReportPath).Hash.ToLowerInvariant();log_sha256=(Get-FileHash -LiteralPath $taskLog).Hash.ToLowerInvariant();engine_process_id=$taskReport.chain.process_id;launcher_process_id=$taskProcess.Id}
    [IO.File]::WriteAllText((Join-Path $taskFolder 'exit-report.json'),($taskReceipt | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
    $taskReceipts += [ordered]@{chapter=$taskNumber;id=$taskIdentifier;assertions=$taskReport.assertions;moves=$taskReport.moves;shots=$taskReport.shots;receipt=$taskReceipt}
    $taskPrevious = $taskIdentifier
    Write-Host ('CHAIN LEG ACCEPTED: chapter='+$taskNumber+' actual_exit='+$taskExit)
}
[IO.File]::WriteAllText($taskSummary,([ordered]@{schema=1;valid=$true;scope='Actual fresh-save six-leg ordinary-input chain; not human playtest or multi-seed balance';route=$Route;legs=$taskReceipts;source_count=$taskBank.Count} | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
Write-Host 'TEST PASS: CampaignFreshChain 6'
