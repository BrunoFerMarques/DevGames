extends Effect
class_name AdmiralCoral
## +1 de mult extra a cada 3 de combo.

func _init() -> void:
	id = &"coral"
	display_name = "Capita Coral"
	description = "+1 de mult extra a cada 3 de combo."
	portrait = preload("res://sprites/almirantes/capita_coral.png")

func on_shot(ctx: Dictionary) -> void:
	if ctx.get("is_hit", false):
		var streak: int = int(ctx.get("streak", 0))
		ctx["mult"] = float(ctx["mult"]) + float(streak / 3)
