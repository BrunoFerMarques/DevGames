extends Button
class_name Cell
## Uma celula clicavel do tabuleiro alvo.

## ARMORED: casa blindada que ja levou um tiro sem furar (ainda da pra atirar).
## MINE: mina detonada. SONAR_MINE: sonar achou mina (da pra atirar, mas explode).
## CLEAR: agua deduzida pela regra de navios nao se encostarem (diagonal de um
## acerto, borda de um afundado) - marcada de graca, nao da pra atirar.
enum State { HIDDEN, WATER, HIT, SUNK, SONAR_SHIP, SONAR_EMPTY, ARMORED, MINE, SONAR_MINE, CLEAR }

signal shot_requested(coord: Vector2i)

var coord: Vector2i
var state: State = State.HIDDEN
var has_ship: bool = false
## Tiros que ainda so amassam a blindagem antes de virar acerto.
var armor: int = 0
var has_mine: bool = false
## Navio submerso: o sonar responde "vazio" aqui.
var sonar_proof: bool = false
## Cor do segmento quando aparece (submarino fica esverdeado).
var ship_tint: Color = Color.WHITE

var _ship_tex: Texture2D = null
var _ship_rot_deg: float = 0.0
var _mark: TextureRect
var _sprite: TextureRect
var _hit_fx: SpriteSheetPlayer
var _sunk_burst: SpriteSheetPlayer
var _sunk_fire: SpriteSheetPlayer
var _splash: SpriteSheetPlayer
var _sonar_blip: SpriteSheetPlayer
var _burnt: SpriteSheetPlayer
var _sparks: SpriteSheetPlayer

const HIT_SMOKE_SHEET: Texture2D = preload("res://sprites/efeitos/hit_smoke_sheet.png")
const SUNK_BURST_SHEET: Texture2D = preload("res://sprites/efeitos/hits.png")
const SUNK_FIRE_SHEET: Texture2D = preload("res://sprites/efeitos/hit_fire_sheet.png")
const WATER_SPLASH_SHEET: Texture2D = preload("res://sprites/efeitos/agua_respingo_sheet.png")
const WATER_MARK: Texture2D = preload("res://sprites/tabuleiro/agua_marca.png")
const SONAR_SHIP_SHEET: Texture2D = preload("res://sprites/tabuleiro/sonar_navio_sheet.png")
const SONAR_EMPTY_MARK: Texture2D = preload("res://sprites/tabuleiro/sonar_vazio.png")
const BURNT_SHEET: Texture2D = preload("res://sprites/tabuleiro/queimado_sheet.png")
const SPARK_SHEET: Texture2D = preload("res://sprites/efeitos/faisca_blindagem_sheet.png")
const MINE_MARK: Texture2D = preload("res://sprites/tabuleiro/mina_detonada.png")
const SONAR_MINE_MARK: Texture2D = preload("res://sprites/tabuleiro/sonar_mina.png")

# Ladrilho pixel art de cada estado. Celula ja atirada fica "afundada" (relevo
# invertido); vermelho so pra acerto; sonar e' informacao, entao fica no teal.
const TILE_TEX := {
	State.HIDDEN: preload("res://sprites/tabuleiro/celula_oculta.png"),
	State.WATER: preload("res://sprites/tabuleiro/celula_agua.png"),
	State.HIT: preload("res://sprites/tabuleiro/celula_acerto.png"),
	State.SUNK: preload("res://sprites/tabuleiro/celula_afundado.png"),
	State.SONAR_SHIP: preload("res://sprites/tabuleiro/celula_sonar.png"),
	State.SONAR_EMPTY: preload("res://sprites/tabuleiro/celula_oculta.png"),
	State.ARMORED: preload("res://sprites/tabuleiro/celula_blindada.png"),
	State.MINE: preload("res://sprites/tabuleiro/celula_agua.png"),
	State.SONAR_MINE: preload("res://sprites/tabuleiro/celula_oculta.png"),
	State.CLEAR: preload("res://sprites/tabuleiro/celula_agua.png"),
}
const CLEAR_MARK_ALPHA := 0.4   # deduzida fica mais apagada que agua atirada
const HOVER_TEX: Texture2D = preload("res://sprites/tabuleiro/celula_hover.png")
const TILE_MARGIN := 8   # borda de 2px da arte (x4); o miolo repete em vez de esticar

static var _style_cache: Dictionary = {}

static func _tile_style(tex: Texture2D) -> StyleBoxTexture:
	if not _style_cache.has(tex):
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.set_texture_margin_all(TILE_MARGIN)
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		_style_cache[tex] = sb
	return _style_cache[tex]

