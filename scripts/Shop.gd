extends Control
class_name Shop
## Tela entre rodadas: compra Almirantes (coringas) e melhorias de navio com
## Game.money. Nao troca de cena, so fica visivel/invisivel dentro de Main.

signal closed

const ADMIRAL_PRICE := 7
const UPGRADE_PRICE := 5
const REROLL_BASE_COST := 2
const OFFER_COUNT := 2

@onready var money_label: Label = $Panel/VBox/Money
@onready var items_box: HBoxContainer = $Panel/VBox/Items
@onready var reroll_btn: Button = $Panel/VBox/Actions/Reroll
@onready var continue_btn: Button = $Panel/VBox/Actions/Continue

var _reroll_cost: int = REROLL_BASE_COST
var _admiral_offers: Array[Effect] = []
var _upgrade_offers: Array[ShipUpgradeDef] = []

func _ready() -> void:
	reroll_btn.pressed.connect(_on_reroll)
	continue_btn.pressed.connect(func(): closed.emit())

## Chamado pelo Main toda vez que a loja abre (fim de rodada vencida).
func open() -> void:
	_reroll_cost = REROLL_BASE_COST
	_roll_offers()
	_refresh()

func _roll_offers() -> void:
	_admiral_offers = _pick_random(AdmiralCatalog.all(), OFFER_COUNT)
	_upgrade_offers = _pick_random(ShipUpgradeCatalog.all(), OFFER_COUNT)

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

func _buy_admiral(def: Effect) -> void:
	if Game.admirals.size() >= Game.MAX_ADMIRALS:
		return
	if not Game.spend_money(ADMIRAL_PRICE):
		return
	Game.admirals.append(def)
	Game.admirals_changed.emit()
	_admiral_offers.erase(def)
	_refresh()

func _buy_upgrade(def: ShipUpgradeDef) -> void:
	if Game.money < UPGRADE_PRICE:
		return
	var menu := PopupMenu.new()
	add_child(menu)
	var targets: Array[PlayerShip] = []
	for ship in Game.player_ships:
		if ship.kind != PlayerShip.Kind.SHOT:
			continue
		var tag := ""
		if ship.upgrade:
			tag = "  [%s x%d]" % [ship.upgrade.display_name, ship.upgrade_level]
		menu.add_item("%s%s" % [ship.display_name, tag], targets.size())
		targets.append(ship)
	menu.id_pressed.connect(func(id: int) -> void: _apply_upgrade(def, targets[id]))
	menu.popup_hide.connect(menu.queue_free)
	menu.popup(Rect2i(get_global_mouse_position(), Vector2i(240, 0)))

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

func _refresh() -> void:
	var fleet_full: bool = Game.admirals.size() >= Game.MAX_ADMIRALS
	money_label.text = "Dinheiro: %d   Almirantes: %d/%d" % [
		Game.money, Game.admirals.size(), Game.MAX_ADMIRALS]
	reroll_btn.text = "Reroll (%d)" % _reroll_cost
	reroll_btn.disabled = Game.money < _reroll_cost
	for c in items_box.get_children():
		c.queue_free()
	for adm in _admiral_offers:
		items_box.add_child(_make_card(adm.display_name, adm.description, ADMIRAL_PRICE,
			func(): _buy_admiral(adm), fleet_full, adm.portrait))
	for up in _upgrade_offers:
		items_box.add_child(_make_card(up.display_name, up.description, UPGRADE_PRICE,
			func(): _buy_upgrade(up), false, null))

func _make_card(title: String, desc: String, price: int, on_buy: Callable, locked: bool,
		portrait: Texture2D = null) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(170, 210 if portrait else 150)
	btn.disabled = locked or Game.money < price
	btn.pressed.connect(on_buy)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)

	if portrait:
		var portrait_rect := TextureRect.new()
		portrait_rect.texture = portrait
		portrait_rect.custom_minimum_size = Vector2(0, 64)
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(portrait_rect)

	var name_lbl := Label.new()
	name_lbl.text = title
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(desc_lbl)

	var price_lbl := Label.new()
	price_lbl.text = "frota cheia" if locked else "%d moedas" % price
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(price_lbl)

	return btn
