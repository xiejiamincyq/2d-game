# Independent native/combat/chapter fixtures; only owned isolated evidence saves.
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$EvidenceId,
    [Parameter(Mandatory=$true)][ValidatePattern('^build/diagnostics/campaign-goal/[A-Za-z0-9_-]+/report\.json$')][string]$RiftActionsGpuReport,
    [Parameter(Mandatory=$true)][ValidatePattern('^build/diagnostics/campaign-goal/[A-Za-z0-9_/-]+\.log$')][string]$ResourceGpuLog,
    [Parameter(Mandatory=$true)][ValidatePattern('^build/diagnostics/campaign-goal/[A-Za-z0-9_-]+/receipt\.json$')][string]$ResourceGpuReceipt,
    [Parameter(Mandatory=$true)][ValidatePattern('^build/diagnostics/campaign-goal/[A-Za-z0-9_-]+\.json$')][string]$SourceFreezeReport,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]*$')][string[]]$AdditionalSuites = @(),
    [ValidatePattern('^build/diagnostics/campaign-goal/[A-Za-z0-9_-]+/report\.json$')][string]$CombatGpuReport = '',
    [ValidateRange(10,64)][int]$ExpectedCombatCaptureCount = 10,
    [ValidatePattern('^build/diagnostics/campaign-goal/[A-Za-z0-9_-]+/report\.json$')][string[]]$ChapterFlowReports = @(),
    [ValidatePattern('^build/diagnostics/campaign-goal/[A-Za-z0-9_-]+/report\.json$')][string]$EntryGpuReport = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$engine = 'C:/Users/21604/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe'
