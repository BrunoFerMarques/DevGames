extends VBoxContainer
class_name AdmiralBar
## Coluna dos Almirantes (coringas) que o jogador possui, encostada na
## quina esquerda da tela (estilo Balatro), fora da area do tabuleiro.
## So exibicao (retrato + nome, efeito completo no tooltip); comprar/vender
## e' na loja. Almirantes sem retrato proprio caem no placeholder de cor.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.admirals_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	for c in get_children():
		c.queue_free()
	for adm in Game.admirals:
		add_child(_make_card(adm))

func _make_card(adm: Effect) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(96, 56)
	frame.tooltip_text = "%s\n%s" % [adm.display_name, adm.description]

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.14, 0.07, 0.85)
	sb.border_color = Color(0.75, 0.6, 0.28, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 4.0
	sb.content_margin_right = 4.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	frame.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	frame.add_child(row)

	if adm.portrait:
		var portrait := TextureRect.new()
		portrait.texture = adm.portrait
		portrait.custom_minimum_size = Vector2(40, 40)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(portrait)

	var name_lbl := Label.new()
	name_lbl.text = adm.display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(name_lbl)

	return frame
