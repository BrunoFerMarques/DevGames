extends Effect
class_name AdmiralCommander
## +2 de mult fixo em todo acerto.

func _init() -> void:
	id = &"commander"
	display_name = "Comandante"
	description = "+2 de mult em todo acerto."

func on_shot(ctx: Dictionary) -> void:
	if ctx.get("is_hit", false):
		ctx["mult"] = float(ctx["mult"]) + 2.0
