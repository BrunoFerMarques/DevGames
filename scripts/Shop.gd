extends Control
class_name Shop
## Loja antes de cada rodada (inclusive a 1a). Secoes fixas na tela, sem abas:
## topo = rodada, reroll (sorteia todas as ofertas) e dinheiro; esquerda, de
## cima pra baixo = almirantes, melhorias/armamento e estaleiro (navios novos);
## direita = sua frota (tiros da rodada, venda de navio, vagas da doca) + Zarpar.
## A coluna da quina esquerda fica livre pra AdmiralBar (almirantes que o
## jogador ja tem; clicar vende). Nao troca de cena, so fica visivel/invisivel.

signal closed

const ADMIRAL_PRICE := 7
const UPGRADE_PRICE := 5
const REROLL_BASE_COST := 2
const OFFER_COUNT := 2
const SHIP_OFFER_COUNT := 3
const RED := Color("#e43c4f")

const DIM := Color(0.6, 0.63, 0.68, 1)
const GOLD := Color("#f3c44b")
const TEAL := Color("#2fbfb0")
## Fontes das cartas: tres faixas de ofertas dividem a altura da coluna.
const CARD_TITLE_SIZE := 17
const CARD_TEXT_SIZE := 15

@onready var round_info: Label = $TopBar/HBox/RoundInfo
@onready var money_label: Label = $TopBar/HBox/Money
@onready var upgrade_items: HBoxContainer = $Upgrades/VBox/Items
@onready var reroll_btn: Button = $TopBar/HBox/Reroll
@onready var ship_items: HBoxContainer = $Shipyard/VBox/Items
@onready var admiral_items: HBoxContainer = $Admirals/VBox/Items
@onready var admiral_count: Label = $Admirals/VBox/Header/Count
@onready var dock_label: Label = $Shots/VBox/Header/Dock
@onready var shots_info: Label = $Shots/VBox/Info
@onready var shot_rows: VBoxContainer = $Shots/VBox/Scroll/Rows
@onready var shots_total: Label = $Shots/VBox/Total
@onready var warning: Label = $Shots/VBox/Warning
@onready var continue_btn: Button = $Shots/VBox/Continue
@onready var load_all_btn: Button = $Shots/VBox/LoadAll

var _reroll_cost: int = REROLL_BASE_COST
var _admiral_offers: Array[Effect] = []
var _upgrade_offers: Array[ShipUpgradeDef] = []
var _shot_offers: Array[ShotTypeDef] = []
var _ship_offers: Array[ShipClassDef] = []

func _ready() -> void:
	reroll_btn.pressed.connect(_on_reroll)
	load_all_btn.pressed.connect(_load_all)
	continue_btn.pressed.connect(func(): closed.emit())
	for sig in [Game.admirals_changed, Game.ships_changed]:
		sig.connect(func():
			if visible:
				_refresh()
		)
	Game.money_changed.connect(func(_m):
		if visible:
			_refresh()
	)

## Chamado pelo Main antes de cada rodada, ja com a rodada seguinte configurada.
func open() -> void:
	_reroll_cost = REROLL_BASE_COST
	_roll_offers()
	_refresh()

func _roll_offers() -> void:
	_admiral_offers = _pick_random(_admiral_pool(), OFFER_COUNT)
	_upgrade_offers = _pick_random(ShipUpgradeCatalog.all(), OFFER_COUNT)
	_shot_offers = _pick_random(ShotTypeCatalog.all(), 1)
	_ship_offers = _pick_random(ShipClassCatalog.all(), SHIP_OFFER_COUNT)

## Almirantes que o jogador ainda nao tem: a loja nao vende repetido (o
## efeito so somaria duas vezes). Vendeu, volta a aparecer no proximo sorteio.
## Catalogo tem 12 e a frota no maximo MAX_ADMIRALS, entao sempre sobra oferta.
func _admiral_pool() -> Array[Effect]:
	var out: Array[Effect] = []
	for adm: Effect in AdmiralCatalog.all():
		if not _owns_admiral(adm.id):
			out.append(adm)
	return out

