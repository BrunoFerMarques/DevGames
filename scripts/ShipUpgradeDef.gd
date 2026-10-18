extends Resource
class_name ShipUpgradeDef
## Melhoria comprada na loja e aplicada a UM navio (PlayerShip.upgrade).
## Escala com upgrade_level (recompra da mesma melhoria acumula).

enum Kind { CHIPS_PER_HIT, MULT_PER_SINK }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var kind: Kind = Kind.CHIPS_PER_HIT
@export var magnitude: float = 0.0
@export var price: int = 5

func apply_shot(ctx: Dictionary, level: int) -> void:
	if not ctx.get("is_hit", false):
		return
	match kind:
		Kind.CHIPS_PER_HIT:
			ctx["chips"] = int(ctx["chips"]) + int(magnitude) * level
		Kind.MULT_PER_SINK:
			if ctx.get("sank", false):
				ctx["mult"] = float(ctx["mult"]) + magnitude * level
