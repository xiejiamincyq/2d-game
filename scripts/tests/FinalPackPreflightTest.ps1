# Execute the actual package preflight, without export or an engine process.
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$gatePath = Join-Path $PSScriptRoot 'verify_rift_observer_actions_pack.ps1'
$source = Get-Content -LiteralPath $gatePath -Raw
$boundary = 'New-Item -ItemType Directory -Path $evidenceRoot | Out-Null'
if(([regex]::Matches($source,[regex]::Escape($boundary))).Count -ne 1) { throw 'Unique pre-export boundary missing' }
# ScriptBlock.Create has no script filename; supply only those two automatic
# variables, leaving the actual preflight statements and parameters unchanged.
$header = $source.Substring(0,$source.IndexOf($boundary)).Replace('$PSScriptRoot',("'"+$PSScriptRoot.Replace("'","''")+"'")).Replace('$PSCommandPath',("'"+$gatePath.Replace("'","''")+"'"))
$preflight = [scriptblock]::Create($header)
$identifier = 'pack-preflight-'+[guid]::NewGuid().ToString('N')
$relativeRoot = 'build/diagnostics/campaign-goal/'+$identifier
$ownedRoot = Join-Path $projectRoot $relativeRoot
New-Item -ItemType Directory -Path $ownedRoot | Out-Null
$bank = @{}
foreach($root in @('scripts','scenes','assets/art/actors/native','assets/art/shaders')) {
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot $root) -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($projectRoot,$file.FullName).Replace('\','/')
        if($file.Extension -in @('.gd','.gdshader','.tscn','.tres','.uid') -and $relative -notmatch '/\.[^/]+/') { $bank[$relative] = (Get-FileHash -LiteralPath $file.FullName).Hash.ToLowerInvariant() }
    }
}
foreach($path in @('project.godot','export_presets.cfg','assets/audio/overdrive_bone_breaking.mp3','scripts/tests/run_tests.ps1','scripts/tests/run_campaign_chain.ps1','scripts/tests/check_campaign_chain_report.py')) { $bank[$path]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $path)).Hash.ToLowerInvariant() }
$themes = @{}
foreach($path in @('themes/CyberTheme.tres','themes/MintFarmTheme.tres')) { $themes[$path]=(Get-FileHash -LiteralPath (Join-Path $projectRoot $path)).Hash.ToLowerInvariant() }
$freezePath=$relativeRoot+'.json'
$gpuOriginal='build/diagnostics/campaign-goal/f7_final_rift_resource_gpu_v1/report.json'
$log='build/diagnostics/campaign-goal/f7-final-rift-resource-gpu-v1.log'
$gpu=Get-Content -LiteralPath (Join-Path $projectRoot $gpuOriginal) -Raw|ConvertFrom-Json
$receiptOriginal=Get-Content -LiteralPath (Join-Path $projectRoot 'build/diagnostics/campaign-goal/f7_final_rift_resource_gpu_v1/receipt.json') -Raw|ConvertFrom-Json
$checks=0
foreach($case in @('positive','boolean-exit','string-exit','missing-exit','string-passed','missing-source','wrong-theme')) {
    $gpuCase=ConvertFrom-Json (ConvertTo-Json $gpu -Depth 40)
    $receiptCase=ConvertFrom-Json (ConvertTo-Json $receiptOriginal)
    $freeze=[ordered]@{source_bank=$bank.Clone();supplemental_themes=$themes.Clone()}
    switch($case) {
        'boolean-exit' {$receiptCase.actual_exit=$false}
        'string-exit' {$receiptCase.actual_exit='0'}
        'missing-exit' {$receiptCase.PSObject.Properties.Remove('actual_exit')}
        'string-passed' {$gpuCase.passed='false'}
        'missing-source' {$freeze.source_bank.Remove('scripts/world/TerrainSweep.gd')}
        'wrong-theme' {$freeze.supplemental_themes.Remove('themes/CyberTheme.tres');$freeze.supplemental_themes['scripts/world/TerrainSweep.gd']=$bank['scripts/world/TerrainSweep.gd']}
    }
    $gpuPath=$relativeRoot+'/report.json'
    [IO.File]::WriteAllText((Join-Path $projectRoot $gpuPath),(ConvertTo-Json $gpuCase -Depth 40))
    # Capture files are real immutable originals copied by SHA, never fabricated.
    foreach($capture in $gpu.captures.PSObject.Properties) { Copy-Item -LiteralPath (Join-Path (Split-Path (Join-Path $projectRoot $gpuOriginal) -Parent) ($capture.Name+'.png')) -Destination (Join-Path $ownedRoot ($capture.Name+'.png')) }
    $receiptCase.report_path=$gpuPath
    $receiptCase.report_sha256=(Get-FileHash -LiteralPath (Join-Path $projectRoot $gpuPath)).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path $ownedRoot 'receipt.json'),(ConvertTo-Json $receiptCase))
    [IO.File]::WriteAllText((Join-Path $projectRoot $freezePath),(ConvertTo-Json $freeze -Depth 5))
    $rejected=$false
    try { & $preflight -EvidenceId ($identifier+'-never-export') -RiftActionsGpuReport $gpuPath -ResourceGpuLog $log -ResourceGpuReceipt ($relativeRoot+'/receipt.json') -SourceFreezeReport $freezePath } catch { $rejected=$true; Write-Output "PREFLIGHT REJECT: $case $($_.Exception.Message)" }
    $checks++
    if(($case -eq 'positive' -and $rejected) -or ($case -ne 'positive' -and -not $rejected)) { throw "Preflight contract failed: $case rejected=$rejected" }
    if(Test-Path -LiteralPath (Join-Path $projectRoot ($relativeRoot+'-never-export'))) { throw 'Preflight unexpectedly created export folder' }
}
Write-Output "TEST PASS: FinalPackPreflightTest $checks (preflight only; no export, engine or gameplay claim)"
exit 0
