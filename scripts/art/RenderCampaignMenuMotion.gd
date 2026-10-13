extends SceneTree
## Real native menu frames; isolated models, not OS input or performance.
const Menu = preload("res://scripts/ui/CampaignStartScreen.gd")
const Static = preload("res://scripts/ui/CampaignBackdrop.gd")
const Progress = preload("res://scripts/systems/CampaignProgress.gd")
const ORIGINAL := "res://build/diagnostics/campaign-goal/f9-menu-motion-static-original-v1/StaticBackdrop.gd"
const ORIGINAL_SHA := "e6727ffef4e848e2a4f4c77159cafab0d63463cb6b6b80c26bdb972003307251"
var checks := 0
var failures := 0
var captures: Array[Dictionary] = []
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("TEST FAIL: RenderCampaignMenuMotion " + message)
func _initialize() -> void: call_deferred("_run")
func render(view: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func changed(a: Image, b: Image, area: Rect2i) -> int:
	var count := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			count += int(a.get_pixel(x, y) != b.get_pixel(x, y))
	return count
func capture(pixels: Image, path: String) -> void:
	var opaque := pixels.get_format() == Image.FORMAT_RGBA8
	var bytes := pixels.get_data()
	if opaque:
		for offset in range(3, bytes.size(), 4):
			if bytes[offset] != 255:
				opaque = false
				break
	check(opaque, "menu background has transparent pixels")
	check(pixels.save_png(path) == OK, "capture write failed")
	captures.append({"path":path.trim_prefix("res://"),"sha256":FileAccess.get_sha256(path),"size":[pixels.get_width(),pixels.get_height()],"opaque_background":opaque})
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_valid_identifier() or DisplayServer.get_name() == "headless": quit(1); return
	var folder := "res://build/diagnostics/campaign-goal/" + args[0] + "/"
	if DirAccess.dir_exists_absolute(folder) or not FileAccess.file_exists(ORIGINAL): quit(1); return
	check(FileAccess.get_sha256(ORIGINAL) == ORIGINAL_SHA, "retained static original was replaced")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(folder)
	var sources := {}
	for path in ["scripts/ui/CampaignBackdrop.gd","scripts/ui/CampaignAnimatedBackdrop.gd","scripts/ui/CampaignStartScreen.gd","scripts/ui/CampaignMenuTheme.gd","scripts/art/RenderCampaignMenuMotion.gd",ORIGINAL.trim_prefix("res://")]:
		sources[path] = FileAccess.get_sha256("res://" + path)
	var view := SubViewport.new()
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	for width in [960,1280,1920]:
		view.size = Vector2i(width,width * 9 / 16)
		var old: Control = load(ORIGINAL).new()
		old.size = view.size
		view.add_child(old)
		var original := await render(view)
		old.free()
		var retained := Static.new()
		retained.size = view.size
		view.add_child(retained)
		var static_pixels := await render(view)
		check(original.get_data() == static_pixels.get_data(), "static source hooks changed retained artwork")
		retained.free()
		var menu = Menu.new()
		menu.process_mode = Node.PROCESS_MODE_ALWAYS
		menu.size = view.size
		view.add_child(menu)
		menu.apply_viewport_size(view.size)
		menu.set_campaign(Progress.new(),[1,2,3,4,5,6],"")
		var art: Control = menu.get_child(0)
		art.set_process(false)
		art.set("_motion_seconds",0.0)
		var zero := await render(view)
		var control_rects: Array[Rect2] = []
		for item in menu.get_active_controls(): control_rects.append(item.get_global_rect())
		for seconds in [0.0,3.0,9.0]:
			art.set("_motion_seconds",seconds); art.queue_redraw()
			var pixels := await render(view)
			check(changed(zero,pixels,Rect2i(0,0,width * 520 / 1280,view.size.y)) == 0, "animation altered left reading/input zone")
			if seconds > 0: check(pixels.get_data() != zero.get_data(), "native pixels did not animate")
			var controls: Array[Control] = menu.get_active_controls()
			for index in controls.size(): check(controls[index].get_global_rect() == control_rects[index], "control geometry moved")
			capture(pixels,folder + "%d-cover-%d.png" % [width,int(seconds)])
		for page in [menu.Page.CHAPTERS,menu.Page.SETTINGS,menu.Page.LEGACY]:
			menu.show_page(page)
			capture(await render(view),folder + "%d-page-%d.png" % [width,page])
		if width == 1280:
			menu.show_page(menu.Page.COVER)
			art.set_process(true)
			var first := await render(view)
			var start_clock: float = art.get("_motion_seconds")
			for _frame in 60: await process_frame; await RenderingServer.frame_post_draw
			var last := view.get_texture().get_image()
			check(art.get("_motion_seconds") > start_clock and last.get_data() != first.get_data(), "actual scheduled process did not render moving pixels")
			capture(last,folder + "1280-automatic.png")
		menu.free()
	view.free()
	await process_frame
	for path in sources: check(FileAccess.get_sha256("res://" + path) == sources[path], "source changed during render")
	var report := {"passed":failures == 0,"checks":checks,"sources":sources,"captures":captures,"scope":"Three actual native viewport sizes, static-original exact pixel comparison, controlled0/3/9s poses and60 actual scheduled menu frames. Left reading zone and button geometry unchanged. Isolated component models, no user files, not Main normal input, OS mouse, performance or human acceptance."}
	var file := FileAccess.open(folder + "report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	if not failures: print("TEST PASS: RenderCampaignMenuMotion %d" % checks)
	quit(1 if failures else 0)
