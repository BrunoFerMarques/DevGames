extends RefCounted
class_name ShotTypeCatalog
## Lista fixa de armamentos (tipos de tiro) vendidos na loja.

static func all() -> Array[ShotTypeDef]:
	var out: Array[ShotTypeDef] = [
		ShotTypeDef.new(&"piercing", "Ogiva Perfurante",
			"Os tiros deste navio furam blindagem na hora.",
			PlayerShip.Shot.PIERCING, 5),
		ShotTypeDef.new(&"salvo", "Salva em Cruz",
			"Cada tiro acerta a casa e as 4 vizinhas. O combo sobe 1 por tiro.",
			PlayerShip.Shot.SALVO, 8),
		ShotTypeDef.new(&"torpedo", "Torpedo",
			"Corre a linha para a direita, revelando água, até bater em algo.",
			PlayerShip.Shot.TORPEDO, 6),
	]
	return out
