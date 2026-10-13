extends "RenderArchiveBossSeal.gd"
## Whole actual Actor motion audit + genuine chapter births/victory. Controlled,
## not ordinary-input progression, save/unlock or a six-chapter performance proof.
const Director = preload("res://scripts/systems/ArchiveEncounterDirector.gd")
const Growth = preload("res://scripts/systems/UpgradeSystem.gd")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].is_valid_identifier(): quit(1); return
	output = "res://build/diagnostics/campaign-goal/"+args[0]+"/"
	check(DisplayServer.get_name()!="headless" and not DirAccess.dir_exists_absolute(output),"fresh GPU evidence required")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	var sources := {}
	for path in ["scripts/art/RenderArchiveBossComplete.gd","scripts/art/RenderArchiveBossSeal.gd","scripts/actors/ArchiveArchivistBoss.gd","scripts/actors/OverseerBoss.gd","scripts/actors/Player.gd","scripts/actors/SplittingMoteEnemy.gd","scripts/actors/CapsulePlanterEnemy.gd","scripts/campaign/RegionalEnemyFactory.gd","scripts/systems/ArchiveEncounterDirector.gd","scripts/systems/ChapterEncounterDirector.gd","scripts/systems/WaveDirector.gd","scripts/components/SporeArchivistAttackDirector.gd","scripts/components/ArchiveSealAttack.gd","scripts/components/ArchivePageProjectile.gd","scripts/components/NativeProjectileOriginSafety.gd","scripts/components/NativeSporeArchivistMotion.gd","scripts/components/NativeActorView.gd","scripts/effects/EnemyWorldStatus.gd","scripts/world/ArchiveMap.gd","scenes/world/luminous_archive.tscn","scenes/actors/native/spore_archivist_paper_v2.tscn","assets/art/actors/native/spore_archivist_motion_v2.tres","assets/art/shaders/dasher_hit_flash.gdshader"]:
		sources[path] = FileAccess.get_sha256("res://"+path); check(sources[path].length()==64,"missing source "+path)
	make_viewport(Vector2i(320,320))
	var shots := Node2D.new(); viewport.add_child(shots)
	var target := Player.new(); target.position = Vector2(300,180); viewport.add_child(target)
	target.visible = false; target.set_physics_process(false)
	var boss := Boss.new(); boss.setup(4,shots,target); boss.position = Vector2(160,180)
	viewport.add_child(boss); boss.set_physics_process(false); boss.world_status.visible = false
	var view := boss.get_visual_node()
	var samples: Array[Dictionary] = []
	# Death is terminal even in the production view; sample it last, never reset it.
	for family in ["page","seal","brood","base"]:
		var clips: Array = ["idle","walk","hit","entrance","death"] if family=="base" else [family+"_warning",family+"_attack",family+"_recovery"]
		var sheet := Image.create(1920,320*clips.size(),false,Image.FORMAT_RGBA8); sheet.fill(Color("304138"))
		for row in clips.size():
			var clip: String = clips[row]; var column := 0
			for left in [false,true]:
				view.set_facing_left(left)
				for fraction in [0.15,0.55,0.85]:
					check(view.sample_clip(clip,view.player.get_animation(clip).length*fraction),"sample "+clip)
					for flash in [0.0,0.35]:
						boss.boss_flash_material.set_shader_parameter("flash_amount",flash)
						var image := await pixels(); var opaque := 0; var partial := 0; var edge := 0
						for y in 320:
							for x in 320:
								var alpha := image.get_pixel(x,y).a
								opaque += 1 if alpha>=0.99 else 0
								partial += 1 if alpha>0.01 and alpha<0.99 else 0
								edge += 1 if alpha>0.01 and (x==0 or x==319 or y==0 or y==319) else 0
						check(opaque>3000 and partial==0 and edge==0,"actual body opacity/crop "+clip)
						samples.append({"clip":clip,"left":left,"fraction":fraction,"flash":flash,"opaque":opaque,"partial":partial,"edge":edge})
						if flash==0: sheet.blend_rect(image,Rect2i(0,0,320,320),Vector2i(column*320,row*320))
					column += 1
		check(sheet.save_png(output+family+"-motion.png")==OK,"motion sheet "+family)
		captures[family+"-motion"] = FileAccess.get_sha256(output+family+"-motion.png")
	viewport.free(); await process_frame
	make_viewport(Vector2i(1280,720),false)
	var map = load("res://scenes/world/luminous_archive.tscn").instantiate(); map.map_seed = 521; viewport.add_child(map)
	var camera := Camera2D.new(); camera.position = Vector2(0,-672); viewport.add_child(camera); camera.make_current()
	var enemies := Node2D.new(); shots = Node2D.new(); var portals := Node2D.new(); shots.z_index = 50
	for layer in [enemies,shots,portals]: viewport.add_child(layer)
	target = Player.new(); target.position = Vector2(240,-672); target.world_bounds = map.layout.world_bounds
	viewport.add_child(target); target.set_physics_process(false)
	var growth := Growth.new(); viewport.add_child(growth); growth.setup(target)
	var director := Director.new(); viewport.add_child(director); director.set_process(false)
	check(director.bind_spore_field(map.spore_field) and director.start_run(521,target,enemies,shots,portals,growth,map.layout),"actual chapter start")
	director.spawn_queue.clear(); director._prepare_boss(); check(director.begin_boss(),"actual Boss boundary")
	boss = director.get_active_boss(); boss.set_physics_process(false)
	var combat = boss.get_attack_director(); combat.advance(1.4); boss._update_entrance_reveal(); combat.attack_gap = 99
	boss.take_damage(boss.BASE_MAX_HEALTH*0.4); combat.advance(0.65)
	boss.flash_timer = 0; boss.boss_flash_material.set_shader_parameter("flash_amount",0)
	check(combat.start_action(&"brood"),"phase2 real warning")
	combat.advance(0.13); await capture("brood-warning")
	check(boss.should_show_attack_marker() and enemies.get_child_count()==1,"warning births or missing head")
	combat.advance(0.13)
	for actor in director.get_active_enemies(): actor.set_physics_process(false)
	check(director.get_active_enemies().size()==3 and director.reinforcements_committed==2,"actual phase2 mothers")
	await capture("brood-phase2")
	boss.take_damage(boss.BASE_MAX_HEALTH*0.35); combat.advance(0.65)
	boss.flash_timer = 0; boss.boss_flash_material.set_shader_parameter("flash_amount",0)
	check(combat.start_action(&"brood"),"phase3 real warning")
	combat.advance(0.26)
	for actor in director.get_active_enemies(): actor.set_physics_process(false)
	check(director.get_active_enemies().size()==6 and director.reinforcements_committed==5 and director.active_portals.is_empty(),"actual phase3 finite mothers")
	await capture("brood-phase3")
	var points: Array[Vector2] = []
	for actor in director.get_active_enemies():
		if actor!=boss: points.append(actor.global_position); check(actor.should_show_health_bar() and actor.modulate.a==1 and actor.scale==Vector2.ONE,"actual mother body/bar")
	var clears := [0]; director.chapter_cleared.connect(func(chapter): clears[0] += 1 if chapter==4 else 0)
	boss.take_damage(boss.health.current_health+1); await process_frame; await process_frame
	check(clears[0]==1 and director.state==director.State.CLEARED and director.get_attack_targets().is_empty() and director.get_active_enemies().is_empty(),"true victory leaves live bodies")
	await capture("victory-cleanup")
	viewport.free(); await process_frame
	for path in sources: check(FileAccess.get_sha256("res://"+path)==sources[path],"source drift "+path)
	var report := {"passed":failures==0,"checks":checks,"actor_samples":samples,"sources":sources,"captures":captures,"mother_positions":points,"scope":"168 actual Actor samples: 14 clips, three times, both facings, normal/hit-flash. Actual Archive map/Director/health phases produce 2+3 real native mothers, followed by true lethal Boss cleanup. Controlled lifecycle, no ordinary input, unlock/save, all-chapter readiness or performance proof."}
	var file := FileAccess.open(output+"report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("ARCHIVE COMPLETE GPU %s: %d checks, %d actual Actor poses, 2+3 genuine mothers and true victory"%["PASS" if failures==0 else "FAIL",checks,samples.size()])
	quit(0 if failures==0 else 1)
