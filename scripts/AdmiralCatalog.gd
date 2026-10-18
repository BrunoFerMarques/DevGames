extends RefCounted
class_name AdmiralCatalog
## Lista fixa de Almirantes (coringas) vendidos na loja.

static func all() -> Array[Effect]:
	var out: Array[Effect] = []
	out.append(AdmiralTreasurer.new())
	out.append(AdmiralCommander.new())
	out.append(AdmiralTorpedoCounter.new())
	out.append(AdmiralLucky.new())
	out.append(AdmiralSteel.new())
	out.append(AdmiralWhitebeard.new())
	out.append(AdmiralCoral.new())
	out.append(AdmiralTide.new())
	out.append(AdmiralStorm.new())
	out.append(AdmiralFogCommodore.new())
	return out
