extends Control
class_name DockTransition
## Transicao ao vencer a rodada: o navio entra pela esquerda, desacelera e
## atraca no cais da doca; depois emite `finished` (Main abre a loja).
## Clique, Enter ou Esc pulam.
## Tudo dentro de Stage esta em pixels da doca_fundo.png (640x384) e Stage e'
## escalado pra cobrir a tela, entao o navio fica sempre alinhado com o cais.
## Water recorta na linha do cais (y 236): respingo nao invade o concreto.
## A posicao de atracacao e' a do Ship na cena - arraste no editor pra ajustar.

signal finished

const STAGE_SIZE := Vector2(640, 384)
const SAIL_TIME := 3.0
const SLOW_WAKE_AT := 0.55   # fracao da viagem em que a esteira desacelera
const FADE_TIME := 0.4       # esteira/onda somem depois de parar
const HOLD_TIME := 0.8       # parado no cais antes de abrir a loja

@onready var stage: Control = $Stage
@onready var ship: Control = $Stage/Water/Ship
@onready var wake_fast: SpriteSheetPlayer = $Stage/Water/Ship/WakeFast
@onready var wake_slow: SpriteSheetPlayer = $Stage/Water/Ship/WakeSlow
@onready var bow_wave: SpriteSheetPlayer = $Stage/Water/Ship/BowWave
@onready var smoke: SpriteSheetPlayer = $Stage/Water/Ship/Smoke

var _dock_x: float
var _tween: Tween
var _done: bool = true

func _ready() -> void:
	_dock_x = ship.position.x
	resized.connect(_fit_stage)
	_fit_stage()

func play() -> void:
	visible = true
	_done = false
	_fit_stage()
	# Comeca logo fora da borda esquerda; a esteira fica pra tras, fora da tela.
	ship.position.x = -ship.size.x
	for fx in [wake_fast, bow_wave, smoke]:
		fx.modulate.a = 1.0
		fx.play()
	wake_slow.modulate.a = 1.0
	wake_slow.stop()

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(ship, "position:x", _dock_x, SAIL_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_callback(_slow_down).set_delay(SAIL_TIME * SLOW_WAKE_AT)
	# Parou: esteira e onda de proa somem, so a fumaca continua.
	_tween.tween_property(wake_slow, "modulate:a", 0.0, FADE_TIME)
	_tween.parallel().tween_property(bow_wave, "modulate:a", 0.0, FADE_TIME)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_callback(_finish)

func _slow_down() -> void:
	wake_fast.stop()
	wake_slow.play()

func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween:
		_tween.kill()
	# Continua visivel ate a cortina cobrir; quem esconde e' o Main (stop).
	finished.emit()

## Esconde a cena (Main chama com a tela ja coberta pela cortina).
func stop() -> void:
	for fx in [wake_fast, wake_slow, bow_wave, smoke]:
		fx.stop()
	visible = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_finish()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		_finish()

## Escala o Stage pra cobrir a tela inteira (como KEEP_ASPECT_COVERED), centralizado.
func _fit_stage() -> void:
	var s: float = maxf(size.x / STAGE_SIZE.x, size.y / STAGE_SIZE.y)
	stage.scale = Vector2(s, s)
	stage.position = (size - STAGE_SIZE * s) / 2.0
