extends Effect
class_name AdmiralFogCommodore
## So presenca: libera trocar/remover o desafio de boss por dinheiro
## (ver Board.can_adjust_boss / reroll_boss / remove_boss), antes do
## primeiro tiro da rodada.

func _init() -> void:
	id = &"commodore_nevoa"
	display_name = "Comodoro Nevoa"
	description = "Libera trocar ou remover o desafio de boss por dinheiro, antes do primeiro tiro da rodada."
	portrait = preload("res://sprites/comodoro_nevoa.png")
