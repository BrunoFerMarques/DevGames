extends Node
## Estado da run inteira. Autoload "Game".
## Tambem guarda o caminho de fases (rotas escolhidas, estrelas por parada),
## o recorde e o checkpoint do ultimo chefe vencido, salvos em SAVE_PATH
## junto com as opcoes (tremor de tela).
## nation/admirals guardam Effect (coringas/nacoes plugaveis) em duck-typing,
## sem depender do tipo, ja que sao carregados de fora (loja/selecao).
## player_ships e' estado proprio do Game (frota fixa do MVP), por isso
## referencia PlayerShip diretamente.

signal money_changed(total: int)
signal admirals_changed
signal run_started
## Navio comprado/vendido no Estaleiro (FleetBar remonta os cards).
signal ships_changed

const GRID_SIZE := 10        ## tamanho maximo (layout/camera). Atual = grid_size.
const MAX_ADMIRALS := 5      ## teto de coringas, igual ao limite de jokers do Balatro.
const ADMIRAL_SELL_REFUND := 3   ## metade do preco de compra (Shop.ADMIRAL_PRICE = 7)
const CARGO_CHANCE := 0.35       ## chance de cada navio (menos o 1o) ser cargueiro
const TREASURE_CHANCE := 0.15    ## chance por rodada de ter um navio-tesouro
const ARMOR_FROM_ANTE := 2       ## blindagem so aparece depois do 1o ante
const ARMOR_CHANCE := 0.35       ## chance de um navio de guerra vir blindado
const SUB_FROM_ANTE := 2         ## submarino (invisivel ao sonar) a partir do ante 2
const SUB_CHANCE := 0.4          ## chance de 1 navio pequeno (<=3) ser submarino
## Tiro nao recarrega sozinho: a loja abre antes de toda rodada (inclusive a
## 1a) e cada tiro e' comprado. Dinheiro inicial paga a carga da 1a rodada.
const START_MONEY := 12
const ROUNDS_PER_ANTE := 3
## Meta da 1a rodada de cada ante; a 2a e' x1.5 e a do chefe x2
## (ROUND_TARGET_STEP). Era 300 x 1.6^(ante-1): simulando runs com compra na
## loja, o poder do jogador cresce ~1.7-1.8x por ante do 2 ao 5 e a pontuacao
## fechava o chefe com ~2x a meta. A tabela segura a folga do chefe perto de
## 1.3x. Depois do ultimo ante, cresce ANTE_TARGET_GROWTH por ante.
const ANTE_BASE_TARGETS: Array[int] = [350, 520, 1100, 1800, 2900, 4200, 6000, 8500]
const ANTE_TARGET_GROWTH := 1.45
const ROUND_TARGET_STEP := 0.5
## Vagas da doca: soma das vagas (tonnage) dos navios da frota nao passa
## disso. Almirantes de estaleiro aumentam (Effect.modify_dock).
const DOCK_BASE := 10
## Cada tiro comprado na loja (vale so pra proxima rodada).
const SHOT_PRICE := 1
## Frota inicial: 10 vagas, 9 tiros de pente, 2 vantagens (Cruzador, Destroyer).
const STARTING_FLEET: Array[StringName] = [&"battleship", &"cruiser", &"destroyer", &"sonar_ship"]

## Parada do mapa. As rodadas 1 e 2 de cada ante tem bifurcacao: rota segura
## (NORMAL) ou a especial sorteada pro ante (DANGER ou TREASURE).
enum Stop { NORMAL, DANGER, TREASURE }
const STOP_NAMES := {
	Stop.NORMAL: "Rota segura",
	Stop.DANGER: "Aguas perigosas",
	Stop.TREASURE: "Rota do tesouro",
}
const STOP_DESCS := {
	Stop.NORMAL: "Sem surpresas.",
	Stop.DANGER: "Meta +30%, +1 mina. Vencer paga +$6.",
	Stop.TREASURE: "Navio-tesouro garantido na frota inimiga. Meta +10%.",
}
const DANGER_TARGET_MULT := 1.3
const DANGER_EXTRA_MINES := 1
const DANGER_REWARD := 6
const TREASURE_TARGET_MULT := 1.1
## Pontos/meta pra ganhar a 2a e a 3a estrela (a 1a vem com a vitoria).
const STAR_RATIOS: Array[float] = [1.5, 2.0]
const STAR_BONUS := 1            ## $ por estrela alem da 1a
const SAVE_PATH := "user://progresso.cfg"
## Treino: 4 tiros no Encouracado afundam a frota fixa inteira (Tutorial.gd).
const TUTORIAL_MONEY := 4
const TUTORIAL_GRID := 5
const TUTORIAL_TARGET := 200

