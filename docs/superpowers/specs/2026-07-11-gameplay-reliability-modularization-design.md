# Gameplay Reliability and Modularization Design

## Goal

Turn the current Godot 4.7 prototype into a reliable, testable, and progressively modular game foundation. The work prioritizes deterministic gameplay correctness, single ownership of run state, isolated automated tests, responsive UI, and measured performance improvements without prematurely rebuilding the project around Resources, object pools, or a new data layer.

## Delivery Strategy

Work is delivered as independently verifiable units. Each unit receives focused regression coverage, a full smoke run, a scoped Git commit, and an automatic push to `origin/master` after verification.

1. Gameplay correctness: death drops, pickup idempotency, damage acceptance, rate timers, dash sweep, and spawn safety.
2. Test isolation and state ownership: split suites, strict runner, Main-owned state machine, and transactional upgrades.
3. UI modularization and low-risk performance: independent screens, modal input ownership, redraw reduction, registries, bounded audio playback, and upgrade caps.
4. Documentation and multi-configuration acceptance.

The existing runtime-generated visual and audio style remains intact. This design does not introduce external assets, a Resource-driven balance database, object pooling, or a spatial index unless profiling after the low-risk work proves one is necessary.

## Root Causes

### Death Drops During Physics Flush

Projectile overlap callbacks can synchronously damage and kill an enemy. `Enemy._die()` emits `died`, and `WaveDirector._on_enemy_died()` immediately calls Main to add an `Area2D` pickup with a collision shape while Godot is flushing physics queries. The fix must break this synchronous chain at the world-mutation boundary, while copying all values before the enemy is freed.

### Invulnerability Renewal

Player damage currently mutates shield before the health component decides whether the hit is accepted. Player also refreshes invulnerability independently of that decision. The damage component therefore cannot enforce one rule for shield and health. A single acceptance gate must precede both resources, and only an accepted hit may start the 0.35-second window.

### Frame-Quantized Timers

Primary fire and enemy spawning reset expired timers to a full interval. Any negative remainder is discarded, so effective rates depend on frame duration. Accumulator-style timers must add the interval after each event and process a bounded number of catch-up events per frame.

### Unsafe Spawn Clamp

Wave spawning first chooses a point around the player and then clamps it into the world. Near an edge, many invalid samples collapse onto the same boundary and can violate the player safety radius. Sampling must happen in the legal rectangle and validate both constraints together.

### Shared Pause and Upgrade State

Main, GameUI, and UpgradeSystem all mutate pause or panel state. Upgrade dictionaries are also accepted without proving that they are current, genuine, or unconsumed. This permits duplicate application, forged selections, and incorrect unpausing. Main must own run state and pause; upgrades must be transactional.

### Smoke Test Contamination

The single smoke script mutates one scene through damage, dash, traps, drones, upgrades, pause, and result behavior. Objects and global pause state leak between assertions, and `push_error()` alone is not a reliable process-level contract. Tests need fresh fixtures and an outer runner that validates both process status and output.

## Gameplay Correctness Architecture

### Deferred Drop Requests

`WaveDirector._on_enemy_died()` copies `global_position`, `xp_value`, and `shield_drop_value` into value types. It emits kill accounting synchronously, then uses `call_deferred()` to invoke private drop-request methods with only copied values. Deferred code checks that the run and parent are still valid before asking Main to spawn pickups. The soon-to-be-freed Enemy is never captured or passed to deferred code.

Pickup `_ready()` creates its shape, then enables monitoring through `set_deferred()`. Both distance collection and `body_entered` call the same `_try_collect()` method. A `collected_once` guard is set before emitting, monitoring is disabled with `set_deferred()`, and `queue_free()` follows. Exactly one value emission is possible.

### Accepted-Hit Contract

`HealthComponent.damage(amount) -> bool` returns `false` when dead, invulnerable, or the amount is non-positive; otherwise it applies health damage and returns `true`. Player owns the combined shield/health transaction through `take_damage(amount, source) -> bool`:

- Reject the hit immediately when the health component reports an active invulnerability window.
- For an accepted positive hit, consume shield first and pass any remainder to health without performing a second invulnerability check.
- Start the 0.35-second invulnerability window exactly once after the combined transaction.
- Emit shield and health UI updates only for resources that changed.
- Return whether the hit was accepted.

The component exposes `can_accept_damage() -> bool` and `begin_invulnerability(seconds)` so Player does not duplicate timer internals. Enemies may ignore the boolean return, but tests and future effects can rely on it.

