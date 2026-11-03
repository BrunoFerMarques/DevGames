extends Control
class_name StreakGlow
## A tela "esquenta" com o streak: brilho nas bordas na cor do combo (mesma
## escala do mult no Hud), pulsando, e a partir de Hud.FIRE_STREAK uma fileira
## de chamas sobe do pe da tela, mais alta a cada acerto. Fica logo acima do
## tabuleiro e atras da frota e do painel, sem pegar clique.

const FIRE_SHEET: Texture2D = preload("res://sprites/efeitos/hit_fire_sheet.png")
# Intensidade do brilho por acertos seguidos (indice = streak; o ultimo vale pra cima).
const GLOW_BY_STREAK: Array[float] = [0.0, 0.0, 0.35, 0.5, 0.6, 0.7, 0.8]
const GLOW_TIME := 0.25
const GLOW_FLASH := 0.2        # brilho extra no instante do acerto, depois assenta
const GLOW_WIDTH := 0.06       # espessura base (fracao da altura) ...
const GLOW_WIDTH_STEP := 0.02  # ... + isso por acerto seguido, ate 6
const FLAME_SIZE := 64.0       # altura das chamas no 1o nivel de fogo (= quadro do sheet)
const FLAME_GROW := 16.0       # + isso por acerto alem do FIRE_STREAK
const FLAME_MAX := 128.0       # = altura do no Flames
const FLAME_STEP := 0.6        # passo entre chamas, em fracao da altura delas
const FLAME_ALPHA := 0.85

@onready var glow: ColorRect = $Glow
@onready var flames: Control = $Flames

var _mat: ShaderMaterial
var _streak: int = 0
var _flame_size: float = 0.0
var _glow_tween: Tween
var _flame_tween: Tween

func _ready() -> void:
	_mat = glow.material
	resized.connect(_on_resized)
	_on_resized()

func bind(board: Board) -> void:
	board.combo_changed.connect(_on_combo_changed)

func _on_combo_changed(streak: int, _combo_mult: int) -> void:
	var grew := streak > _streak
	_streak = streak
	var level: float = GLOW_BY_STREAK[mini(streak, GLOW_BY_STREAK.size() - 1)]
	if streak >= 2:
		_mat.set_shader_parameter("glow_color", Hud.HEAT[mini(streak - 2, Hud.HEAT.size() - 1)])
		_mat.set_shader_parameter("width", GLOW_WIDTH + GLOW_WIDTH_STEP * mini(streak, 6))
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween()
	if grew and level > 0.0:
		_glow_tween.tween_property(_mat, "shader_parameter/intensity", minf(1.0, level + GLOW_FLASH), 0.06)
	_glow_tween.tween_property(_mat, "shader_parameter/intensity", level, GLOW_TIME)

	var fire := streak - Hud.FIRE_STREAK
	_set_flames(minf(FLAME_SIZE + FLAME_GROW * fire, FLAME_MAX) if fire >= 0 else 0.0)

## Refaz a fileira de chamas na altura `s` (0 apaga com fade).
func _set_flames(s: float) -> void:
	if s == _flame_size:
		return
	var was_lit := _flame_size > 0.0
	_flame_size = s
	if _flame_tween and _flame_tween.is_valid():
		_flame_tween.kill()
	if s == 0.0:
		_flame_tween = create_tween()
		_flame_tween.tween_property(flames, "modulate:a", 0.0, GLOW_TIME)
		_flame_tween.tween_callback(_clear_flames)
		return
	_build_flames()
	if not was_lit:
		flames.modulate.a = 0.0
		_flame_tween = create_tween()
		_flame_tween.tween_property(flames, "modulate:a", FLAME_ALPHA, GLOW_TIME)
	else:
		flames.modulate.a = FLAME_ALPHA

func _build_flames() -> void:
	_clear_flames()
	var s := _flame_size
	var step := s * FLAME_STEP
	for i in int(flames.size.x / step) + 2:
		var flame := SpriteSheetPlayer.new()
		flame.sheet = FIRE_SHEET
		flame.frame_count = 4
		# fps diferentes dessincronizam as chamas.
		flame.fps = randf_range(7.0, 10.0)
		flame.loop = true
		flame.fill_parent = false
		flames.add_child(flame)
		flame.size = Vector2.ONE * s
		# Base da chama um pouco abaixo da borda, pra nao ficar "flutuando".
		flame.position = Vector2(i * step - s / 2.0, flames.size.y - s * 0.85)
		flame.play()

func _clear_flames() -> void:
	for child in flames.get_children():
		child.queue_free()

func _on_resized() -> void:
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	if _flame_size > 0.0:
		_build_flames()