var nation = null            # Effect ou null
var admirals: Array = []     # Array de Effect (coringas comprados na loja)
var player_ships: Array[PlayerShip] = []   # Frota de navios-carta do jogador
var money: int = START_MONEY
var ante: int = 1
var round_in_ante: int = 1
var boss_modifier = null     # Effect ou null - so ativo na 3a rodada de cada ante

# --- Config recalculada a cada rodada ---
var grid_size: int = 6
var target_score: int = 350
var enemy_fleet: Array[EnemyShipDef] = []
var mine_count: int = 0      # minas soltas no tabuleiro (custam 1 tiro e o combo)
var _base_target_score: int = 350   # meta antes do desafio de boss

# --- Caminho de fases ---
var stop_lane: int = -1      # rota da rodada atual: 0 segura, 1 especial, -1 sem escolha
var route_log: Dictionary = {}   # indice global da parada -> {lane, stars}
var last_stars: int = 0      # estrelas da ultima vitoria (doca mostra)
var _specials: Dictionary = {}   # ante -> [Stop, Stop] especial das rodadas 1 e 2
var _bosses: Dictionary = {}     # ante -> Effect (sorteado cedo pro mapa mostrar)

# --- Treino ---
var tutorial: bool = false
## Posicao fixa da frota inimiga ({def, body, horiz}); vazio = sorteia (Board).
var fixed_layout: Array = []

# --- Salvo em disco ---
var tutorial_done: bool = false
var best_index: int = 0      # parada mais longe ja alcancada (recorde)
var checkpoint: Dictionary = {}  # estado logo apos o ultimo chefe vencido
var screen_shake: bool = true    # opcao de acessibilidade (tela de inicio)

func _ready() -> void:
	randomize()
	_load_progress()
	# A loja abre antes da 1a rodada e ja precisa da frota pra vender tiros.
	if player_ships.is_empty():
		_build_starting_fleet()

func reset_run() -> void:
	admirals.clear()
	money = START_MONEY
	ante = 1
	round_in_ante = 1
	boss_modifier = null
	stop_lane = -1
	route_log.clear()
	_specials.clear()
	_bosses.clear()
	tutorial = false
	fixed_layout.clear()
	# Frota volta a inicial: navios comprados/vendidos e melhorias somem.
	_build_starting_fleet()
	if nation:
		nation.on_run_start(self)
	# Barra de Almirantes e HUD de dinheiro so redesenham ouvindo esses sinais.
	admirals_changed.emit()
	money_changed.emit(money)
	run_started.emit()

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

## Vende um Almirante da frota do jogador, devolvendo parte do preco de compra.
func sell_admiral(adm: Effect) -> bool:
	if not admirals.has(adm):
		return false
	admirals.erase(adm)
	add_money(ADMIRAL_SELL_REFUND)
	admirals_changed.emit()
	return true

## Gasta dinheiro (loja). Retorna false sem efeito se nao tiver o suficiente.
func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true

## Recarrega a carga de cada navio da frota (chamado no inicio de cada rodada)
## e aplica os modificadores de tiro/sonar de boss, nacao e almirantes, nessa
## ordem (desafio ajusta primeiro, almirante pode compensar depois).
func refill_player_ships() -> void:
	if player_ships.is_empty():
		_build_starting_fleet()
	for ship in player_ships:
		ship.refill()
		var n: int = ship.charges
		if ship.kind == PlayerShip.Kind.SHOT:
			if boss_modifier:
				n = boss_modifier.modify_shots(n)
			if nation:
				n = nation.modify_shots(n)
			for adm in admirals:
				n = adm.modify_shots(n)
		else:
			if boss_modifier:
				n = boss_modifier.modify_sonar(n)
			if nation:
				n = nation.modify_sonar(n)
			for adm in admirals:
				n = adm.modify_sonar(n)
		ship.charges = maxi(0, n)
		ship.round_cap = ship.charges

## Tiro comprado vale so pra rodada seguinte a compra.
func clear_bought_shots() -> void:
	for ship in player_ships:
		ship.bought_shots = 0

func _build_starting_fleet() -> void:
	player_ships.clear()
	for class_id in STARTING_FLEET:
		player_ships.append(ShipClassCatalog.by_id(class_id).build())
	ships_changed.emit()

# --- Doca / Estaleiro ------------------------------------------------------------

