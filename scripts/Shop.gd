extends Control
class_name Shop
## Loja antes de cada rodada (inclusive a 1a). Secoes fixas na tela:
## topo = rodada/dinheiro; esquerda em cima = melhorias e armamento;
## esquerda embaixo = almirantes; direita = tiros da rodada + Zarpar.
## A coluna da quina esquerda fica livre pra AdmiralBar (almirantes que o
## jogador ja tem; clicar vende). Nao troca de cena, so fica visivel/invisivel.

signal closed

const ADMIRAL_PRICE := 7
const UPGRADE_PRICE := 5
const REROLL_BASE_COST := 2
const OFFER_COUNT := 2
## Tiro nao recarrega: cada um e' comprado e vale so pra proxima rodada.
## Cada navio leva ate max_charges (o pente).
const SHOT_PRICE := 1

const DIM := Color(0.6, 0.63, 0.68, 1)
const GOLD := Color("#f3c44b")

@onready var round_info: Label = $TopBar/HBox/RoundInfo
@onready var money_label: Label = $TopBar/HBox/Money
@onready var upgrade_items: HBoxContainer = $Upgrades/VBox/Items
@onready var reroll_btn: Button = $Upgrades/VBox/Header/Reroll
@onready var admiral_items: HBoxContainer = $Admirals/VBox/Items
@onready var admiral_count: Label = $Admirals/VBox/Header/Count
@onready var shots_info: Label = $Shots/VBox/Info
@onready var shot_rows: VBoxContainer = $Shots/VBox/Rows
@onready var shots_total: Label = $Shots/VBox/Total
@onready var warning: Label = $Shots/VBox/Warning
@onready var continue_btn: Button = $Shots/VBox/Continue
@onready var load_all_btn: Button = $Shots/VBox/LoadAll

var _reroll_cost: int = REROLL_BASE_COST
var _admiral_offers: Array[Effect] = []
var _upgrade_offers: Array[ShipUpgradeDef] = []
var _shot_offers: Array[ShotTypeDef] = []

func _ready() -> void:
	reroll_btn.pressed.connect(_on_reroll)
	load_all_btn.pressed.connect(_load_all)
	continue_btn.pressed.connect(func(): closed.emit())
	Game.money_changed.connect(func(_m):
		if visible:
			_refresh()
	)
	Game.admirals_changed.connect(func():
		if visible:
			_refresh()
	)

## Chamado pelo Main antes de cada rodada, ja com a rodada seguinte configurada.
func open() -> void:
	_reroll_cost = REROLL_BASE_COST
	_roll_offers()
	_refresh()

func _roll_offers() -> void:
	_admiral_offers = _pick_random(AdmiralCatalog.all(), OFFER_COUNT)
	_upgrade_offers = _pick_random(ShipUpgradeCatalog.all(), OFFER_COUNT)
	_shot_offers = _pick_random(ShotTypeCatalog.all(), 1)

func _pick_random(pool: Array, n: int) -> Array:
	var copy := pool.duplicate()
	copy.shuffle()
	copy.resize(mini(n, copy.size()))
	return copy

func _on_reroll() -> void:
	if not Game.spend_money(_reroll_cost):
		return
	_reroll_cost += 1
	_roll_offers()
	_refresh()

# --- Tiros -------------------------------------------------------------------

func _load_shot(ship: PlayerShip) -> void:
	if not ship.can_load_shot() or not Game.spend_money(SHOT_PRICE):
		return
	ship.bought_shots += 1
	_refresh()

## Enche os navios de tiro em ordem (o da frente primeiro) ate o pente ou o
## dinheiro acabar.
func _load_all() -> void:
	for ship in Game.player_ships:
		while ship.can_load_shot() and Game.spend_money(SHOT_PRICE):
			ship.bought_shots += 1
	_refresh()

