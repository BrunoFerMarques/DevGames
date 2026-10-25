extends Resource
class_name PlayerShip
## Carta de navio da frota do jogador. Guarda a carga propria (tiros ou
## usos de sonar) e os sprites que montam o navio na FleetBar.

enum Kind { SHOT, SONAR }
## Municao que o navio dispara (troca comprando Armamento na loja).
## PIERCING ignora blindagem; SALVO acerta a casa + as 4 vizinhas;
## TORPEDO corre a linha pra direita ate bater em algo.
enum Shot { NORMAL, PIERCING, SALVO, TORPEDO }
const SHOT_TAGS := {
	Shot.NORMAL: "",
	Shot.PIERCING: "PERF",
	Shot.SALVO: "SALVA",
	Shot.TORPEDO: "TORP",
}

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.SHOT
@export var segments: Array[Texture2D] = []
@export var max_charges: int = 1

## Melhoria comprada na loja para este navio (1 slot; recomprar a mesma sobe
## o nivel, comprar outra diferente substitui).
var upgrade: ShipUpgradeDef = null
var upgrade_level: int = 0
var shot_type: Shot = Shot.NORMAL

var charges: int = 0
## Navio de tiro comeca a rodada vazio: so dispara o que foi comprado na loja
## (ate max_charges, o tamanho do pente). Game.clear_bought_shots zera no fim
## da rodada. Sonar continua recarregando sozinho.
var bought_shots: int = 0

func _init(p_id: StringName = &"", p_name: String = "", p_kind: Kind = Kind.SHOT,
		p_segments: Array[Texture2D] = [], p_max_charges: int = 1) -> void:
	id = p_id
	display_name = p_name
	kind = p_kind
	segments = p_segments
	max_charges = p_max_charges
	charges = p_max_charges

func refill() -> void:
	charges = round_capacity()

## Carga com que o navio entra na rodada.
func round_capacity() -> int:
	return bought_shots if kind == Kind.SHOT else max_charges

func can_load_shot() -> bool:
	return kind == Kind.SHOT and bought_shots < max_charges

func has_charge() -> bool:
	return charges > 0

func shot_tag() -> String:
	return SHOT_TAGS[shot_type]

## Aplica a melhoria deste navio (se tiver) no ctx do tiro atual.
func apply_shot_upgrade(ctx: Dictionary) -> void:
	if upgrade:
		upgrade.apply_shot(ctx, upgrade_level)