func dock_capacity() -> int:
	var n := DOCK_BASE
	for adm in admirals:
		n = adm.modify_dock(n)
	return n

func dock_used() -> int:
	var n := 0
	for ship in player_ships:
		n += ship.tonnage()
	return n

## Cabe na doca (vender almirante de estaleiro pode deixar a frota acima do
## limite: ela fica, mas so da pra comprar quando voltar a caber).
func has_dock_room(def: ShipClassDef) -> bool:
	return dock_used() + def.tonnage <= dock_capacity()

func buy_ship(def: ShipClassDef) -> bool:
	if not has_dock_room(def) or not spend_money(def.price):
		return false
	player_ships.append(def.build())
	ships_changed.emit()
	return true

## Sempre sobra pelo menos 1 navio de tiro (sem ele a rodada nao joga).
func can_sell_ship(ship: PlayerShip) -> bool:
	if ship.kind != PlayerShip.Kind.SHOT:
		return true
	return player_ships.filter(func(s: PlayerShip) -> bool: return s.kind == PlayerShip.Kind.SHOT).size() > 1

## Metade do preco + os tiros ja comprados pra ele nesta loja.
func ship_sell_value(ship: PlayerShip) -> int:
	return ship.ship_class.sell_price() + ship.bought_shots * SHOT_PRICE

## Pente efetivo de um navio de tiro: o da classe ajustado pelos almirantes
## (ex.: Flotilha). Fica aqui e nao no PlayerShip porque precisa dos
## almirantes, e o PlayerShip nao pode depender do Game (Game depende dele).
func magazine(ship: PlayerShip) -> int:
	var n := ship.max_charges
	for adm in admirals:
		n = adm.modify_magazine(ship, n)
	return n

func can_load_shot(ship: PlayerShip) -> bool:
	return ship.kind == PlayerShip.Kind.SHOT and ship.bought_shots < magazine(ship)

func sell_ship(ship: PlayerShip) -> bool:
	if not can_sell_ship(ship):
		return false
	var value := ship_sell_value(ship)
	player_ships.erase(ship)
	add_money(value)
	ships_changed.emit()
	return true

## Recalcula meta e frota inimiga com base no ante/rodada/rota atuais.
## Rodada 3 de cada ante e' rodada-boss: o desafio (sorteado no inicio do
## ante, ver boss_for) ajusta a meta e/ou a frota do jogador (aplicado em
## refill_player_ships). Pode ser chamado de novo ao trocar de rota.
func configure_round() -> void:
	_base_target_score = base_target_for(ante, round_in_ante)
	grid_size = _grid_for_ante(ante)
	enemy_fleet = _fleet_for_ante(ante)
	mine_count = _mines_for_ante(ante)
	match stop_kind():
		Stop.DANGER:
			_base_target_score = int(_base_target_score * DANGER_TARGET_MULT)
			mine_count += DANGER_EXTRA_MINES
		Stop.TREASURE:
			_base_target_score = int(_base_target_score * TREASURE_TARGET_MULT)
			if not enemy_fleet.any(func(d: EnemyShipDef) -> bool: return d.id == &"treasure"):
				enemy_fleet.append(EnemyShipDef.treasure())
	boss_modifier = boss_for(ante) if round_in_ante == ROUNDS_PER_ANTE else null
	_apply_boss_target()
	if stage_index() > best_index:
		best_index = stage_index()
		_save_progress()

## Meta da rodada `round_n` do ante `a`, antes de rota e chefe.
func base_target_for(a: int, round_n: int) -> int:
	var last := ANTE_BASE_TARGETS.size()
	var base := float(ANTE_BASE_TARGETS[mini(a, last) - 1])
	if a > last:
		base *= pow(ANTE_TARGET_GROWTH, a - last)
	return int(base * (1.0 + ROUND_TARGET_STEP * (round_n - 1)))

func _apply_boss_target() -> void:
	target_score = boss_modifier.modify_target(_base_target_score) if boss_modifier else _base_target_score

func _pick_boss() -> Effect:
	var opts: Array[Effect] = BossModifierCatalog.all()
	return opts[randi() % opts.size()]

## Troca o desafio de boss da rodada atual por outro sorteado. Quem chama ja
## deve ter debitado o custo (ver Board.reroll_boss). So faz sentido antes do
## primeiro tiro, pois re-recarrega a frota do zero.
func reroll_boss() -> void:
	boss_modifier = _pick_boss()
	_bosses[ante] = boss_modifier
	_apply_boss_target()
	refill_player_ships()