func _owns_admiral(id: StringName) -> bool:
	return Game.admirals.any(func(a: Effect) -> bool: return a.id == id)

## Precos com a dificuldade "Almirante" (+$PRICE_UP em almirante e melhoria).
func _admiral_price() -> int:
	return ADMIRAL_PRICE + _difficulty_markup()

func _upgrade_price() -> int:
	return UPGRADE_PRICE + _difficulty_markup()

func _difficulty_markup() -> int:
	return DifficultyCatalog.PRICE_UP if Game.rule(DifficultyCatalog.PRICEY_SHOP) else 0

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
	Sfx.play(&"reroll")
	_refresh()

# --- Tiros -------------------------------------------------------------------

func _load_shot(ship: PlayerShip) -> void:
	if not Game.can_load_shot(ship) or not Game.spend_money(Game.SHOT_PRICE):
		return
	ship.bought_shots += 1
	Sfx.play(&"load")
	_refresh()

## Enche os navios de tiro em ordem (o da frente primeiro) ate o pente ou o
## dinheiro acabar.
func _load_all() -> void:
	var loaded := 0
	for ship in Game.player_ships:
		while Game.can_load_shot(ship) and Game.spend_money(Game.SHOT_PRICE):
			ship.bought_shots += 1
			loaded += 1
	# Um "clac" por tiro, encadeados (no maximo 6, pra nao virar metralhadora).
	for i in mini(loaded, 6):
		Sfx.play_later(&"load", i * 0.06)
	_refresh()

## Devolve um tiro comprado nesta visita (tudo que esta carregado foi
## comprado agora: a carga zera no fim de cada rodada).
func _unload_shot(ship: PlayerShip) -> void:
	if ship.bought_shots <= 0:
		return
	ship.bought_shots -= 1
	Game.add_money(Game.SHOT_PRICE)
	_refresh()

# --- Almirantes / melhorias / armamento --------------------------------------

func _buy_admiral(def: Effect) -> void:
	if Game.admirals.size() >= Game.MAX_ADMIRALS or _owns_admiral(def.id):
		return
	if not Game.spend_money(_admiral_price()):
		return
	Game.admirals.append(def)
	_admiral_offers.erase(def)
	Sfx.play(&"buy")
	Game.admirals_changed.emit()

## Abre um menu pra escolher em qual navio (de tiro ou sonar, conforme
## `kind`) aplicar a compra. Com um navio so, aplica direto.
func _pick_ship(kind: PlayerShip.Kind, on_pick: Callable, label_for: Callable) -> void:
	var targets: Array[PlayerShip] = []
	for ship in Game.player_ships:
		if ship.kind == kind:
			targets.append(ship)
	if targets.is_empty():
		return
	if targets.size() == 1:
		on_pick.call(targets[0])
		return
	var menu := PopupMenu.new()
	add_child(menu)
	for i in targets.size():
		menu.add_item(label_for.call(targets[i]), i)
	menu.id_pressed.connect(func(id: int) -> void: on_pick.call(targets[id]))
	menu.popup_hide.connect(menu.queue_free)
	menu.popup(Rect2i(get_global_mouse_position(), Vector2i(260, 0)))

func _buy_upgrade(def: ShipUpgradeDef) -> void:
	if Game.money < _upgrade_price():
		return
	var kind := PlayerShip.Kind.SONAR if def.for_sonar() else PlayerShip.Kind.SHOT
	_pick_ship(kind, func(ship: PlayerShip) -> void: _apply_upgrade(def, ship),
		func(ship: PlayerShip) -> String:
			if ship.upgrade:
				return "%s  [%s x%d]" % [ship.display_name, ship.upgrade.display_name, ship.upgrade_level]
			return ship.display_name)

func _apply_upgrade(def: ShipUpgradeDef, ship: PlayerShip) -> void:
	if not Game.spend_money(_upgrade_price()):
		return
	if ship.upgrade != null and ship.upgrade.id == def.id:
		ship.upgrade_level += 1
	else:
		ship.upgrade = def
		ship.upgrade_level = 1
	_upgrade_offers.erase(def)
	Sfx.play(&"buy")
	_refresh()

