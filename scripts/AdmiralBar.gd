extends VBoxContainer
class_name AdmiralBar
## Coluna dos Almirantes (coringas) que o jogador possui, encostada na
## quina esquerda da tela (estilo Balatro), fora da area do tabuleiro.
## Sempre visivel (jogo e loja). Clicar no card: fora da loja mostra a
## habilidade num popup; na loja (set_sellable) pede confirmacao de venda -
## Main liga/desliga via set_sellable. Almirantes sem retrato proprio mostram
## o nome no lugar do retrato.

signal sell_requested(adm: Effect)

# Retratos sao arte 32x32 em 4x (128px): 64px = 2x exato, pixel nitido.
const CARD_MARGIN := 4
const CARD_SIZE := Vector2(64 + CARD_MARGIN * 2, 64 + CARD_MARGIN * 2)

var sellable: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.admirals_changed.connect(_refresh)
	_refresh()

func set_sellable(v: bool) -> void:
	sellable = v
	_refresh()

func _refresh() -> void:
	for c in get_children():
		c.queue_free()
	add_child(_make_header())
	for adm in Game.admirals:
		add_child(_make_card(adm))

## Sempre visivel, mesmo com 0 almirantes - confirma que a barra esta
## renderizando (evita confundir "vazia" com "quebrada").
func _make_header() -> Control:
	var lbl := Label.new()
	# Na loja o titulo longo invadiria a barra do topo; a contagem basta.
	var count := "%d/%d" % [Game.admirals.size(), Game.MAX_ADMIRALS]
	lbl.text = count if sellable else "Almirantes " + count
	lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	return lbl

func _make_card(adm: Effect) -> Control:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#12365f")
	sb.border_color = Color(0.75, 0.25, 0.25, 1) if sellable else Color(0.75, 0.6, 0.28, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)

	var btn := Button.new()
	btn.custom_minimum_size = CARD_SIZE
	# Sem SHRINK o VBox estica o card ate a largura da barra e sobra fundo.
	btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for slot in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(slot, sb)
	if sellable:
		btn.pressed.connect(func(): sell_requested.emit(adm))
		btn.tooltip_text = "%s\n\nClique para vender por %d" % [adm.display_name, Game.ADMIRAL_SELL_REFUND]
	else:
		btn.pressed.connect(func(): _show_info(adm))
		btn.tooltip_text = adm.display_name

	# Card estilo Balatro: so o retrato; nome fica no tooltip/popup.
	# Sem retrato proprio, o nome ocupa o lugar dele no mesmo tamanho.
	var content: Control
	if adm.portrait:
		var portrait := TextureRect.new()
		portrait.texture = adm.portrait
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		content = portrait
	else:
		var name_lbl := Label.new()
		name_lbl.text = adm.display_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# 10px = 1px por pixel da fonte, cabe no card; contorno engoliria a letra.
		name_lbl.add_theme_font_size_override("font_size", 10)
		name_lbl.add_theme_constant_override("outline_size", 0)
		content = name_lbl
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, CARD_MARGIN)

	return btn

## Popup com nome + descricao da habilidade - clique fora fecha sozinho.
func _show_info(adm: Effect) -> void:
	var popup := PopupPanel.new()
	add_child(popup)

	var box := VBoxContainer.new()
	popup.add_child(box)

	var title_lbl := Label.new()
	title_lbl.text = adm.display_name
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	box.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = adm.description
	desc_lbl.custom_minimum_size = Vector2(220, 0)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(desc_lbl)

	popup.popup_hide.connect(popup.queue_free)
	popup.popup(Rect2i(get_global_mouse_position(), Vector2i(240, 0)))
