extends Node
## Estado da run inteira. Autoload "Game".
## Tambem guarda o caminho de fases (rotas escolhidas, estrelas por parada),
## o recorde e o checkpoint do ultimo chefe vencido, salvos em SAVE_PATH.
## nation/admirals guardam Effect (coringas/nacoes plugaveis) em duck-typing,
## sem depender do tipo, ja que sao carregados de fora (loja/selecao).
## player_ships e' estado proprio do Game (frota fixa do MVP), por isso
## referencia PlayerShip diretamente.

signal money_changed(total: int)
signal admirals_changed
signal run_started

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

var nation = null            # Effect ou null
var admirals: Array = []     # Array de Effect (coringas comprados na loja)
var player_ships: Array[PlayerShip] = []   # Frota de navios-carta do jogador
var money: int = START_MONEY
var ante: int = 1
var round_in_ante: int = 1
var boss_modifier = null     # Effect ou null - so ativo na 3a rodada de cada ante

# --- Config recalculada a cada rodada ---
var grid_size: int = 6
var target_score: int = 300
var enemy_fleet: Array[EnemyShipDef] = []
var mine_count: int = 0      # minas soltas no tabuleiro (custam 1 tiro e o combo)
var _base_target_score: int = 300   # meta antes do desafio de boss

# --- Caminho de fases ---
var stop_lane: int = -1      # rota da rodada atual: 0 segura, 1 especial, -1 sem escolha
var route_log: Dictionary = {}   # indice global da parada -> {lane, stars}
var last_stars: int = 0      # estrelas da ultima vitoria (doca mostra)
var _specials: Dictionary = {}   # ante -> [Stop, Stop] especial das rodadas 1 e 2
var _bosses: Dictionary = {}     # ante -> Effect (sorteado cedo pro mapa mostrar)

# --- Salvo em disco ---
var best_index: int = 0      # parada mais longe ja alcancada (recorde)
var checkpoint: Dictionary = {}  # estado logo apos o ultimo chefe vencido

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
	if player_ships.is_empty():
		_build_starting_fleet()
	else:
		for ship in player_ships:
			ship.upgrade = null
			ship.upgrade_level = 0
			ship.shot_type = PlayerShip.Shot.NORMAL
		clear_bought_shots()
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

## Tiro comprado vale so pra rodada seguinte a compra.
func clear_bought_shots() -> void:
	for ship in player_ships:
		ship.bought_shots = 0

## Frota fixa do MVP (sem loja ainda): 1 grande (4 cargas), 2 pequenos
## (3 cargas cada) e 1 sonar (3 cargas). Pequenos subiram de 2 pra 3 quando o
## sonar encolheu de linha inteira pra 3 casas: poder sai da informacao e vai
## pro tiro.
func _build_starting_fleet() -> void:
	var bow: Texture2D = load("res://sprites/frota/bow.png")
	var mid: Texture2D = load("res://sprites/frota/mid.png")
	var stern: Texture2D = load("res://sprites/frota/stern.png")
	var sonar_tex: Texture2D = load("res://sprites/frota/sonar.png")
	player_ships = [
		PlayerShip.new(&"battleship", "Encouracado", PlayerShip.Kind.SHOT,
			[bow, mid, stern], 4),
		PlayerShip.new(&"destroyer_a", "Destroyer A", PlayerShip.Kind.SHOT,
			[bow, stern], 3),
		PlayerShip.new(&"destroyer_b", "Destroyer B", PlayerShip.Kind.SHOT,
			[bow, stern], 3),
		# sonar.png tem as duas pontas cortadas - precisa de proa e popa em volta.
		PlayerShip.new(&"sonar_ship", "Navio-sonar", PlayerShip.Kind.SONAR,
			[bow, sonar_tex, stern], 3),
	]

## Recalcula meta e frota inimiga com base no ante/rodada/rota atuais.
## Rodada 3 de cada ante e' rodada-boss: o desafio (sorteado no inicio do
## ante, ver boss_for) ajusta a meta e/ou a frota do jogador (aplicado em
## refill_player_ships). Pode ser chamado de novo ao trocar de rota.
func configure_round() -> void:
	var ante_mult := pow(1.6, ante - 1)
	var round_mult := 1.0 + 0.5 * (round_in_ante - 1)
	_base_target_score = int(300.0 * ante_mult * round_mult)
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

# --- Checkpoint / save ---------------------------------------------------------

func has_checkpoint() -> bool:
	return not checkpoint.is_empty()

## Snapshot logo depois de vencer o chefe: a run volta pro inicio do ante
## seguinte com o dinheiro, almirantes e navios desse momento.
func _save_checkpoint() -> void:
	var ships: Array = []
	for ship in player_ships:
		ships.append({
			"id": ship.id,
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
	for data in checkpoint["ships"]:
		for ship in player_ships:
			if ship.id != data["id"]:
				continue
			ship.shot_type = data["shot"]
			ship.upgrade_level = data["level"]
			for up in ShipUpgradeCatalog.all():
				if up.id == data["upgrade"]:
					ship.upgrade = up
	admirals_changed.emit()
	money_changed.emit(money)

func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progresso", "best_index", best_index)
	cfg.set_value("progresso", "checkpoint", checkpoint)
	cfg.save(SAVE_PATH)

func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best_index = cfg.get_value("progresso", "best_index", 0)
	checkpoint = cfg.get_value("progresso", "checkpoint", {})

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
