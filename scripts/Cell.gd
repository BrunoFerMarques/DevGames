extends Button
class_name Cell
## Uma celula clicavel do tabuleiro alvo.

enum State { HIDDEN, WATER, HIT, SUNK, SONAR_SHIP, SONAR_EMPTY }

signal shot_requested(coord: Vector2i)

var coord: Vector2i
var state: State = State.HIDDEN
var has_ship: bool = false

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
	_refresh()

func setup(c: Vector2i, ship: bool) -> void:
	coord = c
	has_ship = ship
	state = State.HIDDEN
	_refresh()

func is_shootable() -> bool:
	return state == State.HIDDEN or state == State.SONAR_SHIP or state == State.SONAR_EMPTY

func set_state(s: State) -> void:
	state = s
	_refresh()

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
	match state:
		State.HIT:
			text = "X"
		State.SUNK:
			text = "#"
		State.WATER, State.SONAR_EMPTY:
			text = "~"
		State.SONAR_SHIP:
			text = "?"
		_:
			text = ""
