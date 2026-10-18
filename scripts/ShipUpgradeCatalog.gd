extends RefCounted
class_name ShipUpgradeCatalog
## Lista fixa de melhorias de navio vendidas na loja.

static func all() -> Array[ShipUpgradeDef]:
	var gunner := ShipUpgradeDef.new()
	gunner.id = &"gunner"
	gunner.display_name = "Artilheiro"
	gunner.description = "+10 chips a cada acerto deste navio (por nivel)."
	gunner.kind = ShipUpgradeDef.Kind.CHIPS_PER_HIT
	gunner.magnitude = 10.0

	var demolisher := ShipUpgradeDef.new()
	demolisher.id = &"demolisher"
	demolisher.display_name = "Demolidor"
	demolisher.description = "+0.5 de mult a cada navio afundado por este navio (por nivel)."
	demolisher.kind = ShipUpgradeDef.Kind.MULT_PER_SINK
	demolisher.magnitude = 0.5

	var out: Array[ShipUpgradeDef] = [gunner, demolisher]
	return out
