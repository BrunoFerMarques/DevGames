extends Resource
class_name ShipUpgradeDef
## Melhoria comprada na loja e aplicada a UM navio (PlayerShip.upgrade).
## Escala com upgrade_level (recompra da mesma melhoria acumula).
## Kinds SONAR_* so vao no navio-sonar (lidos pelo Board/PlayerShip, nao
## mexem no ctx do tiro); os outros so em navio de tiro.

enum Kind { CHIPS_PER_HIT, MULT_PER_SINK, SONAR_DEEP, SONAR_WIDE, SONAR_CHARGE }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var kind: Kind = Kind.CHIPS_PER_HIT
@export var magnitude: float = 0.0
@export var price: int = 5

## True se a melhoria e' do navio-sonar (loja oferece so pra ele).
func for_sonar() -> bool:
	return kind in [Kind.SONAR_DEEP, Kind.SONAR_WIDE, Kind.SONAR_CHARGE]

func apply_shot(ctx: Dictionary, level: int) -> void:
	if not ctx.get("is_hit", false):
		return
	match kind:
		Kind.CHIPS_PER_HIT:
			ctx["chips"] = int(ctx["chips"]) + int(magnitude) * level
		Kind.MULT_PER_SINK:
			if ctx.get("sank", false):
				ctx["mult"] = float(ctx["mult"]) + magnitude * level
