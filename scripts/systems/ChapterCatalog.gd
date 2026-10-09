extends RefCounted
class_name ChapterCatalog

const CHAPTER_COUNT := 6
# Content IDs describe planned chapter profiles, not yet integrated encounters.
const CHAPTERS: Array[Dictionary] = [
	{
		"id": 1, "name": "雾苔苗圃", "theme_id": "mist_nursery",
		"map_profile_id": "root_beds", "enemy_family_id": "rootbound",
		"boss_id": "vine_crown", "boss_name": "藤冠守卫", "mechanic_id": "root_blockade",
		"enemy_roles": ["root_pursuer", "spore_spitter"],
		"description": "错位植床与树根之间，辨识孢子弹道并留出绕行路线。",
	},
	{
		"id": 2, "name": "余烬铸坊", "theme_id": "ember_foundry",
		"map_profile_id": "furnace_lanes", "enemy_family_id": "emberforged",
		"boss_id": "furnace_warden", "boss_name": "炉心督工", "mechanic_id": "heat_vents",
		"enemy_roles": ["slag_charger", "spark_gunner"],
		"description": "借管道遮挡避开冲撞，在间歇热区之间寻找安全节奏。",
	},
	{
		"id": 3, "name": "盐蚀水道", "theme_id": "salt_culvert",
		"map_profile_id": "linked_causeways", "enemy_family_id": "saltcarapace",
		"boss_id": "tide_shell", "boss_name": "潮壳巨兽", "mechanic_id": "tidal_bands",
		"enemy_roles": ["flanking_crab", "salt_needle"],
		"description": "相连堤道带来侧向包围风险，预留浪带与盐针的躲避空间。",
	},
	{
		"id": 4, "name": "菌光档案", "theme_id": "luminous_archive",
		"map_profile_id": "shelf_chambers", "enemy_family_id": "sporekeepers",
		"boss_id": "spore_archivist", "boss_name": "藏孢书记", "mechanic_id": "spore_nests",
		"enemy_roles": ["capsule_planter", "splitting_mote"],
		"description": "穿越书架隔断与侧室，及时处理孢囊避免主路被菌群封锁。",
	},
	{
		"id": 5, "name": "回声墓庭", "theme_id": "echo_court",
		"map_profile_id": "concentric_columns", "enemy_family_id": "bellbound",
		"boss_id": "bell_priest", "boss_name": "钟骨司祭", "mechanic_id": "echo_beats",
		"enemy_roles": ["echo_sentinel", "circling_shade"],
		"description": "墓碑内外圈形成迂回路线，用移动节拍化解音波预判与突袭。",
	},
	{
		"id": 6, "name": "裂隙观测站", "theme_id": "rift_observatory",
		"map_profile_id": "rift_platforms", "enemy_family_id": "riftwatchers",
		"boss_id": "rift_observer", "boss_name": "裂隙观测者", "mechanic_id": "shifting_faults",
		"enemy_roles": ["rift_elite", "space_cutter"],
		"description": "利用平台隔断保留退路，应对空间切线与终局阶段组合。",
	},
]

static func get_chapter(chapter: int) -> Dictionary:
	if chapter < 1 or chapter > CHAPTER_COUNT:
		return {}
	return CHAPTERS[chapter - 1].duplicate(true)
