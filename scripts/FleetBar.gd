extends HBoxContainer
class_name FleetBar
## Barra de cartas da frota do jogador. Cada navio vira um card clicavel
## (sprite montado dos segments + carga restante); clicar seleciona o navio
## no Board, que passa a resolver o proximo clique de celula com ele.

var _board: Board = null
var _cards: Dictionary = {}   # PlayerShip -> { "button": Button, "label": Label }

func bind(board: Board) -> void:
	_board = board
	_board.fleet_changed.connect(_refresh)
	_board.ship_selected.connect(func(_s): _refresh())
	_build_cards()
	_refresh()

func _build_cards() -> void:
	for c in get_children():
		c.queue_free()
	_cards.clear()
	for ship in Game.player_ships:
		var parts := _make_card(ship)
		add_child(parts["button"])
		_cards[ship] = parts

func _make_card(ship: PlayerShip) -> Dictionary:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(64 * maxi(ship.segments.size(), 1), 84)
	btn.tooltip_text = ship.display_name
	btn.pressed.connect(func(): _board.select_ship(ship))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)

	var sprite_row := HBoxContainer.new()
	sprite_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sprite_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_row.add_theme_constant_override("separation", 0)
	box.add_child(sprite_row)
	for tex in ship.segments:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(64, 64)
		tr.stretch_mode = TextureRect.STRETCH_KEEP
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite_row.add_child(tr)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	return {"button": btn, "label": label}

func _refresh() -> void:
	for ship in _cards.keys():
		var parts: Dictionary = _cards[ship]
		var btn: Button = parts["button"]
		var label: Label = parts["label"]
		label.text = "%d/%d" % [ship.charges, ship.max_charges]
		btn.disabled = not ship.has_charge()
		btn.button_pressed = (ship == _board.selected_ship)
