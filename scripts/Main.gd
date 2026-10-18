extends Control
## Casca jogavel: instancia Board + FleetBar + painel de debug, e troca pra
## Shop (mesma cena, so visibilidade) quando a rodada e vencida.

@onready var board: Board = $Board
@onready var fleet_bar: FleetBar = $FleetBar
@onready var admiral_bar: AdmiralBar = $AdmiralBar
@onready var panel: PanelContainer = $Panel
@onready var shop: Shop = $Shop
@onready var game_over: GameOver = $GameOver
@onready var boss_label: Label = $Panel/VBox/Boss
@onready var boss_actions: HBoxContainer = $Panel/VBox/BossActions
@onready var reroll_boss_btn: Button = $Panel/VBox/BossActions/RerollBoss
@onready var remove_boss_btn: Button = $Panel/VBox/BossActions/RemoveBoss
@onready var info: Label = $Panel/VBox/Info
@onready var result: Label = $Panel/VBox/Result
@onready var restart_btn: Button = $Panel/VBox/Restart

func _ready() -> void:
	board.score_changed.connect(func(_s, _t): _refresh())
	board.shots_changed.connect(func(_l): _refresh())
	board.sonar_changed.connect(func(_l): _refresh())
	board.combo_changed.connect(func(_s, _m): _refresh())
	board.shot_resolved.connect(_on_shot)
	board.round_won.connect(_on_round_won)
	board.round_lost.connect(_on_round_lost)

	fleet_bar.bind(board)
	shop.closed.connect(_on_shop_closed)
	restart_btn.pressed.connect(_on_restart)
	reroll_boss_btn.pressed.connect(_on_reroll_boss)
	remove_boss_btn.pressed.connect(_on_remove_boss)
	admiral_bar.sell_requested.connect(_on_sell_admiral)
	game_over.restart.connect(_on_game_over_restart)
	_refresh()

func _on_round_lost() -> void:
	result.text = "RODADA PERDIDA - sem tiros"
	board.visible = false
	fleet_bar.visible = false
	panel.visible = false
	game_over.visible = true
	game_over.open(board.score, board.target, Game.ante, Game.round_in_ante)

## So aqui a run reseta de verdade (dinheiro, almirantes, ante voltam ao
## inicio) - ate clicar "Novo Jogo" a tela de fim de jogo fica congelada
## mostrando o resultado da tentativa que acabou de perder.
func _on_game_over_restart() -> void:
	game_over.visible = false
	board.visible = true
	fleet_bar.visible = true
	panel.visible = true
	result.text = ""
	Game.reset_run()
	Game.configure_round()
	board.start_round()
	_refresh()

## Confirma antes de vender - venda e' definitiva (o Almirante some da frota
## e pode nao voltar a aparecer na loja).
func _on_sell_admiral(adm: Effect) -> void:
	var menu := PopupMenu.new()
	add_child(menu)
	menu.add_item("Vender %s por %d" % [adm.display_name, Game.ADMIRAL_SELL_REFUND], 0)
	menu.add_item("Cancelar", 1)
	menu.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			Game.sell_admiral(adm)
	)
	menu.popup_hide.connect(menu.queue_free)
	menu.popup(Rect2i(get_global_mouse_position(), Vector2i(220, 0)))

func _on_reroll_boss() -> void:
	board.reroll_boss()
	_refresh()

func _on_remove_boss() -> void:
	board.remove_boss()
	_refresh()

func _on_restart() -> void:
	result.text = ""
	Game.configure_round()
	board.start_round()
	_refresh()

func _on_round_won() -> void:
	result.text = "RODADA VENCIDA"
	board.visible = false
	fleet_bar.visible = false
	panel.visible = false
	shop.visible = true
	admiral_bar.set_sellable(true)
	shop.open()

func _on_shop_closed() -> void:
	shop.visible = false
	board.visible = true
	fleet_bar.visible = true
	panel.visible = true
	result.text = ""
	admiral_bar.set_sellable(false)
	Game.advance_round()
	Game.configure_round()
	board.start_round()
	_refresh()

func _refresh() -> void:
	var beat_target: String = "  (META BATIDA)" if board.score >= board.target else ""
	info.text = "Pontos %d / %d%s\nTiros %d   Sonar %d\nCombo x%d (mult +%d)" % [
		board.score, board.target, beat_target, board.shots_left, board.sonar_left,
		board.streak, maxi(0, board.streak - 1),
	]
	if Game.boss_modifier:
		boss_label.text = "DESAFIO: %s - %s" % [Game.boss_modifier.display_name, Game.boss_modifier.description]
		boss_label.modulate = Color(1.0, 0.55, 0.2)
	else:
		boss_label.text = ""
	var can_adjust := board.can_adjust_boss()
	boss_actions.visible = can_adjust
	if can_adjust:
		reroll_boss_btn.text = "Trocar desafio ($%d)" % Board.BOSS_ADJUST_COST
		remove_boss_btn.text = "Remover desafio ($%d)" % Board.BOSS_ADJUST_COST

func _on_shot(d: Dictionary) -> void:
	if d["hit"]:
		var extra: String = "  AFUNDOU!" if d["sank"] else ""
		result.text = "+%d  =  %d chips  x%s%s" % [d["gained"], d["chips"], _fmt_mult(d["mult"]), extra]
	else:
		var combo_txt: String = "combo mantido" if board.streak > 0 else "combo zerado"
		var gained_txt: String = "  +%d chips" % d["gained"] if d["gained"] > 0 else ""
		result.text = "agua - %s%s" % [combo_txt, gained_txt]

func _fmt_mult(m: float) -> String:
	return str(int(m)) if m == floor(m) else ("%.1f" % m)
