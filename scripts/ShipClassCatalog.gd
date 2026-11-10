extends RefCounted
class_name ShipClassCatalog
## Classes de navio que o Estaleiro vende. Quanto menor o navio, menor o
## pente e mais especifica a vantagem.

const P := ShipClassDef.Perk

static func all() -> Array[ShipClassDef]:
	var out: Array[ShipClassDef] = [
		ShipClassDef.new(&"battleship", "Encouraçado", PlayerShip.Kind.SHOT, 3, 4, P.NONE,
			"Sem truque: o maior pente da frota.", 8, [&"bow", &"mid", &"stern"]),
		ShipClassDef.new(&"cruiser", "Cruzador", PlayerShip.Kind.SHOT, 3, 3, P.SINK_MULT,
			"+1 de multiplicador no tiro que afunda um navio.", 8, [&"bow", &"mid", &"stern"],
			Color(0.82, 0.9, 1.0)),
		ShipClassDef.new(&"destroyer", "Destroyer", PlayerShip.Kind.SHOT, 2, 2, P.WATER_SHIELD,
			"O 1º tiro na água da rodada não quebra o combo.", 5, [&"bow", &"stern"]),
		ShipClassDef.new(&"privateer", "Corsário", PlayerShip.Kind.SHOT, 2, 2, P.PRIVATEER,
			"Cada acerto deste navio dá +$1.", 6, [&"bow", &"stern"],
			Color(1.0, 0.8, 0.74)),
		ShipClassDef.new(&"corvette", "Corveta", PlayerShip.Kind.SHOT, 1, 1, P.SCOUT,
			"Ao acertar, revela no sonar as 4 casas vizinhas.", 4, [&"bow"],
			Color(0.82, 1.0, 0.88)),
		ShipClassDef.new(&"sonar_ship", "Navio-sonar", PlayerShip.Kind.SONAR, 2, 3, P.NONE,
			"Usos de sonar grátis toda rodada.", 6, [&"bow", &"sonar", &"stern"]),
	]
	return out

static func by_id(id: StringName) -> ShipClassDef:
	for def in all():
		if def.id == id:
			return def
	return null
