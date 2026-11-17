extends Control
class_name Tutorial
## Rodada de treino guiada (tela de inicio > Treino). Escurece a tela e abre
## um "buraco" so no que o passo pede (botao, carta, casa): cliques fora dele
## sao barrados. Cada passo espera um evento do jogo (comprar tiro, zarpar,
## selecionar navio, atirar, usar sonar) ou o botao Proximo. O tabuleiro do
## treino e' fixo (Game.setup_tutorial), entao o roteiro sempre bate.
## Depois da rodada, um tour so de leitura pela loja e pela carta nautica
## (passo com "screen": Main troca a tela pedida).

signal finished(play: bool)
## Passo do tour pede outra tela: &"shop" ou &"map" (Main faz a troca).
signal screen_requested(screen: StringName)

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
var _map: LevelMap
var _enemy_fleet: EnemyFleetPanel

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
func bind(shop: Shop, board: Board, fleet_bar: FleetBar, hud: Hud, map: LevelMap,
		enemy_fleet: EnemyFleetPanel) -> void:
	_shop = shop
	_board = board
	_fleet_bar = fleet_bar
	_hud = hud
	_map = map
	_enemy_fleet = enemy_fleet
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
##   check: Callable -> bool (opcional, condicao extra pro evento contar),
##   screen: tela que o Main abre ao entrar no passo (opcional) }
## on = next/won/final: passo de leitura (o buraco nao recebe clique).
func _build_steps() -> Array[Dictionary]:
	var battleship := _ship_of(&"battleship")
	var cruiser := _ship_of(&"cruiser")
	var sonar_ship := _ship_of(&"sonar_ship")
	var steps: Array[Dictionary] = [
		# --- Loja: carga ---
		{"on": &"next",
			"text": "Bem-vindo ao treino, almirante! Em poucos minutos você aprende a batalha, a loja e o mapa."},
		{"on": &"money", "rect": func() -> Rect2: return _shop.load_all_btn.get_global_rect(),
			"check": func() -> bool: return Game.money < Game.SHOT_PRICE,
			"text": "Seus navios saem VAZIOS: antes de cada rodada você compra os tiros, $1 cada (o + e o - carregam um navio por vez). Clique em Carregar tudo."},
		{"on": &"round", "rect": func() -> Rect2: return _shop.continue_btn.get_global_rect(),
			"text": "Encouraçado e Cruzador carregados. Clique em Zarpar."},
		# --- Batalha ---
		{"on": &"next", "rect": func() -> Rect2: return _enemy_fleet.get_global_rect(),
			"text": "Esta é a frota inimiga. BLIND marca casco blindado e $4 é o saque que o Cargueiro paga ao afundar (quanto menor o navio, mais paga). E tem 1 MINA escondida na grade."},
		{"on": &"next", "rect": _grid_rect,
			"text": "Os números em volta da grade dizem quantas casas de navio faltam em cada linha e coluna. Navios nunca se encostam, nem na diagonal."},
		{"on": &"select", "rect": func() -> Rect2: return _fleet_bar.card_rect(battleship),
			"check": func() -> bool: return _board.selected_ship == battleship,
			"text": "Clique no Encouraçado para armar um tiro."},
		{"on": &"shot", "rect": _cell(1, 1),
			"text": "Atire na casa B2."},
		{"on": &"shot", "rect": _cell(1, 1),
			"text": "BLINDADO! O 1º tiro só amassa a casa: não pontua, mas também não quebra o combo. Atire de novo em B2."},
		{"on": &"next", "rect": func() -> Rect2: return _hud.get_node("VBox/Calc").get_global_rect(),
			"text": "Acertou! Cada tiro vale fichas × multiplicador. As casas na diagonal viraram água, já que navios não se encostam."},
		{"on": &"shot", "rect": _cell(2, 1),
			"text": "Acertos seguidos fazem COMBO e sobem o multiplicador; tiro na água zera. Atire em C2, logo ao lado."},
		{"on": &"shot", "rect": _cell(2, 1),
			"text": "Amassou a blindagem de novo. Mais um em C2 afunda o navio!"},
		{"on": &"next", "rect": _grid_rect,
			"text": "Afundou! Navio afundado dá bônus de fichas (blindado dá ainda mais) e a água em volta fica marcada sozinha."},
		{"on": &"select", "rect": func() -> Rect2: return _fleet_bar.card_rect(sonar_ship),
			"check": func() -> bool: return _board.selected_ship == sonar_ship,
			"text": "Agora o sonar: ele não gasta tiro e recarrega quando você afunda um navio. Clique no Navio-sonar."},
		{"on": &"sonar", "rect": _cell(2, 3),
			"check": func() -> bool: return sonar_ship.charges < sonar_ship.round_cap,
			"text": "O sonar revela 3 casas da linha. Use em C4."},
		{"on": &"next", "rect": _cells(Vector2i(1, 3), Vector2i(3, 3)),
			"text": "O círculo que pulsa marca navio e o pontilhado marca água. Em B4 o sonar achou a MINA: tiro nela gasta 1 tiro extra e zera o combo. Submarinos (SUB) passam batido pelo sonar."},
		{"on": &"select", "rect": func() -> Rect2: return _fleet_bar.card_rect(cruiser),
			"check": func() -> bool: return _board.selected_ship == cruiser,
			"text": "O Encouraçado esvaziou. Cada classe de navio tem uma vantagem: o Cruzador dá +1 de multiplicador no tiro que afunda. Clique no Cruzador."},
		{"on": &"shot", "rect": _cell(3, 3),
			"text": "Atire onde o sonar achou o navio, longe da mina."},
		{"on": &"shot", "rect": _cell(3, 4),
			"text": "O navio segue para baixo. Afunde em D5!"},
		{"on": &"won",
			"text": "Sem tiros, a rodada acaba e conta os pontos..."},
		{"on": &"next", "rect": func() -> Rect2: return _hud.money_box.get_global_rect(),
			"text": "Meta batida! A vitória paga $8, passar da meta paga um bônus e o Cargueiro deu $4 de saque. Se os tiros acabarem abaixo da meta, sua frota afunda: fim de jogo."},
		# --- Tour da loja (so leitura) ---
		{"on": &"next", "screen": &"shop",
			"rect": func() -> Rect2: return (_shop.get_node("Admirals") as Control).get_global_rect(),
			"text": "Entre as rodadas você passa na LOJA. ALMIRANTES são cartas com efeito na run inteira (até 5). Na loja, clique num almirante seu para vendê-lo."},
		{"on": &"next", "rect": func() -> Rect2: return (_shop.get_node("Upgrades") as Control).get_global_rect(),
			"text": "MELHORIAS fortalecem um navio. ARMAMENTOS trocam o tiro dele: Ogiva Perfurante fura blindagem, Torpedo corre a linha, Salva em Cruz acerta 5 casas."},
		{"on": &"next", "rect": func() -> Rect2: return (_shop.get_node("Shipyard") as Control).get_global_rect(),
			"text": "No ESTALEIRO você compra navios novos; o botão $ da sua frota vende. Cada navio ocupa vagas e a soma não pode passar da Doca."},
		{"on": &"next", "rect": func() -> Rect2: return _shop.reroll_btn.get_global_rect(),
			"text": "Não gostou das ofertas? Reroll sorteia tudo de novo e fica $1 mais caro a cada uso na mesma loja."},
		# --- Tour do mapa (so leitura) ---
		{"on": &"next", "screen": &"map", "rect": func() -> Rect2: return _map.ante_rect(Game.ante),
			"text": "Esta é a carta náutica. Cada SETOR tem 3 rodadas. Nas 2 primeiras você escolhe a rota: a segura (em cima) ou a especial (embaixo), Águas perigosas ou Rota do tesouro."},
		{"on": &"next", "rect": func() -> Rect2: return _map.ante_rect(Game.ante),
			"text": "A 3ª rodada é o CHEFE: meta maior e um desafio que muda as regras. Vencer o chefe salva um CHECKPOINT para tentar de novo se afundar."},
		{"on": &"final",
			"text": "Treino concluído! Passar de 1,5× e 2× a meta dá estrelas e $ extra. Vença o chefe do Setor %d para vencer a run e liberar o próximo nível de dificuldade. Bons mares, almirante!" % Game.FINAL_ANTE},
	]
	return steps

