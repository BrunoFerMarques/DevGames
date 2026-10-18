extends Effect
class_name AdmiralTreasurer
## +6 de dinheiro sempre que a rodada e vencida.

func _init() -> void:
	id = &"treasurer"
	display_name = "Tesoureiro"
	description = "+6 de dinheiro ao vencer a rodada."

func on_round_end(_ctx: Dictionary) -> void:
	Game.add_money(6)
