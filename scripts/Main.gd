extends Control
## Casca jogavel: instancia Board + FleetBar + Hud, e troca pra
## Shop (mesma cena, so visibilidade) quando a rodada e vencida, passando
## pela animacao do navio atracando (DockTransition). Na derrota passa pelo
## naufragio (SinkTransition) antes do GameOver. Toda troca de tela passa
## pela cortina (ScreenFader) em vez de corte seco.

const LAST_SHOT_DELAY := 0.6   # explosao/respingo do ultimo tiro duram ~0.45s

@onready var board: Board = $Board
@onready var fleet_bar: FleetBar = $FleetBar
@onready var admiral_bar: AdmiralBar = $AdmiralBar
@onready var hud: Hud = $Hud
@onready var shop: Shop = $Shop
@onready var game_over: GameOver = $GameOver
@onready var dock: DockTransition = $DockTransition
@onready var shot_fx: ShotFx = $ShotFx
@onready var sink: SinkTransition = $SinkTransition
@onready var fader: ScreenFader = $ScreenFader

func _ready() -> void:
	board.round_won.connect(_on_round_won)
	board.round_lost.connect(_on_round_lost)

	fleet_bar.bind(board)
	hud.bind(board)
	shot_fx.fleet_bar = fleet_bar
	board.shot_fx = shot_fx
	shop.closed.connect(_on_shop_closed)
	dock.finished.connect(_open_shop)
	sink.finished.connect(_show_game_over)
	admiral_bar.sell_requested.connect(_on_sell_admiral)
	game_over.restart.connect(_on_game_over_restart)
	# Tiro e' comprado antes de cada rodada: a run ja comeca na loja.
	Game.configure_round()
	_show_shop()

func _on_round_lost() -> void:
	await get_tree().create_timer(LAST_SHOT_DELAY).timeout
	fader.swap(func():
		_set_board_visible(false)
		admiral_bar.visible = false
		sink.play()
	)

## Navio afundou (ou o jogador pulou): painel de fim de jogo por cima do mar.
func _show_game_over() -> void:
	game_over.visible = true
	game_over.open(board.score, board.target)

## So aqui a run reseta de verdade (dinheiro, almirantes, ante voltam ao
## inicio) - ate clicar "Novo Jogo" a tela de fim de jogo fica congelada
## mostrando o resultado da tentativa que acabou de perder.
func _on_game_over_restart() -> void:
	fader.swap(func():
		game_over.visible = false
		sink.stop()
		Game.reset_run()
		Game.configure_round()
		_show_shop()
	)

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

func _on_round_won() -> void:
	# Deixa a animacao do ultimo tiro (explosao/respingo) terminar antes da doca.
	await get_tree().create_timer(LAST_SHOT_DELAY).timeout
	fader.swap(func():
		_set_board_visible(false)
		admiral_bar.visible = false
		dock.play()
	)

## Navio atracou (ou o jogador pulou a animacao): avanca a rodada e abre a
## loja ja com a rodada seguinte configurada (meta/desafio aparecem no topo).
func _open_shop() -> void:
	fader.swap(func():
		dock.stop()
		Game.advance_round()
		Game.configure_round()
		_show_shop()
	)

func _show_shop() -> void:
	_set_board_visible(false)
	shop.visible = true
	admiral_bar.visible = true
	admiral_bar.set_sellable(true)
	shop.open()

func _on_shop_closed() -> void:
	fader.swap(func():
		shop.visible = false
		_set_board_visible(true)
		admiral_bar.set_sellable(false)
		board.start_round()
	)

## Tela de jogo: tabuleiro + frota + painel da direita andam juntos.
func _set_board_visible(v: bool) -> void:
	board.visible = v
	fleet_bar.visible = v
	hud.visible = v
