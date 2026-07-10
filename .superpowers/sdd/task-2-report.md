# Task 2 Report — Damage-source routing and controlled laser audio

## Status

Task 2 is GREEN. No commit was created and Git configuration was not changed.

## Changes

- Added `DamageTypes` with `generic` plus the exact ordered five-source `ALL` list.
- Routed projectile, laser, arc, dash, and spike sources through damage producers, `Enemy.take_damage`, its typed `hit` signal, `WaveDirector`, and `Main`.
- Kept enemy projectiles compatible by allowing `Player.take_damage` to accept and ignore an optional source.
- Replaced periodic laser chirps with `laser_active_changed` state transitions.
- Added five distinct runtime-generated hit sounds, a generic fallback, per-source 55 ms throttling, and one reusable runtime-generated looping laser player.
- Corrected the focused test's signal capture holder from a scalar to a Dictionary. Godot lambdas capture local scalar values by value, so the original callback could not update the outer `StringName`; the assertion itself remains unchanged in strength.

## TDD and verification evidence

RED command:

`Godot_v4.7-stable_win64_console.exe --headless --path . --quit-after 120 --script res://scripts/tests/BalanceTest.gd`

Initial result: exit 1, parse failure because `res://scripts/components/DamageTypes.gd` did not exist.

Intermediate result before correcting the test holder: exit 1 at `BalanceTest.gd:20`, because the lambda's scalar capture did not propagate its assignment.

GREEN evidence for Task 2 using the same full command after implementation and holder correction: all damage-source, exact `DamageTypes.ALL`, five stream mappings, independent cooldown, generic fallback, player-count, and reusable loop assertions passed. Execution then failed at the first Task 3 assertion:

`BalanceTest.gd:83 — upgrade requirement at level 1 was 10 instead of 20.`

Project parse command:

`Godot_v4.7-stable_win64_console.exe --headless --editor --path . --quit`

Result: exit 0; global script classes including Enemy, Player, DamageTypes, Projectile, SpikeTrap, AudioManager, and WaveDirector registered successfully.

`git diff --check` produced no whitespace errors (only Git's existing LF-to-CRLF notices).

## Files

- `scripts/components/DamageTypes.gd` (new)
- `scripts/actors/Enemy.gd`
- `scripts/components/Projectile.gd`
- `scripts/components/SpikeTrap.gd`
- `scripts/actors/Player.gd`
- `scripts/systems/WaveDirector.gd`
- `scripts/systems/AudioManager.gd`
- `scripts/Main.gd`
- `scripts/tests/BalanceTest.gd` (capture-holder correctness only)

## Self-review

- Confirmed `DamageTypes.ALL` is exactly projectile, laser, arc, dash, spike, in that order; generic is deliberately excluded.
- Confirmed unknown sources resolve to generic without being explicitly inserted into the source mapping.
- Confirmed hit cooldown keys are independent and the loop player is allocated once in `_ready`.
- Confirmed no external audio resources, UI work, spatial audio, or bus refactor were introduced.
- Confirmed no Task 3 XP/upgrade logic was changed.

## Concerns

- The full suite remains red solely at the expected Task 3 experience-threshold assertion.
- The headless failure path reports leaked ObjectDB instances because `BalanceTest._fail()` quits immediately before its cleanup block; this is test-exit behavior, not a Task 2 audio allocation failure.
- Runtime-generated sounds were structurally verified but not subjectively auditioned in this headless environment.

## Lifecycle review fix (2026-07-11)

### Changes

- Added an end-of-run regression to `SmokeTest`: start the reusable laser loop, call `_end_run(false)`, then require the player to have physics processing disabled and the loop player to be stopped before the existing scene cleanup.
- Updated the shared `_end_run(victory)` path so both defeat and victory explicitly disable player physics processing and stop the laser loop before showing results.
- Removed the unused legacy `streams["laser"]` short-tone synthesis entry from `AudioManager`.

### TDD note

The first SmokeTest RED attempt was run without `--quit-after`; it produced no Godot output, did not terminate, and the command timed out after 124 seconds. The residual Godot process was then explicitly stopped. All verification runs below used the requested 120-frame guard.

### Verification output

SmokeTest command:

`Godot_v4.7-stable_win64_console.exe --headless --path . --quit-after 120 --script res://scripts/tests/SmokeTest.gd`

Result: exit 0.

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

WARNING: 13 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2535)
```

BalanceTest command:

`Godot_v4.7-stable_win64_console.exe --headless --path . --quit-after 120 --script res://scripts/tests/BalanceTest.gd`

Result: exit 1 at the expected first Task 3 experience-threshold assertion, after the Task 2 assertions.

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

ERROR: BalanceTest failed: upgrade requirement at level 1 was 10 instead of 20.
   at: push_error (core/variant/variant_utility.cpp:1023)
   GDScript backtrace (most recent call first):
       [0] _fail (res://scripts/tests/BalanceTest.gd:9)
       [1] _initialize (res://scripts/tests/BalanceTest.gd:83)
WARNING: 9 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2535)
```

### Concerns

- SmokeTest exits successfully but Godot reports 13 leaked ObjectDB instances at forced/scripted exit.
- BalanceTest remains red only at the expected Task 3 level-1 experience requirement and reports 9 leaked instances because its failure path quits before cleanup.
