extends SceneTree

const Chapter = preload("res://scenes/campaign/nursery_chapter.tscn")
const Shot = preload("res://scripts/components/Projectile.gd")
const Support = preload("res://scripts/tests/TestSupport.gd")
var assertions := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("TEST FAIL: NurseryProjectileDropTest " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var chapter = Chapter.instantiate()
	chapter.audio_enabled = false
	chapter.campaign_store_path = "user://nursery_drop_%d.json" % OS.get_process_id()
	root.add_child(chapter)
	for frame in 360:
		if not chapter.player.is_entrance_active():
			break
		await process_frame
	chapter.ui.proceed_button.pressed.emit()
	chapter.director.set_process(false)
	chapter.director._spawn_enemy_at(0, Vector2(110, 0))
	var enemy = chapter.director.get_active_enemies().back()
	var value: int = enemy.coin_value
	var shot := Shot.new()
	shot.damage = 1e9 # Fixture damage only; still the actual body_entered path.
	shot.position = enemy.global_position
	chapter.projectiles.add_child(shot)
	for frame in 120:
		await physics_frame
		if chapter.growth.coins > 0:
			break
	check(chapter.kills == 1 and chapter.growth.coins == value, "real projectile kill did not deliver exactly one deferred coin drop")
	paused = false
	Support.stop_audio(chapter.audio)
	chapter.free()
	await process_frame
	if failures == 0:
		print("TEST PASS: NurseryProjectileDropTest %d" % assertions)
	quit(1 if failures > 0 else 0)
