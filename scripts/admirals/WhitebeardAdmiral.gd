extends Effect
class_name AdmiralWhitebeard
## Veterano: +1 tiro em cada navio de ataque toda rodada.

func _init() -> void:
	id = &"whitebeard"
	display_name = "Almirante Barba Branca"
	description = "+1 tiro em cada navio de ataque toda rodada."
	portrait = preload("res://sprites/almirante_barba_branca.png")

func modify_shots(n: int) -> int:
	return n + 1
