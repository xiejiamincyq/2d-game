extends SceneTree
const Definitions = preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const Backdrop = preload("res://scripts/world/ChapterMapBackdrop.gd")
var assertions := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	assertions+=1
	if not ok:
		failures+=1
		push_error("TEST FAIL: ChapterMapBackdropTest "+label)
func _initialize() -> void: call_deferred("run_checks")
func run_checks() -> void:
	await process_frame
	var colors: Array[Color] = []
	for chapter in range(1,7):
		var view := SubViewport.new()
		view.size=Vector2i(1280,720)
		root.add_child(view)
		var map: Node2D = Definitions.get_definition(chapter).map.instantiate()
		map.map_seed=521
		view.add_child(map)
		var area: Rect2 = map.layout.world_bounds
		var obstacles := JSON.stringify(map.layout.get_obstacle_descriptors())
		var colliders := map.find_children("*","CollisionObject2D",true,false).size()
		var backdrop: Node2D = map.get_node_or_null("MapBackdrop")
		check(backdrop!=null,"actual map lacks native backdrop")
		if backdrop!=null:
			var canvas: CanvasLayer = backdrop.get_node("OutsidePaper")
			var fill: ColorRect = canvas.get_node("Fill")
			check(backdrop.bounds==area and backdrop.z_index<map.floor_view.z_index,"backdrop covers original floor")
			check(canvas.layer<0 and fill.mouse_filter==Control.MOUSE_FILTER_IGNORE,"background blocks world or UI input")
			check(fill.anchor_left==0 and fill.anchor_top==0 and fill.anchor_right==1 and fill.anchor_bottom==1,"background not viewport-sized")
			check(backdrop.process_mode==Node.PROCESS_MODE_DISABLED and backdrop.find_children("*","CollisionObject2D",true,false).is_empty(),"render-only additive acquired gameplay processing/colliders")
			check(is_equal_approx(fill.color.a,1.0) and fill.color==Backdrop.PALETTES[chapter-1],"region color/opacity wrong")
			colors.append(fill.color)
			var original := backdrop.get_instance_id()
			Backdrop.install(map,area,chapter)
			check(map.get_node("MapBackdrop").get_instance_id()==original and backdrop.get_child_count()==1,"reconfigure duplicates backgrounds")
			map.generate_map(521)
			await process_frame
			check(map.get_node("MapBackdrop").get_instance_id()==original,"seed generation replaces/leaks background")
		check(map.layout.world_bounds==area and JSON.stringify(map.layout.get_obstacle_descriptors())==obstacles,"background alters seeded terrain")
		check(map.find_children("*","CollisionObject2D",true,false).size()==colliders,"background alters physical collider count")
		view.free()
		await process_frame
	for index in colors.size():
		for other in range(index+1,colors.size()): check(colors[index]!=colors[other],"regional palettes collapsed")
	if failures==0: print("TEST PASS: ChapterMapBackdropTest %d"%assertions)
	quit(1 if failures else 0)
