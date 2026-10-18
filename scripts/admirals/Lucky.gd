extends Effect
class_name AdmiralLucky
## 15% de chance de dobrar os chips num acerto.

func _init() -> void:
	id = &"lucky"
	display_name = "Sortudo"
	description = "15% de chance de dobrar os chips num acerto."

func on_shot(ctx: Dictionary) -> void:
	if ctx.get("is_hit", false) and randf() < 0.15:
		ctx["chips"] = int(ctx["chips"]) * 2
