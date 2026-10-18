extends Effect
class_name BossFog
## Desafio: sonar inutilizado na rodada (cada navio-sonar perde toda carga).

func _init() -> void:
	id = &"fog_boss"
	display_name = "Nevoa"
	description = "Nevoa densa cobre o mar: sonar inutilizado nesta rodada."

func modify_sonar(_n: int) -> int:
	return 0
