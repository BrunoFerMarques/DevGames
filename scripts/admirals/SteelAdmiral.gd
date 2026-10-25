extends Effect
class_name AdmiralSteel
## +5 chips fixos em todo acerto.

func _init() -> void:
	id = &"steel"
	display_name = "Almirante Aco"
	description = "+5 chips fixos em todo acerto."
	portrait = preload("res://sprites/almirantes/almirante_aco.png")

func on_shot(ctx: Dictionary) -> void:
	if ctx.get("is_hit", false):
		ctx["chips"] = int(ctx["chips"]) + 5
