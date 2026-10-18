extends Effect
class_name AdmiralTide
## Sonar vira area 3x3 em vez de linha inteira.

func _init() -> void:
	id = &"tide"
	display_name = "Capita Mare"
	description = "Sonar revela uma area 3x3 em vez da linha inteira."
	portrait = preload("res://sprites/capita_mare.png")

func sonar_is_box() -> bool:
	return true
