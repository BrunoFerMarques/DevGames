extends PanelContainer
class_name EnemyFleetPanel
## Frota inimiga da rodada, no canto esquerdo da batalha (entre a coluna de
## almirantes e o tabuleiro). Uma linha por tipo de navio: quadradinhos do
## tamanho, nome, "xN" de quantos ainda flutuam e marcas ($ de saque, BLIND,
## SUB); embaixo, as minas. So revela o que o batalha naval classico anuncia
## (quem ja afundou), nunca a posicao.
## Ficava no Hud, mas a frota grande dos setores altos empurrava o painel da
## direita pra fora da tela (e por cima da barra da sua frota).

const CREAM := Color("#fdf6e3")
const GOLD := Color("#f3c44b")
const HIT_RED := Color("#e43c4f")
const ALIVE := Color("#2fbfb0")
const SUNK := Color("#e43c4f")
const DIM := Color(0.6, 0.63, 0.68, 0.8)
const STEEL := Color("#9fb0c4")
const TAG_COLORS := {
	&"loot": GOLD,
	&"armor": STEEL,
	&"sub": Color("#2fbfb0"),
}
## Linhas compactas: o painel tem ~248px entre os almirantes e a grade.
const SQUARE := 9
const SQUARE_GAP := 2
const MAX_SHIP := 5          # maior navio: largura fixa da coluna de quadrados
const NAME_SIZE := 16
const TAG_SIZE := 14

@onready var rows_box: VBoxContainer = $VBox/Rows

var _board: Board = null

func bind(board: Board) -> void:
	_board = board
	board.round_started.connect(refresh)
	board.enemy_fleet_changed.connect(refresh)

func refresh() -> void:
	for c in rows_box.get_children():
		rows_box.remove_child(c)
		c.queue_free()
	var groups: Dictionary = {}   # nome|tamanho|marcas -> {def, alive, total}
	for ship in _board.enemy_ships:
		var def: EnemyShipDef = ship["def"]
		var key := "%s|%d|%s" % [def.display_name, def.size, str(def.tags())]
		if not groups.has(key):
			groups[key] = {"def": def, "alive": 0, "total": 0}
		groups[key]["total"] += 1
		if not _board.is_sunk(ship):
			groups[key]["alive"] += 1
	for group in groups.values():
		var def: EnemyShipDef = group["def"]
		var sunk: bool = group["alive"] == 0
		var row := _row(def.size, func(i: int) -> Color: return SUNK if sunk else ALIVE)
		var text := def.display_name
		if group["total"] > 1:
			text += " x%d" % (group["total"] if sunk else group["alive"])
		row.add_child(_label(text, DIM if sunk else CREAM, NAME_SIZE))
		for tag in def.tags():
			row.add_child(_label(tag["text"], DIM if sunk else TAG_COLORS.get(tag["kind"], CREAM), TAG_SIZE))
		rows_box.add_child(row)
	# Minas: um quadrado por mina (vermelho = escondida, cinza = detonada).
	if _board.mines_total > 0:
		var row := _row(_board.mines_total,
			func(i: int) -> Color: return DIM if i < _board.mines_exploded else HIT_RED)
		row.add_child(_label("Minas -1 tiro", HIT_RED, NAME_SIZE))
		rows_box.add_child(row)

## Linha com `n` quadradinhos coloridos por `color_of(i)`.
func _row(n: int, color_of: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var squares := HBoxContainer.new()
	squares.add_theme_constant_override("separation", SQUARE_GAP)
	squares.custom_minimum_size = Vector2(MAX_SHIP * (SQUARE + SQUARE_GAP), 0)
	squares.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in n:
		var sq := ColorRect.new()
		sq.custom_minimum_size = Vector2(SQUARE, SQUARE)
		sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sq.color = color_of.call(i)
		sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
		squares.add_child(sq)
	row.add_child(squares)
	return row

func _label(text: String, color: Color, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl
