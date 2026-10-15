extends Node2D
## Original code-native feedback in the existing ink/cream/mint language.
## Child-only drawing: never modulate, displace or resize the physical owner.
const INK:=Color("123b3b")
const PAPER:=Color("f3eddc")
const MINT:=Color("9bd7bd")
const FLASH_SECONDS:=0.08
var health_ratio:=1.0
var flash_remaining:=0.0
var damage_level:=0
var solid_rect:=Rect2()
var bar_rect:=Rect2()
var bar: Node2D

func configure(body: Node2D) -> void:
	var collider: CollisionShape2D=body.get_node("CollisionShape2D")
	solid_rect=Rect2(collider.position-collider.shape.size/2,collider.shape.size)
	var silhouette: Variant=body.get("occlusion_rect")
	var top: float=silhouette.position.y if silhouette is Rect2 else solid_rect.position.y
	bar_rect=Rect2(Vector2(-28,top-12),Vector2(56,6))

func _ready() -> void:
	z_index=1
	bar=Node2D.new(); bar.name="HealthBar"
	bar.z_as_relative=false; bar.z_index=18 # Under player silhouette and hostile cues.
	bar.draw.connect(_draw_bar); add_child(bar)
	bar.visible=visible
	set_process(flash_remaining>0)

func refresh(current: float,maximum: float) -> void:
	var previous:=health_ratio
	health_ratio=clampf(current/maxf(maximum,0.001),0,1)
	damage_level=3 if health_ratio<=0.25 else 2 if health_ratio<=0.5 else 1 if health_ratio<=0.75 else 0
	visible=health_ratio>0 and health_ratio<1
	if is_instance_valid(bar): bar.visible=visible
	if health_ratio<previous and visible: flash_remaining=FLASH_SECONDS
	if not visible: flash_remaining=0
	set_process(flash_remaining>0)
	queue_redraw()
	if is_instance_valid(bar): bar.queue_redraw()

func _process(delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	flash_remaining=maxf(0,flash_remaining-delta)
	queue_redraw()
	if flash_remaining==0: set_process(false)

func _draw_bar() -> void:
	draw_health_bar(bar)

func draw_health_bar(canvas: Node2D) -> void:
	canvas.draw_rect(bar_rect,INK)
	canvas.draw_rect(Rect2(bar_rect.position+Vector2.ONE,Vector2(54,4)),Color("36524a"))
	canvas.draw_rect(Rect2(bar_rect.position+Vector2.ONE,Vector2(54*health_ratio,4)),MINT if health_ratio>0.25 else PAPER)

func _draw() -> void:
	if flash_remaining>0:
		var inset:=minf(2,minf(solid_rect.size.x,solid_rect.size.y)*0.2)
		draw_rect(solid_rect.grow(-inset),Color(PAPER,flash_remaining/FLASH_SECONDS*0.8),false,2)
	var safe:=solid_rect.grow(-minf(6,minf(solid_rect.size.x,solid_rect.size.y)*0.2))
	for index in damage_level:
		var center:=solid_rect.get_center()+Vector2((index-1)*solid_rect.size.x*0.23,(index%2)*solid_rect.size.y*0.15)
		var points:=PackedVector2Array()
		for offset in [Vector2(-9,-14),Vector2(-2,-3),Vector2(-5,3),Vector2(8,13)]: points.append((center+offset).clamp(safe.position,safe.end))
		draw_polyline(points,INK,3,true)
		draw_polyline(points,Color(PAPER,0.65),1,true)
