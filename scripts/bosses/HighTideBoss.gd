extends Effect
class_name BossHighTide
## Desafio: meta de pontos +25% nesta rodada.

func _init() -> void:
	id = &"high_tide_boss"
	display_name = "Mare Alta"
	description = "Mare alta: meta de pontos +25% nesta rodada."

func modify_target(n: int) -> int:
	return int(n * 1.25)
