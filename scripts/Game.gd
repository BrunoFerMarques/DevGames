extends Node
## Estado da run inteira. Autoload "Game".
## Mantido SEM dependencia de tipo de outros scripts (class_name) para o
## singleton sempre carregar. nation/fleet guardam Effect, mas em duck-typing.

signal money_changed(total: int)
signal run_started

const GRID_SIZE := 10        ## tamanho maximo (layout/camera). Atual = grid_size.

var nation = null            # Effect ou null
var fleet: Array = []        # Array de Effect
var money: int = 0
var ante: int = 1
var round_in_ante: int = 1

# --- Config recalculada a cada rodada ---
var grid_size: int = 6
var target_score: int = 300
var base_shots: int = 8
var base_sonar: int = 3
var enemy_ship_sizes: Array[int] = [5, 4, 4]

func reset_run() -> void:
	fleet.clear()
	money = 0
	ante = 1
	round_in_ante = 1
	if nation:
		nation.on_run_start(self)
	run_started.emit()

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)

## Tiros efetivos da rodada = base + nacao + navios.
func shots_for_round() -> int:
	var n := base_shots
	if nation:
		n = nation.modify_shots(n)
	for ship in fleet:
		n = ship.modify_shots(n)
	return maxi(n, 1)

## Cargas de sonar da rodada = base + nacao + navios.
func sonar_for_round() -> int:
	var n := base_sonar
	if nation:
		n = nation.modify_sonar(n)
	for ship in fleet:
		n = ship.modify_sonar(n)
	return maxi(n, 0)

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
