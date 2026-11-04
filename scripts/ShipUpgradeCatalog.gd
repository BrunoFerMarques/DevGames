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

	# --- So pro navio-sonar (mesmo slot unico: comprar outra substitui) ---
	var deep := ShipUpgradeDef.new()
	deep.id = &"sonar_deep"
	deep.display_name = "Sonar Profundo"
	deep.description = "O sonar enxerga submarinos."
	deep.kind = ShipUpgradeDef.Kind.SONAR_DEEP

	var wide := ShipUpgradeDef.new()
	wide.id = &"sonar_wide"
	wide.display_name = "Varredura Larga"
	wide.description = "O sonar revela +2 casas de largura (por nivel)."
	wide.kind = ShipUpgradeDef.Kind.SONAR_WIDE
	wide.magnitude = 2.0

	var battery := ShipUpgradeDef.new()
	battery.id = &"sonar_charge"
	battery.display_name = "Bateria Extra"
	battery.description = "+1 carga de sonar por rodada (por nivel)."
	battery.kind = ShipUpgradeDef.Kind.SONAR_CHARGE
	battery.magnitude = 1.0

	var out: Array[ShipUpgradeDef] = [gunner, demolisher, deep, wide, battery]
	return out
