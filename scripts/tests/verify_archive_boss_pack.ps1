# Independent pack fixtures. Never touches the existing EXE or real campaign save.
param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9-]+$')][string]$EvidenceId,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]*$')][string[]]$AdditionalSuites = @(),
    [ValidatePattern('^[A-Za-z][A-Za-z0-9]*$')][string[]]$ExtraFixtures = @()
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$engine = 'C:/Users/21604/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe'
$evidenceRoot = Join-Path $projectRoot ('build/diagnostics/campaign-goal/'+$EvidenceId)
if(Test-Path -LiteralPath $evidenceRoot) { throw "Fresh evidence directory required: $evidenceRoot" }
New-Item -ItemType Directory -Path $evidenceRoot | Out-Null
$pack = Join-Path $evidenceRoot 'game.pck'
$forbidden = 'SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use'
& $engine --headless --audio-driver Dummy --path $projectRoot --export-pack 'Windows Desktop' $pack *> (Join-Path $evidenceRoot 'export.log')
$exportExit = $LASTEXITCODE
$exportOutput = Get-Content (Join-Path $evidenceRoot 'export.log') -Raw
if($exportExit -ne 0 -or $exportOutput -match $forbidden -or -not (Test-Path -LiteralPath $pack)) { throw "Pack export failed: $exportExit" }
foreach($excluded in @('res://scripts/tests/','res://scripts/art/','res://assets/art/source/','res://scenes/art/technical/')) {
    if($exportOutput.Contains($excluded)) { throw "Author-only content exported: $excluded" }
}
$bytes = (Get-Item -LiteralPath $pack).Length
if($bytes -le 0 -or $bytes -gt 30MB) { throw "Pack byte budget failed: $bytes" }
$hash = (Get-FileHash -LiteralPath $pack).Hash
$suites = @('ArchiveBossBroodTest','ArchiveBossCycleTest','ArchiveBossBroodBirthTest','ArchiveBossBroodLifecycleTest','ArchiveBossFailureCancellationTest','ArchiveBossVictoryCleanupTest','ArchiveEncounterPolicyTest','ArchiveEncounterTest','ArchivePageProjectileTest','ArchiveBossPageIntegrationTest','ArchiveBossPageLifecycleTest','ArchiveBossPageDodgeTest','ArchiveBossSealTest','ArchiveBossSealLifecycleTest','ArchiveBossSealDodgeTest','NativeCharacterRosterTest')
$suites = @($suites + $AdditionalSuites | Select-Object -Unique)
foreach($suite in @($suites + $ExtraFixtures | Select-Object -Unique)) {
    $source = Join-Path $PSScriptRoot ($suite+'.gd'); $target = Join-Path $evidenceRoot ($suite+'.gd')
    Copy-Item -LiteralPath $source -Destination $target
    if((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $target).Hash) { throw "Fixture source drift: $suite" }
}
$assertions = 0
Push-Location $evidenceRoot
try {
    foreach($suite in $suites) {
        $log = Join-Path $evidenceRoot ($suite+'.log')
        $frames = if($suite -in @('ArchivePageProjectileTest','ArchiveBossPageDodgeTest','ArchiveBossSealDodgeTest')) { 6000 } else { 1800 }
        if($suite -eq 'EchoMovementTest') { $frames = 12000 }
        if($suite -eq 'RiftMovementTest') { $frames = 12000 }
        if($suite -eq 'RiftFaultPhysicsTest') { $frames = 30000 }
        if($suite -eq 'RiftFieldPhysicsTest') { $frames = 18000 }
        if($suite -eq 'RiftEncounterTest') { $frames = 5000 }
        if($suite -eq 'RiftEncounterRuntimeTest') { $frames = 8000 }
        if($suite -eq 'EchoBeatPhysicsTest') { $frames = 16000 }
        if($suite -in @('EchoBeatEntitySeparationTest','EchoEncounterPolicyTest','EchoEncounterTest','EchoEncounterRuntimeTest','EchoBossEncounterTest','EchoChapterTest','EchoChapterLaunchTest')) { $frames = 6000 }
        if($suite -in @('BellPriestBellDodgeTest','BellPriestPendantDodgeTest','BellPriestCrownDodgeTest','BellPriestCrownPhase3DodgeTest')) { $frames = 12000 }
        # No --path: all production resources must come from this exact pack.
        & $engine --headless --audio-driver Dummy --max-fps 120 --main-pack $pack --script (Join-Path $evidenceRoot ($suite+'.gd')) --quit-after $frames *> $log
        $engineExit = $LASTEXITCODE; $output = Get-Content -LiteralPath $log -Raw
        $passMatches = [regex]::Matches($output,('TEST PASS: '+[regex]::Escape($suite)+' ([0-9]+)'))
        if($engineExit -ne 0 -or $passMatches.Count -ne 1 -or $output -match $forbidden) { throw "Pack fixture failed: $suite exit=$engineExit`n$output" }
        $assertions += [int]$passMatches[0].Groups[1].Value
        Write-Output "PACK SUITE PASS: $suite $($passMatches[0].Groups[1].Value)"
    }
    & $engine --headless --audio-driver Dummy --main-pack $pack --quit-after 120 *> (Join-Path $evidenceRoot 'main.log')
    $mainExit = $LASTEXITCODE; $mainOutput = Get-Content (Join-Path $evidenceRoot 'main.log') -Raw
    if($mainExit -ne 0 -or $mainOutput -match $forbidden) { throw "Pack Main failed: $mainExit`n$mainOutput" }
} finally { Pop-Location }
if((Get-FileHash -LiteralPath $pack).Hash -ne $hash) { throw 'Pack changed during verification' }
Write-Output "ARCHIVE PACK PASS: $($suites.Count) suites/$assertions assertions, Main120, $bytes bytes, SHA256=$hash"