## Devolve um tiro comprado nesta visita (tudo que esta carregado foi
## comprado agora: a carga zera no fim de cada rodada).
func _unload_shot(ship: PlayerShip) -> void:
	if ship.bought_shots <= 0:
		return
	ship.bought_shots -= 1
	Game.add_money(SHOT_PRICE)
	_refresh()

# --- Almirantes / melhorias / armamento --------------------------------------

func _buy_admiral(def: Effect) -> void:
	if Game.admirals.size() >= Game.MAX_ADMIRALS:
		return
	if not Game.spend_money(ADMIRAL_PRICE):
		return
	Game.admirals.append(def)
	_admiral_offers.erase(def)
	Game.admirals_changed.emit()

## Abre um menu pra escolher em qual navio de tiro aplicar a compra.
func _pick_shot_ship(on_pick: Callable, label_for: Callable) -> void:
	var menu := PopupMenu.new()
	add_child(menu)
	var targets: Array[PlayerShip] = []
	for ship in Game.player_ships:
		if ship.kind != PlayerShip.Kind.SHOT:
			continue
		menu.add_item(label_for.call(ship), targets.size())
		targets.append(ship)
	menu.id_pressed.connect(func(id: int) -> void: on_pick.call(targets[id]))
	menu.popup_hide.connect(menu.queue_free)
	menu.popup(Rect2i(get_global_mouse_position(), Vector2i(260, 0)))

func _buy_upgrade(def: ShipUpgradeDef) -> void:
	if Game.money < UPGRADE_PRICE:
		return
	_pick_shot_ship(func(ship: PlayerShip) -> void: _apply_upgrade(def, ship),
		func(ship: PlayerShip) -> String:
			if ship.upgrade:
				return "%s  [%s x%d]" % [ship.display_name, ship.upgrade.display_name, ship.upgrade_level]
			return ship.display_name)

func _apply_upgrade(def: ShipUpgradeDef, ship: PlayerShip) -> void:
	if not Game.spend_money(UPGRADE_PRICE):
		return
	if ship.upgrade != null and ship.upgrade.id == def.id:
		ship.upgrade_level += 1
	else:
		ship.upgrade = def
		ship.upgrade_level = 1
	_upgrade_offers.erase(def)
	_refresh()

func _buy_shot_type(def: ShotTypeDef) -> void:
	if Game.money < def.price:
		return
	_pick_shot_ship(func(ship: PlayerShip) -> void: _apply_shot_type(def, ship),
		func(ship: PlayerShip) -> String:
			var tag := ship.shot_tag()
			return "%s  [%s]" % [ship.display_name, tag] if tag != "" else ship.display_name)

func _apply_shot_type(def: ShotTypeDef, ship: PlayerShip) -> void:
	if not Game.spend_money(def.price):
		return
	ship.shot_type = def.shot
	_shot_offers.erase(def)
	_refresh()

# --- Desenho -----------------------------------------------------------------

func _refresh() -> void:
	money_label.text = "$%d" % Game.money
	var info := "Ante %d · Rodada %d/3 · Meta %d" % [Game.ante, Game.round_in_ante, Game.target_score]
	if Game.boss_modifier:
		info += " · DESAFIO: %s" % Game.boss_modifier.display_name
	elif Game.stop_kind() != Game.Stop.NORMAL:
		info += " · %s" % Game.STOP_NAMES[Game.stop_kind()]
	round_info.text = info
	reroll_btn.text = "Reroll ($%d)" % _reroll_cost
	reroll_btn.disabled = Game.money < _reroll_cost

	_clear(upgrade_items)
	for up in _upgrade_offers:
		upgrade_items.add_child(_make_item_card(up.display_name, up.description, UPGRADE_PRICE,
			func(): _buy_upgrade(up)))
	for st in _shot_offers:
		upgrade_items.add_child(_make_item_card(st.display_name, st.description, st.price,
			func(): _buy_shot_type(st)))

	var fleet_full: bool = Game.admirals.size() >= Game.MAX_ADMIRALS
	admiral_count.text = "%d/%d" % [Game.admirals.size(), Game.MAX_ADMIRALS]
	_clear(admiral_items)
	for adm in _admiral_offers:
		admiral_items.add_child(_make_admiral_card(adm, fleet_full))

	_refresh_shots()

