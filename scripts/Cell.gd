extends Button
class_name Cell
## Uma celula clicavel do tabuleiro alvo.

enum State { HIDDEN, WATER, HIT, SUNK, SONAR_SHIP, SONAR_EMPTY }

signal shot_requested(coord: Vector2i)

var coord: Vector2i
var state: State = State.HIDDEN
var has_ship: bool = false

var _ship_tex: Texture2D = null
var _ship_rot_deg: float = 0.0
var _sprite: TextureRect
var _hit_fx: SpriteSheetPlayer
var _sunk_burst: SpriteSheetPlayer
var _sunk_fire: SpriteSheetPlayer

const HIT_SMOKE_SHEET: Texture2D = preload("res://sprites/hit_smoke_sheet.png")
const SUNK_BURST_SHEET: Texture2D = preload("res://sprites/hits.png")
const SUNK_FIRE_SHEET: Texture2D = preload("res://sprites/hit_fire_sheet.png")

const COLORS := {
	State.HIDDEN: Color("#1e3a5f"),
	State.WATER: Color("#2a6f97"),
	State.HIT: Color("#e63946"),
	State.SUNK: Color("#6a040f"),
	State.SONAR_SHIP: Color("#f4a261"),
	State.SONAR_EMPTY: Color("#3d5a80"),
}

func _ready() -> void:
	custom_minimum_size = Vector2(56, 56)
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)
	_sprite = TextureRect.new()
	_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sprite.visible = false
	add_child(_sprite)

	_hit_fx = SpriteSheetPlayer.new()
	_hit_fx.sheet = HIT_SMOKE_SHEET
	_hit_fx.frame_count = 4
	_hit_fx.fps = 10.0
	add_child(_hit_fx)

	_sunk_burst = SpriteSheetPlayer.new()
	_sunk_burst.sheet = SUNK_BURST_SHEET
	_sunk_burst.frame_count = 6
	_sunk_burst.fps = 14.0
	_sunk_burst.finished.connect(func():
		if state == State.SUNK:
			_sunk_fire.play()
	)
	add_child(_sunk_burst)

	_sunk_fire = SpriteSheetPlayer.new()
	_sunk_fire.sheet = SUNK_FIRE_SHEET
	_sunk_fire.frame_count = 4
	_sunk_fire.fps = 8.0
	_sunk_fire.loop = true
	add_child(_sunk_fire)

	_refresh()

func setup(c: Vector2i, ship: bool) -> void:
	coord = c
	has_ship = ship
	state = State.HIDDEN
	_ship_tex = null
	_ship_rot_deg = 0.0
	_hit_fx.stop()
	_sunk_burst.stop()
	_sunk_fire.stop()
	_refresh()

## Segmento do navio inimigo que ocupa esta celula. So fica visivel no HIT/SUNK.
func set_ship_sprite(tex: Texture2D, rot_deg: float) -> void:
	_ship_tex = tex
	_ship_rot_deg = rot_deg
	_refresh()

func is_shootable() -> bool:
	return state == State.HIDDEN or state == State.SONAR_SHIP or state == State.SONAR_EMPTY

func set_state(s: State) -> void:
	var prev := state
	state = s
	_refresh()
	if s == State.HIT and prev != State.HIT and prev != State.SUNK:
		_hit_fx.play()
	elif s == State.SUNK and prev != State.SUNK:
		_hit_fx.stop()
		_sunk_burst.play()

## Sonar so marca celulas ainda ocultas.
func reveal_sonar() -> void:
	if state != State.HIDDEN:
		return
	state = State.SONAR_SHIP if has_ship else State.SONAR_EMPTY
	_refresh()

func _on_pressed() -> void:
	if is_shootable():
		shot_requested.emit(coord)

func _refresh() -> void:
	# TODO: cachear os styleboxes em vez de recriar a cada refresh.
	var col: Color = COLORS[state]
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = col.lightened(0.25)
	for slot in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(slot, sb)
	add_theme_color_override("font_color", Color.WHITE)

	var show_ship := (state == State.HIT or state == State.SUNK) and _ship_tex != null
	_sprite.visible = show_ship
	if show_ship:
		_sprite.texture = _ship_tex
		_sprite.pivot_offset = _sprite.size / 2.0
		_sprite.rotation_degrees = _ship_rot_deg
		_sprite.modulate = Color(0.55, 0.15, 0.15) if state == State.SUNK else Color.WHITE

	match state:
		State.HIT:
			text = "" if show_ship else "X"
		State.SUNK:
			text = "" if show_ship else "#"
		State.WATER, State.SONAR_EMPTY:
			text = "~"
		State.SONAR_SHIP:
			text = "?"
		_:
			text = ""
