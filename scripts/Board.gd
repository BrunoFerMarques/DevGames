extends Control
class_name Board
## Tabuleiro alvo: monta a grade, posiciona a frota inimiga oculta,
## resolve cada tiro (pontuacao chips * mult + combo) e o sonar.
## Tiros/sonar sao consumidos da carga do PlayerShip selecionado (frota do
## jogador), nao de um pool global solto.

signal score_changed(score: int, target: int)
signal shots_changed(left: int)
signal sonar_changed(left: int)
signal combo_changed(streak: int, combo_mult: int)
signal shot_resolved(info: Dictionary)
signal ship_selected(ship: PlayerShip)
signal fleet_changed
signal round_won
signal round_lost

const BASE_HIT_CHIPS := 10
const SINK_BONUS_CHIPS := 50
const CellScene: PackedScene = preload("res://scenes/Cell.tscn")

@onready var grid: GridContainer = $Margin/VBox/GridFrame/GridPanel/Grid

var gsize: int = Game.grid_size
var cells: Dictionary = {}                 # Vector2i -> Cell
var enemy_ships: Array[Dictionary] = []    # { cells: Array[Vector2i], hits: int, size: int }

var score: int = 0
var target: int = 0
var shots_left: int = 0    # derivado: soma de charges dos navios SHOT
var sonar_left: int = 0    # derivado: soma de charges dos navios SONAR
var streak: int = 0
var selected_ship: PlayerShip = null

var _active: bool = false
var _water_count: int = 0

func _ready() -> void:
	Game.configure_round()
	start_round()

func start_round() -> void:
	gsize = Game.grid_size
	target = Game.target_score
	Game.refill_player_ships()
	score = 0
	streak = 0
	_water_count = 0
	_active = true
	selected_ship = null
	_build_grid()
	_place_fleet(Game.enemy_ship_sizes)
	_recalc_pools()
	score_changed.emit(score, target)
	combo_changed.emit(streak, _combo_mult())

## Seleciona o navio que vai disparar no proximo clique de celula.
func select_ship(ship: PlayerShip) -> void:
	if not _active or ship == null or not ship.has_charge():
		return
	selected_ship = ship
	ship_selected.emit(selected_ship)

func _build_grid() -> void:
	for c in cells.values():
		c.queue_free()
	cells.clear()
	grid.columns = gsize
	for y in gsize:
		for x in gsize:
			var cell: Cell = CellScene.instantiate()
			grid.add_child(cell)
			cell.setup(Vector2i(x, y), false)
			cell.shot_requested.connect(_on_cell_shot)
			cells[Vector2i(x, y)] = cell

func _place_fleet(sizes: Array) -> void:
	enemy_ships.clear()
	var occupied: Dictionary = {}
	for s in sizes:
		var attempts := 0
		while attempts < 500:
			attempts += 1
			var horiz := randi() % 2 == 0
			var span_x: int = s if horiz else 1
			var span_y: int = 1 if horiz else s
			var ox := randi() % (gsize - span_x + 1)
			var oy := randi() % (gsize - span_y + 1)
			var body: Array[Vector2i] = []
			for i in s:
				body.append(Vector2i(ox + (i if horiz else 0), oy + (0 if horiz else i)))
			var clash := false
			for p in body:
				if occupied.has(p):
					clash = true
					break
			if clash:
				continue
			for p in body:
				occupied[p] = true
				cells[p].has_ship = true
			enemy_ships.append({"cells": body, "hits": 0, "size": int(s)})
			break

func _ship_at(coord: Vector2i) -> Dictionary:
	for ship in enemy_ships:
		if coord in ship["cells"]:
			return ship
	return {}

func _combo_mult() -> int:
	return maxi(0, streak - 1)

