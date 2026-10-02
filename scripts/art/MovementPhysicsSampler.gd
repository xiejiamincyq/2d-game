extends Node

# Diagnostic-only taps bracket the production physics callbacks. No render-frame
# await is allowed between input and sampling: one rendered frame may have 0..N ticks.
signal finished

class PhysicsTap extends Node:
	var callback: Callable
	func _physics_process(delta: float) -> void:
		callback.call(delta)

const DIRECTIONS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
const DASH_STEPS := [180, 360, 540, 720, 900, 1080]
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "fire", "dash_melee"]
var scene: Node
var view: SubViewport
var config: Dictionary
var read_state: Callable
var samples: Array[Dictionary] = []
var valid := true
var done := false
var terminal := "invalid_sampling"
var terminal_phase := "not_started"
var first_frame := 0
var previous_frame := 0
var started_usec := 0
var ended_usec := 0
var simulated_seconds := 0.0
var travelled := 0.0
var previous_position := Vector2.ZERO
var pending: Dictionary = {}
var terminal_state: Dictionary = {}
var health_loss := 0.0
var shield_loss := 0.0
var previous_health := 0.0
var previous_shield := 0.0

func start() -> void:
	previous_position = scene.player.global_position
	previous_health = scene.player.health.current_health
	previous_shield = scene.player.shield
	scene.player.health_changed.connect(_health_changed)
	scene.player.shield_changed.connect(_shield_changed)
	started_usec = Time.get_ticks_usec()
	for phase in [-1, 1]:
		var tap := PhysicsTap.new()
		tap.process_mode = Node.PROCESS_MODE_ALWAYS
		tap.process_physics_priority = phase * 100000
		tap.callback = _before_physics if phase < 0 else _after_physics
		add_child(tap)

func _before_physics(delta: float) -> void:
	if done:
		return
	if scene.game_over:
		terminal_phase = "before_input"
		_finish("death") # Physics-server contacts can end the run before this tap.
		return
	if get_tree().paused or not scene.player.is_physics_processing():
		terminal_phase = "before_input"
		valid = false
		_finish("invalid_sampling")
		return
	var frame := Engine.get_physics_frames()
	if samples.is_empty():
		first_frame = frame - 1
		previous_frame = first_frame
	var index := samples.size()
	var direction: Vector2 = DIRECTIONS[(index / 75) % DIRECTIONS.size()]
	for action in ACTIONS:
		Input.action_release(action)
	Input.action_press("fire")
	if direction.x != 0:
		Input.action_press("move_right" if direction.x > 0 else "move_left")
	if direction.y != 0:
		Input.action_press("move_down" if direction.y > 0 else "move_up")
	var dash_requested: bool = config.mode == "dash" and index + 1 in DASH_STEPS
	if dash_requested:
		Input.action_press("dash_melee")
	var aim_world: Vector2 = scene.player.global_position + direction * 480.0
	var before: Vector2 = scene.player.global_position
	var mouse := InputEventMouseMotion.new()
	mouse.position = view.canvas_transform * aim_world
	view.push_input(mouse, true)
	var actual_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	pending = {"step": index + 1, "pre_physics_frame": frame, "pre_physics_delta": delta,
		"position_before": [before.x, before.y], "requested_motion_pixels": scene.player.get_effective_move_speed() * delta,
		"motion_budget_basis": "walk_speed_even_during_dash",
		"process_frame": Engine.get_process_frames(), "input_pre": [actual_input.x, actual_input.y],
		"fire_pressed_pre": Input.is_action_pressed("fire"),
		"dash_pressed_pre": Input.is_action_pressed("dash_melee"), "dash_requested": dash_requested,
		"mouse_injected_physics_frame": frame, "mouse_viewport": [mouse.position.x, mouse.position.y],
		"aim_world_requested": [aim_world.x, aim_world.y], "scale_before_physics": Engine.time_scale}
	valid = valid and frame == previous_frame + 1 and actual_input.is_equal_approx(direction)
	valid = valid and (config.track != "D" or is_equal_approx(Engine.time_scale, 1.0))

func _after_physics(delta: float) -> void:
	if done:
		return
	if pending.is_empty():
		valid = false
		_finish("invalid_sampling")
		return
	var frame := Engine.get_physics_frames()
	var point: Vector2 = scene.player.global_position
	var actual_input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := Vector2(pending.input_pre[0], pending.input_pre[1])
	var aim := Vector2.RIGHT.rotated(scene.player.gun_angle)
	var aim_validated: bool = not scene.game_over
	valid = valid and frame == pending.pre_physics_frame and frame == previous_frame + 1
	valid = valid and is_equal_approx(delta, pending.pre_physics_delta) and actual_input.is_equal_approx(direction)
	if aim_validated:
		valid = valid and not get_tree().paused and scene.player.is_physics_processing() and scene.run_state == scene.RunState.PLAYING
		valid = valid and aim.dot(direction) >= 0.9999
	valid = valid and is_finite(delta) and delta > 0.0 and delta <= 1.0 / 60.0 + 0.000001
	simulated_seconds += delta
	travelled += previous_position.distance_to(point)
	var state: Dictionary = read_state.call()
	state.merge(pending)
	state.merge({"physics_frame": frame, "post_physics_frame": frame, "physics_delta": delta,
		"simulated_seconds": simulated_seconds, "wall_seconds": float(Time.get_ticks_usec() - started_usec) / 1000000.0,
		"input": [actual_input.x, actual_input.y], "actual_aim": [aim.x, aim.y], "aim_validated": aim_validated,
		"scale_after_physics": Engine.time_scale, "spawn_rng_state": str(scene.wave_director.spawn_rng.state),
		"remaining_enemies": scene.wave_director.active_enemies.size()})
	samples.append(state)
	pending = {}
	previous_position = point
	previous_frame = frame
	if not valid or scene.game_over or samples.size() >= int(config.steps):
		terminal_phase = "after_callbacks"
		_finish("invalid_sampling" if not valid else ("death" if scene.game_over else "step_budget"))

func _finish(reason: String) -> void:
	done = true
	terminal = reason
	ended_usec = Time.get_ticks_usec()
	terminal_state = read_state.call().duplicate(true) # Before PAUSED clears runtime modifiers.
	for action in ACTIONS:
		Input.action_release(action)
	# The SceneTree owner resumes synchronously on this signal and freezes before
	# its first await. Do not defer emission: another physics tick may run meanwhile.
	finished.emit()

func _health_changed(current: float, _maximum: float) -> void:
	if not done:
		health_loss += maxf(0.0, previous_health - current)
	previous_health = current

func _shield_changed(current: float, _maximum: float) -> void:
	if not done:
		shield_loss += maxf(0.0, previous_shield - current)
	previous_shield = current
