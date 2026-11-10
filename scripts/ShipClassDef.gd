extends RefCounted
class_name ShipClassDef
## Classe de navio da frota do jogador (vendida no Estaleiro da loja).
## Navio grande = pente maior e nenhum truque; navio pequeno = menos tiros e
## uma vantagem propria (Perk). Cada navio ocupa `tonnage` vagas da doca
## (Game.dock_capacity), entao a escolha e' entre poucos grandes ou varios
## pequenos com vantagens.

## SINK_MULT: +1 mult no tiro que afunda. WATER_SHIELD: o 1o tiro na agua da
## rodada nao quebra o combo. SCOUT: acerto revela no sonar as 4 vizinhas.
## PRIVATEER: cada acerto da +$1.
enum Perk { NONE, SINK_MULT, WATER_SHIELD, SCOUT, PRIVATEER }

var id: StringName
var display_name: String
var kind: PlayerShip.Kind
var tonnage: int
## Pente (tiros que da pra comprar por rodada) ou usos de sonar.
var magazine: int
var perk: Perk
var perk_text: String
var price: int
## Sprites de sprites/frota/, na ordem em que o card monta o navio.
var parts: Array[StringName]
var tint: Color

func _init(p_id: StringName, p_name: String, p_kind: PlayerShip.Kind, p_tonnage: int,
		p_magazine: int, p_perk: Perk, p_perk_text: String, p_price: int,
		p_parts: Array[StringName], p_tint: Color = Color.WHITE) -> void:
	id = p_id
	display_name = p_name
	kind = p_kind
	tonnage = p_tonnage
	magazine = p_magazine
	perk = p_perk
	perk_text = p_perk_text
	price = p_price
	parts = p_parts
	tint = p_tint

## Venda devolve metade do preco.
func sell_price() -> int:
	return int(price / 2.0)

## "Pente 3 · 2 vagas" (ou "Sonar 3") pra carta do Estaleiro.
func summary() -> String:
	var load_text := "Pente %d" % magazine if kind == PlayerShip.Kind.SHOT else "Sonar %d" % magazine
	return "%s · %d %s" % [load_text, tonnage, "vaga" if tonnage == 1 else "vagas"]

func build() -> PlayerShip:
	var segs: Array[Texture2D] = []
	for part in parts:
		segs.append(load("res://sprites/frota/%s.png" % part))
	var ship := PlayerShip.new(id, display_name, kind, segs, magazine)
	ship.ship_class = self
	return ship