func _ready() -> void:
	custom_minimum_size = Vector2(56, 56)
	focus_mode = Control.FOCUS_NONE
	# Sprites sao pixel art; os filhos herdam o filtro.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pressed.connect(_on_pressed)
	_mark = _new_overlay()
	_sprite = _new_overlay()

	_hit_fx = _new_sheet(HIT_SMOKE_SHEET, 4, 10.0)

	_sunk_burst = _new_sheet(SUNK_BURST_SHEET, 6, 14.0)
	_sunk_burst.finished.connect(func():
		if state == State.SUNK:
			_sunk_fire.play()
	)
	_sunk_fire = _new_sheet(SUNK_FIRE_SHEET, 4, 8.0, true)

	# Respingo termina e deixa a marca fixa de agua no lugar.
	_splash = _new_sheet(WATER_SPLASH_SHEET, 6, 14.0)
	_splash.finished.connect(func():
		if state == State.WATER:
			_mark.visible = true
	)

	_sonar_blip = _new_sheet(SONAR_SHIP_SHEET, 8, 8.0, true)
	_burnt = _new_sheet(BURNT_SHEET, 4, 6.0, true)
	_sparks = _new_sheet(SPARK_SHEET, 4, 14.0)

	_refresh()

func _new_overlay() -> TextureRect:
	var rect := TextureRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	add_child(rect)
	return rect

func _new_sheet(sheet: Texture2D, frames: int, fps: float, loop: bool = false) -> SpriteSheetPlayer:
	var player := SpriteSheetPlayer.new()
	player.sheet = sheet
	player.frame_count = frames
	player.fps = fps
	player.loop = loop
	add_child(player)
	return player

func setup(c: Vector2i, ship: bool) -> void:
	coord = c
	has_ship = ship
	armor = 0
	has_mine = false
	sonar_proof = false
	ship_tint = Color.WHITE
	state = State.HIDDEN
	_ship_tex = null
	_ship_rot_deg = 0.0
	_hit_fx.stop()
	_sunk_burst.stop()
	_sunk_fire.stop()
	_splash.stop()
	_refresh()

## Segmento do navio inimigo que ocupa esta celula. So fica visivel no HIT/SUNK.
func set_ship_sprite(tex: Texture2D, rot_deg: float) -> void:
	_ship_tex = tex
	_ship_rot_deg = rot_deg
	_refresh()

func is_shootable() -> bool:
	return state in [State.HIDDEN, State.SONAR_SHIP, State.SONAR_EMPTY, State.ARMORED, State.SONAR_MINE]

func set_state(s: State) -> void:
	var prev := state
	state = s
	_refresh()
	if s == State.HIT and prev != State.HIT and prev != State.SUNK:
		_hit_fx.play()
	elif s == State.SUNK and prev != State.SUNK:
		_hit_fx.stop()
		_sunk_burst.play()
	elif s == State.WATER and prev != State.WATER:
		_mark.visible = false
		_splash.play()
	elif s == State.ARMORED:
		_sparks.play()
	elif s == State.MINE and prev != State.MINE:
		_sunk_burst.play()

## Marca como agua deduzida (sem respingo). Mina nunca e' marcada: a regra
## so garante que nao ha navio, e o Board ja evita mina colada em navio.
func mark_clear() -> void:
	if has_ship or has_mine or not state in [State.HIDDEN, State.SONAR_EMPTY]:
		return
	state = State.CLEAR
	_refresh()

## Sonar so marca celulas ainda ocultas. Submarino passa batido (le como vazio).
func reveal_sonar() -> void:
	if state != State.HIDDEN:
		return
	if has_ship and not sonar_proof:
		state = State.SONAR_SHIP
	elif has_mine:
		state = State.SONAR_MINE
	else:
		state = State.SONAR_EMPTY
	_refresh()

func _on_pressed() -> void:
	if is_shootable():
		shot_requested.emit(coord)

func _refresh() -> void:
	var base := _tile_style(TILE_TEX[state])
	# Hover com cantos teal (mesma linguagem da mira) so onde ainda da pra atirar.
	var hover := _tile_style(HOVER_TEX) if is_shootable() else base
	for slot in ["normal", "disabled"]:
		add_theme_stylebox_override(slot, base)
	for slot in ["hover", "pressed", "hover_pressed"]:
		add_theme_stylebox_override(slot, hover)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var hit_or_sunk := state == State.HIT or state == State.SUNK
	var show_ship := hit_or_sunk and _ship_tex != null
	_sprite.visible = show_ship
	if show_ship:
		_sprite.texture = _ship_tex
		_sprite.pivot_offset = _sprite.size / 2.0
		_sprite.rotation_degrees = _ship_rot_deg
		_sprite.modulate = ship_tint * (Color(0.55, 0.15, 0.15) if state == State.SUNK else Color.WHITE)

	var mark: Texture2D = null
	match state:
		State.WATER, State.CLEAR:
			mark = WATER_MARK
		State.SONAR_EMPTY:
			mark = SONAR_EMPTY_MARK
		State.MINE:
			mark = MINE_MARK
		State.SONAR_MINE:
			mark = SONAR_MINE_MARK
	_mark.texture = mark
	_mark.modulate.a = CLEAR_MARK_ALPHA if state == State.CLEAR else 1.0
	_mark.visible = mark != null and not _splash.visible

	_set_looping(_sonar_blip, state == State.SONAR_SHIP)
	# Fallback: acerto sem segmento de navio vira marca de queimado.
	_set_looping(_burnt, hit_or_sunk and _ship_tex == null)

## Liga/desliga uma animacao em loop sem reiniciar a que ja esta tocando.
func _set_looping(player: SpriteSheetPlayer, on: bool) -> void:
	if not on:
		player.stop()
	elif not player.visible:
		player.play()