### Stable Rate Accumulators

Primary fire subtracts delta without clamping. While input remains held and the timer is non-positive, it fires and adds `1.0 / fire_rate`, up to four shots per physics frame. When fire input is released, the timer cannot accumulate more than one interval of credit. This preserves rates across 30/60/120 Hz while preventing a long stall from emitting an unbounded burst.

Wave spawning follows the same pattern with a maximum of eight spawns per process frame. It adds the current wave interval after each spawn instead of assigning it. If the queue empties, the loop exits immediately.

### Deterministic Dash Movement and Sweep

Each dash step uses `step_time = min(delta, dash_timer)`, records the previous position, moves by `dash_speed * step_time`, clamps to world bounds, then checks a swept capsule from the previous to new position. The capsule radius is `dash_melee_radius`; projection onto the segment plus endpoint distance handles enemies at both ends and between physics frames. A per-dash hit set guarantees one damage application per enemy. Total unobstructed distance is exactly 165 logical pixels regardless of frame rate.

### Safe Spawn Sampling

`WaveDirector` exposes a pure helper that receives world bounds, player position, enemy margin, minimum distance, and an RNG. It samples directly inside the inset legal rectangle and rejects candidates inside the safety radius. After 32 failed samples, it evaluates legal rectangle corners and edge midpoints and chooses the farthest valid candidate. If the playable rectangle itself cannot satisfy the requested safety distance, it returns the farthest legal point and reports this explicit degraded condition to tests instead of clamping an invalid radial sample.

The production safety distance remains 430 pixels, matching the current minimum radial spawn distance. Property tests use seeded RNGs, four player-corner configurations, and 10,000 samples per corner.

## State and Upgrade Architecture

### Main-Owned Run State

Main defines:

```gdscript
enum RunState { START, PLAYING, UPGRADE, PAUSED, RESULT }
```

Only `Main._transition_to(next_state)` writes `get_tree().paused`. Transition rules are explicit:

- `START -> PLAYING`
- `PLAYING -> UPGRADE`, `PAUSED`, or `RESULT`
- `UPGRADE -> PLAYING` or `RESULT`
- `PAUSED -> PLAYING` or `RESULT`
- `RESULT -> PLAYING` through restart

Illegal transitions are rejected without changing UI or pause. Entering each state updates the corresponding UI screen in one place. UI emits `start_requested`, `pause_requested`, `restart_requested`, and `upgrade_selected`; it never writes pause. UpgradeSystem emits `upgrade_choices_requested` and `upgrade_committed`; it never writes pause or hides UI.

### Transactional Upgrade Queue

UpgradeSystem stores:

- `pending_choices: Array[Dictionary]`
- `pending_upgrade_count: int`
- `awaiting_choice: bool`

Experience processing consumes every crossed threshold and increments `pending_upgrade_count` for each level. If no choice is active, it generates one three-choice transaction and emits it. `apply_upgrade(choice) -> bool` accepts only a dictionary whose stable `id` occurs in the current pending choices while `awaiting_choice` is true. Before applying effects, it clears the active transaction so reentrant or duplicate input cannot consume it twice. An invalid dictionary returns false and emits nothing.

After a successful choice, one pending level is consumed. If more remain, the next choice transaction is emitted while Main remains in `UPGRADE`; otherwise UpgradeSystem emits completion and Main returns to `PLAYING`.

Upgrade caps prevent unbounded node and projectile growth. Initial caps are conservative and explicit: weapon lines 5, projectile pierce 6, fire-rate upgrades 12, drones 4, arc pulse 8, and spike trail 8. Capped upgrades are filtered out of future choices; if fewer than three uncapped upgrades remain, the UI shows the available count without duplicating choices.

## Test Architecture

Tests are split into focused `SceneTree` scripts:

- `DamageTest.gd`: accepted-hit contract, shield/health consistency, and invulnerability timing.
- `ProjectilePickupTest.gd`: real overlap kill, deferred drop spawning, and single collection.
- `DashTest.gd`: 30/60/120 Hz distance and swept-path damage.
- `UpgradeTest.gd`: forged, duplicate, capped, and multi-level queued choices.
- `WaveTest.gd`: rate accumulator and 40,000 seeded spawn property samples.
- `UITest.gd`: state transitions, modal visibility, focus, and responsive minimum sizes.

