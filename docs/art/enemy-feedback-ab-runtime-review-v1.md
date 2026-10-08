# Enemy feedback AB runtime review

2026-10-08 (Asia/Shanghai), branch `5分钟超载`.

Human style selection: **combine A and B**. Use A's sparse crisp directional strokes with B's compact cream core and dark-teal contour. The original A/B/C comparison remains a preview, never a production texture. These effects are native procedural drawing; no new raster asset or generated-image license approval is needed. Existing actor art/alpha/imports are unchanged. The art skill's gameplay-scale gate applies to this implementation.

## Slice 1 — actor-local incoming hit

Seven enemy kinds plus real OverseerBoss share one idle-disabled `EnemyHitFeedback` child per actor. Accepted damage drives a small contact star and two short ticks at the struck edge. Undirected damage keeps a center fallback. Impacts inherit actor movement and layer above their own body, without promoting ground decorations. Radius is 7px ordinary / 11px heavy; lifetime 100/140ms; local admission interval 65ms and one live impact. Parent free removes it, pause inheritance freezes it. Existing 80ms / 0.35 palette-preserving hit flash, real damage, health, camera/hit-stop/audio and global VFX caps are unchanged.

Evidence: new test failed with eight missing-feedback assertions against the original implementation. An intermediate inference error in the drawing loop was rejected by the strict runner, fixed with an explicit Vector2/float boundary, and retained under ignored `enemy-hit-ab-green-v1`. Subsequent isolated import and suites passed: EnemyHitFeedback81, EnemyReadability2576, BossReadability244, CombatFeedback48, EnemyDamageMultiplier63.

Native Vulkan controlled capture `build/diagnostics/enemy-feedback-ab/hit-v1`: real damage calls on 22 actor fixtures, bright/dark mint backgrounds and expiration checks; valid true, exit 0, no runtime errors. Viewed `hit-bright.png`: small outlined edge sparks remain legible without erasing actor shapes. This is actual 1280x720 rendering, but frozen fixture poses, not Main/input playthrough or performance/human acceptance.

Self-review across correctness, simplicity, architecture, security and performance: Critical0 / Required0 after the type fix. No new dependencies, events, persistent allocation per hit, gameplay range/timing changes, shader changes, or unrelated dirty-resource edits.

## Remaining approved scope

Active claw/pounce traces, ordinary melee slash, hostile bullet/Boss diamond trails and lob impact clarity; exact warning geometry and all damage/timing retained. Then controlled animated native and dense-scene rendering, full strict tests and a fresh local playtest package. Slice1 is not completion of the full attack-effects request.
