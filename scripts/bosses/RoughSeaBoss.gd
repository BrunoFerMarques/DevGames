extends Effect
class_name BossRoughSea
## Desafio: -1 tiro em cada navio de ataque da frota nesta rodada.

func _init() -> void:
	id = &"rough_sea_boss"
	display_name = "Mare Brava"
	description = "Mar agitado: -1 tiro em cada navio de ataque nesta rodada."

func modify_shots(n: int) -> int:
	return maxi(1, n - 1)
