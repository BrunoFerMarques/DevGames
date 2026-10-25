extends Control
class_name SinkTransition
## Animacao de derrota: o navio a deriva leva uma sequencia de explosoes,
## pega fogo e afunda; depois emite `finished` (Main mostra o GameOver por
## cima, com este mar ainda visivel atras). Clique, Enter ou Esc pulam.
## Tudo dentro de Stage esta na mesma escala de pixel da doca (sprites 4x)
## e Stage e' escalado pra cobrir a tela.

signal finished

const BURST_SHEET: Texture2D = preload("res://sprites/efeitos/hits.png")
const FIRE_SHEET: Texture2D = preload("res://sprites/efeitos/hit_fire_sheet.png")
const SPLASH_SHEET: Texture2D = preload("res://sprites/efeitos/agua_respingo_sheet.png")

const STAGE_SIZE := Vector2(640, 360)
# Pontos de impacto no casco (coords do navio_guerra 192x64, popa -> proa).
const HIT_POINTS: Array[Vector2] = [Vector2(132, 30), Vector2(40, 36), Vector2(164, 34), Vector2(88, 28)]
const HIT_GAP := 0.35        # intervalo entre explosoes
const SHAKE_PX := 10.0
const DRIFT_PX := 40.0       # navio a deriva pra frente durante tudo
const SINK_TIME := 1.6
const HOLD_TIME := 0.5
# Fileira de chamas atras do titulo: 64px do sprite em 1.5x, base um pouco
# abaixo das letras pra elas ficarem "sobre" o fogo.
const FLAME_SIZE := 96.0
const FLAME_STEP := 56.0
const FLAME_BASE_EM := 0.6   # base das chamas abaixo do centro do texto, em fracao do tamanho da fonte

@onready var stage: Control = $Stage
@onready var ship: Control = $Stage/Ship
@onready var wake: SpriteSheetPlayer = $Stage/Ship/Wake
@onready var smoke: SpriteSheetPlayer = $Stage/Ship/Smoke
@onready var title: Control = $Title
@onready var title_label: Label = $Title/Label
@onready var flames: Control = $Title/Flames

var _ship_start: Vector2
var _stage_origin: Vector2
var _tweens: Array[Tween] = []
var _spawned: Array[Node] = []
var _done: bool = true

func _ready() -> void:
	_ship_start = ship.position
	resized.connect(_fit_stage)
	_fit_stage()

func play() -> void:
	visible = true
	_done = false
	_fit_stage()
	_reset()
	wake.play()
	smoke.play()

	var drift := _track(create_tween())
	drift.tween_property(ship, "position:x", _ship_start.x + DRIFT_PX, HIT_GAP * HIT_POINTS.size() + SINK_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var seq := _track(create_tween())
	for p in HIT_POINTS:
		seq.tween_interval(HIT_GAP)
		seq.tween_callback(_explode.bind(p))
	seq.tween_interval(HIT_GAP)
	seq.tween_callback(_sink)
	seq.tween_interval(SINK_TIME + HOLD_TIME)
	seq.tween_callback(_finish)

## Esconde tudo (Main chama ao comecar um jogo novo).
func stop() -> void:
	_kill_tweens()
	_done = true
	visible = false

func _explode(p: Vector2) -> void:
	var burst := _spawn(ship, BURST_SHEET, 6, 14.0, false, p - Vector2(32, 32))
	# Fogo nasce quando a explosao acaba; base da chama fica no ponto atingido.
	burst.finished.connect(func():
		if not _done:
			_spawn(ship, FIRE_SHEET, 4, 8.0, true, p - Vector2(32, 56))
	)
	_shake()

## Casco escurece, inclina e some na agua (filhos - fogo, fumaca, esteira - somem junto).
func _sink() -> void:
	wake.stop()
	_show_title()
	var tw := _track(create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN))
	tw.tween_property(ship, "modulate", Color(0.2, 0.35, 0.5, 0.0), SINK_TIME)
	tw.tween_property(ship, "rotation_degrees", 8.0, SINK_TIME)
	tw.tween_property(ship, "scale", Vector2.ONE * 0.9, SINK_TIME)
	# Respingos ficam no Stage (nao no navio) pra nao sumirem com ele.
	var splashes := _track(create_tween())
	for p in HIT_POINTS:
		splashes.tween_callback(func():
			if not _done:
				# So os 3 primeiros quadros: os ultimos viram o pino de "agua" do tabuleiro.
				_spawn(stage, SPLASH_SHEET, 3, 10.0, false, ship.position + p - Vector2(32, 32))
		)
		splashes.tween_interval(SINK_TIME / HIT_POINTS.size())

