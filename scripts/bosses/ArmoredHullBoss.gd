extends Effect
class_name BossArmoredHull
## Desafio: cascos reforcados absorvem parte do bonus de afundamento.

const PENALTY := 20

func _init() -> void:
	id = &"armored_boss"
	display_name = "Casco Reforcado"
	description = "Cascos reforcados: bonus de afundamento reduzido em %d chips." % PENALTY

func on_shot(ctx: Dictionary) -> void:
	if ctx.get("sank", false):
		ctx["chips"] = maxi(0, int(ctx["chips"]) - PENALTY)
