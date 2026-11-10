extends Control
class_name Tutorial
## Rodada de treino guiada (tela de inicio > Treino). Escurece a tela e abre
## um "buraco" so no que o passo pede (botao, carta, casa): cliques fora dele
## sao barrados. Cada passo espera um evento do jogo (comprar tiro, zarpar,
## selecionar navio, atirar, usar sonar) ou o botao Proximo. O tabuleiro do
## treino e' fixo (Game.setup_tutorial), entao o roteiro sempre bate.

signal finished(play: bool)

const DIM := Color(0.02, 0.06, 0.12, 0.72)
const FRAME := Color("#f3c44b")
const HOLE_PAD := 6.0
const BUBBLE_W := 380.0
const GAP := 14.0
const EDGE := 8.0

var _shop: Shop
var _board: Board
var _fleet_bar: FleetBar
var _hud: Hud

var _steps: Array[Dictionary] = []
var _i: int = -1
var _hole := Rect2()
var _pulse: float = 0.0

var _blocks: Array[ColorRect] = []
var _hole_block: Control
var _frame: Control
var _bubble: PanelContainer
var _text: Label
var _skip_btn: Button
var _next_btn: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 4:
		var b := ColorRect.new()
		b.color = DIM
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(b)
		_blocks.append(b)
	# Passo so de leitura: o buraco aparece mas nao deixa clicar no que esta nele.
	_hole_block = Control.new()
	_hole_block.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_hole_block)
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	_build_bubble()
	set_process(false)

