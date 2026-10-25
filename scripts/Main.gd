extends Control
## Casca jogavel: instancia Board + FleetBar + Hud, e troca pra
## Shop (mesma cena, so visibilidade) quando a rodada e vencida, passando
## pela animacao do navio atracando (DockTransition) e pela carta nautica
## (LevelMap) com o caminho de fases. Na derrota passa pelo
## naufragio (SinkTransition) antes do GameOver. Toda troca de tela passa
## pela cortina (ScreenFader) em vez de corte seco.

const LAST_SHOT_DELAY := 0.6   # explosao/respingo do ultimo tiro duram ~0.45s

@onready var board: Board = $Board
@onready var fleet_bar: FleetBar = $FleetBar
@onready var admiral_bar: AdmiralBar = $AdmiralBar
@onready var hud: Hud = $Hud
@onready var shop: Shop = $Shop
@onready var level_map: LevelMap = $LevelMap
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
	level_map.closed.connect(_on_map_closed)
	level_map.resume_requested.connect(_on_resume_checkpoint)
	dock.finished.connect(_open_map)
	sink.finished.connect(_show_game_over)
	admiral_bar.sell_requested.connect(_on_sell_admiral)
	game_over.restart.connect(_on_game_over_restart)
	game_over.resume.connect(_on_resume_checkpoint)
	# A run comeca na carta nautica (parada 1) e de la vai pra loja comprar tiros.
	Game.configure_round()
	_show_map(false)

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
		_show_map(false)
	)

## Volta pro inicio do ante seguinte ao ultimo chefe vencido, com o dinheiro,
## almirantes e navios daquele momento (fim de jogo ou inicio do jogo).
func _on_resume_checkpoint() -> void:
	fader.swap(func():
		game_over.visible = false
		sink.stop()
		Game.load_checkpoint()
		Game.configure_round()
		_show_map(false)
	)

## Atalhos de teste, so rodando pelo editor (build de debug):
## F1 +$20, F2 vence a rodada atual, F3 revela os navios no sonar.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			Game.add_money(20)
		KEY_F2:
			if board.visible:
				board.debug_win()
		KEY_F3:
			if board.visible:
				board.debug_reveal()

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
		dock.play(Game.last_stars)
	)

## Navio atracou (ou o jogador pulou a animacao): avanca a rodada e abre a
## carta nautica ja com a rodada seguinte configurada; o navio navega da
## parada vencida ate a nova.
func _open_map() -> void:
	fader.swap(func():
		dock.stop()
		Game.advance_round()
		Game.configure_round()
		_show_map(true)
	)

func _show_map(sail: bool) -> void:
	_set_board_visible(false)
	shop.visible = false
	admiral_bar.visible = false
	level_map.visible = true
	level_map.open(sail)

func _on_map_closed() -> void:
	fader.swap(func():
		level_map.visible = false
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
