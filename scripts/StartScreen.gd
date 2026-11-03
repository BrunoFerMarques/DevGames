extends Control
class_name StartScreen
## Tela de inicio: mar rolando com um navio cruzando ao fundo, logo do
## RogueShip balancando e o menu. "Jogar" comeca uma run do zero (sinal
## `play`; Main chama Game.reset_run()). Se ja venceu algum chefe, oferece
## continuar do checkpoint (sinal `resume`; Main chama Game.load_checkpoint()).
## Mar e navio ficam dentro de Stage, na mesma escala de pixel da doca, e
## Stage e' escalado pra cobrir a tela.

signal play
signal resume

const STAGE_SIZE := Vector2(640, 360)
const SEA_TILE := 256.0       # lado do water_texture; rolar 1 tile fecha o loop
const SEA_SCROLL_TIME := 10.0
const SAIL_TIME := 18.0       # navio cruza a tela inteira
const SAIL_FROM := -200.0     # casco + esteira fora da tela pela esquerda
const SAIL_TO := 800.0        # ...e pela direita
const BOB_PX := 6.0
const BOB_TIME := 1.6

@onready var stage: Control = $Stage
@onready var sea: TextureRect = $Stage/Sea
@onready var ship: Control = $Stage/Ship
@onready var wake: SpriteSheetPlayer = $Stage/Ship/Wake
@onready var smoke: SpriteSheetPlayer = $Stage/Ship/Smoke
@onready var menu: VBoxContainer = $Menu
@onready var logo: TextureRect = $Menu/LogoBox/Logo
@onready var play_btn: Button = $Menu/Play
@onready var resume_btn: Button = $Menu/Resume
@onready var quit_btn: Button = $Menu/Quit
@onready var record_label: Label = $Menu/Record

var _tweens: Array[Tween] = []

func _ready() -> void:
	play_btn.pressed.connect(func(): play.emit())
	resume_btn.pressed.connect(func(): resume.emit())
	quit_btn.pressed.connect(func(): get_tree().quit())
	# No navegador nao tem janela pra fechar.
	quit_btn.visible = not OS.has_feature("web")
	# Pop do logo cresce a partir do centro, qualquer que seja o tamanho da tela.
	logo.resized.connect(func(): logo.pivot_offset = logo.size / 2.0)
	resized.connect(_fit_stage)
	_fit_stage()

func open() -> void:
	visible = true
	resume_btn.visible = Game.has_checkpoint()
	if resume_btn.visible:
		resume_btn.text = "Continuar (Ante %d)" % Game.checkpoint["ante"]
	var r := Game.ROUNDS_PER_ANTE
	record_label.visible = Game.best_index > 0
	record_label.text = "Recorde: Ante %d · Rodada %d" % [Game.best_index / r + 1, Game.best_index % r + 1]

	_kill_tweens()
	_fit_stage()
	wake.play()
	smoke.play()
	var sea_tw := _track(create_tween().set_loops())
	sea_tw.tween_property(sea, "position:x", -SEA_TILE, SEA_SCROLL_TIME).from(0.0)
	var sail := _track(create_tween().set_loops())
	sail.tween_property(ship, "position:x", SAIL_TO, SAIL_TIME).from(SAIL_FROM)
	var bob := _track(create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))
	bob.tween_property(logo, "position:y", -BOB_PX, BOB_TIME).from(BOB_PX)
	bob.tween_property(logo, "position:y", BOB_PX, BOB_TIME)

	# Entra com "pop" (menu aparece, logo cresce passando um pouco e assenta).
	menu.modulate.a = 0.0
	logo.scale = Vector2.ONE * 0.85
	var tw := _track(create_tween().set_parallel())
	tw.tween_property(menu, "modulate:a", 1.0, 0.3)
	tw.tween_property(logo, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Enter/Espaco ja jogam sem precisar do mouse.
	play_btn.grab_focus()

## Esconde e para as animacoes (Main chama com a cortina fechada).
func close() -> void:
	_kill_tweens()
	wake.stop()
	smoke.stop()
	visible = false

func _track(tw: Tween) -> Tween:
	_tweens.append(tw)
	return tw

func _kill_tweens() -> void:
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()

## Escala o Stage pra cobrir a tela inteira (como KEEP_ASPECT_COVERED), centralizado.
func _fit_stage() -> void:
	var s: float = maxf(size.x / STAGE_SIZE.x, size.y / STAGE_SIZE.y)
	stage.scale = Vector2(s, s)
	stage.position = (size - STAGE_SIZE * s) / 2.0
