extends PanelContainer
class_name Hud
## Painel da direita, estilo Balatro: meta, pontos da rodada (contando ate o
## valor novo, com barra ate a meta), conta do ultimo tiro em fichas x mult,
## combo e contadores (tiros, sonar, dinheiro). No topo, mini-trilha do ante
## atual (3 paradas, a ultima e' o chefe), igual ao mapa de fases.
## Combo "esquenta" o mult: cor sobe de dourado pra vermelho, caixa pula,
## painel treme mais a cada acerto e a partir de FIRE_STREAK o mult pega fogo.

const FIRE_SHEET: Texture2D = preload("res://sprites/efeitos/hit_fire_sheet.png")

const CREAM := Color("#fdf6e3")
const GOLD := Color("#f3c44b")
const HIT_RED := Color("#e43c4f")
const WATER_BLUE := Color("#8fb3c9")
const FLEET_ALIVE := Color("#2fbfb0")
const SUNK_RED := Color("#e43c4f")
const FLEET_DIM := Color(0.6, 0.63, 0.68, 0.8)
const STEEL := Color("#9fb0c4")
const TAG_COLORS := {
	&"loot": GOLD,
	&"armor": STEEL,
	&"sub": Color("#2fbfb0"),
}
# Cor do combo por tamanho da sequencia (indice = acertos seguidos - 2).
const HEAT: Array[Color] = [Color("#f3c44b"), Color("#f08a3c"), Color("#e4573c"), Color("#ff3b2f")]
const FIRE_STREAK := 4        # a partir daqui o mult pega fogo (+1 chama por acerto)
const MAX_FLAMES := 3
const COUNT_TIME := 0.35      # pontos contando ate o valor novo
const TRACK_LEFT := 96.0      # espaco do "ANTE n" antes das paradas
const TRACK_Y := 14.0
const STAT_BG := Color("#12365f")
const DANGER_ORANGE := Color("#f08a3c")

@onready var track: Control = $VBox/Track
@onready var boss_box: PanelContainer = $VBox/Boss
@onready var boss_name: Label = $VBox/Boss/VBox/Name
@onready var boss_desc: Label = $VBox/Boss/VBox/Desc
@onready var boss_actions: HBoxContainer = $VBox/Boss/VBox/Actions
@onready var reroll_btn: Button = $VBox/Boss/VBox/Actions/Reroll
@onready var remove_btn: Button = $VBox/Boss/VBox/Actions/Remove
@onready var target_value: Label = $VBox/Target/Value
@onready var score_value: Label = $VBox/Score/Value
@onready var progress: ProgressBar = $VBox/Progress
@onready var shot_name: Label = $VBox/ShotName
@onready var chips_box: PanelContainer = $VBox/Calc/Chips
@onready var chips_value: Label = $VBox/Calc/Chips/Value
@onready var mult_box: PanelContainer = $VBox/Calc/Mult
@onready var mult_value: Label = $VBox/Calc/Mult/Value
@onready var flames: Control = $VBox/Calc/Mult/Flames
@onready var combo_label: Label = $VBox/Combo
@onready var shots_value: Label = $VBox/Stats/Shots/VBox/Value
@onready var sonar_value: Label = $VBox/Stats/Sonar/VBox/Value
@onready var money_box: PanelContainer = $VBox/Stats/Money
@onready var money_value: Label = $VBox/Stats/Money/VBox/Value
@onready var fleet_box: VBoxContainer = $VBox/Fleet

var _board: Board = null
var _shown_score: float = 0.0
var _score_tween: Tween
var _shake_tween: Tween
var _rest_pos: Vector2
var _streak: int = 0
var _goal_reached: bool = false
var _fill_style: StyleBox      # barra normal (teal); vira dourada ao bater a meta
var _mult_style: StyleBoxFlat  # copia propria: a borda muda de cor com o combo