## Remove o desafio de boss da rodada atual. Mesmas condicoes de reroll_boss.
func remove_boss() -> void:
	boss_modifier = null
	_apply_boss_target()
	refill_player_ships()

func advance_round() -> void:
	stop_lane = -1
	round_in_ante += 1
	if round_in_ante > ROUNDS_PER_ANTE:
		round_in_ante = 1
		ante += 1

# --- Caminho de fases ----------------------------------------------------------

## Indice global da parada atual (0 = ante 1 rodada 1).
func stage_index() -> int:
	return (ante - 1) * ROUNDS_PER_ANTE + round_in_ante - 1

## Rodadas 1 e 2 tem bifurcacao; o chefe e' parada unica.
func is_fork(round_n: int) -> bool:
	return round_n < ROUNDS_PER_ANTE

func needs_route_choice() -> bool:
	return is_fork(round_in_ante) and stop_lane < 0

## Parada especial da rodada `round_n` (1 ou 2) do ante `a`, sorteada uma vez.
func special_for(a: int, round_n: int) -> Stop:
	if not _specials.has(a):
		var pool := [Stop.DANGER, Stop.TREASURE]
		_specials[a] = [pool.pick_random(), pool.pick_random()]
	return _specials[a][round_n - 1]

## Desafio do chefe do ante, sorteado na 1a vez que alguem pergunta (o mapa
## pergunta logo na entrada do ante, entao o jogador ve o chefe de antemao).
func boss_for(a: int) -> Effect:
	if not _bosses.has(a):
		_bosses[a] = _pick_boss()
	return _bosses[a]

func stop_kind() -> Stop:
	if stop_lane == 1 and is_fork(round_in_ante):
		return special_for(ante, round_in_ante)
	return Stop.NORMAL

## Escolha feita no mapa; reconfigura a rodada com a rota nova.
func choose_lane(lane: int) -> void:
	stop_lane = lane
	configure_round()

## Vitoria: calcula estrelas, paga bonus (estrelas + aguas perigosas), anota
## a parada no caminho e, se era o chefe, grava o checkpoint. Retorna o bonus.
func record_win(score: int, target: int) -> int:
	var stars := 1
	for ratio in STAR_RATIOS:
		if score >= target * ratio:
			stars += 1
	last_stars = stars
	var bonus := (stars - 1) * STAR_BONUS
	if stop_kind() == Stop.DANGER:
		bonus += DANGER_REWARD
	add_money(bonus)
	route_log[stage_index()] = {"lane": stop_lane, "stars": stars}
	if round_in_ante == ROUNDS_PER_ANTE:
		_save_checkpoint()
	return bonus

# --- Treino --------------------------------------------------------------------

## Rodada de treino: grade 5x5, Destroyer em B2-C2 e Cargueiro em D4-D5
## (posicoes fixas pro roteiro do Tutorial bater) e dinheiro so pros 4 tiros.
func setup_tutorial() -> void:
	reset_run()
	tutorial = true
	money = TUTORIAL_MONEY
	grid_size = TUTORIAL_GRID
	target_score = TUTORIAL_TARGET
	_base_target_score = TUTORIAL_TARGET
	boss_modifier = null
	mine_count = 0
	var destroyer := EnemyShipDef.warship(2)
	var cargo := EnemyShipDef.cargo(2)
	enemy_fleet = [destroyer, cargo]
	var destroyer_body: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1)]
	var cargo_body: Array[Vector2i] = [Vector2i(3, 3), Vector2i(3, 4)]
	fixed_layout = [
		{"def": destroyer, "body": destroyer_body, "horiz": true},
		{"def": cargo, "body": cargo_body, "horiz": false},
	]
	money_changed.emit(money)

func finish_tutorial() -> void:
	tutorial = false
	fixed_layout.clear()
	tutorial_done = true
	_save_progress()

# --- Checkpoint / save ---------------------------------------------------------

func has_checkpoint() -> bool:
	return not checkpoint.is_empty()

## Snapshot logo depois de vencer o chefe: a run volta pro inicio do ante
## seguinte com o dinheiro, almirantes e navios desse momento.
func _save_checkpoint() -> void:
	var ships: Array = []
	for ship in player_ships:
		ships.append({
			"class": ship.ship_class.id,
			"upgrade": ship.upgrade.id if ship.upgrade else &"",
			"level": ship.upgrade_level,
			"shot": ship.shot_type,
		})
	checkpoint = {
		"ante": ante + 1,
		"money": money,
		"admirals": admirals.map(func(a: Effect) -> StringName: return a.id),
		"ships": ships,
		"log": route_log.duplicate(true),
	}
	_save_progress()