$evidenceRoot = Join-Path $projectRoot ('build/diagnostics/campaign-goal/'+$EvidenceId)
if(Test-Path -LiteralPath $evidenceRoot) { throw 'Fresh evidence folder required' }
$forbidden = 'SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use'
$gpu = Get-Content -LiteralPath (Join-Path $projectRoot $RiftActionsGpuReport) -Raw | ConvertFrom-Json
$gpuLog = Get-Content -LiteralPath (Join-Path $projectRoot $ResourceGpuLog) -Raw
$gpuReceipt = Get-Content -LiteralPath (Join-Path $projectRoot $ResourceGpuReceipt) -Raw | ConvertFrom-Json
if($gpu -isnot [pscustomobject] -or $gpu.passed -isnot [bool] -or $gpu.passed -ne $true -or ($gpu.checks -isnot [int] -and $gpu.checks -isnot [long]) -or $gpu.checks -le 0 -or $gpu.sources -isnot [pscustomobject] -or $gpu.captures -isnot [pscustomobject]) { throw 'Measured GPU schema invalid' }
if($gpuReceipt -isnot [pscustomobject] -or ($gpuReceipt.actual_exit -isnot [int] -and $gpuReceipt.actual_exit -isnot [long]) -or $gpuReceipt.actual_exit -ne 0 -or $gpuReceipt.report_path -isnot [string] -or $gpuReceipt.log_path -isnot [string]) { throw 'Actual GPU exit receipt schema invalid' }
foreach($field in @('report_sha256','log_sha256','script_sha256')) { if($gpuReceipt.$field -isnot [string] -or $gpuReceipt.$field -cnotmatch '^[a-f0-9]{64}$') { throw ('GPU receipt SHA schema invalid: '+$field) } }
$gpuPasses = [regex]::Matches($gpuLog,'RIFT OBSERVER GPU PASS: ([0-9]+) checks/168 poses')
if(-not $gpu.passed -or $gpu.checks -le 0 -or @($gpu.sources.PSObject.Properties).Count -eq 0 -or $gpu.samples.Count -ne 168 -or $gpu.continuous_samples.Count -ne 90 -or $gpu.gameplay_scale_samples.Count -ne 3 -or $gpuPasses.Count -ne 1 -or [int]$gpuPasses[0].Groups[1].Value -ne $gpu.checks -or $gpuLog -match $forbidden) { throw 'Measured GPU prerequisite failed' }
if($gpuReceipt.actual_exit -ne 0 -or $gpuReceipt.report_path -ne $RiftActionsGpuReport -or $gpuReceipt.log_path -ne $ResourceGpuLog -or $gpuReceipt.report_sha256 -ne (Get-FileHash -LiteralPath (Join-Path $projectRoot $RiftActionsGpuReport)).Hash.ToLowerInvariant() -or $gpuReceipt.log_sha256 -ne (Get-FileHash -LiteralPath (Join-Path $projectRoot $ResourceGpuLog)).Hash.ToLowerInvariant() -or $gpuReceipt.script_sha256 -ne (Get-FileHash -LiteralPath (Join-Path $projectRoot 'scripts/art/RenderRiftObserverActions.gd')).Hash.ToLowerInvariant()) { throw 'Actual GPU exit receipt mismatch' }
$bank = @{}
$freeze = Get-Content -LiteralPath (Join-Path $projectRoot $SourceFreezeReport) -Raw | ConvertFrom-Json
if(@($freeze.source_bank.PSObject.Properties).Count -eq 0) { throw 'Complete fixed-root source freeze missing' }
# Same fixed roots/extensions and explicit files as CampaignChainEvidence.
$canonicalPaths = @()
foreach($root in @('scripts','scenes','assets/art/actors/native','assets/art/shaders')) {
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot $root) -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($projectRoot,$file.FullName).Replace('\','/')
        if($file.Extension -in @('.gd','.gdshader','.tscn','.tres','.uid') -and $relative -notmatch '/\.[^/]+/') { $canonicalPaths += $relative }
    }
}
foreach($path in @('project.godot','export_presets.cfg','assets/audio/overdrive_bone_breaking.mp3','scripts/tests/run_tests.ps1','scripts/tests/run_campaign_chain.ps1','scripts/tests/check_campaign_chain_report.py')) { if(Test-Path -LiteralPath (Join-Path $projectRoot $path)) { $canonicalPaths += $path } }
if(@(Compare-Object -ReferenceObject ($canonicalPaths|Sort-Object -Unique) -DifferenceObject @($freeze.source_bank.PSObject.Properties.Name|Sort-Object) -CaseSensitive).Count) { throw 'Canonical source freeze key set mismatch' }
if((@($freeze.supplemental_themes.PSObject.Properties.Name|Sort-Object) -join ',') -ne 'themes/CyberTheme.tres,themes/MintFarmTheme.tres') { throw 'Supplemental theme key set mismatch' }
foreach($group in @($freeze.source_bank,$freeze.supplemental_themes)) {
    foreach($pair in $group.PSObject.Properties) {
        $actual = (Get-FileHash -LiteralPath (Join-Path $projectRoot $pair.Name)).Hash.ToLowerInvariant()
        if($actual -ne $pair.Value) { throw ('Frozen source drift: '+$pair.Name) }
        $bank[$pair.Name] = $actual
    }
}
foreach($pair in $gpu.sources.PSObject.Properties) {
    $actual = (Get-FileHash -LiteralPath (Join-Path $projectRoot $pair.Name)).Hash.ToLowerInvariant()
    if($actual -ne $pair.Value) { throw ('GPU source drift: '+$pair.Name) }
    $bank[$pair.Name] = $actual
}
$captureNames = @($gpu.captures.PSObject.Properties.Name | Sort-Object)
if(($captureNames -join ',') -ne 'action-keyframes,action-poses,action-poses-left,gameplay-scale') { throw 'Resource GPU capture matrix missing' }
foreach($capture in $gpu.captures.PSObject.Properties) {
    $path = ((Split-Path $RiftActionsGpuReport -Parent)+'/'+$capture.Name+'.png') -replace '\\','/'
    if((Get-FileHash -LiteralPath (Join-Path $projectRoot $path)).Hash.ToLowerInvariant() -ne $capture.Value) { throw ('Resource GPU capture drift: '+$path) }
    $bank[$path] = $capture.Value
}
foreach($path in @($RiftActionsGpuReport,$ResourceGpuLog,$ResourceGpuReceipt,$SourceFreezeReport)) { $bank[$path] = (Get-FileHash -LiteralPath (Join-Path $projectRoot $path)).Hash.ToLowerInvariant() }
if($CombatGpuReport) {
    $combatGpu = Get-Content -LiteralPath (Join-Path $projectRoot $CombatGpuReport) -Raw | ConvertFrom-Json
    if(-not $combatGpu.passed -or $combatGpu.captures.Count -ne $ExpectedCombatCaptureCount) { throw 'Combat GPU prerequisite failed' }
    foreach($pair in $combatGpu.sources.PSObject.Properties) {
        $actual = (Get-FileHash -LiteralPath (Join-Path $projectRoot $pair.Name)).Hash.ToLowerInvariant()
        if($actual -ne $pair.Value) { throw ('Combat GPU source drift: '+$pair.Name) }
        $bank[$pair.Name] = $actual
    }
    foreach($capture in $combatGpu.captures) {
        $path = $capture.path.Substring(6)
        if((Get-FileHash -LiteralPath (Join-Path $projectRoot $path)).Hash.ToLowerInvariant() -ne $capture.sha256) { throw ('Combat GPU capture drift: '+$path) }
        $bank[$path] = $capture.sha256
    }
    $bank[$CombatGpuReport] = (Get-FileHash -LiteralPath (Join-Path $projectRoot $CombatGpuReport)).Hash.ToLowerInvariant()
}
$fixtures = @(
    @('scripts/art/VerifyRiftObserverPackedResources.gd','VerifyRiftObserverPackedResources'),
    @('scripts/tests/RiftObserverMotionContractTest.gd','RiftObserverMotionContractTest'),
    @('scripts/tests/NativeCharacterRosterTest.gd','NativeCharacterRosterTest')
)
if($AdditionalSuites -contains 'CampaignPrimaryEntryTest' -and -not $EntryGpuReport) { throw 'Formal entry pack requires current GPU proof' }
if($EntryGpuReport) {
    $entryGpu = Get-Content -LiteralPath (Join-Path $projectRoot $EntryGpuReport) -Raw | ConvertFrom-Json
    if(-not $entryGpu.passed -or $entryGpu.checks -le 0 -or $entryGpu.captures.Count -ne 15 -or $entryGpu.save_checks.Count -ne 3 -or ($entryGpu.save_checks.preseeded_clears -join ',') -ne '0,5,6') { throw 'Formal entry GPU prerequisite failed' }
    if((ConvertTo-Json $entryGpu.real_saves_before -Compress) -ne (ConvertTo-Json $entryGpu.real_saves_after -Compress)) { throw 'Formal entry changed real saves' }
    foreach($pair in $entryGpu.sources.PSObject.Properties) {
        $actual = (Get-FileHash -LiteralPath (Join-Path $projectRoot $pair.Name)).Hash.ToLowerInvariant()
        if($actual -ne $pair.Value) { throw ('Formal entry source drift: '+$pair.Name) }
        $bank[$pair.Name] = $actual
    }
    foreach($capture in $entryGpu.captures) {
        if((Get-FileHash -LiteralPath (Join-Path $projectRoot $capture.path)).Hash.ToLowerInvariant() -ne $capture.sha256) { throw ('Formal entry image drift: '+$capture.path) }
        $bank[$capture.path] = $capture.sha256
    }
    $bank[$EntryGpuReport] = (Get-FileHash -LiteralPath (Join-Path $projectRoot $EntryGpuReport)).Hash.ToLowerInvariant()
}
if($ChapterFlowReports.Count -gt 0) {
    if($ChapterFlowReports.Count -ne 2 -or @($ChapterFlowReports | Select-Object -Unique).Count -ne 2) { throw 'Two distinct ordinary sixth routes required' }
    $routes = @()
    foreach($reportPath in $ChapterFlowReports) {
        $flow = Get-Content -LiteralPath (Join-Path $projectRoot $reportPath) -Raw | ConvertFrom-Json
        if(-not $flow.valid -or $flow.chapter -ne 6 -or $flow.route -notin @('supply','risk') -or $flow.samples[-1].state -ne 'CLEARED' -or $flow.moves -le 500 -or $flow.shots -le 50 -or $flow.pointer_checks -le 500 -or $flow.samples[-1].kills -lt $flow.expected_actual_kills) { throw 'Ordinary sixth route prerequisite failed' }
        foreach($action in @('beam','probes','refract')) { if(-not $flow.boss_actions.$action) { throw ('Missing real ordinary Boss action: '+$action) } }
        foreach($phase in @('1','2','3')) { if(-not $flow.boss_phases.$phase) { throw ('Missing real ordinary Boss phase: '+$phase) } }
        foreach($pair in $flow.sources.PSObject.Properties) {
            $actual = (Get-FileHash -LiteralPath (Join-Path $projectRoot $pair.Name)).Hash.ToLowerInvariant()
            if($actual -ne $pair.Value) { throw ('Ordinary flow source drift: '+$pair.Name) }
            $bank[$pair.Name] = $actual
        }
        foreach($capture in @($flow.samples)+@($flow.layout_samples)) {
            $path = $capture.file -replace '^res://',''
            if((Get-FileHash -LiteralPath (Join-Path $projectRoot $path)).Hash.ToLowerInvariant() -ne $capture.sha256) { throw ('Ordinary flow capture drift: '+$path) }
            $bank[$path] = $capture.sha256
        }
        $folder = Split-Path $reportPath -Parent
        $restorePath = ($folder+'/restore-report.json') -replace '\\','/'
        $restore = Get-Content -LiteralPath (Join-Path $projectRoot $restorePath) -Raw | ConvertFrom-Json
        $progressPath = ($folder+'/campaign.json') -replace '\\','/'
        if(-not $restore.passed -or $restore.checks -le 0 -or ($restore.state.cleared_chapters -join ',') -ne '1,2,3,4,5,6' -or ($restore.ready_chapters -join ',') -ne '1,2,3,4,5,6' -or (Get-FileHash -LiteralPath (Join-Path $projectRoot $progressPath)).Hash.ToLowerInvariant() -ne $restore.progress_sha256 -or (Get-FileHash -LiteralPath (Join-Path $projectRoot 'scripts/art/VerifyRiftCampaignRestore.gd')).Hash.ToLowerInvariant() -ne $restore.restore_source_sha256) { throw 'Fresh-process sixth restore prerequisite failed' }
        foreach($path in @($reportPath,$restorePath,$progressPath,'scripts/art/VerifyRiftCampaignRestore.gd')) { $bank[$path] = (Get-FileHash -LiteralPath (Join-Path $projectRoot $path)).Hash.ToLowerInvariant() }
        $routes += $flow.route
    }
    if(($routes | Sort-Object) -join ',' -ne 'risk,supply') { throw 'Ordinary sixth routes must cover supply and risk' }
}
if(@($AdditionalSuites | Where-Object { $_ -in @('RiftChapterTest','RiftChapterLaunchTest') }).Count -gt 0 -and $ChapterFlowReports.Count -ne 2) { throw 'Chapter pack requires both ordinary sixth routes' }
foreach($suite in @($AdditionalSuites | Select-Object -Unique)) { $fixtures += ,@(('scripts/tests/'+$suite+'.gd'),$suite) }
$supportPaths = @()
if($AdditionalSuites -contains 'BossCameraFramingTest') { $supportPaths += 'scripts/tests/TestSupport.gd' }
$relativeParents = @{
    'CombatFeedbackTest' = @('TestSupport')
    'ArenaRuntimeTest' = @('TestSupport')
    'CampaignPrimaryEntryTest' = @('TestSupport')
    'CampaignMenuIntegrationTest' = @('TestSupport')
    'CampaignChapterLaunchTest' = @('TestSupport')
    'CampaignProgressStoreTest' = @('fixtures/CampaignFailedCommitStore')
    'RiftChapterTest' = @('SaltChapterTest','TestSupport')
    'RiftChapterLaunchTest' = @('EchoChapterLaunchTest','TestSupport')
    'RiftEncounterPolicyTest' = @('EchoEncounterPolicyTest')
    'RiftEncounterTest' = @('EchoEncounterTest')
    'RiftEncounterRuntimeTest' = @('EchoEncounterRuntimeTest','EchoMovementTest')
}
foreach($suite in $AdditionalSuites) {
    if($relativeParents.ContainsKey($suite)) { foreach($parent in $relativeParents[$suite]) { $supportPaths += ('scripts/tests/'+$parent+'.gd') } }
}
$supportPaths = @($supportPaths | Select-Object -Unique)
foreach($path in @('scripts/actors/RiftObserverBoss.gd','scripts/components/RiftObserverAttackDirector.gd','scripts/components/RiftObserverBeam.gd','scripts/components/RiftObserverProbe.gd','scripts/components/RiftObserverCircleFlight.gd','scripts/components/RiftObserverFragment.gd','scripts/components/RiftObserverRefractVolley.gd','scripts/actors/OverseerBoss.gd','scripts/components/NativeProjectileOriginSafety.gd','scripts/world/TerrainSweep.gd','scripts/components/HealthComponent.gd','scripts/tests/run_tests.ps1')) {
    if(Test-Path -LiteralPath (Join-Path $projectRoot $path)) { $bank[$path] = (Get-FileHash -LiteralPath (Join-Path $projectRoot $path)).Hash.ToLowerInvariant() }
}
foreach($fixture in $fixtures) { $bank[$fixture[0]] = (Get-FileHash -LiteralPath (Join-Path $projectRoot $fixture[0])).Hash.ToLowerInvariant() }
foreach($path in $supportPaths) { $bank[$path] = (Get-FileHash -LiteralPath (Join-Path $projectRoot $path)).Hash.ToLowerInvariant() }
$bank['scripts/tests/verify_rift_observer_actions_pack.ps1'] = (Get-FileHash -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()
New-Item -ItemType Directory -Path $evidenceRoot | Out-Null
$pack = Join-Path $evidenceRoot 'game.pck'
$forbidden = 'SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use'
& $engine --headless --audio-driver Dummy --path $projectRoot --export-pack 'Windows Desktop' $pack *> (Join-Path $evidenceRoot 'export.log')
$exportExit = $LASTEXITCODE
$exportOutput = Get-Content -LiteralPath (Join-Path $evidenceRoot 'export.log') -Raw
if($exportExit -ne 0 -or $exportOutput -match $forbidden -or -not (Test-Path -LiteralPath $pack)) { throw "Export failed exit=$exportExit" }
foreach($excluded in @('res://scripts/tests/','res://scripts/art/','res://assets/art/source/','res://scenes/art/technical/','res://docs/')) {
    if($exportOutput.Contains($excluded)) { throw ('Author source exported: '+$excluded) }
}
$bytes = (Get-Item -LiteralPath $pack).Length
if($bytes -le 0 -or $bytes -gt 30MB) { throw ('Pack budget failed: '+$bytes) }
$packHash = (Get-FileHash -LiteralPath $pack).Hash
$assertions = 0
foreach($fixture in $fixtures) {
    $source = Join-Path $projectRoot $fixture[0]; $target = Join-Path $evidenceRoot ($fixture[1]+'.gd')
    Copy-Item -LiteralPath $source -Destination $target
    if((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $target).Hash) { throw ('Canonical fixture drift: '+$fixture[1]) }
}
foreach($path in $supportPaths) {
    $relativeTarget = if($path.StartsWith('scripts/tests/fixtures/')) { 'fixtures/'+(Split-Path $path -Leaf) } else { Split-Path $path -Leaf }
    $source = Join-Path $projectRoot $path; $target = Join-Path $evidenceRoot $relativeTarget
    if(-not (Test-Path -LiteralPath (Split-Path $target -Parent))) { New-Item -ItemType Directory -Path (Split-Path $target -Parent) | Out-Null }
    Copy-Item -LiteralPath $source -Destination $target
    if((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $target).Hash) { throw ('Canonical support drift: '+$path) }
}
Push-Location $evidenceRoot
try {
    foreach($fixture in $fixtures) {
        $name = $fixture[1]; $log = Join-Path $evidenceRoot ($name+'.log')
        $frames = if($name -in @('RiftObserverBeamDodgeTest','RiftObserverProbeDodgeTest','RiftObserverRefractDodgeTest','RiftObserverRuntimeTest')) { 12000 } elseif($name -in @('RiftObserverCircleFlightTest','RiftObserverFragmentTest','RiftObserverRefractAttackTest','RiftObserverBeamClockTest','RiftObserverProbeTest','RiftObserverProbeBoundaryTest','RiftObserverProbeOriginBoundaryTest','RiftObserverProbeAttackTest','RiftObserverAutomaticCycleTest','RiftObserverLifecycleTest','RiftObserverIntegrationTest')) { 3000 } else { 1800 }
        if($name -in @('RiftChapterTest','RiftChapterLaunchTest','CampaignPrimaryEntryTest')) { $frames = 6000 }
        if($name -eq 'RiftEncounterTest') { $frames = 5000 }
        if($name -eq 'RiftEncounterRuntimeTest') { $frames = 8000 }
        & $engine --headless --audio-driver Dummy --max-fps 120 --main-pack $pack --script (Join-Path $evidenceRoot ($name+'.gd')) --quit-after $frames *> $log
        $actualExit = $LASTEXITCODE; $output = Get-Content -LiteralPath $log -Raw
        $passes = [regex]::Matches($output,('TEST PASS: '+[regex]::Escape($name)+' ([0-9]+)'))
        if($actualExit -ne 0 -or $passes.Count -ne 1 -or [int]$passes[0].Groups[1].Value -le 0 -or $output -match $forbidden) { throw "Pack fixture failed $name exit=$actualExit" }
        $assertions += [int]$passes[0].Groups[1].Value
        Write-Output "OBSERVER PACK SUITE PASS: $name $($passes[0].Groups[1].Value) exit=$actualExit"
    }
    & $engine --headless --audio-driver Dummy --main-pack $pack --quit-after 120 *> (Join-Path $evidenceRoot 'main.log')
    $mainExit = $LASTEXITCODE; $mainOutput = Get-Content -LiteralPath (Join-Path $evidenceRoot 'main.log') -Raw
    if($mainExit -ne 0 -or $mainOutput -match $forbidden) { throw "Pack Main failed exit=$mainExit" }
} finally { Pop-Location }
foreach($path in $bank.Keys) { if((Get-FileHash -LiteralPath (Join-Path $projectRoot $path)).Hash.ToLowerInvariant() -ne $bank[$path]) { throw ('Source changed during package: '+$path) } }
if((Get-FileHash -LiteralPath $pack).Hash -ne $packHash) { throw 'Pack changed during verification' }
Write-Output "OBSERVER ACTION PACK PASS: $($fixtures.Count) fixtures/$assertions assertions, Main120, $($bank.Count) unchanged sources, $bytes bytes, SHA256=$packHash"
