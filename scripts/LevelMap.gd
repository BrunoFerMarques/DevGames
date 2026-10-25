extends Control
class_name LevelMap
## Carta nautica entre rodadas (mapa de fases). Cada rodada e' uma parada; as
## rodadas 1 e 2 de cada ante bifurcam (rota segura em cima, especial embaixo)
## e o chefe fecha o ante como parada unica - vencido, vira checkpoint.
## Mostra o ante anterior, o atual e o proximo. A coluna 0 e' o ponto de
## partida: o porto (ante 1) ou o checkpoint do ante antes da janela.
## Na bifurcacao o jogador clica a rota, o navio navega ate ela e so entao
## "Ir para a loja" libera. Nao troca de cena, so fica visivel/invisivel.
## Uma parada e' Vector2i(indice global, rota): rota -1 = parada unica,
## 0 = segura, 1 = especial. Indice -1 = porto.

signal closed
signal resume_requested

const ANTES_SHOWN := 3
const R := 3                 # = Game.ROUNDS_PER_ANTE (const nao le autoload)
const PORT := Vector2i(-1, -1)
const SAIL_DELAY := 0.35     # espera a cortina clarear antes de navegar
const SAIL_TIME := 1.0
const MARGIN_X := 70.0
const WAVE := 0.16           # amplitude do zigue-zague, fracao da altura util
const LANE_GAP := 58.0       # distancia de cada rota da bifurcacao ao centro
const NODE_RADIUS := 24.0
const BOSS_RADIUS := 34.0
const DASH := 12.0           # tracejado das rotas ainda nao navegadas
const MARKER_SIZE := Vector2(120, 40)  # navio_guerra.png (192x64) reduzido
const LABEL_SIZE := 18
const EDGE_STEPS := 24

const GOLD := Color("#f3c44b")
const CREAM := Color("#fdf6e3")
const DIM := Color(0.6, 0.63, 0.68, 1)
const NAVY := Color("#0a1b33")
const SEA := Color("#16304f")
const BOSS_RED := Color("#e43c4f")
const DANGER := Color("#f08a3c")
const TEAL := Color("#2fbfb0")

@onready var chart: Control = $Chart
@onready var info_label: Label = $Panel/VBox/Info
@onready var detail_label: Label = $Panel/VBox/Detail
@onready var record_label: Label = $Panel/VBox/Record
@onready var resume_btn: Button = $Panel/VBox/Buttons/Resume
@onready var continue_btn: Button = $Panel/VBox/Buttons/Continue

var _ship_tex: Texture2D = preload("res://sprites/frota/navio_guerra.png")
var _first_ante: int = 1
var _sail_from: Vector2i = PORT
var _sail_to: Vector2i = PORT
var _sail_t: float = 1.0
var _hover: int = -1         # rota sob o mouse na bifurcacao atual
var _time: float = 0.0
var _tween: Tween

func _ready() -> void:
	chart.draw.connect(_draw_chart)
	continue_btn.pressed.connect(_continue)
	resume_btn.pressed.connect(func():
		resume_btn.disabled = true
		resume_requested.emit()
	)

func _process(delta: float) -> void:
	if not visible:
		return
	# Pulso das paradas e balanco do navio.
	_time += delta
	chart.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		_continue()

## Clique/hover nas rotas da bifurcacao atual.
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouse):
		return
	var lane := _lane_at(event.position - chart.position)
	_hover = lane
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if lane >= 0 else Control.CURSOR_ARROW
	if lane >= 0 and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_lane(lane)

## Chamado pelo Main ja com a rodada configurada. `sail` anima o navio saindo
## da parada anterior quando a atual nao pede escolha (ex.: chegando no chefe).
func open(sail: bool) -> void:
	_first_ante = maxi(1, Game.ante - 1)
	_hover = -1
	resume_btn.disabled = false
	if _tween:
		_tween.kill()
	var cur := Game.stage_index()
	var prev := _node_of(cur - 1)
	if Game.needs_route_choice():
		_sail_from = prev
		_sail_to = prev
		_sail_t = 1.0
	else:
		_sail_to = _node_of(cur)
		_sail_from = prev if sail else _sail_to
		_sail_t = 0.0 if sail else 1.0
		if sail:
			_sail(SAIL_DELAY)
	_refresh_info()

func _pick_lane(lane: int) -> void:
	if lane == Game.stop_lane:
		return
	Game.choose_lane(lane)
	_sail_from = _node_of(Game.stage_index() - 1)
	_sail_to = Vector2i(Game.stage_index(), lane)
	_sail_t = 0.0
	_sail(0.0)
	_refresh_info()