func _ready() -> void:
	_fill_style = progress.get_theme_stylebox("fill")
	_mult_style = (mult_box.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	mult_box.add_theme_stylebox_override("panel", _mult_style)
	track.draw.connect(_draw_track)

func bind(board: Board) -> void:
	_board = board
	board.round_started.connect(_on_round_started)
	board.score_changed.connect(_on_score_changed)
	board.shots_changed.connect(func(_l): _refresh_counts())
	board.sonar_changed.connect(func(_l): _refresh_counts())
	board.combo_changed.connect(_on_combo_changed)
	board.shot_resolved.connect(_on_shot)
	board.enemy_fleet_changed.connect(_refresh_fleet)
	Game.money_changed.connect(func(_m):
		_refresh_counts()
		_pop(money_box)
	)
	reroll_btn.pressed.connect(func(): board.reroll_boss())
	remove_btn.pressed.connect(func(): board.remove_boss())
	_on_round_started()

func _on_round_started() -> void:
	_goal_reached = false
	_streak = 0
	progress.add_theme_stylebox_override("fill", _fill_style)
	shot_name.text = " "
	chips_value.text = "0"
	mult_value.text = "x1"
	combo_label.text = " "
	_mult_style.border_color = HIT_RED
	_set_flames(0)
	track.queue_redraw()
	_on_score_changed(_board.score, _board.target)
	_refresh_counts()
	_refresh_fleet()

## Paradas do ante: vencidas em ouro, atual em creme com anel, chefe com coroa.
## Rota especial (perigo/tesouro) escrita embaixo.
func _draw_track() -> void:
	var font := get_theme_default_font()
	track.draw_string(font, Vector2(0, TRACK_Y + 7), "ANTE %d" % Game.ante, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, GOLD)
	var gap := (track.size.x - TRACK_LEFT - 16.0) / (Game.ROUNDS_PER_ANTE - 1)
	var first := Vector2(TRACK_LEFT, TRACK_Y)
	track.draw_line(first, first + Vector2(gap * (Game.ROUNDS_PER_ANTE - 1), 0), FLEET_DIM, 3.0)
	for i in Game.ROUNDS_PER_ANTE:
		var p := first + Vector2(gap * i, 0)
		var boss := i == Game.ROUNDS_PER_ANTE - 1
		var r := 12.0 if boss else 9.0
		var here := i == Game.round_in_ante - 1
		var fill := STAT_BG
		if i < Game.round_in_ante - 1:
			fill = GOLD
		elif here:
			fill = CREAM
			track.draw_arc(p, r + 5.0, 0.0, TAU, 32, HIT_RED if boss else GOLD, 2.0, true)
		track.draw_circle(p, r, fill)
		if boss:
			MapIcons.crown(track, p, 0.4, HIT_RED)
	var kind := Game.stop_kind()
	if kind != Game.Stop.NORMAL:
		var color := DANGER_ORANGE if kind == Game.Stop.DANGER else GOLD
		track.draw_string(font, Vector2(0, TRACK_Y + 34), Game.STOP_NAMES[kind], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)

## Uma linha por tipo de navio inimigo: quadradinhos do tamanho + nome, e
## "xN" com quantos ainda flutuam quando ha mais de um igual. So revela o que
## o batalha naval classico anuncia (quem ja afundou), nunca a posicao.
func _refresh_fleet() -> void:
	for c in fleet_box.get_children():
		fleet_box.remove_child(c)
		c.queue_free()
	var groups: Dictionary = {}   # nome|tamanho|marcas -> {def, alive, total}
	for ship in _board.enemy_ships:
		var def: EnemyShipDef = ship["def"]
		var key := "%s|%d|%s" % [def.display_name, def.size, str(def.tags())]
		if not groups.has(key):
			groups[key] = {"def": def, "alive": 0, "total": 0}
		groups[key]["total"] += 1
		if not _board.is_sunk(ship):
			groups[key]["alive"] += 1
	for group in groups.values():
		var def: EnemyShipDef = group["def"]
		var sunk: bool = group["alive"] == 0
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var squares := HBoxContainer.new()
		squares.add_theme_constant_override("separation", 2)
		squares.custom_minimum_size = Vector2(5 * 14, 0)
		for i in def.size:
			var sq := ColorRect.new()
			sq.custom_minimum_size = Vector2(12, 12)
			sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sq.color = SUNK_RED if sunk else FLEET_ALIVE
			squares.add_child(sq)
		row.add_child(squares)
		var name_lbl := Label.new()
		name_lbl.text = def.display_name
		if group["total"] > 1:
			name_lbl.text += " x%d" % (group["total"] if sunk else group["alive"])
		name_lbl.add_theme_color_override("font_color", FLEET_DIM if sunk else CREAM)
		row.add_child(name_lbl)
		for tag in def.tags():
			var tag_lbl := Label.new()
			tag_lbl.text = tag["text"]
			tag_lbl.add_theme_color_override("font_color", FLEET_DIM if sunk else TAG_COLORS.get(tag["kind"], CREAM))
			row.add_child(tag_lbl)
		fleet_box.add_child(row)
	if _board.mines_total > 0:
		fleet_box.add_child(_mines_row())

## Minas: um quadrado por mina (vermelho = ainda escondida, cinza = detonada).
func _mines_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var squares := HBoxContainer.new()
	squares.add_theme_constant_override("separation", 2)
	squares.custom_minimum_size = Vector2(5 * 14, 0)
	for i in _board.mines_total:
		var sq := ColorRect.new()
		sq.custom_minimum_size = Vector2(12, 12)
		sq.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sq.color = FLEET_DIM if i < _board.mines_exploded else HIT_RED
		squares.add_child(sq)
	row.add_child(squares)
	var lbl := Label.new()
	lbl.text = "Minas  -1 tiro"
	lbl.add_theme_color_override("font_color", HIT_RED)
	row.add_child(lbl)
	return row

func _on_score_changed(score: int, target: int) -> void:
	target_value.text = str(target)
	progress.max_value = maxi(target, 1)
	if _score_tween:
		_score_tween.kill()
	if score <= _shown_score:
		# Rodada nova ou meta trocada pelo desafio: sem contagem.
		_set_shown_score(score)
	else:
		_score_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_score_tween.tween_method(_set_shown_score, _shown_score, float(score), COUNT_TIME)
		_pop(score_value)
	if score >= target and not _goal_reached:
		_goal_reached = true
		var gold_fill := (_fill_style as StyleBoxFlat).duplicate()
		gold_fill.bg_color = GOLD
		progress.add_theme_stylebox_override("fill", gold_fill)
		_flash(shot_name, "META BATIDA!", GOLD)
	_refresh_boss()

func _set_shown_score(v: float) -> void:
	_shown_score = v
	score_value.text = str(int(v))
	progress.value = v

func _on_shot(d: Dictionary) -> void:
	if d.get("mine", false) and not d["hit"]:
		_flash(shot_name, "MINA! -%d tiro" % Board.MINE_SHOT_PENALTY, HIT_RED)
		_shake(6.0)
	elif d.get("armor", false):
		_flash(shot_name, "BLINDADO!", STEEL)
	elif d["hit"]:
		var text := "ACERTO" if d.get("hits", 1) <= 1 else "ACERTO x%d" % d["hits"]
		if d["sank"]:
			text = "AFUNDOU! +$%d" % d["loot"] if d.get("loot", 0) > 0 else "AFUNDOU!"
		_flash(shot_name, text, GOLD if d["sank"] else CREAM)
	else:
		_flash(shot_name, "AGUA", WATER_BLUE)
	chips_value.text = str(d["chips"])
	mult_value.text = "x" + _fmt_mult(d["mult"])
	_pop(chips_box)
	_pop(mult_box, 1.25, 0.08)

func _on_combo_changed(streak: int, _combo_mult: int) -> void:
	var grew := streak > _streak
	var lost := streak == 0 and _streak >= 2
	_streak = streak
	if streak >= 2:
		var heat := HEAT[mini(streak - 2, HEAT.size() - 1)]
		_mult_style.border_color = heat
		combo_label.text = "COMBO x%d" % streak
		combo_label.add_theme_color_override("font_color", heat)
		if grew:
			_pop(combo_label, 1.0 + 0.12 * mini(streak, 6))
			_shake(2.0 * mini(streak, 6))
		_set_flames(clampi(streak - FIRE_STREAK + 1, 0, MAX_FLAMES))
	else:
		_mult_style.border_color = HIT_RED
		_set_flames(0)
		if lost:
			_flash(combo_label, "combo perdido", WATER_BLUE)
		else:
			combo_label.text = " "

func _refresh_counts() -> void:
	shots_value.text = str(_board.shots_left)
	sonar_value.text = str(_board.sonar_left)
	money_value.text = str(Game.money)
	_refresh_boss()

## Desafio so aparece na rodada de boss; botoes so antes do 1o tiro/sonar.
func _refresh_boss() -> void:
	var boss = Game.boss_modifier
	boss_box.visible = boss != null
	if boss:
		boss_name.text = "DESAFIO: %s" % boss.display_name
		boss_desc.text = boss.description
	var can_adjust := _board.can_adjust_boss()
	boss_actions.visible = can_adjust
	if can_adjust:
		reroll_btn.text = "Trocar $%d" % Board.BOSS_ADJUST_COST
		remove_btn.text = "Remover $%d" % Board.BOSS_ADJUST_COST

## Chamas em cima da caixa do mult, espalhadas pela largura.
func _set_flames(n: int) -> void:
	if flames.get_child_count() == n:
		return
	for c in flames.get_children():
		flames.remove_child(c)   # sai da contagem ja, nao so no fim do quadro
		c.queue_free()
	for i in n:
		var flame := SpriteSheetPlayer.new()
		flame.sheet = FIRE_SHEET
		flame.frame_count = 4
		flame.fps = randf_range(7.0, 10.0)
		flame.loop = true
		flame.fill_parent = false
		flames.add_child(flame)
		flame.size = Vector2(48, 48)
		flame.position = Vector2(flames.size.x * (i + 1) / (n + 1) - 24, -30)
		flame.play()

func _flash(label: Label, text: String, color: Color) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	_pop(label)

## Pulo de escala (passa do tamanho e assenta). Container nao mexe em scale.
func _pop(node: Control, amount: float = 1.25, delay: float = 0.0) -> void:
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2.ONE * amount
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.25).set_delay(delay)

func _shake(px: float) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		position = _rest_pos
	_rest_pos = position
	_shake_tween = create_tween()
	for i in 4:
		_shake_tween.tween_property(self, "position", _rest_pos + Vector2(randf_range(-px, px), randf_range(-px, px)), 0.04)
	_shake_tween.tween_property(self, "position", _rest_pos, 0.04)

func _fmt_mult(m: float) -> String:
	return str(int(m)) if m == floor(m) else ("%.1f" % m)