func _buy_shot_type(def: ShotTypeDef) -> void:
	if Game.money < def.price:
		return
	_pick_ship(PlayerShip.Kind.SHOT, func(ship: PlayerShip) -> void: _apply_shot_type(def, ship),
		func(ship: PlayerShip) -> String:
			var tag := ship.shot_tag()
			return "%s  [%s]" % [ship.display_name, tag] if tag != "" else ship.display_name)

func _apply_shot_type(def: ShotTypeDef, ship: PlayerShip) -> void:
	if not Game.spend_money(def.price):
		return
	ship.shot_type = def.shot
	_shot_offers.erase(def)
	Sfx.play(&"buy")
	_refresh()

# --- Estaleiro (navios) --------------------------------------------------------

func _buy_ship(def: ShipClassDef) -> void:
	if Game.buy_ship(def):
		_ship_offers.erase(def)
		Sfx.play(&"buy")
		_refresh()

## Venda e' definitiva: confirma antes (devolve metade do preco + os tiros
## ja comprados pra ele nesta loja).
func _confirm_sell(ship: PlayerShip) -> void:
	var menu := PopupMenu.new()
	add_child(menu)
	menu.add_item("Vender %s por $%d" % [ship.display_name, Game.ship_sell_value(ship)], 0)
	menu.add_item("Cancelar", 1)
	menu.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			Game.sell_ship(ship)
			Sfx.play(&"sell")
	)
	menu.popup_hide.connect(menu.queue_free)
	menu.popup(Rect2i(get_global_mouse_position(), Vector2i(260, 0)))

# --- Desenho -----------------------------------------------------------------

func _refresh() -> void:
	money_label.text = "$%d" % Game.money
	var info := "Setor %d · Rodada %d/3 · Meta %d" % [Game.ante, Game.round_in_ante, Game.target_score]
	if Game.tutorial:
		info = "TREINO · Meta %d" % Game.target_score
	elif Game.boss_modifier:
		info += " · DESAFIO: %s" % Game.boss_modifier.display_name
	elif Game.stop_kind() != Game.Stop.NORMAL:
		info += " · %s" % Game.STOP_NAMES[Game.stop_kind()]
	round_info.text = info
	reroll_btn.text = "Reroll ($%d)" % _reroll_cost
	reroll_btn.disabled = Game.money < _reroll_cost

	_clear(upgrade_items)
	for up in _upgrade_offers:
		upgrade_items.add_child(_make_item_card(up.display_name, up.description, _upgrade_price(),
			func(): _buy_upgrade(up), "", "SONAR" if up.for_sonar() else "MELHORIA"))
	for st in _shot_offers:
		upgrade_items.add_child(_make_item_card(st.display_name, st.description, st.price,
			func(): _buy_shot_type(st), "", "ARMAMENTO"))

	_clear(ship_items)
	for def in _ship_offers:
		var full := not Game.has_dock_room(def)
		var card := _make_ship_card(def, full)
		if full:
			card.tooltip_text = "Venda um navio ($) ou contrate um almirante de estaleiro."
		ship_items.add_child(card)

	var fleet_full: bool = Game.admirals.size() >= Game.MAX_ADMIRALS
	admiral_count.text = "%d/%d" % [Game.admirals.size(), Game.MAX_ADMIRALS]
	_clear(admiral_items)
	for adm in _admiral_offers:
		admiral_items.add_child(_make_admiral_card(adm, fleet_full))

	_refresh_shots()