func _on_cell_shot(coord: Vector2i) -> void:
	if not _active or selected_ship == null:
		return
	var cell: Cell = cells[coord]
	if not cell.is_shootable():
		return

	var kind: int = selected_ship.kind
	_consume_selected_charge()

	match kind:
		PlayerShip.Kind.SHOT:
			_resolve_shot(coord, cell)
		PlayerShip.Kind.SONAR:
			_resolve_sonar(coord)

func _resolve_shot(coord: Vector2i, cell: Cell) -> void:
	var ship := _ship_at(coord)
	var is_hit := not ship.is_empty()
	var sank := false

	if is_hit:
		ship["hits"] += 1
		sank = ship["hits"] >= ship["size"]
		streak += 1
	else:
		_water_count += 1
		if not _nation_keeps_combo(_water_count):
			streak = 0

	var base_chips := 0
	if is_hit:
		base_chips = BASE_HIT_CHIPS + (SINK_BONUS_CHIPS if sank else 0)

	var ctx: Dictionary = {
		"coord": coord,
		"is_hit": is_hit,
		"sank": sank,
		"ship_size": int(ship.get("size", 0)),
		"streak": streak,
		"chips": base_chips,
		"mult": 1 + _combo_mult(),
	}
	if Game.nation:
		Game.nation.on_shot(ctx)
	for adm in Game.admirals:
		adm.on_shot(ctx)

	var gained: int = int(ctx["chips"]) * int(ctx["mult"])
	score += gained

	if is_hit and sank:
		for p in ship["cells"]:
			cells[p].set_state(Cell.State.SUNK)
	elif is_hit:
		cell.set_state(Cell.State.HIT)
	else:
		cell.set_state(Cell.State.WATER)

	shot_resolved.emit({
		"coord": coord,
		"gained": gained,
		"chips": int(ctx["chips"]),
		"mult": int(ctx["mult"]),
		"hit": is_hit,
		"sank": sank,
	})
	score_changed.emit(score, target)
	combo_changed.emit(streak, _combo_mult())
	_check_end()

func _resolve_sonar(coord: Vector2i) -> void:
	use_sonar_row(coord.y)

func _nation_keeps_combo(water_n: int) -> bool:
	if Game.nation and Game.nation.has_method("keeps_combo_on_water"):
		return Game.nation.keeps_combo_on_water(water_n)
	return false

## Sonar de linha (descarte padrao). Nao pontua. Reveal puro: quem controla
## carga/ativacao e' _resolve_sonar / _on_cell_shot.
func use_sonar_row(row: int) -> void:
	row = clampi(row, 0, gsize - 1)
	for x in gsize:
		cells[Vector2i(x, row)].reveal_sonar()

## Sonar 3x3 (usado por nacoes tipo Japao).
func use_sonar_box(center: Vector2i) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var p: Vector2i = center + Vector2i(dx, dy)
			if cells.has(p):
				cells[p].reveal_sonar()

## Consome 1 carga do navio selecionado e recalcula os pools derivados.
func _consume_selected_charge() -> void:
	selected_ship.charges -= 1
	if not selected_ship.has_charge():
		selected_ship = null
	_recalc_pools()

## Recalcula shots_left/sonar_left a partir da carga de cada navio da frota.
func _recalc_pools() -> void:
	var shots := 0
	var sonar := 0
	for ship in Game.player_ships:
		if ship.kind == PlayerShip.Kind.SHOT:
			shots += ship.charges
		else:
			sonar += ship.charges
	shots_left = shots
	sonar_left = sonar
	shots_changed.emit(shots_left)
	sonar_changed.emit(sonar_left)
	fleet_changed.emit()

func _check_end() -> void:
	if score >= target:
		_active = false
		_run_round_end_effects()
		round_won.emit()
	elif shots_left <= 0:
		_active = false
		round_lost.emit()

func _run_round_end_effects() -> void:
	var ctx: Dictionary = {"score": score, "target": target, "game": Game}
	if Game.nation:
		Game.nation.on_round_end(ctx)
	for adm in Game.admirals:
		adm.on_round_end(ctx)
