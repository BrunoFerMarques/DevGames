extends Effect
class_name AdmiralFlotilla
## +1 vaga na doca e navios de 1 vaga (Corveta) levam +1 tiro no pente:
## deixa a frota de muitos navios pequenos viavel.

const EXTRA_DOCK := 1
const EXTRA_MAGAZINE := 1

func _init() -> void:
	id = &"flotilla"
	display_name = "Almirante da Flotilha"
	description = "+%d vaga na doca e navios de 1 vaga levam +%d tiro no pente." % [EXTRA_DOCK, EXTRA_MAGAZINE]

func modify_dock(n: int) -> int:
	return n + EXTRA_DOCK

func modify_magazine(ship: PlayerShip, n: int) -> int:
	if ship.kind == PlayerShip.Kind.SHOT and ship.tonnage() == 1:
		return n + EXTRA_MAGAZINE
	return n