func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	add_child(_bubble)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_bubble.add_child(box)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(BUBBLE_W, 0)
	box.add_child(_text)
	var row := HBoxContainer.new()
	box.add_child(row)
	_skip_btn = Button.new()
	_skip_btn.pressed.connect(func(): _finish(false))
	row.add_child(_skip_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_next_btn = Button.new()
	_next_btn.pressed.connect(_on_next)
	row.add_child(_next_btn)

## Main liga uma vez; os eventos so contam enquanto o treino esta rodando.
## Deferred: o estado (tiro comprado, carga, casa revelada) so assenta depois
## do sinal.
func bind(shop: Shop, board: Board, fleet_bar: FleetBar, hud: Hud) -> void:
	_shop = shop
	_board = board
	_fleet_bar = fleet_bar
	_hud = hud
	Game.money_changed.connect(func(_m): _event.call_deferred(&"money"))
	board.round_started.connect(func(): _event.call_deferred(&"round"))
	board.ship_selected.connect(func(_s): _event.call_deferred(&"select"))
	board.shot_resolved.connect(func(_d): _event.call_deferred(&"shot"))
	board.sonar_changed.connect(func(_l): _event.call_deferred(&"sonar"))

func begin() -> void:
	_steps = _build_steps()
	visible = true
	set_process(true)
	_go(0)

## Main avisa quando a rodada de treino foi vencida (depois da explosao final).
func notify_won() -> void:
	_event(&"won")

func is_running() -> bool:
	return _i >= 0

# --- Roteiro -------------------------------------------------------------------

## { text, on: evento que avanca, rect: Callable -> Rect2 global (buraco),
##   check: Callable -> bool (opcional, condicao extra pro evento contar) }
## on = next/won/final: passo de leitura (o buraco nao recebe clique).
func _build_steps() -> Array[Dictionary]:
	var battleship := _ship_of(PlayerShip.Kind.SHOT)
	var sonar_ship := _ship_of(PlayerShip.Kind.SONAR)
	var steps: Array[Dictionary] = [
		{"on": &"next",
			"text": "Bem-vindo ao treino, almirante! Em 1 minuto você aprende o básico."},
		{"on": &"money", "rect": func() -> Rect2: return _shop_row(0),
			"check": func() -> bool: return battleship.bought_shots >= battleship.max_charges,
			"text": "Seus navios saem VAZIOS: antes de cada rodada você compra os tiros. Aperte + até carregar 4 tiros no Encouraçado ($1 cada)."},
		{"on": &"round", "rect": func() -> Rect2: return _shop.continue_btn.get_global_rect(),
			"text": "Tudo carregado. Clique em Zarpar."},
		{"on": &"next", "rect": func() -> Rect2: return _hud.fleet_box.get_global_rect(),
			"text": "Esta é a frota inimiga. O Cargueiro paga $4 de saque ao afundar: quanto menor o navio, mais ele paga."},
		{"on": &"next", "rect": _grid_rect,
			"text": "Os números em volta da grade dizem quantas casas de navio faltam em cada linha e coluna. Navios nunca se encostam, nem na diagonal."},
		{"on": &"select", "rect": func() -> Rect2: return _fleet_bar.card_rect(battleship),
			"check": func() -> bool: return _board.selected_ship == battleship,
			"text": "Clique no Encouraçado para armar um tiro."},
		{"on": &"shot", "rect": _cell(1, 1),
			"text": "Atire na casa B2."},
		{"on": &"next", "rect": func() -> Rect2: return _hud.get_node("VBox/Calc").get_global_rect(),
			"text": "Acertou! Cada tiro vale fichas × multiplicador."},
		{"on": &"shot", "rect": _cell(2, 1),
			"text": "Acertos seguidos fazem COMBO e sobem o multiplicador. Atire em C2, logo ao lado."},
		{"on": &"next", "rect": _grid_rect,
			"text": "Afundou! Navio afundado dá bônus de fichas, e a água em volta fica marcada sozinha."},
		{"on": &"select", "rect": func() -> Rect2: return _fleet_bar.card_rect(sonar_ship),
			"check": func() -> bool: return _board.selected_ship == sonar_ship,
			"text": "Agora o sonar: ele não gasta tiro e recarrega quando você afunda um navio. Clique no Navio-sonar."},
		{"on": &"sonar", "rect": _cell(3, 3),
			"check": func() -> bool: return sonar_ship.charges < sonar_ship.round_cap,
			"text": "O sonar revela 3 casas da linha. Use em D4."},
		{"on": &"next", "rect": _cells(Vector2i(2, 3), Vector2i(4, 3)),
			"text": "Teal = tem navio ali. Pontilhado = só água."},
		{"on": &"select", "rect": func() -> Rect2: return _fleet_bar.card_rect(battleship),
			"check": func() -> bool: return _board.selected_ship == battleship,
			"text": "Arme o Encouraçado de novo."},
		{"on": &"shot", "rect": _cell(3, 3),
			"text": "Atire onde o sonar achou o navio."},
		{"on": &"shot", "rect": _cell(3, 4),
			"text": "O navio segue para baixo. Afunde em D5!"},
		{"on": &"won",
			"text": "Sem tiros, a rodada acaba e conta os pontos..."},
		{"on": &"final",
			"text": "Treino concluído: meta batida e +$4 de saque! Na campanha ainda tem mapa de rotas, almirantes, blindagem, minas e submarinos. Bons mares, almirante!"},
	]
	return steps

func _ship_of(kind: PlayerShip.Kind) -> PlayerShip:
	for ship in Game.player_ships:
		if ship.kind == kind:
			return ship
	return null

## Linha do navio `i` (so navios de tiro) na coluna de tiros da loja.
func _shop_row(i: int) -> Rect2:
	if _shop.shot_rows.get_child_count() <= i:
		return Rect2()
	return (_shop.shot_rows.get_child(i) as Control).get_global_rect()

func _grid_rect() -> Rect2:
	return (_board.get_node("Margin/VBox/GridFrame") as Control).get_global_rect()

func _cell(x: int, y: int) -> Callable:
	return func() -> Rect2:
		var p := Vector2i(x, y)
		return _board.cell_rect(p) if _board.cells.has(p) else Rect2()

func _cells(a: Vector2i, b: Vector2i) -> Callable:
	return func() -> Rect2:
		if not (_board.cells.has(a) and _board.cells.has(b)):
			return Rect2()
		return _board.cell_rect(a).merge(_board.cell_rect(b))

# --- Fluxo ---------------------------------------------------------------------

func _event(name: StringName) -> void:
	if _i < 0 or _i >= _steps.size():
		return
	var st: Dictionary = _steps[_i]
	if st["on"] != name:
		return
	if st.has("check") and not (st["check"] as Callable).call():
		return
	_go(_i + 1)

func _go(i: int) -> void:
	_i = i
	var st: Dictionary = _steps[i]
	var on: StringName = st["on"]
	var final: bool = on == &"final"
	_text.text = st["text"]
	_next_btn.visible = on == &"next" or final
	_next_btn.text = "Jogar campanha" if final else "Próximo"
	_skip_btn.text = "Voltar ao menu" if final else "Pular treino"
	_hole_block.visible = on in [&"next", &"won", &"final"]
	_bubble.modulate.a = 0.0
	create_tween().tween_property(_bubble, "modulate:a", 1.0, 0.15)
	if _next_btn.visible:
		_next_btn.grab_focus()

func _on_next() -> void:
	if _steps[_i]["on"] == &"final":
		_finish(true)
	else:
		_event(&"next")

func _finish(play: bool) -> void:
	_i = -1
	set_process(false)
	visible = false
	finished.emit(play)

# --- Desenho -------------------------------------------------------------------

## Recalcula o buraco todo quadro: a grade so ganha tamanho um quadro depois de
## montada e o HUD treme/pula.
func _process(delta: float) -> void:
	_pulse += delta
	var st: Dictionary = _steps[_i]
	var r: Rect2 = (st["rect"] as Callable).call() if st.has("rect") else Rect2()
	_set_hole(r)
	_place_bubble()
	_frame.queue_redraw()

func _set_hole(r: Rect2) -> void:
	var s := size
	if not r.has_area():
		_hole = Rect2()
		_place(_blocks[0], Rect2(Vector2.ZERO, s))
		for b in [_blocks[1], _blocks[2], _blocks[3], _hole_block]:
			_place(b, Rect2())
		return
	_hole = Rect2(r.position - global_position, r.size).grow(HOLE_PAD)
	var h := _hole
	_place(_blocks[0], Rect2(0, 0, s.x, h.position.y))
	_place(_blocks[1], Rect2(0, h.end.y, s.x, s.y - h.end.y))
	_place(_blocks[2], Rect2(0, h.position.y, h.position.x, h.size.y))
	_place(_blocks[3], Rect2(h.end.x, h.position.y, s.x - h.end.x, h.size.y))
	_place(_hole_block, h)

func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = Vector2(maxf(r.size.x, 0.0), maxf(r.size.y, 0.0))

## Balao embaixo do buraco; se nao couber, em cima; sem buraco, no centro.
func _place_bubble() -> void:
	var bs := _bubble.get_combined_minimum_size()
	_bubble.size = bs
	var s := size
	if not _hole.has_area():
		_bubble.position = (s - bs) / 2.0
		return
	var below := _hole.end.y + GAP
	var above := _hole.position.y - GAP - bs.y
	var y := below if below + bs.y <= s.y - EDGE else maxf(EDGE, above)
	var x := clampf(_hole.get_center().x - bs.x / 2.0, EDGE, s.x - bs.x - EDGE)
	_bubble.position = Vector2(x, y)

func _draw_frame() -> void:
	if not _hole.has_area():
		return
	var a := 0.6 + 0.4 * sin(_pulse * 5.0)
	_frame.draw_rect(_hole, Color(FRAME, a), false, 3.0)