func _finish() -> void:
	if _done:
		return
	_done = true
	_kill_tweens()
	ship.visible = false
	stage.position = _stage_origin
	# Pulou antes do afundamento: titulo aparece direto, sem o pop.
	_show_title()
	title.scale = Vector2.ONE
	title.modulate.a = 1.0
	finished.emit()

## "Rodada perdida" entra com pop por cima de uma fileira de chamas do
## tamanho do texto.
func _show_title() -> void:
	if title.visible:
		return
	title.visible = true
	var fs := title_label.get_theme_font_size("font_size")
	var text_w := title_label.get_theme_font("font").get_string_size(
		title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var left := (title.size.x - text_w) / 2.0 - FLAME_STEP / 2.0
	var base_y := title.size.y / 2.0 + fs * FLAME_BASE_EM
	for i in int((text_w + FLAME_STEP) / FLAME_STEP) + 1:
		var at := Vector2(left + i * FLAME_STEP - FLAME_SIZE / 2.0, base_y - FLAME_SIZE)
		# fps diferentes dessincronizam as chamas.
		var flame := _spawn(flames, FIRE_SHEET, 4, randf_range(7.0, 10.0), true, at)
		flame.size = Vector2.ONE * FLAME_SIZE
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2.ONE * 1.6
	title.modulate.a = 0.0
	var tw := _track(create_tween().set_parallel())
	tw.tween_property(title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title, "modulate:a", 1.0, 0.2)
	_shake()

func _shake() -> void:
	var tw := _track(create_tween())
	for i in 4:
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_PX
		tw.tween_property(stage, "position", _stage_origin + off, 0.04)
	tw.tween_property(stage, "position", _stage_origin, 0.04)

func _reset() -> void:
	_kill_tweens()
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
	ship.visible = true
	ship.position = _ship_start
	ship.modulate = Color.WHITE
	ship.rotation_degrees = 0.0
	ship.scale = Vector2.ONE
	stage.position = _stage_origin
	title.visible = false

func _spawn(parent: Control, sheet: Texture2D, frames: int, fps: float, loop: bool, at: Vector2) -> SpriteSheetPlayer:
	var player := SpriteSheetPlayer.new()
	player.sheet = sheet
	player.frame_count = frames
	player.fps = fps
	player.loop = loop
	player.fill_parent = false
	parent.add_child(player)
	player.size = Vector2.ONE * sheet.get_height()
	player.position = at
	if not loop:
		player.finished.connect(player.queue_free)
	_spawned.append(player)
	player.play()
	return player

func _track(tw: Tween) -> Tween:
	_tweens.append(tw)
	return tw

func _kill_tweens() -> void:
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_finish()

func _unhandled_input(event: InputEvent) -> void:
	if visible and not _done and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		_finish()

## Escala o Stage pra cobrir a tela inteira (como KEEP_ASPECT_COVERED), centralizado.
func _fit_stage() -> void:
	var s: float = maxf(size.x / STAGE_SIZE.x, size.y / STAGE_SIZE.y)
	stage.scale = Vector2(s, s)
	_stage_origin = (size - STAGE_SIZE * s) / 2.0
	stage.position = _stage_origin
