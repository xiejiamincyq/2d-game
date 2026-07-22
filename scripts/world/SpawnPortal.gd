extends Node2D
class_name SpawnPortal

signal burst_started(portal: Node)
signal closed(portal: Node)

enum State { WARNING, BURST, CLOSED }

const CYAN := Color("33fff2")
const MAGENTA := Color("f559bf")
const ORANGE := Color("ff571f")

var state: int = State.CLOSED
var warning_duration := 0.7
var burst_duration := 0.45
var state_time := 0.0

func _ready() -> void:
	visible = state != State.CLOSED

func configure(world_position: Vector2, warning_seconds: float = 0.7, burst_seconds: float = 0.45) -> void:
	global_position = world_position
	warning_duration = maxf(0.01, warning_seconds)
	burst_duration = maxf(0.01, burst_seconds)
	state_time = 0.0
	state = State.WARNING
	visible = true
	queue_redraw()

func advance(delta: float) -> bool:
	if state == State.CLOSED:
		return false
	state_time += maxf(0.0, delta)
	var duration := warning_duration if state == State.WARNING else burst_duration
	if state_time + 0.0001 < duration:
		queue_redraw()
		return false
	state_time = 0.0
	if state == State.WARNING:
		state = State.BURST
		burst_started.emit(self)
	else:
		state = State.CLOSED
		visible = false
		closed.emit(self)
	queue_redraw()
	return true

func _process(delta: float) -> void:
	advance(delta)

func _draw() -> void:
	if state == State.CLOSED:
		return
	var pulse := 0.5 + 0.5 * sin(state_time * 12.0)
	var radius := 30.0 if state == State.WARNING else 42.0
	var inner_color := Color(MAGENTA, 0.24 + pulse * 0.12)
	var ring_color := Color(ORANGE if state == State.WARNING else CYAN, 0.72 + pulse * 0.22)
	draw_circle(Vector2.ZERO, radius * (0.72 + pulse * 0.08), inner_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, ring_color, 2.5)
	draw_arc(Vector2.ZERO, radius * 0.52, -state_time * 4.0, TAU - state_time * 4.0, 18, Color(CYAN, 0.8), 1.5)