Every test creates its own Main scene or minimal fixture, resets `SceneTree.paused` during cleanup, frees the fixture, waits for deferred deletion, and prints a machine-readable `TEST PASS: <suite> <count>` line. Every failure prints `TEST FAIL:` and quits non-zero.

`scripts/tests/run_tests.ps1` launches each suite in a separate Godot process. For each process it checks:

- exit code is zero;
- output contains exactly one matching pass marker with a positive assertion count;
- output contains none of `SCRIPT ERROR`, `ERROR:`, or `TEST FAIL:`;
- no suite times out.

It prints a final suite/assertion total and exits non-zero on any violation. This script becomes the canonical command documented in README and used before pushes.

## UI Modularization

GameUI becomes an orchestration shell with references to four focused scene-backed controls:

- `HUD.tscn` and `HUD.gd`: health, shield, XP, wave, runtime statistics, combo, pause intent, and toast overlay.
- `UpgradeScreen.tscn` and `UpgradeScreen.gd`: choice rendering and choice intent.
- `PauseScreen.tscn` and `PauseScreen.gd`: modal pause presentation and resume intent.
- `ResultScreen.tscn` and `ResultScreen.gd`: victory/defeat statistics and restart intent.
- `CyberTheme.tres`: shared fonts, colors, panels, buttons, and progress bars.

Toast is a top-level overlay sibling rather than an HBox child. HUD keeps one tween reference, kills it before starting a new toast animation, and removes layout participation when hidden. Upgrade, pause, and result overlays use `MOUSE_FILTER_STOP`; opening a modal grabs focus on its primary action, and closing it returns focus to the HUD pause control.

Layouts use anchors, containers, and breakpoint-driven compact presentation rather than a fixed 1,182-pixel logical width. Acceptance sizes are 960x540, 1280x720, 1920x1080, and 2560x1080. At 960x540 all critical meters, choices, and modal actions must remain visible without overlap.

## Performance Work

Low-risk changes precede structural optimization:

- Main caches the Player reference it already owns.
- WaveDirector owns an active enemy registry updated on spawn and tree exit. Player targeting and wave status consume that registry rather than repeatedly scanning the scene tree.
- Projectile and pickup visuals redraw only when visual state changes; static drawings do not call `queue_redraw()` every frame.
- Enemy redraws only when flash or attack visuals change.
- AudioManager uses a fixed voice pool or Godot polyphony for hit sounds; a hit never creates a new AudioStreamPlayer node.
- UI setters return early when displayed values have not changed.

A reproducible wave-eight profiling scenario records frame time, physics time, node count, and audio-player count before and after these changes. Object pooling or a spatial index is allowed only if this profile still identifies allocation churn or full-scan targeting as a material bottleneck.

## Error Handling and Lifecycle

Deferred callbacks verify `is_instance_valid()` for their owner and require an active run before spawning. State transitions are idempotent and reject illegal requests. Restart first returns the tree to an unpaused state through Main, disposes the old run graph, and then builds a new run so old signals cannot affect the new session. Result, pause, and upgrade requests that arrive after run completion are ignored.

Test fixtures always clean up in a finally-style helper even after assertion failure where Godot permits it. The outer runner treats leaked ObjectDB warnings as failures after the suites have been migrated, preventing the existing cleanup warnings from becoming permanent background noise.

## Documentation and Acceptance

README states Godot 4.7, right-click dash, Space pause, the canonical PowerShell test command, headless single-suite commands, and export steps for Windows desktop.

Completion requires:

- physical projectile kills create each configured drop once with no physics-flush errors;
- 0.1-second repeated hits consume shield/health only on accepted invulnerability windows;
- 10-second firing and spawn simulations remain within one event across 30/60/120 Hz after startup alignment;
- dash distance is 165 pixels across those rates and hits enemies crossed between frames;
- all 40,000 spawn property samples remain legal and safe;
- duplicate and forged upgrades have no side effects, while multi-level gains serialize choices;
- Main is the only production code that assigns `SceneTree.paused`;
- all split suites pass through the strict runner without errors, script errors, leak warnings, or missing pass counts;
- UI is usable at all four target resolutions;
- hit-audio node count remains bounded during sustained combat;
- the final diff contains no secrets, generated local state, or unrelated `.superpowers/sdd` artifacts.

## Out of Scope

- Resource-based migration of waves, enemies, and upgrades.
- Object pooling or a spatial index without profiler evidence.
- Networked play, save migration, mobile controls, or console export.
- Replacing the current runtime-generated art and audio direction.