func _refresh_shots() -> void:
	shots_info.text = "Os navios começam a rodada vazios. Cada tiro custa $%d e vale só para a próxima rodada." % SHOT_PRICE
	_clear(shot_rows)
	var total := 0
	for ship in Game.player_ships:
		if ship.kind == PlayerShip.Kind.SHOT:
			total += ship.bought_shots
			shot_rows.add_child(_make_shot_row(ship))
		else:
			var lbl := Label.new()
			lbl.text = "%s: %d usos (grátis)" % [ship.display_name, ship.max_charges]
			lbl.add_theme_color_override("font_color", Color("#2fbfb0"))
			shot_rows.add_child(lbl)
	shots_total.text = "Total: %d tiros" % total
	# Zarpar sem tiro perde a rodada na hora: so deixa quando nao da pra pagar
	# nem um tiro (senao o jogo travaria na loja).
	var can_buy := Game.money >= SHOT_PRICE and Game.player_ships.any(
		func(s: PlayerShip) -> bool: return s.can_load_shot())
	continue_btn.disabled = total == 0 and can_buy
	load_all_btn.disabled = not can_buy
	if total > 0:
		warning.text = " "
	elif can_buy:
		warning.text = "Compre tiros (+) para zarpar."
	else:
		warning.text = "Sem tiros, a rodada termina na hora!"

func _make_shot_row(ship: PlayerShip) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var name_lbl := Label.new()
	name_lbl.text = ship.display_name + ("  " + ship.shot_tag() if ship.shot_tag() != "" else "")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.clip_text = true
	row.add_child(name_lbl)
	var count := Label.new()
	count.text = "%d/%d" % [ship.bought_shots, ship.max_charges]
	count.add_theme_color_override("font_color", GOLD if ship.bought_shots > 0 else DIM)
	row.add_child(count)
	var minus := _small_button("-")
	minus.disabled = ship.bought_shots <= 0
	minus.pressed.connect(func(): _unload_shot(ship))
	row.add_child(minus)
	var plus := _small_button("+")
	plus.disabled = not ship.can_load_shot() or Game.money < SHOT_PRICE
	plus.pressed.connect(func(): _load_shot(ship))
	row.add_child(plus)
	return row

func _small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(36, 36)
	return b

## Melhoria/armamento: carta vertical compacta (titulo, descricao, preco).
func _make_item_card(title: String, desc: String, price: int, on_buy: Callable) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(196, 0)
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.disabled = Game.money < price
	btn.pressed.connect(on_buy)
	var box := _card_box(btn)
	box.add_child(_card_label(title, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var desc_lbl := _card_label(desc, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc_lbl)
	box.add_child(_card_label("$%d" % price, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	return btn

## Almirante: carta horizontal (retrato a esquerda, texto a direita).
func _make_admiral_card(adm: Effect, fleet_full: bool) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(298, 0)
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.disabled = fleet_full or Game.money < ADMIRAL_PRICE
	btn.pressed.connect(func(): _buy_admiral(adm))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	btn.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	if adm.portrait:
		var portrait := TextureRect.new()
		portrait.texture = adm.portrait
		portrait.custom_minimum_size = Vector2(64, 64)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(portrait)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	box.add_child(_card_label(adm.display_name, GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	var desc_lbl := _card_label(adm.description, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc_lbl)
	box.add_child(_card_label("frota cheia" if fleet_full else "$%d" % ADMIRAL_PRICE, GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	return btn

func _card_box(btn: Button) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	return box

func _card_label(text: String, color: Color, align: HorizontalAlignment) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = align
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
