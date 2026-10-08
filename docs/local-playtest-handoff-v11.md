# v11 — AB enemy attack and hit effects

2026-10-08 (Asia/Shanghai). Local-only playtest; not a public release.

## Run

Open `build/playtest/5分钟超载-current-v11/` and double-click `five-minute-overdrive.exe`. Keep its matching PCK in the same directory; copy the whole directory if needed. No Godot/editor/test run is needed to play. This build directory is local and ignored by Git; cloning the repository does not download it. v10-r2/v9 remain untouched. Do not use the rejected initial v10 or mix PCK versions.

Production source commit: `5c8ae1cf82314623a63bf46caedba8cf04d47d9e`, after the focused incoming-hit commit `29aa972`. Final handoff-only documentation commits do not alter the exported production inputs. Contains original preexisting dirty resources; **not a clean-HEAD-only build**. Protected20 paths match their baseline hashes.

## Change

Human selection: combine A's crisp short slashes/speed strokes with B's dark outline and compact cream contact star. Real actor-local incoming hits are direction-aware and capped to one live effect with65ms admission spacing,7/11px radius and100/140ms life. Scrapper active claw/pounce use the original locked geometry; warnings, recovery and cancel have no attack strokes. Ordinary melee shares the strokes. Hostile bullets/Boss diamonds gain bounded rear trails; lob flight/impact and Boss sweep get restrained contrast accents. No new raster asset, large smoke, full-body whiteout or per-hit node allocation. Existing enemy damage×3, Matrix interval+50%, grenade30% inheritance/+20% base speed, flocking and reticle changes remain. No damage, attack speed, collision, movement, camera/hit-stop/audio or save format change this round.

[Runtime review and actual native screenshots](art/enemy-feedback-ab-runtime-review-v1.md) distinguish the prior AI concept from implemented rendering. Concept board never imported. Rejected intermediate type/pause/diagnostic errors are preserved in ignored evidence, not hidden or passed off as valid captures.

## Verification

- Full strict gate:85 Godot suites /174906 assertions;35 Python suites /269 tests; exit0, no timeout. Evidence: `build/diagnostics/gameplay-feedback-v2/enemy-feedback-ab-full-v1/closed.json` and retained logs.
- Native Vulkan controlled fixture `build/diagnostics/enemy-feedback-ab/combined-v2`:22 incoming-hit actors, bright/dark contexts and expiry;90 manually advanced60Hz attack steps and45 encoded native frames, plus48 accepted-hit enemies and a visible Player. Source hashes checked. Inspected active claw/pounce and dense images; not a performance benchmark or natural-input run.
- Real Main controlled capture `build/diagnostics/enemy-feedback-ab/main-v3`:random obstacle map, actual Player/HUD and16 accepted-hit enemies plus active claw/pounce. Screenshot inspected, runtime log checked error/leak-free; isolated APPDATA. This is staged, not a normal-input playthrough.
- Fresh source copy with unchanged export preset and isolated APPDATA/templates.200 eligible production inputs byte-identical between the working tree, registered receipt and fresh copy before/after export. Import/export exit0 and error/leak-free.
- Ordinary final EXE native title:3 frames1280x720, nonblank and inspected; exit0 and no errors/leaks. **Not a full ordinary-EXE combat playthrough.**
- Actual exported PCK tested with external fixtures driving its packed `res://`, not working-tree actors:

| Suite | Assertions |
| --- | ---: |
| EnemyHitFeedbackTest |82|
| EnemyAttackFeedbackTest |803|
| EnemyDamageMultiplierTest |63|
| ThunderMatrixIntervalTest |112|
| ScrapperAttackTest |21|
| AimReticleOutlineTest |8|
| GameplayDescriptionsTest |36|
| GrenadeVelocityTest |73|
| EnemyFlockTest |33|
| **Total** |**1231**|

## Package identity

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| five-minute-overdrive.exe |109019648|`b5972ed3389906d857e60315308e18d3474bab4eeaa3a32a00bf637643cfc4d0`|
| five-minute-overdrive.pck |3024840|`b1a71a2bd85973fc612d4ed043c8e61eedda44283dd50b9eb2f6a9da0453ad86`|

EXE is the same engine template; changed gameplay code/effects live in the PCK. Receipt with200 source hashes,9 test logs/counts,3 title hashes and real operation exits: `build/diagnostics/enemy-feedback-ab/package-v11/receipt.json`. No credentials, saves or machine settings copied into the build; only existing Godot Windows4.7 x64 export templates copied into the isolated tool profile.

## Remaining human gates

No new v11 natural-input whole-run, ordinary-EXE full combat/continue matrix, audio listening or minimum-hardware benchmark was performed this round; v10's older normal-input victory is historical only. Current style/runtime review is agent verification, not human playtest approval. Environment license/draft status is unchanged. Please assess visual clarity and feel in this local candidate; public publication remains disabled.
