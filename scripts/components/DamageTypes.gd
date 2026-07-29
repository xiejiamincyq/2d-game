extends RefCounted
class_name DamageTypes

const GENERIC: StringName = &"generic"
const PROJECTILE: StringName = &"projectile"
const LASER: StringName = &"laser"
const ARC: StringName = &"arc"
const DASH: StringName = &"dash"
const SPIKE: StringName = &"spike"
const BURN: StringName = &"burn"
const ALL: Array[StringName] = [PROJECTILE, LASER, ARC, DASH, SPIKE, BURN]

static func resolve(source: StringName) -> StringName:
	if source == GENERIC or ALL.has(source):
		return source
	return GENERIC
