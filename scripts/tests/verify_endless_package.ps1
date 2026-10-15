param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9_-]{2,80}$')][string]$CandidateId
)
$ErrorActionPreference='Stop'
$taskRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskEngine='C:/Users/21604/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe'
$taskCandidate=Join-Path $taskRoot ('build/playtest/'+$CandidateId)
$taskEvidence=Join-Path $taskRoot ('build/diagnostics/campaign-goal/'+$CandidateId)
$taskViews=Join-Path $taskRoot ('build/diagnostics/campaign-goal/'+$CandidateId+'-views')
foreach($path in @($taskCandidate,$taskEvidence,$taskViews)) { if(Test-Path -LiteralPath $path) { throw ('Refusing existing artifact/evidence: '+$path) } }
$taskForbidden='SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use'
function PhysicsArgs([int]$rate) { return @('--',('--ticks='+$rate)) }
foreach($rate in @(30,60,120)) {
    $argsCheck=@(PhysicsArgs $rate)
    if($argsCheck.Count -ne 2 -or $argsCheck[1] -cne ('--ticks='+$rate)) { throw 'Physics CLI argument contract failed' }
}
function SourceBank {
    $bank=[ordered]@{}
    foreach($dir in @('scripts','scenes','assets')) {
        foreach($file in Get-ChildItem -LiteralPath (Join-Path $taskRoot $dir) -Recurse -File | Sort-Object FullName) {
            $relative=[IO.Path]::GetRelativePath($taskRoot,$file.FullName).Replace('\','/')
            $bank[$relative]=(Get-FileHash -LiteralPath $file.FullName).Hash.ToLowerInvariant()
        }
    }
    foreach($relative in @('project.godot','export_presets.cfg')) { $bank[$relative]=(Get-FileHash -LiteralPath (Join-Path $taskRoot $relative)).Hash.ToLowerInvariant() }
    return $bank
}
$taskBank=SourceBank
New-Item -ItemType Directory -Path $taskCandidate,$taskEvidence | Out-Null
$taskExe=Join-Path $taskCandidate 'five-minute-overdrive.exe'
$taskPack=Join-Path $taskCandidate 'five-minute-overdrive.pck'
& $taskEngine --headless --audio-driver Dummy --path $taskRoot --export-release 'Windows Desktop' $taskExe *> (Join-Path $taskEvidence 'export.log')
$taskExit=$LASTEXITCODE
$taskText=Get-Content -LiteralPath (Join-Path $taskEvidence 'export.log') -Raw
if($taskExit -ne 0 -or $taskText -match $taskForbidden -or -not (Test-Path -LiteralPath $taskExe) -or -not (Test-Path -LiteralPath $taskPack)) { throw "Export failed exit=$taskExit" }
foreach($path in @('res://scripts/tests/','res://scripts/art/','res://assets/art/source/','res://docs/')) { if($taskText.Contains($path)) { throw ('Author source exported: '+$path) } }
if((Get-Item -LiteralPath $taskPack).Length -le 0 -or (Get-Item -LiteralPath $taskPack).Length -gt 30MB) { throw 'PCK size budget failed' }
$taskPackHash=(Get-FileHash -LiteralPath $taskPack).Hash.ToLowerInvariant()
$taskExeHash=(Get-FileHash -LiteralPath $taskExe).Hash.ToLowerInvariant()
$taskNames=@('CampaignLoopRulesTest','CampaignLoopIntegrationTest','CampaignLoopCapacityTest','CampaignSixChapterCarryFlowTest','CampaignCarrySettlementUITest','CampaignTerrainDestructionTest','CampaignTerrainProjectileTest','CampaignStepTrapIntegrationTest','CampaignStepTrapPhysicsTest','ProjectileFirstImpactTest','GrenadeTerrainTest','LaserTerrainTest','AoeTerrainTest','MobilityTerrainTest','EnemyTerrainAttackTest','ArchivePageWidthTest')
$taskRuns=@()
foreach($name in $taskNames) { $taskRuns+=@{name=$name;source='scripts/tests/'+$name+'.gd';marker=$name;extra=@()} }
foreach($rate in @(30,60,120)) { $taskRuns+=@{name='CampaignFirstBossSeedEmissionRegression_'+$rate;source='scripts/tests/CampaignFirstBossSeedEmissionRegression.gd';marker='CampaignFirstBossSeedEmissionRegression';extra=@(PhysicsArgs $rate)} }
$taskRuns+=@{name='VerifyEndlessPackedResources';source='scripts/art/VerifyEndlessPackedResources.gd';marker='VerifyEndlessPackedResources';extra=@()}
$taskRuns+=@{name='VerifyEndlessPackedViews';source='scripts/art/VerifyEndlessPackedViews.gd';marker='VerifyEndlessPackedViews';extra=@('--',$taskViews,$taskPackHash);gpu=$true}
Copy-Item -LiteralPath (Join-Path $taskRoot 'scripts/tests/TestSupport.gd') -Destination $taskEvidence
foreach($run in $taskRuns) {
    $target=Join-Path $taskEvidence ($run.name+'.gd')
    Copy-Item -LiteralPath (Join-Path $taskRoot $run.source) -Destination $target
    if((Get-FileHash -LiteralPath $target).Hash.ToLowerInvariant() -ne $taskBank[$run.source]) { throw ('External fixture differs: '+$run.name) }
}
$taskResults=@()
Push-Location $taskCandidate
try {
    foreach($run in $taskRuns) {
        $log=Join-Path $taskEvidence ($run.name+'.log')
        $engineArgs=@('--audio-driver','Dummy','--max-fps','120','--main-pack',$taskPack,'--script',(Join-Path $taskEvidence ($run.name+'.gd')),'--quit-after','18000')
        if(-not $run.gpu) { $engineArgs=@('--headless')+$engineArgs }
        $engineArgs+=$run.extra
        & $taskEngine @engineArgs *> $log
        $actualExit=$LASTEXITCODE; $output=Get-Content -LiteralPath $log -Raw
        $passes=[regex]::Matches($output,('(?m)^TEST PASS: '+[regex]::Escape($run.marker)+' ([1-9][0-9]*)\r?$'))
        if($actualExit -ne 0 -or $passes.Count -ne 1 -or $output -match $taskForbidden) { throw ('Actual PCK fixture failed: '+$run.name+' exit='+$actualExit+' log='+$log) }
        $taskResults+=@{name=$run.name;actual_exit=$actualExit;assertions=[int]$passes[0].Groups[1].Value;log_sha256=(Get-FileHash -LiteralPath $log).Hash.ToLowerInvariant();fixture_sha256=$taskBank[$run.source]}
        Write-Output ('ENDLESS PACKAGE SUITE PASS: '+$run.name+' '+$passes[0].Groups[1].Value+' exit='+$actualExit)
    }
    # Release startup is a distinct claim; release templates need not execute external scripts.
    & $taskExe --headless --audio-driver Dummy --quit-after 120 *> (Join-Path $taskEvidence 'exe-startup.log')
    $taskStartupExit=$LASTEXITCODE
    if($taskStartupExit -ne 0 -or (Get-Content -LiteralPath (Join-Path $taskEvidence 'exe-startup.log') -Raw) -match $taskForbidden) { throw ('Release EXE startup failed: '+$taskStartupExit) }
} finally { Pop-Location }
if((Get-FileHash -LiteralPath $taskPack).Hash.ToLowerInvariant() -ne $taskPackHash -or (Get-FileHash -LiteralPath $taskExe).Hash.ToLowerInvariant() -ne $taskExeHash) { throw 'Candidate bytes changed during verification' }
$taskAfter=SourceBank
if(($taskBank | ConvertTo-Json -Depth 5 -Compress) -cne ($taskAfter | ConvertTo-Json -Depth 5 -Compress)) { throw 'Source changed during package verification' }
$taskReport=[ordered]@{schema=1;passed=$true;exe=$taskExe;exe_sha256=$taskExeHash;pck=$taskPack;pck_sha256=$taskPackHash;pck_bytes=(Get-Item -LiteralPath $taskPack).Length;source_bank=$taskBank;results=$taskResults;exe_startup_actual_exit=$taskStartupExit;gpu_report=(Join-Path $taskViews 'report.json');scope='Same compiled PCK behavior via editor engine with external byte-exact fixtures; release EXE startup separately. Controlled GPU views require human/agent inspection; not natural victories, OS input or performance acceptance.'}
$taskReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $taskEvidence 'package-report.json') -Encoding utf8
Write-Output ('ENDLESS PACKAGE PASS: '+$taskResults.Count+' fixtures, EXE startup exit='+$taskStartupExit+', PCK SHA256='+$taskPackHash)
