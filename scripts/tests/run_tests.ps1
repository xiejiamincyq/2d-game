# Strict test runner for Wasteland Protocol.
#   -Group all (default) : gameplay + art Godot suites and Python pipeline suites
#   -Group gameplay      : gameplay Godot suites only (fast iteration)
#   -Group art           : art Godot suites and Python pipeline suites
#   -Group python        : Python art-pipeline suites only
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

$forbidden = "SCRIPT ERROR|ERROR:|TEST FAIL:|ObjectDB instances were leaked|RID.+leaked|resources still in use"
$importOutput = (& $godot --headless --path $projectRoot --import 2>&1 | Out-String)
$importExitCode = $LASTEXITCODE
if ($importExitCode -ne 0 -or $importOutput -match $forbidden) {
    Write-Host "===== RESOURCE IMPORT FAILED =====" -ForegroundColor Red
    Write-Host $importOutput
    exit 1
}
Write-Host "RESOURCE IMPORT PASS" -ForegroundColor Green

$gameplayTests = @(
    "BossPhaseShutdownTest",
    "BossFairnessFirstSecondTest",
    "BossFairnessThirdFifthTest",
    "BossFairnessFourthSixthTest",
    "SporeArchivistMotionContractTest",
    "BossWarningHitchTest",
    "BossEscapeGateTest",
    "VineSeedCancellationTest",
    "VineRootReentryTest",
    "BossReleasePreviewTest",
    "CampaignCatalogTest",
    "CampaignEntryPolicyTest",
    "CampaignPrimaryEntryTest",
    "CampaignFlowCompletionTest",
    "CampaignChainEvidenceTest",
    "CampaignChainFileTest",
    "CampaignChainFlowTest",
    "CampaignEndlessEvidenceTest",
    "CampaignEndlessInputTest",
    "CampaignRuntimeProfileTest",
    "NativeChapterPilotThreatTest",
    "CampaignProgressTest",
    "CampaignProgressStoreTest",
    "CampaignCarryRulesTest",
    "CampaignJourneyTest",
    "CampaignJourneyPendingClearTest",
    "CampaignJourneyStoreTest",
    "CampaignJourneyStoreRetryTest",
    "CampaignSessionTest",
    "CampaignSessionRestartTest",
    "CampaignExitCheckpointRetryTest",
    "CampaignPendingEntryMenuTest",
    "CampaignBossCoinSettlementTest",
    "CampaignRangedWarningTest",
    "CampaignRangedReactionTest",
    "CampaignRangedReactionTest_60FPS",
    "CampaignAttackStartClockTest",
    "CampaignMeleeReactionTest_30Hz",
    "CampaignMeleeReactionTest_60Hz",
    "CampaignMeleeReactionTest_120Hz",
    "CampaignMeleeReactionTest_120Hz_60FPS",
    "CampaignCapsuleHatchTest",
    "CampaignCloseContactReactionTest_30Hz",
    "CampaignCloseContactReactionTest_60Hz",
    "CampaignCloseContactReactionTest_120Hz",
    "CampaignTerrainDestructionTest",
    "CampaignTerrainProjectileTest",
    "CampaignTerrainFirstWallTest",
    "ProjectileFirstImpactTest",
    "TerrainDamageReentryTest",
    "ReusableStepTrapTest",
    "ReusableTrapFieldTest",
    "CampaignStepTrapIntegrationTest",
    "CampaignStepTrapPhysicsTest",
    "GrenadeTerrainTest",
    "LaserTerrainTest",
    "AoeTerrainTest",
    "MobilityTerrainTest",
    "EnemyTerrainAttackTest",
    "TerrainFeedbackTest",
    "CampaignDensityTest",
    "CampaignLoopRulesTest",
    "CampaignLoopIntegrationTest",
    "CampaignLoopCapacityTest",
    "CampaignLegacyRetirementTest",
    "CampaignHubLifecycleTest",
    "StepTrapWallIsolationTest",
    "CampaignCrossChapterCoinsRegression",
    "CampaignSixChapterCarryFlowTest",
    "CampaignPendingRewardRecoveryTest",
    "CampaignChapterCarryBuildTest",
    "CampaignCarrySettlementUITest",
    "CampaignFirstBossSeedEmissionRegression_30Hz",
    "CampaignFirstBossSeedEmissionRegression_60Hz",
    "CampaignFirstBossSeedEmissionRegression_120Hz",
    "CampaignMenuTest",
    "CampaignMenuMotionTest",
    "CampaignMenuIntegrationTest",
    "CampaignChapterLaunchTest",
    "NurseryMapTest",
    "ChapterMapBackdropTest",
    "NurseryMovementTest",
    "FoundryMapTest",
    "FoundrySeedGenerationTest",
    "FoundryMovementTest",
    "SaltLayoutTest",
    "SaltMapTest",
    "SaltMovementTest",
    "ArchiveLayoutTest",
    "ArchiveMapTest",
    "ArchiveMovementTest",
    "EchoLayoutTest",
    "RiftLayoutTest",
    "RiftPropArtTest",
    "RiftMapTest",
    "RiftMovementTest",
    "RiftFaultTest",
    "RiftFaultPhysicsTest",
    "RiftFieldTest",
    "RiftFieldPhysicsTest",
    "RiftEncounterPolicyTest",
    "RiftEncounterTest",
    "RiftEncounterRuntimeTest",
    "RiftObserverAttackGateTest",
    "RiftObserverAttackResourceTest",
    "RiftObserverMotionContractTest",
    "RiftObserverBeamTest",
    "RiftObserverBeamClockTest",
    "RiftObserverBeamDodgeTest",
    "RiftObserverOriginSafetyTest",
    "RiftObserverCircleFlightTest",
    "RiftObserverFragmentTest",
    "RiftObserverRefractAttackTest",
    "RiftObserverRefractDodgeTest",
    "RiftObserverProbeTest",
    "RiftObserverProbeBoundaryTest",
    "RiftObserverProbeOriginBoundaryTest",
    "RiftObserverProbeAttackTest",
    "RiftObserverProbeDodgeTest",
    "RiftObserverAutomaticCycleTest",
    "RiftObserverLifecycleTest",
    "RiftObserverIntegrationTest",
    "RiftObserverRuntimeTest",
    "RiftChapterTest",
    "RiftChapterLaunchTest",
    "EchoMapTest",
    "EchoMovementTest",
    "EchoBeatTest",
    "EchoFieldTest",
    "EchoBeatPhysicsTest",
    "EchoBeatEntitySeparationTest",
    "EchoEncounterPolicyTest",
    "EchoEncounterTest",
    "EchoEncounterRuntimeTest",
    "EchoBossEncounterTest",
    "EchoChapterTest",
    "EchoChapterLaunchTest",
    "ArchiveSporeNestTest",
    "ArchiveSporeFieldTest",
    "ArchiveSporePhysicsTest",
    "SaltTidalBandTest",
    "SaltTidalFieldTest",
    "SaltTidalPhysicsTest",
    "FoundryHeatVentTest",
    "FoundryHeatFieldTest",
    "FoundryHeatPhysicsTest",
    "ChapterEncounterCompatibilityTest",
    "ChapterSplitClearanceTest",
    "SplittingMoteOwnerExitTest",
    "CapsuleBirthContextTest",
    "ArchiveEncounterPolicyTest",
    "ArchiveEncounterTest",
    "ArchiveBossBroodTest",
    "ArchiveBossCycleTest",
    "ArchiveBossBroodBirthTest",
    "ArchiveBossBroodLifecycleTest",
    "ArchiveBossVictoryCleanupTest",
    "ArchiveBossFailureCancellationTest",
    "ArchiveChapterTest",
    "ArchiveChapterLaunchTest",
    "ArchiveDamageTargetsTest",
    "SaltEncounterPolicyTest",
    "SaltEncounterTest",
    "SaltEncounterRuntimeTest",
    "SaltBossEncounterTest",
    "FoundryEncounterTest",
    "FoundryEncounterRuntimeTest",
    "FoundryBossEncounterTest",
    "NurseryEncounterTest",
    "NurserySupplyPolicyTest",
    "NurserySupplyRuntimeTest",
    "NurseryClearanceProofTest",
    "NurseryChapterTest",
    "ChapterDeathTailTest",
    "SharedChapterRunTest",
    "ChapterEvolutionContextTest",
    "ChapterFinaleFlowTest",
    "ChapterFinaleUITest",
    "ChapterBuildChoiceTest",
    "ChapterRewardBudgetTest",
    "ChapterPostClearHookTest",
    "ChapterReplayGuardTest",
    "ChapterFailureCleanupTest",
    "ChapterTerrainWitnessTest",
    "DiagnosticProjectileAimTest",
    "ChapterBuildAimTest",
    "ChapterBuildPointerTest",
    "FoundryChapterTest",
    "FoundryChapterLaunchTest",
    "SaltChapterTest",
    "SaltChapterLaunchTest",
    "ChapterViewportHostingTest",
    "NurseryProjectileDropTest",
    "NativeMonsterSampleTest",
    "NativePaperSkinTest",
    "RootlingDraftTest",
    "NativeActorResourceTest",
    "NativePlayerResourceTest",
    "PlayerNativeIntegrationTest",
    "NativeArtValidatorTest",
    "NativeRigCheckpointTest",
    "NativePlayerCatalogTest",
    "NativeDroneResourceTest",
    "NativeDroneCatalogTest",
    "NativeDroneIntegrationTest",
    "NativeCharacterRosterTest",
    "PaperStyleGroupTest",
    "EnemyNativeIntegrationTest",
    "EnemyWorldStatusTest",
    "SporelingResourceTest",
    "SporelingIntegrationTest",
    "CinderRunnerResourceTest",
    "CinderRunnerIntegrationTest",
    "CinderChargeTest",
    "CinderChargeResourceTest",
    "SaltNeedlerResourceTest",
    "SaltNeedlerIntegrationTest",
    "FolioLobberTest",
    "FolioLobberResourceTest",
    "StoneCarrierResourceTest",
    "StoneCarrierAttackResourceTest",
    "StoneCarrierAttackIntegrationTest",
    "StoneCarrierIntegrationTest",
    "VineGuardResourceTest",
    "VineGuardIntegrationTest",
    "VineGuardAttackResourceTest",
    "VineGuardAttackDirectorTest",
    "VineRootFairnessTest",
    "VineGuardAttackIntegrationTest",
    "VineSeedPhysicsTest",
    "FurnaceForemanResourceTest",
    "FurnaceForemanPlaybackTest",
    "FurnaceForemanAttackDirectorTest",
    "FurnaceForemanPhysicsTest",
    "FurnaceForemanAttackResourceTest",
    "FurnaceForemanIntegrationTest",
    "FurnaceForemanDodgeTest",
    "TideShellResourceTest",
    "TideShellPlaybackTest",
    "TideShellAttackGateTest",
    "TideShellAttackResourceTest",
    "TideShellWaveGeometryTest",
    "TideShellAttackDirectorTest",
    "TideShellIntegrationTest",
    "TideShellClawSweepTest",
    "TideShellPhysicsTest",
    "TideShellDodgeTest",
    "SporeArchivistResourceTest",
    "SporeArchivistPlaybackTest",
    "SporeArchivistAttackGateTest",
    "SporeArchivistAttackResourceTest",
    "ArchivePageProjectileTest",
    "ArchivePageWidthTest",
    "ArchiveBossPageIntegrationTest",
    "ArchiveBossPageLifecycleTest",
    "ArchiveBossPageDodgeTest",
    "ArchiveBossSealTest",
    "ArchiveBossSealLifecycleTest",
    "ArchiveBossSealDodgeTest",
    "BellPriestResourceTest",
    "BellPriestPlaybackTest",
    "BellPriestAttackGateTest",
    "BellPriestAttackResourceTest",
    "BellPriestMotionContractTest",
    "BellPriestIntegrationTest",
    "BellPriestStrikeTest",
    "BellPriestBellAttackTest",
    "BellPriestBellDodgeTest",
    "BellPriestPendantProjectileTest",
    "BellPriestPendantAttackTest",
    "BellPriestPendantDodgeTest",
    "BellPriestCrownProjectileTest",
    "BellPriestCrownAttackTest",
    "BellPriestCrownDodgeTest",
    "BellPriestCrownPhase3DodgeTest",
    "BellPriestLifecycleTest",
    "BellPriestAutomaticCycleTest",
    "RiftObserverResourceTest",
    "RiftObserverPlaybackTest",
    "RootCommanderResourceTest",
    "RootCommanderIntegrationTest",
    "RootCommanderAttackResourceTest",
    "RootCommanderAttackIntegrationTest",
    "NativeLegacyBossIntegrationTest",
    "LegacyOverseerActionsResourceTest",
    "LegacyOverseerMotionIntegrationTest",
    "NativeImpactArtTest",
    "NativeImpactRuntimeTest",
    "NativeArenaArtTest",
    "NativeArenaRuntimeTest",
    "NativeArenaPropGeometryTest",
    "EmberSparkResourceTest",
    "EmberSparkIntegrationTest",
    "EmberSparkClockTest",
    "FlankingCrabResourceTest",
    "FlankingCrabIntegrationTest",
    "FlankingCrabMotionTest",
    "SplittingMoteResourceTest",
    "SplittingMoteIntegrationTest",
    "SplittingMoteLifecycleTest",
    "CapsulePlanterResourceTest",
    "CapsulePlantHazardTest",
    "CapsulePlanterIntegrationTest",
    "CapsulePlanterLifecycleTest",
    "EchoRingAttackTest",
    "EchoSentinelResourceTest",
    "EchoSentinelIntegrationTest",
    "EchoSentinelClockTest",
    "ShadeAmbushAttackTest",
    "CirclingShadeGeometryTest",
    "CirclingShadeResourceTest",
    "CirclingShadeIntegrationTest",
    "CirclingShadeClockTest",
    "EliteHybridAttackTest",
    "RiftEliteGeometryTest",
    "RiftEliteResourceTest",
    "RiftEliteIntegrationTest",
    "RiftShardPhysicsTest",
    "RiftEliteClockTest",
    "SpaceCutAttackTest",
    "SpaceCutterGeometryTest",
    "SpaceCutterResourceTest",
    "SpaceCutterIntegrationTest",
    "SpaceCutterClockTest",
    "BalanceTest",
    "EconomyBuildTest",
    "CombatEventTest",
    "CombatFeedbackTest",
    "EnemyHitFeedbackTest",
    "EnemyAttackFeedbackTest",
    "EnemyCompactAttackTest",
    "EnemyHealthBarTest",
    "AudioLifecycleTest",
    "OriginalOverdriveAudioTest",
    "ChapterPerformanceLedgerTest",
    "MainCloseTest",
    "DamageTest",
    "ProjectilePickupTest",
    "GrenadeVelocityTest",
    "EnemyProjectileRadiusTest",
    "EnemyDamageMultiplierTest",
    "ThunderMatrixIntervalTest",
    "ScrapperAttackTest",
    "GameplayDescriptionsTest",
    "RateTest",
    "DashTest",
    "PlayerDashWallContactTest_30Hz",
    "PlayerDashWallContactTest_60Hz",
    "PlayerDashWallContactTest_120Hz",
    "StealthTerrainTest_30Hz",
    "StealthTerrainTest_60Hz",
    "StealthTerrainTest_120Hz",
    "StealthRecoveryTest_30Hz",
    "StealthRecoveryTest_60Hz",
    "StealthRecoveryTest_120Hz",
    "StealthRecoverySideEffectTest_30Hz",
    "StealthRecoverySideEffectTest_60Hz",
    "StealthRecoverySideEffectTest_120Hz",
    "StealthRecoveryQueryTest_30Hz",
    "StealthRecoveryQueryTest_60Hz",
    "StealthRecoveryQueryTest_120Hz",
    "StealthRecoveryAccountingTest_30Hz",
    "StealthRecoveryAccountingTest_60Hz",
    "StealthRecoveryAccountingTest_120Hz",
    "MovementTest",
    "ArenaMapTest",
    "ArenaRuntimeTest",
    "WaveTest",
    "PortalTest",
    "PortalRuntimeClockTest",
    "Phase5CombatTest",
    "BossTest",
    "BossHealthBarTest",
    "CombatStatusLayoutTest",
    "BossCameraFramingTest",
    "BossIndicatorOcclusionTest",
    "BossTentacleTest",
    "BossPatternTest",
    "BossDirectorTest",
    "BossRuntimeClockTest",
    "SnapshotTest",
    "ContinueTest",
    "OverdriveTest",
    "Phase19Test",
    "Phase20Test",
    "Phase21Test",
    "DroneVisualLifecycleTest",
    "EnemyBehaviorTest",
    "EnemyFlockTest",
    "EnemyFlockPolicyTest",
    "EnemyNeighborGridTest",
    "UpgradeTest",
    "StateTest",
    "GateFailureTest",
    "UITest",
    "AimReticleOutlineTest",
    "SettlementUITest",
    "PerformanceTest",
    "SmokeTest"
    "LegacyWaveSmokeTest"
)
$artTests = @(
    "FriendlyEffectPaletteTest",
    "HostileEffectPaletteTest",
    "NaturalRunPolicyTest",
    "NaturalRunSnapshotCheckTest",
    "NaturalRunRenderedTest",
    "CollectionCaptureTest",
    "LateCrowdLedgerTest",
    "StressCaptureTest",
    "BossReadabilityTest",
    "EnemyReadabilityTest",
    "EnemyDasherArtTest",
    "EnemyStaticArtTest",
    "ProjectileLandingVisualTest",
    "LobberVisualLifecycleTest",
    "ChibiRuntimeArtTest",
    "PlayerOcclusionOutlineTest",
    "FriendlyEffectLayerTest",
    "GroundWarningLayerTest"
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

foreach ($test in $tests) {
    $scriptTest = $test
    $fixedStepArguments = ""
    $userArguments = ""
    $frameBudget = if ($test -in @("AudioLifecycleTest", "MainCloseTest")) { 12000 }
        elseif ($test -in @("NurseryMovementTest", "FoundryMovementTest", "SaltMovementTest", "ArchiveMovementTest", "ArchiveSporePhysicsTest", "SaltTidalPhysicsTest", "FoundryHeatPhysicsTest", "SaltEncounterRuntimeTest", "FoundryEncounterRuntimeTest", "FurnaceForemanPhysicsTest", "FurnaceForemanDodgeTest", "TideShellPhysicsTest", "TideShellDodgeTest")) { 6000 }
        elseif ($test -in @("ChapterSplitClearanceTest", "SplittingMoteOwnerExitTest", "CapsuleBirthContextTest", "ArchiveEncounterTest", "NurseryEncounterTest", "NurseryChapterTest", "NurseryProjectileDropTest", "CampaignChapterLaunchTest", "SaltEncounterTest", "FoundryChapterTest", "FoundryChapterLaunchTest", "SaltChapterTest", "SaltChapterLaunchTest")) { 1800 }
        elseif ($test -in @("DashTest", "ScrapperAttackTest", "EnemyFlockTest", "EnemyFlockPolicyTest", "EnemyNeighborGridTest", "FlankingCrabMotionTest", "SplittingMoteLifecycleTest", "CapsulePlantHazardTest", "CapsulePlanterLifecycleTest", "EchoRingAttackTest", "EchoSentinelClockTest", "ShadeAmbushAttackTest", "CirclingShadeClockTest", "EliteHybridAttackTest", "RiftEliteIntegrationTest", "RiftShardPhysicsTest", "RiftEliteClockTest", "SpaceCutAttackTest", "SpaceCutterClockTest")) { 1800 }
        elseif ($test -in @("PortalRuntimeClockTest", "BossRuntimeClockTest", "CombatStatusLayoutTest", "EnemyWorldStatusTest")) { 600 }
        else { 120 }
    if ($test -match '^CampaignFirstBossSeedEmissionRegression_(30|60|120)Hz$') {
        $scriptTest = "CampaignFirstBossSeedEmissionRegression"
        $physicsHz = $Matches[1]
        $fixedStepArguments = "--fixed-fps $physicsHz"
        $userArguments = "-- --ticks=$physicsHz"
        $frameBudget = 3000
    }
    # Clock tests observe real portal/Boss warnings at 60 FPS.
    if ($test -eq "NurserySupplyRuntimeTest") { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
    if ($test -like "BossFairness*Test") { $frameBudget = 18000; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("BossEscapeGateTest", "BossWarningHitchTest", "BossReleasePreviewTest", "SporeArchivistMotionContractTest")) { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("VineSeedCancellationTest", "VineRootReentryTest")) { $frameBudget = 3000; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "ChapterDeathTailTest") { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("ChapterEvolutionContextTest", "ChapterFinaleFlowTest", "ChapterFinaleUITest", "ChapterBuildPointerTest", "ChapterReplayGuardTest")) { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "CampaignPrimaryEntryTest") { $frameBudget = 6000; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "CampaignLegacyRetirementTest") { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "CampaignHubLifecycleTest") { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("CampaignEndlessEvidenceTest", "CampaignEndlessInputTest")) { $frameBudget = 600; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("SmokeTest", "LegacyWaveSmokeTest")) { $frameBudget = 6000; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("CampaignLoopIntegrationTest", "CampaignLoopCapacityTest")) { $frameBudget = 12000; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("ArchivePageProjectileTest", "ArchiveBossPageDodgeTest", "ArchiveBossSealDodgeTest")) { $frameBudget = 6000; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("ArchiveBossPageIntegrationTest", "ArchiveBossPageLifecycleTest", "ArchiveBossSealTest", "ArchiveBossSealLifecycleTest")) { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("ArchiveBossBroodTest", "ArchiveBossCycleTest", "ArchiveBossBroodBirthTest", "ArchiveBossBroodLifecycleTest", "ArchiveBossVictoryCleanupTest", "ArchiveBossFailureCancellationTest")) { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("ArchiveChapterTest", "ArchiveChapterLaunchTest")) { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "ArchiveDamageTargetsTest") { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
        if ($test -eq "EchoMovementTest") { $frameBudget = 12000; $fixedStepArguments = "--max-fps 120" }
        if ($test -eq "RiftMovementTest") { $frameBudget = 12000; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("RiftFaultTest", "RiftFieldTest")) { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "RiftFaultPhysicsTest") { $frameBudget = 30000; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "RiftFieldPhysicsTest") { $frameBudget = 18000; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "RiftEncounterPolicyTest") { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "RiftEncounterTest") { $frameBudget = 5000; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "RiftEncounterRuntimeTest") { $frameBudget = 8000; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "RiftObserverBeamClockTest") { $frameBudget = 3000; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "RiftObserverBeamDodgeTest") { $frameBudget = 12000; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("RiftObserverOriginSafetyTest", "RiftObserverCircleFlightTest", "RiftObserverFragmentTest", "RiftObserverRefractAttackTest", "RiftObserverProbeTest", "RiftObserverProbeBoundaryTest", "RiftObserverProbeOriginBoundaryTest", "RiftObserverProbeAttackTest")) { $frameBudget = 3000; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "RiftObserverProbeDodgeTest") { $frameBudget = 12000; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "RiftObserverRefractDodgeTest") { $frameBudget = 12000; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("RiftObserverAutomaticCycleTest", "RiftObserverLifecycleTest", "RiftObserverIntegrationTest")) { $frameBudget = 3000; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "RiftObserverRuntimeTest") { $frameBudget = 12000; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("RiftChapterTest", "RiftChapterLaunchTest")) { $frameBudget = 6000; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("EchoBeatTest", "EchoFieldTest")) { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "EchoBeatPhysicsTest") { $frameBudget = 16000; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("EchoBeatEntitySeparationTest", "EchoEncounterPolicyTest", "EchoEncounterTest", "EchoEncounterRuntimeTest", "EchoBossEncounterTest", "EchoChapterTest", "EchoChapterLaunchTest")) { $frameBudget = 6000; $fixedStepArguments = "--max-fps 120" }
    if ($test -eq "BossIndicatorOcclusionTest") { $frameBudget = 1800; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("BellPriestIntegrationTest", "BellPriestStrikeTest", "BellPriestBellAttackTest", "BellPriestPendantProjectileTest", "BellPriestPendantAttackTest", "BellPriestCrownProjectileTest", "BellPriestCrownAttackTest", "BellPriestLifecycleTest", "BellPriestAutomaticCycleTest")) { $frameBudget = 3000; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("BellPriestBellDodgeTest", "BellPriestPendantDodgeTest", "BellPriestCrownDodgeTest", "BellPriestCrownPhase3DodgeTest")) { $frameBudget = 12000; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("ChapterSplitClearanceTest", "SplittingMoteOwnerExitTest", "CapsuleBirthContextTest", "ArchiveEncounterTest")) {
        $fixedStepArguments = "--max-fps 120"
    }
    # Their own five-second watchdogs remain the lifecycle failure bounds.
	if ($test -in @("CampaignCrossChapterCoinsRegression", "CampaignPendingRewardRecoveryTest")) { $frameBudget = 3000; $fixedStepArguments = "--max-fps 120" }
	if ($test -in @("CampaignSixChapterCarryFlowTest", "CampaignBossCoinSettlementTest")) { $frameBudget = 12000; $fixedStepArguments = "--max-fps 120" }
	if ($test -in @("ArchivePageWidthTest", "CampaignExitCheckpointRetryTest")) { $frameBudget = 3000; $fixedStepArguments = "--max-fps 120" }
	if ($test -eq "CampaignRangedReactionTest") { $frameBudget = 14000; $fixedStepArguments = "--max-fps 120" }
	if ($test -eq "CampaignRangedReactionTest_60FPS") { $scriptTest = "CampaignRangedReactionTest"; $frameBudget = 14000; $fixedStepArguments = "--max-fps 60" }
	if ($test -eq "CampaignCapsuleHatchTest") { $frameBudget = 12000; $fixedStepArguments = "--max-fps 120" }
	if ($test -match '^CampaignMeleeReactionTest_(30|60|120)Hz(?:_60FPS)?$') {
		$scriptTest = "CampaignMeleeReactionTest"
		$userArguments = "-- --ticks=$($Matches[1])"
		$frameBudget = 8000
		$fixedStepArguments = "--max-fps 120"
		if ($test.EndsWith("_60FPS")) { $fixedStepArguments = "--max-fps 60" }
	}
	if ($test -match '^CampaignCloseContactReactionTest_(30|60|120)Hz$') {
		$scriptTest = "CampaignCloseContactReactionTest"
		$physicsHz = $Matches[1]
		$userArguments = "-- --ticks=$physicsHz"
		$frameBudget = 6000
		$fixedStepArguments = "--fixed-fps $physicsHz"
	}
	if ($test -in @("CampaignTerrainDestructionTest", "CampaignTerrainProjectileTest", "ProjectileFirstImpactTest", "TerrainDamageReentryTest", "ReusableStepTrapTest", "StepTrapWallIsolationTest")) {
		$frameBudget = 3000
		$fixedStepArguments = "--max-fps 120"
	}
	if ($test -eq "CampaignTerrainFirstWallTest") { $frameBudget = 8000; $fixedStepArguments = "--max-fps 120" }
	if ($test -eq "ReusableTrapFieldTest") { $frameBudget = 18000; $fixedStepArguments = "--max-fps 120" }
	if ($test -in @("CampaignStepTrapIntegrationTest", "CampaignStepTrapPhysicsTest")) { $frameBudget = 18000; $fixedStepArguments = "--max-fps 120" }
	if ($test -eq "GrenadeTerrainTest") { $frameBudget = 6000; $fixedStepArguments = "--max-fps 120" }
	if ($test -eq "LaserTerrainTest") { $frameBudget = 6000; $fixedStepArguments = "--max-fps 120" }
	if ($test -eq "AoeTerrainTest") { $frameBudget = 6000; $fixedStepArguments = "--max-fps 120" }
	if ($test -in @("MobilityTerrainTest", "EnemyTerrainAttackTest")) { $frameBudget = 6000; $fixedStepArguments = "--max-fps 120" }
	if ($test -eq "TerrainFeedbackTest") { $frameBudget = 6000; $fixedStepArguments = "--max-fps 120" }
	if ($test -eq "CampaignDensityTest") { $frameBudget = 18000; $fixedStepArguments = "--max-fps 120" }
	if ($test -in @("ArchiveSporeFieldTest", "EchoFieldTest", "RiftFieldTest")) { $frameBudget = 6000; $fixedStepArguments = "--max-fps 120" }
    if ($test -in @("NurseryMovementTest", "FoundryMovementTest", "SaltMovementTest", "ArchiveMovementTest", "ArchiveSporePhysicsTest", "SaltTidalPhysicsTest", "FoundryHeatPhysicsTest", "SaltEncounterRuntimeTest", "SaltEncounterTest", "FoundryEncounterRuntimeTest", "FoundryEncounterTest", "FurnaceForemanPhysicsTest", "FurnaceForemanDodgeTest", "TideShellPhysicsTest", "TideShellDodgeTest")) {
        # Three real-time 30/60/120Hz routes await physics, not idle frames.
        # Cap idle throughput so quit-after cannot exhaust before physics runs;
        # keep the positive pass marker, frame bound and wall-clock watchdog.
        $fixedStepArguments = "--max-fps 120"
    }
    if ($test -in @("NurseryEncounterTest", "NurseryChapterTest", "NurseryProjectileDropTest", "CampaignChapterLaunchTest", "FoundryChapterTest", "FoundryChapterLaunchTest", "SaltChapterTest", "SaltChapterLaunchTest")) {
        # This fixture waits the real Boss entrance, preserving its hit gate.
        $fixedStepArguments = "--max-fps 120"
    }
    if ($test -match '^(PlayerDashWallContactTest|StealthTerrainTest|StealthRecoveryTest|StealthRecoverySideEffectTest|StealthRecoveryQueryTest|StealthRecoveryAccountingTest)_(30|60|120)Hz$') {
        $scriptTest = $Matches[1]
        $physicsHz = $Matches[2]
        $fixedStepArguments = "--fixed-fps $physicsHz"
        $userArguments = "-- --physics-hz=$physicsHz"
        $frameBudget = 12000
    }
    $logPath = Join-Path ([System.IO.Path]::GetTempPath()) ("five-minute-overdrive-{0}-{1}.log" -f $test, [guid]::NewGuid().ToString("N"))
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $godot
    $startInfo.WorkingDirectory = $projectRoot
    # The Dummy driver prevents Windows audio playback handles from keeping a
    # finished headless child process alive after its pass marker is emitted.
    # Dash fixtures await real physics registration; 120 frames truncates the
    # expanded matrix before completion. Keep both a frame and wall-clock bound.
    $startInfo.Arguments = "--headless --audio-driver Dummy --path . --log-file `"$logPath`" $fixedStepArguments --script res://scripts/tests/$scriptTest.gd --quit-after $frameBudget $userArguments"
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(120000)) {
        # Process.Kill(Boolean) is unavailable in Windows PowerShell 5.1.
        $process.Kill()
        [void]$process.WaitForExit(5000)
        $failures.Add("${test}: timed out after 120 seconds")
        if (Test-Path -LiteralPath $logPath) {
            Remove-Item -LiteralPath $logPath -Force
        }
        continue
    }
    $output = ""
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    if (Test-Path -LiteralPath $logPath) {
        $output = Get-Content -Raw -LiteralPath $logPath
        Remove-Item -LiteralPath $logPath -Force
    }
    $matches = [regex]::Matches($output, "TEST PASS: $scriptTest ([1-9][0-9]*)")
    $diagnosticOutput = $output + "`n" + $stdout + "`n" + $stderr
    if ($process.ExitCode -ne 0) {
        $failures.Add("${test}: exited with $($process.ExitCode)")
    }
    if ($matches.Count -ne 1) {
        $failures.Add("${test}: expected one pass marker, found $($matches.Count)")
    } else {
        $totalAssertions += [int]$matches[0].Groups[1].Value
    }
    if ($diagnosticOutput -match $forbidden) {
        $failures.Add("${test}: output contained a forbidden error or leak marker")
    }
    if ($failures | Where-Object { $_ -like "${test}:*" }) {
        Write-Host "===== $test FAILED =====" -ForegroundColor Red
        Write-Host $diagnosticOutput
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