func _sail(delay: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(delay)
	_tween.tween_property(self, "_sail_t", 1.0, SAIL_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _continue() -> void:
	# Evita abrir a loja duas vezes (clique + Enter durante a cortina).
	if continue_btn.disabled:
		return
	continue_btn.disabled = true
	if _tween:
		_tween.kill()
	_sail_t = 1.0
	closed.emit()

func _refresh_info() -> void:
	var head := "Ante %d · Rodada %d/%d" % [Game.ante, Game.round_in_ante, R]
	continue_btn.disabled = Game.needs_route_choice()
	detail_label.remove_theme_color_override("font_color")
	if Game.needs_route_choice():
		info_label.text = head + " · Escolha a rota no mapa"
		var special := Game.special_for(Game.ante, Game.round_in_ante)
		detail_label.text = "Em cima: %s. Embaixo: %s - %s" % [
			Game.STOP_NAMES[Game.Stop.NORMAL], Game.STOP_NAMES[special], Game.STOP_DESCS[special]]
	else:
		info_label.text = head + " · Meta %d" % Game.target_score
		if Game.boss_modifier:
			detail_label.text = "CHEFE: %s - %s" % [Game.boss_modifier.display_name, Game.boss_modifier.description]
			detail_label.add_theme_color_override("font_color", BOSS_RED)
		else:
			var kind := Game.stop_kind()
			detail_label.text = "%s: %s" % [Game.STOP_NAMES[kind], Game.STOP_DESCS[kind]]
			if kind != Game.Stop.NORMAL:
				detail_label.add_theme_color_override("font_color", _stop_color(kind))
	record_label.text = "Recorde: Ante %d · Rodada %d" % [Game.best_index / R + 1, Game.best_index % R + 1]
	# Checkpoint so e' oferecido no comeco de uma run nova.
	resume_btn.visible = Game.has_checkpoint() and Game.stage_index() == 0 and Game.route_log.is_empty()
	if resume_btn.visible:
		resume_btn.text = "Checkpoint: Ante %d" % Game.checkpoint["ante"]

# --- Geometria -----------------------------------------------------------------

func _cols() -> int:
	return ANTES_SHOWN * R + 1

## Indice global da parada na coluna 0 (porto = -1 ou chefe de antes da janela).
func _origin() -> int:
	return (_first_ante - 1) * R - 1

func _col(g: int) -> int:
	return g - _origin()

func _is_fork(g: int) -> bool:
	return g >= 0 and g % R != R - 1

## Rotas existentes numa coluna.
func _lanes(g: int) -> Array[int]:
	if _is_fork(g):
		return [0, 1]
	return [-1]

func _center(col: int) -> Vector2:
	var w := chart.size.x - MARGIN_X * 2.0
	var x := MARGIN_X + w * col / (_cols() - 1)
	return Vector2(x, chart.size.y * 0.55 + chart.size.y * WAVE * sin(col * 1.1 + 0.5))

func _pos(n: Vector2i) -> Vector2:
	var p := _center(_col(n.x))
	if n.y >= 0:
		p.y += LANE_GAP * (n.y * 2 - 1)
	return p

## Parada por onde o navio passou (ou vai passar) na coluna g.
func _node_of(g: int) -> Vector2i:
	if g < 0:
		return PORT
	if not _is_fork(g):
		return Vector2i(g, -1)
	if Game.route_log.has(g):
		return Vector2i(g, Game.route_log[g]["lane"])
	if g == Game.stage_index():
		return Vector2i(g, Game.stop_lane)
	return Vector2i(g, -1)

func _taken(n: Vector2i) -> bool:
	var cur := Game.stage_index()
	if n.x < 0 or n.x < cur or (n.x == cur and not Game.needs_route_choice()):
		return _node_of(n.x) == n
	return false

func _radius(n: Vector2i) -> float:
	return BOSS_RADIUS if n.x >= 0 and not _is_fork(n.x) else NODE_RADIUS

func _lane_at(p: Vector2) -> int:
	var cur := Game.stage_index()
	if not visible or not _is_fork(cur):
		return -1
	for lane in [0, 1]:
		if p.distance_to(_pos(Vector2i(cur, lane))) <= NODE_RADIUS + 10.0:
			return lane
	return -1

## Curva da rota entre duas paradas (alcas horizontais, sai e chega reto).
func _edge_point(a: Vector2, b: Vector2, t: float) -> Vector2:
	var h := Vector2((b.x - a.x) * 0.5, 0)
	return a.bezier_interpolate(a + h, b - h, b, t)

func _stop_kind(n: Vector2i) -> int:
	if n.y == 1:
		return Game.special_for(n.x / R + 1, n.x % R + 1)
	return Game.Stop.NORMAL

func _stop_color(kind: int) -> Color:
	return DANGER if kind == Game.Stop.DANGER else GOLD

# --- Desenho -------------------------------------------------------------------

func _draw_chart() -> void:
	var font := get_theme_default_font()
	var last := _origin() + ANTES_SHOWN * R
	_draw_ante_headers(font)
	for g in range(_origin() + 1, last + 1):
		for lane in _lanes(g):
			for prev_lane in _lanes(g - 1):
				_draw_edge(Vector2i(g - 1, prev_lane), Vector2i(g, lane))
	for g in range(_origin(), last + 1):
		for lane in _lanes(g):
			_draw_stop(Vector2i(g, lane), font)
	_draw_record(font)
	_draw_marker()

## Nome de cada ante no topo, com divisoria tracejada entre os grupos.
func _draw_ante_headers(font: Font) -> void:
	for a in ANTES_SHOWN:
		var first := _center(a * R + 1)
		var last := _center(a * R + R)
		var color := GOLD if _first_ante + a == Game.ante else DIM
		_draw_text(font, Vector2((first.x + last.x) / 2.0, 24), "ANTE %d" % (_first_ante + a), LABEL_SIZE + 4, color)
		if a > 0:
			var x := (first.x + _center(a * R).x) / 2.0
			chart.draw_dashed_line(Vector2(x, 8), Vector2(x, chart.size.y - 8), Color(DIM, 0.25), 2.0, 10.0)

## Rota navegada em ouro; a que o navio esta fazendo enche conforme avanca;
## rotas descartadas quase somem; o resto fica tracejado.
func _draw_edge(from: Vector2i, to: Vector2i) -> void:
	var a := _pos(from)
	var b := _pos(to)
	var gold_until := 0.0
	var color := Color(CREAM, 0.5)
	if from == _sail_from and to == _sail_to:
		gold_until = _sail_t
	elif _taken(from) and _taken(to):
		gold_until = 1.0
	elif to.x < Game.stage_index() or (to.x == Game.stage_index() and not _taken(from)):
		color = Color(CREAM, 0.12)
	var prev := a
	var travelled := 0.0
	for k in range(1, EDGE_STEPS + 1):
		var t := float(k) / EDGE_STEPS
		var p := _edge_point(a, b, t)
		if t <= gold_until + 0.001:
			chart.draw_line(prev, p, GOLD, 6.0, true)
		elif int(travelled / DASH) % 2 == 0:
			chart.draw_line(prev, p, color, 4.0, true)
		travelled += prev.distance_to(p)
		prev = p

func _draw_stop(n: Vector2i, font: Font) -> void:
	var cur := Game.stage_index()
	var p := _pos(n)
	var r := _radius(n)
	if n == PORT:
		_draw_port(p, font)
		return
	var boss := not _is_fork(n.x)
	var kind := _stop_kind(n)
	var done := n.x < cur and _taken(n)
	var skipped := n.x < cur and not _taken(n)
	var here := n.x == cur and (boss or n.y == Game.stop_lane)
	var option := n.x == cur and not here

	var fill := SEA
	var border := DIM
	if boss:
		border = Color(BOSS_RED, 0.7)
	elif kind != Game.Stop.NORMAL:
		border = _stop_color(kind)
	var alpha := 1.0
	if done:
		fill = GOLD
		border = NAVY
	elif skipped:
		alpha = 0.3
	elif here:
		r *= 1.0 + 0.06 * sin(_time * 4.0)
		fill = CREAM
		border = BOSS_RED if boss else GOLD
	if here or option:
		var ring := 0.6 if here or _hover == n.y else 0.3
		chart.draw_arc(p, r + 9.0 + 3.0 * sin(_time * 4.0), 0.0, TAU, 48, Color(border, ring), 3.0, true)

	chart.draw_circle(p + Vector2(0, 5), r, Color(0, 0, 0, 0.35 * alpha))
	chart.draw_circle(p, r, Color(fill, alpha))
	chart.draw_arc(p, r, 0.0, TAU, 48, Color(border, alpha), 4.0, true)

	if done and boss:
		MapIcons.flag(chart, p + Vector2(-4, 13), 1.0, TEAL, NAVY)
	elif done:
		chart.draw_polyline(PackedVector2Array([p + Vector2(-9, 0), p + Vector2(-3, 7), p + Vector2(10, -7)]), NAVY, 5.0, true)
	elif boss:
		MapIcons.crown(chart, p, 1.0, Color(BOSS_RED, 1.0 if here else 0.7))
	elif kind == Game.Stop.DANGER:
		_draw_text(font, p + Vector2(0, 8), "!", LABEL_SIZE + 6, Color(NAVY if here else DANGER, alpha))
	elif kind == Game.Stop.TREASURE:
		_draw_text(font, p + Vector2(0, 8), "$", LABEL_SIZE + 6, Color(NAVY if here else GOLD, alpha))
	else:
		_draw_text(font, p + Vector2(0, 8), str(n.x % R + 1), LABEL_SIZE + 4, Color(NAVY if here else CREAM, alpha))

	# Embaixo da parada: estrelas (vencida) e/ou nome. Rota de cima escreve
	# por cima pra nao invadir a de baixo.
	var below := n.y != 0
	var y := r + 14.0 if below else -r - 12.0
	if done:
		MapIcons.star_row(chart, p + Vector2(0, y), 6.0, Game.route_log[n.x]["stars"], 3, GOLD, Color(NAVY, 0.8))
		y += 20.0 if below else -16.0
	var name := _stop_label(n, done, here or option)
	if name != "":
		var color := TEAL if done else (BOSS_RED if boss else border)
		# Rotas da escolha e checkpoint em fonte menor: ficam a 1 coluna um do outro.
		var label_size := LABEL_SIZE if boss and not done else LABEL_SIZE - 3
		_draw_text(font, p + Vector2(0, y + (10.0 if below else 0.0)), name, label_size, color)

## Nome so onde ajuda: chefes (o do ante atual ja revelado) e as rotas da
## escolha atual.
func _stop_label(n: Vector2i, done: bool, current: bool) -> String:
	if _is_fork(n.x):
		return Game.STOP_NAMES[_stop_kind(n)] if current else ""
	if done:
		return "Checkpoint"
	var a: int = n.x / R + 1
	return Game.boss_for(a).display_name if a == Game.ante else "Chefe ?"

func _draw_port(p: Vector2, font: Font) -> void:
	chart.draw_circle(p + Vector2(0, 5), NODE_RADIUS, Color(0, 0, 0, 0.35))
	chart.draw_circle(p, NODE_RADIUS, TEAL)
	chart.draw_arc(p, NODE_RADIUS, 0.0, TAU, 48, NAVY, 4.0, true)
	_draw_text(font, p + Vector2(0, NODE_RADIUS + 26), "Porto", LABEL_SIZE, TEAL)

## Bandeira na parada mais longe ja alcancada, se ela estiver a frente.
func _draw_record(font: Font) -> void:
	var best := Game.best_index
	if best <= Game.stage_index() or _col(best) >= _cols():
		return
	var p := _center(_col(best))
	if not _is_fork(best):
		p.y -= BOSS_RADIUS + 34.0
	MapIcons.flag(chart, p + Vector2(-6, 14), 1.0, TEAL, CREAM)
	_draw_text(font, p + Vector2(0, -18), "Recorde", LABEL_SIZE - 2, TEAL)

## Navio balancando em cima da parada (ou na rota, durante a viagem).
func _draw_marker() -> void:
	var pos := _edge_point(_pos(_sail_from), _pos(_sail_to), _sail_t)
	var r := _radius(_sail_to if _sail_t > 0.5 else _sail_from)
	var bob := 3.0 * sin(_time * 2.5)
	var rect := Rect2(pos + Vector2(-MARKER_SIZE.x / 2.0, -r - MARKER_SIZE.y - 6.0 + bob), MARKER_SIZE)
	# Halo claro achatado embaixo: o casco cinza some no mar escuro sem ele.
	chart.draw_set_transform(rect.get_center() + Vector2(0, 6), 0.0, Vector2(1.0, 0.35))
	chart.draw_circle(Vector2.ZERO, MARKER_SIZE.x * 0.55, Color(CREAM, 0.35))
	chart.draw_set_transform(Vector2.ZERO)
	chart.draw_texture_rect(_ship_tex, rect, false)

func _draw_text(font: Font, center: Vector2, text: String, font_size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := center - Vector2(w / 2.0, 0)
	chart.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(NAVY, color.a))
	chart.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
