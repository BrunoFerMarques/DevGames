extends Node
class_name ImpactFx
## Peso dos golpes: tremor de tela e congelada rapida (hit-stop) que crescem
## com o streak, mais os pontos do tiro subindo da casa atingida. Liga no
## Board pelo sinal shot_resolved (Main chama bind). O tremor mexe no no pai
## inteiro (Main) e respeita a opcao Game.screen_shake.
## Tremor por "trauma": cada golpe soma, o trauma cai sozinho e o
## deslocamento e' trauma^2 - golpe fraco quase nao mexe, golpe em cima de
## golpe sacode forte.

const MAX_OFFSET := 16.0       # px de deslocamento com trauma 1
const DECAY := 1.8             # trauma perdido por segundo
const HIT_TRAUMA := 0.2
const STREAK_TRAUMA := 0.07    # por acerto seguido, ate STREAK_CAP
const STREAK_CAP := 6
const SINK_TRAUMA := 0.35
const MINE_TRAUMA := 0.55
const ARMOR_TRAUMA := 0.15
const HITSTOP_SCALE := 0.05    # Engine.time_scale durante a congelada
const SINK_HITSTOP := 0.09     # segundos de tempo real
const FIRE_HITSTOP := 0.05     # acerto com o mult pegando fogo (Hud.FIRE_STREAK+)
const MINE_HITSTOP := 0.07
const POP_GROW := 0.15         # numero cresce por acerto seguido, ate STREAK_CAP
const SINK_GROW := 0.3
const CREAM := Color("#fdf6e3")
const GOLD := Color("#f3c44b")
const MINE_RED := Color("#e4573c")

var _board: Board
var _shot_fx: ShotFx
var _target: Control
var _rest_pos: Vector2
var _trauma: float = 0.0
var _stop_id: int = 0

func bind(board: Board, shot_fx: ShotFx) -> void:
	_board = board
	_shot_fx = shot_fx
	_target = get_parent()
	_rest_pos = _target.position
	board.shot_resolved.connect(_on_shot)

func add_trauma(amount: float) -> void:
	if not Game.screen_shake:
		return
	_trauma = minf(1.0, _trauma + amount)

## Quase congela o jogo por `sec` (tempo real) pro golpe "pesar". Congelada
## pedida no meio de outra estende ate o fim da mais nova.
func hit_stop(sec: float) -> void:
	_stop_id += 1
	var id := _stop_id
	Engine.time_scale = HITSTOP_SCALE
	await get_tree().create_timer(sec, true, false, true).timeout
	if id == _stop_id:
		Engine.time_scale = 1.0

func _process(delta: float) -> void:
	if _trauma <= 0.0:
		return
	_trauma = maxf(0.0, _trauma - DECAY * delta)
	var px := _trauma * _trauma * MAX_OFFSET
	_target.position = _rest_pos + Vector2(randf_range(-px, px), randf_range(-px, px))
	if _trauma == 0.0:
		_target.position = _rest_pos

func _on_shot(d: Dictionary) -> void:
	var streak: int = _board.streak
	var heat := mini(streak, STREAK_CAP)
	var rect := _board.cell_rect(d["coord"])
	if d["mine"] and not d["hit"]:
		add_trauma(MINE_TRAUMA)
		hit_stop(MINE_HITSTOP)
		_shot_fx.pop_text(rect, "MINA!", MINE_RED, 1.2)
		return
	if d["armor"]:
		add_trauma(ARMOR_TRAUMA)
	elif d["hit"]:
		add_trauma(HIT_TRAUMA + STREAK_TRAUMA * heat + (SINK_TRAUMA if d["sank"] else 0.0))
		if d["sank"]:
			hit_stop(SINK_HITSTOP)
		elif streak >= Hud.FIRE_STREAK:
			hit_stop(FIRE_HITSTOP)
	if d["gained"] > 0:
		# Mesma escala de cor do combo no Hud; navio afundado sai dourado.
		var color := CREAM
		if d["sank"]:
			color = GOLD
		elif streak >= 2:
			color = Hud.HEAT[mini(streak - 2, Hud.HEAT.size() - 1)]
		var grow := 1.0 + POP_GROW * heat + (SINK_GROW if d["sank"] else 0.0)
		_shot_fx.pop_text(rect, "+%d" % d["gained"], color, grow)
