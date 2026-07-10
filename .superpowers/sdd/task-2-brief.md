### Task 2: Damage-source routing and controlled laser audio

**Files:**
- Create: `scripts/components/DamageTypes.gd`
- Modify: `scripts/actors/Enemy.gd`
- Modify: `scripts/components/Projectile.gd`
- Modify: `scripts/components/SpikeTrap.gd`
- Modify: `scripts/actors/Player.gd`
- Modify: `scripts/systems/WaveDirector.gd`
- Modify: `scripts/systems/AudioManager.gd`
- Modify: `scripts/Main.gd`
- Test: `scripts/tests/BalanceTest.gd`

**Interfaces:**
- Produces: `DamageTypes.GENERIC/PROJECTILE/LASER/ARC/DASH/SPIKE`, `Enemy.take_damage(amount: float, source: StringName = DamageTypes.GENERIC)`, `signal hit(source: StringName)`, `signal laser_active_changed(active: bool)`, `AudioManager.play_hit(source: StringName) -> bool`, and `AudioManager.set_laser_active(active: bool) -> void`.
- Consumes: Godot `AudioStreamWAV`, existing damage calls, and the focused test from Task 1.

- [ ] **Step 1: Add stable damage-source constants**

Create `scripts/components/DamageTypes.gd`:

```gdscript
extends RefCounted
class_name DamageTypes

const GENERIC: StringName = &"generic"
const PROJECTILE: StringName = &"projectile"
const LASER: StringName = &"laser"
const ARC: StringName = &"arc"
const DASH: StringName = &"dash"
const SPIKE: StringName = &"spike"
const ALL: Array[StringName] = [PROJECTILE, LASER, ARC, DASH, SPIKE]
```

- [ ] **Step 2: Preserve the source through damage producers and enemy signals**

Use `preload("res://scripts/components/DamageTypes.gd")` in affected scripts. Change `Enemy.hit` to accept a `StringName`; change `take_damage` to an optional source and emit it. Give `Projectile` a `damage_source` defaulting to `DamageTypes.PROJECTILE`, pass it from `_try_hit`, and let `Player.take_damage` accept and ignore an optional source so enemy projectiles stay compatible. Pass `LASER`, `ARC`, `DASH`, and `SPIKE` from their corresponding calls.

The core signatures must be:

```gdscript
signal hit(source: StringName)

func take_damage(amount: float, source: StringName = DamageTypes.GENERIC) -> void:
	if health == null:
		return
	flash_timer = 0.08
	health.damage(amount)
	hit.emit(source)
```

```gdscript
var damage_source: StringName = DamageTypes.PROJECTILE

func _try_hit(node: Node) -> void:
	if not node.is_in_group(target_group) or hit_bodies.has(node):
		return
	hit_bodies.append(node)
	if node.has_method("take_damage"):
		node.take_damage(damage, damage_source)
	if pierce <= 0:
		queue_free()
	else:
		pierce -= 1
```

- [ ] **Step 3: Replace repeated laser chirps with state transitions**

In `Player.gd`, replace `signal laser_fired`, `laser_audio_timer`, and periodic emission with:

```gdscript
signal laser_active_changed(active: bool)
var laser_audio_active: bool = false

func _set_laser_audio_active(active: bool) -> void:
	if laser_audio_active == active:
		return
	laser_audio_active = active
	laser_active_changed.emit(active)
```

Call `_set_laser_audio_active(any_laser_active)` once after updating all drones, and call `_set_laser_audio_active(false)` when lasers are cleared.

- [ ] **Step 4: Add source-specific synthesis, throttling, and one loop player**

In `AudioManager.gd`, add:

```gdscript
const DamageTypes = preload("res://scripts/components/DamageTypes.gd")
const HIT_COOLDOWN := 0.055

var hit_stream_names: Dictionary = {
	DamageTypes.PROJECTILE: "hit_projectile",
	DamageTypes.LASER: "hit_laser",
	DamageTypes.ARC: "hit_arc",
	DamageTypes.DASH: "hit_dash",
	DamageTypes.SPIKE: "hit_spike",
}
var hit_cooldowns: Dictionary = {}
var laser_loop_player: AudioStreamPlayer
```

Build five distinct hit streams plus `laser_loop` in `_ready()`. Keep projectile impact short/noisy; use a new harmonic generator with soft attack and decay for laser impact; vary pitch/noise balance for arc, dash, and spike. Generate `laser_loop` as a seamless loop with low-volume harmonics and slow amplitude modulation. Create one `laser_loop_player`, assign the loop stream, set `volume_db` near `-18.0`, and add it once.

Implement cooldown and loop control:

```gdscript
func _process(delta: float) -> void:
	for source in hit_cooldowns.keys():
		hit_cooldowns[source] = maxf(0.0, float(hit_cooldowns[source]) - delta)

func play_hit(source: StringName) -> bool:
	var resolved := source if hit_stream_names.has(source) else DamageTypes.GENERIC
	if float(hit_cooldowns.get(resolved, 0.0)) > 0.0:
		return false
	hit_cooldowns[resolved] = HIT_COOLDOWN
	play(String(hit_stream_names.get(resolved, "enemy_hit")))
	return true

func set_laser_active(active: bool) -> void:
	if active and not laser_loop_player.playing:
		laser_loop_player.play()
	elif not active and laser_loop_player.playing:
		laser_loop_player.stop()
```

- [ ] **Step 5: Route signals in `Main` and `WaveDirector`**

Connect the player state once:

```gdscript
player.laser_active_changed.connect(audio.set_laser_active)
```

Forward enemy hit sources in `WaveDirector` and accept them in `Main`:

```gdscript
enemy.hit.connect(func(source: StringName) -> void:
	if get_parent().has_method("_on_enemy_hit"):
		get_parent()._on_enemy_hit(source)
)
```

```gdscript
func _on_enemy_hit(source: StringName) -> void:
	audio.play_hit(source)
```

- [ ] **Step 6: Run the focused test**

Run: `godot --headless --path . --script res://scripts/tests/BalanceTest.gd`

Expected: audio and damage-source assertions pass; the test may still fail at XP assertions until Task 3.

- [ ] **Step 7: Commit the audio unit when Git identity is available**

```powershell
git add scripts/components/DamageTypes.gd scripts/actors/Enemy.gd scripts/components/Projectile.gd scripts/components/SpikeTrap.gd scripts/actors/Player.gd scripts/systems/WaveDirector.gd scripts/systems/AudioManager.gd scripts/Main.gd scripts/tests/BalanceTest.gd
git commit -m "fix: distinguish weapon impact audio"
```

---