func _refresh_shots() -> void:
	shots_info.text = "Navios saem vazios: tiro a $%d, só para a próxima rodada." % Game.SHOT_PRICE
	var used := Game.dock_used()
	var cap := Game.dock_capacity()
	dock_label.text = "Doca %d/%d" % [used, cap]
	dock_label.add_theme_color_override("font_color", RED if used > cap else DIM)
	_clear(shot_rows)
	var total := 0
	for ship in Game.player_ships:
		if ship.kind == PlayerShip.Kind.SHOT:
			total += ship.bought_shots
			shot_rows.add_child(_fleet_entry(ship, _make_shot_row(ship)))
		else:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var lbl := Label.new()
			lbl.text = "%d usos" % ship.round_capacity()
			lbl.add_theme_color_override("font_color", Color("#2fbfb0"))
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.clip_text = true
			row.add_child(lbl)
			row.add_child(_sell_button(ship))
			shot_rows.add_child(_fleet_entry(ship, row))
	shots_total.text = "Total: %d tiros" % total
	# Zarpar sem tiro perde a rodada na hora: so deixa quando nao da pra pagar
	# nem um tiro (senao o jogo travaria na loja).
	var can_buy := Game.money >= Game.SHOT_PRICE and Game.player_ships.any(
		func(s: PlayerShip) -> bool: return Game.can_load_shot(s))
	continue_btn.disabled = total == 0 and can_buy
	load_all_btn.disabled = not can_buy
	if total > 0:
		warning.text = " "
	elif can_buy:
		warning.text = "Compre tiros (+) para zarpar."
	else:
		warning.text = "Sem tiros, a rodada termina na hora!"

## Navio da frota na loja: desenho pequeno (com armamento/melhoria, muda na
## hora da compra) no comeco da linha; nome e vantagem no tooltip, como na
## barra da batalha.
func _fleet_entry(ship: PlayerShip, row: HBoxContainer) -> HBoxContainer:
	var view := _mini_ship()
	view.show_ship(ship)
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Largura fixa do maior navio: contadores e botoes ficam alinhados.
	view.custom_minimum_size.x = 96
	row.add_child(view)
	row.move_child(view, 0)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = ship.display_name
	if ship.ship_class:
		row.tooltip_text += "\n" + ship.ship_class.perk_text
	if ship.shot_type != PlayerShip.Shot.NORMAL:
		row.tooltip_text += "\nArmamento: " + ship.shot_tag()
	if ship.upgrade:
		row.tooltip_text += "\n%s x%d" % [ship.upgrade.display_name, ship.upgrade_level]
	return row

func _make_shot_row(ship: PlayerShip) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var tag := Label.new()
	tag.text = ship.shot_tag()
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_color_override("font_color", DIM)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag.clip_text = true
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tag)
	var count := Label.new()
	count.text = "%d/%d" % [ship.bought_shots, Game.magazine(ship)]
	count.add_theme_color_override("font_color", GOLD if ship.bought_shots > 0 else DIM)
	row.add_child(count)
	var minus := _small_button("-")
	minus.disabled = ship.bought_shots <= 0
	minus.pressed.connect(func(): _unload_shot(ship))
	row.add_child(minus)
	var plus := _small_button("+")
	plus.disabled = not Game.can_load_shot(ship) or Game.money < Game.SHOT_PRICE
	plus.pressed.connect(func(): _load_shot(ship))
	row.add_child(plus)
	row.add_child(_sell_button(ship))
	return row

func _sell_button(ship: PlayerShip) -> Button:
	var b := _small_button("$")
	b.disabled = not Game.can_sell_ship(ship)
	b.tooltip_text = "Vender por $%d" % Game.ship_sell_value(ship) if not b.disabled \
		else "Precisa sobrar pelo menos 1 navio de tiro"
	b.pressed.connect(func(): _confirm_sell(ship))
	return b

func _small_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(36, 36)
	return b

