extends RefCounted
class_name EnemyShipDef
## Navio inimigo da rodada. Game monta a frota (configure_round), Board
## posiciona um navio por def e o HUD lista nome/tamanho/marcas pro jogador
## saber o que ainda falta afundar e escolher alvo (ex.: cargueiro com saque).

var id: StringName
var display_name: String
var size: int = 1
## Dinheiro pago na hora em que o navio afunda.
var loot_money: int = 0
## Tiros extras que cada casa aguenta antes de contar como acerto
## (o 1o so amassa a blindagem). Ogiva perfurante ignora.
var armor: int = 0
## Fichas extras ao afundar (paga o tiro a mais que a blindagem custou).
var sink_bonus: int = 0
## Submerso: o sonar passa por cima como se fosse agua.
var sonar_proof: bool = false

func _init(p_id: StringName = &"warship", p_name: String = "", p_size: int = 1) -> void:
	id = p_id
	display_name = p_name
	size = p_size

## Navio de guerra comum, nomeado pelo tamanho.
static func warship(p_size: int) -> EnemyShipDef:
	return EnemyShipDef.new(&"warship", _class_name(p_size), p_size)

## Saque cresce quando o navio encolhe: navio pequeno e' mais dificil de achar.
const CARGO_LOOT_BY_SIZE := {5: 1, 4: 2, 3: 3, 2: 4}
const TREASURE_SIZE := 2
const TREASURE_LOOT := 8

static func cargo(p_size: int) -> EnemyShipDef:
	var d := EnemyShipDef.new(&"cargo", "Cargueiro", p_size)
	d.loot_money = CARGO_LOOT_BY_SIZE.get(p_size, 1)
	return d

## Sempre pequeno e o mais valioso da frota.
static func treasure() -> EnemyShipDef:
	var d := EnemyShipDef.new(&"treasure", "Navio-tesouro", TREASURE_SIZE)
	d.loot_money = TREASURE_LOOT
	return d

## Navio de guerra com casco blindado (cada casa leva 1 tiro a mais).
static func armored(p_size: int) -> EnemyShipDef:
	var d := warship(p_size)
	d.id = &"armored"
	d.armor = 1
	d.sink_bonus = 30
	return d

static func submarine(p_size: int) -> EnemyShipDef:
	var d := EnemyShipDef.new(&"submarine", "Submarino", p_size)
	d.sonar_proof = true
	d.sink_bonus = 20
	return d

## Marcas curtas ao lado do nome na lista da frota: { text, kind }.
## kind decide a cor no HUD (loot = dourado, armor = aco...).
func tags() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if loot_money > 0:
		out.append({"text": "$%d" % loot_money, "kind": &"loot"})
	if armor > 0:
		out.append({"text": "BLIND", "kind": &"armor"})
	if sonar_proof:
		out.append({"text": "SUB", "kind": &"sub"})
	return out

static func _class_name(p_size: int) -> String:
	match p_size:
		5: return "Porta-aviões"
		4: return "Encouraçado"
		3: return "Cruzador"
		2: return "Destroyer"
		_: return "Lancha"
