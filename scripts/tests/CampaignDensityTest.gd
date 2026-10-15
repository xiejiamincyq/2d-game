extends SceneTree
## Real seeded layouts and physical colliders, not counts of decorative sprites.
const Definitions=preload("res://scripts/campaign/ChapterRunDefinitions.gd")
const SEEDS=[0,1,30,521,20261011,-1]
const MIN_COUNTS=[26,26,22,32]
const MAX_COUNTS=[28,28,22,32]
const ECHO_SOURCE_SHA="27399c73777778ac7db1acde672b01b9da2a478378e5f94830e253cee0dac102"
const ECHO_SEED521_SHA="d23e38539f927c49a14aa575e281198be891c0ad8a00e481da26133a91ec2283"
## Captured from actual pre-change generation in density-red-v1.log, SEEDS order.
const BASELINE_AREAS=[
	[354563.3671875,386570.873046875,345344.622070313,352873.170898438,367766.3515625,436535.548828125],
	[401150.779296875,421976.7265625,382783.169921875,425225.137695313,414060.965820313,455823.296875],
	[805013.0,917090.0,918560.0,863838.0,747465.0,932978.0],
	[349336.0,340132.0,342472.0,337064.0,345384.0,336440.0]
]
const AREA_SCALE=[1.2,1.2,1.15,1.2]
const ROUTES=[
	[Vector2(0,-500),Vector2(-1120,0),Vector2(1120,0),Vector2(0,680)],
	[Vector2(0,-660),Vector2(-1360,0),Vector2(1360,0),Vector2(0,800),Vector2(-760,700),Vector2(760,-700)],
	[Vector2(0,-672),Vector2(-1472,0),Vector2(1472,0),Vector2(0,832),Vector2(-1504,896),Vector2(1504,-896)],
	[Vector2(0,-672),Vector2(-1504,0),Vector2(1504,0),Vector2(0,864),Vector2(-1504,864),Vector2(1504,-864)]
]
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("TEST FAIL: CampaignDensityTest "+label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	check(FileAccess.get_sha256("res://scripts/world/EchoArenaLayout.gd")==ECHO_SOURCE_SHA,"fifth generator untouched")
	for chapter in range(1,5):
		var fingerprints: Dictionary={}
		for seed_value in SEEDS:
			var definition: Dictionary=Definitions.get_definition(chapter)
			var map: Node2D=definition.map.instantiate(); map.map_seed=seed_value; root.add_child(map)
			var layout: Node2D=map.layout; var entries: Array=layout.get_obstacle_descriptors()
			var footprint_area:=0.0
			for entry in entries: footprint_area+=Rect2(entry.rect).get_area()
			print("DENSITY_SAMPLE ",JSON.stringify({"chapter":chapter,"seed":seed_value,"count":entries.size(),"area":footprint_area}))
			check(entries.size()>=MIN_COUNTS[chapter-1] and entries.size()<=MAX_COUNTS[chapter-1],"chapter%d seed%d meaningful new density, not empty-map connectivity"%[chapter,seed_value])
			check(footprint_area>=BASELINE_AREAS[chapter-1][SEEDS.find(seed_value)]*AREA_SCALE[chapter-1],"actual occupied area increases, not merely splitting old walls into more descriptors")
			check(layout.get_child_count()==entries.size(),"actual physical structure count matches navigation")
			check(layout.is_position_walkable(Vector2.ZERO,56) and layout.is_position_walkable(layout.BOSS_CENTER,56),"spawn/Boss pockets remain clear")
			for radius in [16.9,56.0]:
				for target in ROUTES[chapter-1]: check(layout.is_reachable(Vector2.ZERO,target,radius),"chapter%d seed%d radius%.1f still has required wide route"%[chapter,seed_value,radius])
			for index in entries.size():
				var entry: Dictionary=entries[index]; var rect: Rect2=entry.rect
				check(layout.world_bounds.grow(-72).encloses(rect) and not rect.intersects(layout.SPAWN_BUFFER) and not rect.intersects(layout.BOSS_BUFFER),"density respects map edges and reserved areas")
				var wall: Node2D=layout.get_child(index); var collider: CollisionShape2D=wall.get_node("CollisionShape2D")
				check(collider.shape.size==rect.size and wall.health.current_health>9 and wall.is_in_group(&"destructible_terrain") and not wall.is_in_group(&"enemies"),"added cover is real destructible terrain, not fake enemies/decor")
				if chapter==4 and entry.get("interior",false):
					var room: Rect2=layout.get_chambers()[entry.chamber]
					var side_gap:=minf(rect.position.x-room.position.x-52,room.end.x-52-rect.end.x)
					var vertical_gap:=minf(rect.position.y-room.position.y-52,room.end.y-52-rect.end.y)
					check(is_zero_approx(side_gap) and is_zero_approx(vertical_gap),"corner furniture joins wall faces instead of leaving thin valid-but-unroutable pockets")
				for other in entries.slice(index+1):
					check(not rect.intersects(other.rect),"solid pieces never overlap")
					if chapter<=3: check(not rect.grow(64).intersects(other.rect),"new small cover retains64px minimum separation")
			var fingerprint:=JSON.stringify(entries); fingerprints[fingerprint]=true
			map.generate_map(seed_value)
			check(JSON.stringify(layout.get_obstacle_descriptors())==fingerprint,"same seed reproduces full denser map")
			map.free(); await process_frame
		check(fingerprints.size()==SEEDS.size(),"each run seed still changes complete layout")
	var fifth: Node2D=Definitions.get_definition(5).map.instantiate(); fifth.map_seed=521; root.add_child(fifth)
	print("ECHO_DESCRIPTOR_SHA ",JSON.stringify(fifth.layout.get_obstacle_descriptors()).sha256_text())
	check(JSON.stringify(fifth.layout.get_obstacle_descriptors()).sha256_text()==ECHO_SEED521_SHA,"fifth complete layout bytes unchanged for reference seed")
	fifth.free(); await process_frame
	if failures==0: print("TEST PASS: CampaignDensityTest %d"%checks)
	quit(1 if failures else 0)
