extends RefCounted
## Pure, bounded encounter composition; no save, RNG or scene-tree writes.
const MAX_ENCOUNTER_ENEMIES := 144
const MAX_POPULATION_LOAD := 48
const MAX_LOOP := 1000001
const FOREIGN_KIND_BASE := 100
const ROLES := [
	{"chapter":1,"role":"root_pursuer"}, {"chapter":1,"role":"spore_spitter"},
	{"chapter":2,"role":"slag_charger"}, {"chapter":2,"role":"spark_gunner"},
	{"chapter":3,"role":"flanking_crab"}, {"chapter":3,"role":"salt_needle"},
	{"chapter":5,"role":"echo_sentinel"}, {"chapter":5,"role":"circling_shade"},
	{"chapter":6,"role":"space_cutter"}, {"chapter":6,"role":"rift_elite"},
]
static func health_scale(loop: int) -> float:
	return 1.0+0.35*float(clampi(loop,1,MAX_LOOP)-1)
static func compose(base: Array[int],chapter: int,loop: int) -> Array[int]:
	if base.is_empty() or base.size()>MAX_ENCOUNTER_ENEMIES or chapter<1 or chapter>6 or loop<1 or loop>MAX_LOOP: return []
	if loop==1: return base.duplicate()
	var pool: Array[int]=[]
	# Rotate by chapter so all six regions do not receive the same first visitor.
	for offset in ROLES.size():
		var index:=posmod((chapter-1)*2+offset,ROLES.size())
		if ROLES[index].chapter!=chapter: pool.append(FOREIGN_KIND_BASE+index)
	var unlocked:=mini(loop-1,pool.size())
	var desired:=mini(MAX_ENCOUNTER_ENEMIES,maxi(base.size()+unlocked,ceili(base.size()*(1.0+0.25*mini(loop-1,MAX_ENCOUNTER_ENEMIES)))))
	var result: Array[int]=[]
	for index in unlocked: result.append(pool[index])
	# Preserve the native majority/proportions instead of replacing the region.
	while result.size()<desired: result.append(base[(result.size()-unlocked)%base.size()])
	return result
static func foreign_role(kind: int) -> Dictionary:
	var index := kind-FOREIGN_KIND_BASE
	return ROLES[index].duplicate() if index>=0 and index<ROLES.size() else {}
