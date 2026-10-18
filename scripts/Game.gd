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

var nation = null            # Effect ou null
var admirals: Array = []     # Array de Effect (coringas comprados na loja)
var player_ships: Array[PlayerShip] = []   # Frota de navios-carta do jogador
var money: int = 0
var ante: int = 1
var round_in_ante: int = 1
var boss_modifier = null     # Effect ou null - so ativo na 3a rodada de cada ante

# --- Config recalculada a cada rodada ---
var grid_size: int = 6
var target_score: int = 300
var enemy_ship_sizes: Array[int] = [5, 4, 4]
var _base_target_score: int = 300   # meta antes do desafio de boss

func _ready() -> void:
	randomize()

func reset_run() -> void:
	admirals.clear()
	money = 0
	ante = 1
	round_in_ante = 1
	boss_modifier = null
	if player_ships.is_empty():
		_build_starting_fleet()
	else:
		for ship in player_ships:
			ship.upgrade = null
			ship.upgrade_level = 0
	if nation:
		nation.on_run_start(self)
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

## Frota fixa do MVP (sem loja ainda): 1 grande (4 cargas), 2 pequenos
## (2 cargas cada) e 1 sonar (3 cargas).
func _build_starting_fleet() -> void:
	var bow: Texture2D = load("res://sprites/bow.png")
	var mid: Texture2D = load("res://sprites/mid.png")
	var stern: Texture2D = load("res://sprites/stern.png")
	var sonar_tex: Texture2D = load("res://sprites/sonar.png")
	player_ships = [
		PlayerShip.new(&"battleship", "Encouracado", PlayerShip.Kind.SHOT,
			[bow, mid, stern], 4),
		PlayerShip.new(&"destroyer_a", "Destroyer A", PlayerShip.Kind.SHOT,
			[bow, stern], 2),
		PlayerShip.new(&"destroyer_b", "Destroyer B", PlayerShip.Kind.SHOT,
			[bow, stern], 2),
		PlayerShip.new(&"sonar_ship", "Navio-sonar", PlayerShip.Kind.SONAR,
			[sonar_tex], 3),
	]

## Recalcula meta e frota inimiga com base no ante/rodada atuais.
## Rodada 3 de cada ante e' rodada-boss: sorteia 1 desafio que ajusta a
## meta e/ou a frota do jogador (aplicado em refill_player_ships).
func configure_round() -> void:
	var ante_mult := pow(1.6, ante - 1)
	var round_mult := 1.0 + 0.5 * (round_in_ante - 1)
	_base_target_score = int(300.0 * ante_mult * round_mult)
	grid_size = _grid_for_ante(ante)
	enemy_ship_sizes = _sizes_for_ante(ante)
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
