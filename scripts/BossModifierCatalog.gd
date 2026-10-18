extends RefCounted
class_name BossModifierCatalog
## Lista fixa de desafios de boss (rodada final de cada ante).

static func all() -> Array[Effect]:
	var out: Array[Effect] = []
	out.append(BossFog.new())
	out.append(BossRoughSea.new())
	out.append(BossArmoredHull.new())
	out.append(BossHighTide.new())
	return out
