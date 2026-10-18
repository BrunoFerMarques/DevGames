extends Resource
class_name PlayerShip
## Carta de navio da frota do jogador. Guarda a carga propria (tiros ou
## usos de sonar) e os sprites que montam o navio na FleetBar.

enum Kind { SHOT, SONAR }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.SHOT
@export var segments: Array[Texture2D] = []
@export var max_charges: int = 1

## Melhoria comprada na loja para este navio (1 slot; recomprar a mesma sobe
## o nivel, comprar outra diferente substitui).
var upgrade: ShipUpgradeDef = null
var upgrade_level: int = 0

var charges: int = 0

func _init(p_id: StringName = &"", p_name: String = "", p_kind: Kind = Kind.SHOT,
		p_segments: Array[Texture2D] = [], p_max_charges: int = 1) -> void:
	id = p_id
	display_name = p_name
	kind = p_kind
	segments = p_segments
	max_charges = p_max_charges
	charges = p_max_charges

func refill() -> void:
	charges = max_charges

func has_charge() -> bool:
	return charges > 0

## Aplica a melhoria deste navio (se tiver) no ctx do tiro atual.
func apply_shot_upgrade(ctx: Dictionary) -> void:
	if upgrade:
		upgrade.apply_shot(ctx, upgrade_level)
