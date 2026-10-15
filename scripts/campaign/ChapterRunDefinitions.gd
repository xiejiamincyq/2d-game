extends RefCounted
## Closed, implemented policies only. Planned catalog entries are not playable.
const Catalog = preload("res://scripts/systems/ChapterCatalog.gd")
const POLICIES := {
	1: {
		"scene_path": "res://scenes/campaign/nursery_chapter.tscn",
		"map": preload("res://scenes/world/mist_nursery.tscn"),
		"director": preload("res://scripts/systems/NurseryEncounterDirector.gd"),
		"intro": "两段必经遭遇 → 风险选择 → 首领。每场第5次击杀前保底血包、第8次前保底小护盾；清场选择构筑。战斗中启用2处压板，风险战4处；踩中预警0.5秒后造成20伤害，可退出橙圈避开，也可攻击摧毁80血量的压板。",
		"risk_name": "根巢",
		"route": "两段必经遭遇已完成。补给后直接迎战首领，或深入根巢换取额外构筑与金币。",
		"boss_hint": "藤鞭橙色扇区预警0.65秒；根刺先锁定落点，0.8秒后从中心依次刺出，侧刺各间隔0.12秒；种雨沿预览弹道发射。看到标记就侧移，身体要完全离开危险边界，落点不会追踪。",
	},
	2: {
		"scene_path": "res://scenes/campaign/foundry_chapter.tscn",
		"map": preload("res://scenes/world/ember_foundry.tscn"),
		"director": preload("res://scripts/systems/FoundryEncounterDirector.gd"),
		"intro": "两段必经遭遇 → 风险选择 → 首领。两段遭遇各启用10处压板，风险战16处；踩中预警0.5秒后造成20伤害，冷却1.5秒后可再次触发。压板80血量，双方攻击均可摧毁；只有遭遇战启用。",
		"risk_name": "过热工位",
		"route": "两段必经遭遇已完成。补给后直接迎战首领，或进入过热工位：敌群更密，启用16处可破坏压板，换取额外构筑与金币。",
		"boss_hint": "扇喷预警0.65秒，冲撞预警0.75秒并显示锁定路线，撞墙后停下；三个热喷口橙圈倒计时0.70秒后喷发，落点不追踪。及时侧移，身体完全离圈；无可撤离路线时跳过本招。",
	},
	3: {
		"scene_path": "res://scenes/campaign/salt_chapter.tscn",
		"map": preload("res://scenes/world/salt_waterway.tscn"),
		"director": preload("res://scripts/systems/SaltEncounterDirector.gd"),
		"intro": "两段必经遭遇 → 风险选择 → 首领。沿堤道绕过盐池；遭遇战启用2处可破坏压板，风险战4处。踩中后橙圈预警0.5秒，单次20伤害，冷却后可再次触发；离开橙圈或摧毁80血量压板可避险。",
		"risk_name": "四堤涨潮",
		"route": "两段必经遭遇已完成。补给后直接迎战首领，或进入四堤涨潮：蟹群与盐针更多、四处可破坏压板启用，换取额外构筑与金币。",
		"boss_hint": "环潮预警0.8秒，只有扩张波沿危险，可提前退入中心或向外跑开；侧钳预警0.52秒，钳尖扫掠区有轮廓；盐喷显示分叉弹道。利用闸墙挡住波沿与盐片，无普通移动退路则跳过本招。",
	},
	4: {
		"scene_path": "res://scenes/campaign/archive_chapter.tscn",
		"map": preload("res://scenes/world/luminous_archive.tscn"),
		"director": preload("res://scripts/systems/ArchiveEncounterDirector.gd"),
		"intro": "两段必经遭遇 → 风险选择 → 首领。绕开错位书架，及时摧毁孵化小怪的孢囊，留意母孢的一次分裂。遭遇战启用2处压板、风险战4处；压板80血量，踩中预警0.5秒后造成20伤害，冷却后可再次触发。",
		"risk_name": "四室菌息",
		"route": "两段必经遭遇已完成。补给后直接迎战首领，或深入四室菌息：孢群与种植者更多、四处可破坏压板启用，换取额外构筑与金币。",
		"boss_hint": "页刃显示锁定弹道，及时侧移或借书架挡住；菌封锁定两处落点，预警0.50秒后生效，身体完全离圈。孢群只在第二、第三阶段各释放一次，全场最多五个母体；留意母体分裂。",
	},
	6: {
		"scene_path": "res://scenes/campaign/rift_chapter.tscn",
		"map": preload("res://scenes/world/rift_observatory.tscn"),
		"director": preload("res://scripts/systems/RiftEncounterDirector.gd"),
		"intro": "两段必经遭遇 → 风险选择 → 首领。沿阶梯设备岛上下绕行，躲开空间切线和精英碎片。遭遇战启用2处压板、风险战4处；压板80血量，踩中预警0.5秒后造成20伤害，冷却后可再次触发。",
		"risk_name": "四区满载",
		"route": "两段必经遭遇已完成。补给后直接迎战本轮首领，或进入四区满载：切线者与精英更多、四处可破坏压板启用，换取额外构筑与金币。",
		"boss_hint": "窄束显示锁定射线，预警0.50秒后生效，及时侧移；双探针与折射预警0.45秒，提前显示落点和分批弹道。利用间隙和设备岛挡住碎片，无撤离路线则跳过本招；击败观测者完成本轮，回帐篷继续下一轮第一关。",
	},
	5: {
		"scene_path": "res://scenes/campaign/echo_chapter.tscn",
		"map": preload("res://scenes/world/echo_court.tscn"),
		"director": preload("res://scripts/systems/EchoEncounterDirector.gd"),
		"intro": "两段必经遭遇 → 风险选择 → 首领。穿过碑柱环的双出口，避开哨兵音波与幽影侧袭。遭遇战启用2处压板、风险战4处；压板80血量，踩中预警0.5秒后造成20伤害，冷却后可再次触发。",
		"risk_name": "四钟余拍",
		"route": "两段必经遭遇已完成。补给后直接迎战首领，或深入四钟余拍：哨兵与幽影更多、四处可破坏压板启用，换取额外构筑与金币。",
		"boss_hint": "钟槌短窄路线预警0.42秒；双坠与冠钟预警0.36秒，显示往返路径或分叉弹道，方向不追踪。冠钟三奏发射三对音钉；利用碑柱挡住投射物，上一招飞弹结束后才开始下一招。",
	},
}
static func get_definition(chapter: int) -> Dictionary:
	if not POLICIES.has(chapter): return {}
	var result: Dictionary = POLICIES[chapter].duplicate()
	result.merge(Catalog.get_chapter(chapter))
	return result
