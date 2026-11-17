extends Control
class_name ShipView
## Desenho de um navio da frota do jogador: sprite da classe
## (sprites/frota/<nome>.png, visao de cima, proa pra direita) e, por cima,
## as camadas das modificacoes compradas, tiradas da folha <nome>_mods.png
## (faixas de 64 px na ordem de mod_rows()). Usado no card da
## FleetBar (tamanho cheio) e na loja (zoom 0.5, so a faixa do casco).

const ROW_H := 64
## Linhas da arte com navio (16 linhas logicas x4, sem a 1a e a ultima, que
## so tem margem): a loja corta o resto.
const HULL_ROWS := Vector2i(4, 60)

var base: Texture2D = null
var mods: Texture2D = null
var rows: Array[int] = []
var zoom: float = 1.0
var hull_only: bool = false

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Navio da frota: classe + armamento e melhoria que ele tem agora.
func show_ship(ship: PlayerShip) -> void:
	if ship.ship_class:
		_set_class(ship.ship_class)
	rows = mod_rows(ship)
	queue_redraw()

## So a classe (carta do Estaleiro).
func show_class(def: ShipClassDef) -> void:
	_set_class(def)
	rows.clear()
	queue_redraw()

func _set_class(def: ShipClassDef) -> void:
	base = def.texture()
	mods = def.mods_texture()
	var h := HULL_ROWS.y - HULL_ROWS.x if hull_only else ROW_H
	custom_minimum_size = Vector2(base.get_width(), h) * zoom

## Faixas da folha de modificacoes: 0-3 armamento (PlayerShip.Shot - 1),
## 4-8 melhoria (4 + ShipUpgradeDef.Kind).
static func mod_rows(ship: PlayerShip) -> Array[int]:
	var out: Array[int] = []
	if ship.shot_type != PlayerShip.Shot.NORMAL:
		out.append(int(ship.shot_type) - 1)
	if ship.upgrade != null:
		out.append(4 + int(ship.upgrade.kind))
	return out

func _draw() -> void:
	if base == null:
		return
	var y0 := HULL_ROWS.x if hull_only else 0
	var h := HULL_ROWS.y - HULL_ROWS.x if hull_only else ROW_H
	var w := base.get_width()
	var dst := Rect2(Vector2.ZERO, Vector2(w, h) * zoom)
	# Centraliza se o controle ficou maior que o navio.
	dst.position = ((size - dst.size) / 2.0).floor()
	draw_texture_rect_region(base, dst, Rect2(0, y0, w, h))
	if mods == null:
		return
	for r in rows:
		draw_texture_rect_region(mods, dst, Rect2(0, r * ROW_H + y0, w, h))