## Navio da frota inicial pela classe (Estaleiro: ShipClassCatalog).
func _ship_of(class_id: StringName) -> PlayerShip:
	for ship in Game.player_ships:
		if ship.ship_class and ship.ship_class.id == class_id:
			return ship
	return null

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
	if st.has("screen"):
		screen_requested.emit(st["screen"])
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

## Balao embaixo do buraco; se nao couber, em cima, e senao do lado; sem
## buraco, no centro.
func _place_bubble() -> void:
	var bs := _bubble.get_combined_minimum_size()
	_bubble.size = bs
	var s := size
	if not _hole.has_area():
		_bubble.position = (s - bs) / 2.0
		return
	var below := _hole.end.y + GAP
	var above := _hole.position.y - GAP - bs.y
	var x := clampf(_hole.get_center().x - bs.x / 2.0, EDGE, s.x - bs.x - EDGE)
	if below + bs.y <= s.y - EDGE:
		_bubble.position = Vector2(x, below)
	elif above >= EDGE:
		_bubble.position = Vector2(x, above)
	else:
		# Buraco alto demais (faixa de um ante na carta): balao do lado.
		var y := clampf(_hole.get_center().y - bs.y / 2.0, EDGE, s.y - bs.y - EDGE)
		var right := _hole.end.x + GAP
		var side := right if right + bs.x <= s.x - EDGE else maxf(EDGE, _hole.position.x - GAP - bs.x)
		_bubble.position = Vector2(side, y)

func _draw_frame() -> void:
	if not _hole.has_area():
		return
	var a := 0.6 + 0.4 * sin(_pulse * 5.0)
	_frame.draw_rect(_hole, Color(FRAME, a), false, 3.0)
