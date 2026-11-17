extends HBoxContainer
class_name FleetBar
## Barra de cartas da frota do jogador. Cada navio vira um card clicavel
## (desenho da classe com as modificacoes compradas, via ShipView, + carga
## restante); clicar seleciona o navio no Board, que passa a resolver o
## proximo clique de celula com ele.

var _board: Board = null
var _cards: Dictionary = {}   # PlayerShip -> { "button": Button, "label": Label, "view": ShipView }

func bind(board: Board) -> void:
	_board = board
	_board.fleet_changed.connect(_refresh)
	_board.ship_selected.connect(func(_s): _refresh())
	Game.ships_changed.connect(func():
		_build_cards()
		_refresh()
	)
	_build_cards()
	_refresh()

func _build_cards() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_cards.clear()
	for ship in Game.player_ships:
		var parts := _make_card(ship)
		add_child(parts["button"])
		_cards[ship] = parts

func _make_card(ship: PlayerShip) -> Dictionary:
	var btn := Button.new()
	btn.toggle_mode = true
	var view := ShipView.new()
	view.show_ship(ship)
	# Sprite (64 de altura) + 24 da linha de carga (fonte 20px).
	btn.custom_minimum_size = Vector2(maxf(view.custom_minimum_size.x, 64.0), 88)
	btn.tooltip_text = ship.display_name
	if ship.ship_class:
		btn.tooltip_text += "\n" + ship.ship_class.perk_text
	btn.pressed.connect(func(): _board.select_ship(ship))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)

	box.add_child(view)

	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	return {"button": btn, "label": label, "view": view}

## Retangulo global da carta do navio (o treino destaca ela).
func card_rect(ship: PlayerShip) -> Rect2:
	if not _cards.has(ship):
		return Rect2()
	return (_cards[ship]["button"] as Button).get_global_rect()

## Ponto global de onde sai o disparo do navio: meio do card, perto do topo.
func muzzle_point(ship: PlayerShip) -> Vector2:
	if not _cards.has(ship):
		return get_global_rect().get_center()
	var r: Rect2 = (_cards[ship]["button"] as Button).get_global_rect()
	return Vector2(r.get_center().x, r.position.y + 24)

func _refresh() -> void:
	for ship in _cards.keys():
		var parts: Dictionary = _cards[ship]
		var btn: Button = parts["button"]
		var label: Label = parts["label"]
		label.text = "%d/%d" % [ship.charges, ship.round_capacity()]
		if ship.shot_tag() != "":
			label.text += " " + ship.shot_tag()
		btn.disabled = not ship.has_charge()
		# Armamento/melhoria comprados na loja aparecem no desenho.
		(parts["view"] as ShipView).show_ship(ship)
		btn.button_pressed = (ship == _board.selected_ship)