func load_checkpoint() -> void:
	reset_run()
	ante = checkpoint["ante"]
	money = checkpoint["money"]
	route_log = checkpoint["log"].duplicate(true)
	for adm_id in checkpoint["admirals"]:
		for adm in AdmiralCatalog.all():
			if adm.id == adm_id:
				admirals.append(adm)
	# Checkpoint de antes do Estaleiro nao guarda a classe: fica a frota inicial.
	var saved: Array = checkpoint["ships"]
	if saved.all(func(d: Dictionary) -> bool: return d.has("class")):
		player_ships.clear()
		for data in saved:
			var def := ShipClassCatalog.by_id(data["class"])
			if def == null:
				continue
			var ship := def.build()
			ship.shot_type = data["shot"]
			ship.upgrade_level = data["level"]
			for up in ShipUpgradeCatalog.all():
				if up.id == data["upgrade"]:
					ship.upgrade = up
			player_ships.append(ship)
		ships_changed.emit()
	admirals_changed.emit()
	money_changed.emit(money)

## Liga/desliga todo tremor de tela (golpes, painel, naufragio) e salva.
func set_screen_shake(on: bool) -> void:
	screen_shake = on
	_save_progress()

func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progresso", "best_index", best_index)
	cfg.set_value("progresso", "checkpoint", checkpoint)
	cfg.set_value("opcoes", "tremor", screen_shake)
	cfg.set_value("opcoes", "treino", tutorial_done)
	cfg.save(SAVE_PATH)

func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_index = cfg.get_value("progresso", "best_index", 0)
	checkpoint = cfg.get_value("progresso", "checkpoint", {})
	screen_shake = cfg.get_value("opcoes", "tremor", true)
	tutorial_done = cfg.get_value("opcoes", "treino", false)

## Grade menor nos antes iniciais, cresce ate o maximo.
func _grid_for_ante(a: int) -> int:
	match a:
		1: return 6
		2: return 7
		3: return 8
		4: return 9
		_: return GRID_SIZE

## Tamanhos fixos por ante; o tipo de cada navio e' sorteado. Cargueiros no
## maximo 2 e sempre sobra navio de guerra. Navio-tesouro (raro) vem como
## navio EXTRA de 2 casas, e todo ante tem botes contrabandistas (1 casa,
## saque alto). O saque aparece na lista da frota (escolha de alvo).
func _fleet_for_ante(a: int) -> Array[EnemyShipDef]:
	var sizes := _sizes_for_ante(a)
	var cargo_count := 0
	var has_sub := false
	var out: Array[EnemyShipDef] = []
	for i in sizes.size():
		var s: int = sizes[i]
		if not has_sub and i > 0 and s <= 3 and a >= SUB_FROM_ANTE and randf() < SUB_CHANCE:
			out.append(EnemyShipDef.submarine(s))
			has_sub = true
		elif cargo_count < 2 and i > 0 and randf() < CARGO_CHANCE:
			out.append(EnemyShipDef.cargo(s))
			cargo_count += 1
		elif a >= ARMOR_FROM_ANTE and randf() < ARMOR_CHANCE:
			out.append(EnemyShipDef.armored(s))
		else:
			out.append(EnemyShipDef.warship(s))
	if randf() < TREASURE_CHANCE:
		out.append(EnemyShipDef.treasure())
	for i in _smugglers_for_ante(a):
		out.append(EnemyShipDef.smuggler())
	return out

func _smugglers_for_ante(a: int) -> int:
	return clampi((a + 1) / 2, 1, 3)

## Sem minas no 1o ante (aprendizado); depois cresce ate 3.
func _mines_for_ante(a: int) -> int:
	return clampi(a - 1, 0, 3)

## Antes iniciais: poucos navios, grandes. Depois: mais navios, menores.
## Navios nunca se encostam (Board._place_fleet), entao a grade 6x6 nao
## comporta mais o [5, 4, 4] antigo com bote e tesouro juntos.
func _sizes_for_ante(a: int) -> Array[int]:
	var out: Array[int] = []
	match a:
		1:
			out.assign([4, 3, 3])
		2:
			out.assign([4, 4, 3, 2])
		3:
			out.assign([4, 3, 3, 3, 2])
		4:
			out.assign([4, 3, 2, 2, 2])
		_:
			out.assign([3, 3, 2, 2, 2, 2])
	return out
