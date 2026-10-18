extends Effect
class_name AdmiralStorm
## Tiros n'agua tambem rendem chips e nao zeram o combo.

const WATER_CHIPS := 5

func _init() -> void:
	id = &"storm"
	display_name = "Capitao Tempestade"
	description = "Tiros n'agua tambem rendem %d chips e nao zeram o combo." % WATER_CHIPS
	portrait = preload("res://sprites/capitao_tempestade.png")

func on_shot(ctx: Dictionary) -> void:
	if not ctx.get("is_hit", false):
		ctx["chips"] = int(ctx["chips"]) + WATER_CHIPS

func keeps_combo_on_water(_water_n: int) -> bool:
	return true
