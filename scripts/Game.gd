extends Node
## Estado da run inteira. Autoload "Game".
## nation/admirals guardam Effect (coringas/nacoes plugaveis) em duck-typing,
## sem depender do tipo, ja que sao carregados de fora (loja/selecao).
## player_ships e' estado proprio do Game (frota fixa do MVP), por isso
## referencia PlayerShip diretamente.

signal money_changed(total: int)
signal run_started

const GRID_SIZE := 10        ## tamanho maximo (layout/camera). Atual = grid_size.

var nation = null            # Effect ou null
var admirals: Array = []     # Array de Effect (coringas comprados na loja)
var player_ships: Array[PlayerShip] = []   # Frota de navios-carta do jogador
var money: int = 0
var ante: int = 1
var round_in_ante: int = 1

# --- Config recalculada a cada rodada ---
var grid_size: int = 6
var target_score: int = 300
var enemy_ship_sizes: Array[int] = [5, 4, 4]

func reset_run() -> void:
	admirals.clear()
	money = 0
	ante = 1
	round_in_ante = 1
	if player_ships.is_empty():
		_build_starting_fleet()
	if nation:
		nation.on_run_start(self)
	run_started.emit()

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

## Recarrega a carga de cada navio da frota (chamado no inicio de cada rodada).
func refill_player_ships() -> void:
	if player_ships.is_empty():
		_build_starting_fleet()
	for ship in player_ships:
		ship.refill()

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
func configure_round() -> void:
	var ante_mult := pow(1.6, ante - 1)
	var round_mult := 1.0 + 0.5 * (round_in_ante - 1)
	target_score = int(300.0 * ante_mult * round_mult)
	grid_size = _grid_for_ante(ante)
	enemy_ship_sizes = _sizes_for_ante(ante)

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
