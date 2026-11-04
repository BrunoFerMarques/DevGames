extends Resource
class_name PlayerShip
## Carta de navio da frota do jogador. Guarda a carga propria (tiros ou
## usos de sonar) e os sprites que montam o navio na FleetBar.

enum Kind { SHOT, SONAR }
## Municao que o navio dispara (troca comprando Armamento na loja).
## PIERCING ignora blindagem; SALVO acerta a casa + as 4 vizinhas;
## TORPEDO corre a linha pra direita ate bater em algo; TRACKER mostra o casco
## (direcao do navio) no acerto - os outros so marcam fogo, sem direcao.
enum Shot { NORMAL, PIERCING, SALVO, TORPEDO, TRACKER }
const SHOT_TAGS := {
	Shot.NORMAL: "",
	Shot.PIERCING: "PERF",
	Shot.SALVO: "SALVA",
	Shot.TORPEDO: "TORP",
	Shot.TRACKER: "RAST",
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
## Carga com que o navio entrou na rodada, ja com boss/nacao/almirantes.
## Teto da recarga de sonar ao afundar navio (Board._refund_sonar).
var round_cap: int = 0
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
	if kind == Kind.SHOT:
		return bought_shots
	return max_charges + sonar_upgrade_level(ShipUpgradeDef.Kind.SONAR_CHARGE)

## Nivel da melhoria de sonar `k` neste navio (0 se nao tem).
func sonar_upgrade_level(k: ShipUpgradeDef.Kind) -> int:
	if upgrade != null and upgrade.kind == k:
		return upgrade_level
	return 0

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
