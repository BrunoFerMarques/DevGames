extends Effect
class_name AdmiralTorpedoCounter
## Dobra os chips do tiro que afunda um navio.

func _init() -> void:
	id = &"torpedo_counter"
	display_name = "Contra-torpedeiro"
	description = "Dobra os chips do tiro que afunda um navio."

func on_shot(ctx: Dictionary) -> void:
	if ctx.get("sank", false):
		ctx["chips"] = int(ctx["chips"]) * 2
