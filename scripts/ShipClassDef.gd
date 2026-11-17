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
## Nome do sprite em sprites/frota/ (<sprite>.png e a folha <sprite>_mods.png
## com as camadas de armamento/melhoria; ver ShipView).
var sprite: String

func _init(p_id: StringName, p_name: String, p_kind: PlayerShip.Kind, p_tonnage: int,
		p_magazine: int, p_perk: Perk, p_perk_text: String, p_price: int,
		p_sprite: String) -> void:
	id = p_id
	display_name = p_name
	kind = p_kind
	tonnage = p_tonnage
	magazine = p_magazine
	perk = p_perk
	perk_text = p_perk_text
	price = p_price
	sprite = p_sprite

## Venda devolve metade do preco.
func sell_price() -> int:
	return int(price / 2.0)

## "Pente 3 · 2 vagas" (ou "Sonar 3") pra carta do Estaleiro.
func summary() -> String:
	var load_text := "Pente %d" % magazine if kind == PlayerShip.Kind.SHOT else "Sonar %d" % magazine
	return "%s · %d %s" % [load_text, tonnage, "vaga" if tonnage == 1 else "vagas"]

func texture() -> Texture2D:
	return load("res://sprites/frota/%s.png" % sprite)

func mods_texture() -> Texture2D:
	return load("res://sprites/frota/%s_mods.png" % sprite)

func build() -> PlayerShip:
	var ship := PlayerShip.new(id, display_name, kind, magazine)
	ship.ship_class = self
	return ship
