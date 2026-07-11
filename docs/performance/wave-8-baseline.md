# Wave 8 Performance Baseline

Date: 2026-07-12

Runtime: Godot 4.7 stable, Windows headless

Scenario: 250 wave-eight scrapper enemies, 1,000 registry lookups, and 100 rapidly scheduled hit sounds.

## Before the low-risk pass

- `Player.gd` contained five independent `get_nodes_in_group("enemies")` scan sites.
- Projectile, ExperienceShard, and ShieldPickup requested redraw every physics frame despite static visuals.
- One AudioStreamPlayer existed before the hit test; 100 accepted hit sounds grew the audio subtree to 101 players.
- WaveDirector derived active counts from repeated scene-tree group scans.

## After the low-risk pass

Latest focused result:

```text
PERFORMANCE: registry_1000_lookups_ms=0.106 nodes=399 audio_players=17
TEST PASS: PerformanceTest 9
```

- Player uses the WaveDirector registry in production and retains one group-scan fallback for isolated fixtures.
- Static projectile and pickup visuals perform no per-frame redraw.
- Enemy idle movement does not redraw; flash and attack visuals still redraw while animated.
- AudioManager owns 16 reusable one-shot voices plus one reusable laser-loop player. One hundred hit sounds do not add nodes.
- Removing 125 of 250 enemies shrinks the registry to 125 after one frame.

## Decision

Do not add object pooling or a spatial index in this iteration. Registry lookup cost is negligible in the synthetic 250-enemy case, audio node growth is bounded, and the measured node count is consistent with the live actors and their collision/health children. Revisit pooling only if an interactive profiler capture shows allocation or deletion spikes after the current correctness and UI work ships.