## Melhoria/armamento/navio: carta vertical compacta (titulo, descricao, preco).
## `blocked` (ex.: "doca cheia") trava a carta e aparece no lugar do preco.
## Carta de oferta: titulo, texto e rodape com preco (e o tipo, quando a
## faixa mistura melhoria/sonar/armamento).
func _make_item_card(title: String, desc: String, price: int, on_buy: Callable,
		blocked: String = "", tag: String = "") -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(196, 0)
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.disabled = blocked != "" or Game.money < price
	btn.pressed.connect(on_buy)
	var box := _card_box(btn)
	box.add_child(_card_label(title, GOLD, HORIZONTAL_ALIGNMENT_LEFT, CARD_TITLE_SIZE))
	var desc_lbl := _card_label(desc, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, CARD_TEXT_SIZE)
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc_lbl)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(foot)
	var price_lbl := _card_label(blocked if blocked != "" else "$%d" % price,
		RED if blocked != "" else GOLD, HORIZONTAL_ALIGNMENT_LEFT, CARD_TITLE_SIZE)
	price_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(price_lbl)
	if tag != "":
		var tag_lbl := _card_label(tag, TEAL if tag == "SONAR" else DIM, HORIZONTAL_ALIGNMENT_RIGHT, 14)
		tag_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF   # sem largura propria, quebraria letra a letra
		tag_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
		foot.add_child(tag_lbl)
	_dim_if_disabled(btn)
	return btn

## Os textos da carta tem cor propria, entao o estilo "desabilitado" do botao
## nao aparece: apaga a carta inteira pra ficar claro que nao da pra comprar.
## Carta do Estaleiro: nome, desenho do navio com pente/vagas do lado,
## vantagem e preco (ou "doca cheia").
func _make_ship_card(def: ShipClassDef, full: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(196, 0)
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.disabled = full or Game.money < def.price
	btn.pressed.connect(func(): _buy_ship(def))
	if full:
		btn.tooltip_text = "Venda um navio ($) ou contrate um almirante de estaleiro."
	var box := _card_box(btn)
	box.add_child(_card_label(def.display_name, GOLD, HORIZONTAL_ALIGNMENT_LEFT, CARD_TITLE_SIZE))
	var pic := HBoxContainer.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.add_theme_constant_override("separation", 8)
	var view := _mini_ship()
	view.show_class(def)
	pic.add_child(view)
	var load_text := "Pente %d" % def.magazine if def.kind == PlayerShip.Kind.SHOT else "Sonar %d" % def.magazine
	var stats := _card_label("%s\n%d %s" % [load_text, def.tonnage, "vaga" if def.tonnage == 1 else "vagas"],
		DIM, HORIZONTAL_ALIGNMENT_LEFT, 13)
	stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	stats.add_theme_constant_override("line_spacing", -2)
	stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pic.add_child(stats)
	box.add_child(pic)
	var perk := _card_label(def.perk_text, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 14)
	perk.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(perk)
	box.add_child(_card_label("doca cheia" if full else "$%d" % def.price, RED if full else GOLD,
		HORIZONTAL_ALIGNMENT_LEFT, CARD_TITLE_SIZE))
	_dim_if_disabled(btn)
	return btn

## Navio pequeno (metade do tamanho, so a faixa do casco) pra loja.
func _mini_ship() -> ShipView:
	var view := ShipView.new()
	view.zoom = 0.5
	view.hull_only = true
	view.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return view

func _dim_if_disabled(btn: Button) -> void:
	if btn.disabled:
		btn.modulate.a = 0.5

## Almirante: carta horizontal (retrato a esquerda, texto a direita).
func _make_admiral_card(adm: Effect, fleet_full: bool) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(298, 0)
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.disabled = fleet_full or Game.money < _admiral_price()
	_dim_if_disabled(btn)
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
	box.add_child(_card_label(adm.display_name, GOLD, HORIZONTAL_ALIGNMENT_LEFT, CARD_TITLE_SIZE))
	var desc_lbl := _card_label(adm.description, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, CARD_TEXT_SIZE)
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(desc_lbl)
	box.add_child(_card_label("frota cheia" if fleet_full else "$%d" % _admiral_price(), GOLD,
		HORIZONTAL_ALIGNMENT_LEFT, CARD_TITLE_SIZE))
	return btn

func _card_box(btn: Button) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	return box

func _card_label(text: String, color: Color, align: HorizontalAlignment, font_size: int = 0) -> Label:
	var lbl := Label.new()
	lbl.text = text
	if font_size > 0:
		lbl.add_theme_font_size_override("font_size", font_size)
	lbl.horizontal_alignment = align
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

func _clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
