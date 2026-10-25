extends Node
## Estado da run inteira. Autoload "Game".
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

func _ready() -> void:
	randomize()
	# A loja abre antes da 1a rodada e ja precisa da frota pra vender tiros.
	if player_ships.is_empty():
		_build_starting_fleet()

func reset_run() -> void:
	admirals.clear()
	money = START_MONEY
	ante = 1
	round_in_ante = 1
	boss_modifier = null
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

## Recalcula meta e frota inimiga com base no ante/rodada atuais.
## Rodada 3 de cada ante e' rodada-boss: sorteia 1 desafio que ajusta a
## meta e/ou a frota do jogador (aplicado em refill_player_ships).
func configure_round() -> void:
	var ante_mult := pow(1.6, ante - 1)
	var round_mult := 1.0 + 0.5 * (round_in_ante - 1)
	_base_target_score = int(300.0 * ante_mult * round_mult)
	grid_size = _grid_for_ante(ante)
	enemy_fleet = _fleet_for_ante(ante)
	mine_count = _mines_for_ante(ante)
	boss_modifier = _pick_boss() if round_in_ante == 3 else null
	_apply_boss_target()

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
	_apply_boss_target()
	refill_player_ships()

## Remove o desafio de boss da rodada atual. Mesmas condicoes de reroll_boss.
func remove_boss() -> void:
	boss_modifier = null
	_apply_boss_target()
	refill_player_ships()

func advance_round() -> void:
	round_in_ante += 1
	if round_in_ante > 3:
		round_in_ante = 1
		ante += 1

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
## navio EXTRA de 2 casas. O saque aparece na lista da frota (escolha de alvo).
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
	return out

## Sem minas no 1o ante (aprendizado); depois cresce ate 3.
func _mines_for_ante(a: int) -> int:
	return clampi(a - 1, 0, 3)

## Antes iniciais: poucos navios, grandes. Depois: mais navios, menores.
func _sizes_for_ante(a: int) -> Array[int]:
	var out: Array[int] = []
	match a:
		1:
			out.assign([5, 4, 4])
		2:
			out.assign([5, 4, 3, 3])
		3:
			out.assign([4, 3, 3, 3, 2])
		4:
			out.assign([4, 3, 2, 2, 2])
		_:
			out.assign([3, 3, 2, 2, 2, 2])
	return out
