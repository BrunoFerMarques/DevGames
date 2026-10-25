extends Effect
class_name AdmiralTide
## Sonar vira area 3x3 em vez de 3 casas na linha.

func _init() -> void:
	id = &"tide"
	display_name = "Capita Mare"
	description = "Sonar revela uma area 3x3 em vez de 3 casas na linha."
	portrait = preload("res://sprites/almirantes/capita_mare.png")

func sonar_is_box() -> bool:
	return true
