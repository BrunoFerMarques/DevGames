extends Control
class_name Board
## Tabuleiro alvo: monta a grade, posiciona a frota inimiga oculta,
## resolve cada tiro (pontuacao chips * mult + combo) e o sonar.

signal score_changed(score: int, target: int)
signal shots_changed(left: int)
signal sonar_changed(left: int)
signal combo_changed(streak: int, combo_mult: int)
signal shot_resolved(info: Dictionary)
signal round_won
signal round_lost

const BASE_HIT_CHIPS := 10
const SINK_BONUS_CHIPS := 50
const CellScene: PackedScene = preload("res://scenes/Cell.tscn")

@onready var grid: GridContainer = $Margin/VBox/Grid

var gsize: int = Game.grid_size
var cells: Dictionary = {}                 # Vector2i -> Cell
var enemy_ships: Array[Dictionary] = []    # { cells: Array[Vector2i], hits: int, size: int }

var score: int = 0
var target: int = 0
var shots_left: int = 0
var sonar_left: int = 0
var streak: int = 0

var _active: bool = false
var _water_count: int = 0

func _ready() -> void:
	Game.configure_round()
	start_round()

func start_round() -> void:
	gsize = Game.grid_size
	target = Game.target_score
	shots_left = Game.shots_for_round()
	sonar_left = Game.sonar_for_round()
	score = 0
	streak = 0
	_water_count = 0
	_active = true
	_build_grid()
	_place_fleet(Game.enemy_ship_sizes)
	score_changed.emit(score, target)
	shots_changed.emit(shots_left)
	sonar_changed.emit(sonar_left)
	combo_changed.emit(streak, _combo_mult())

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
	if not _active or shots_left <= 0:
		return
	var cell: Cell = cells[coord]
	if not cell.is_shootable():
		return

	shots_left -= 1
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
	for sh in Game.fleet:
		sh.on_shot(ctx)

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
	shots_changed.emit(shots_left)
	combo_changed.emit(streak, _combo_mult())
	_check_end()

func _nation_keeps_combo(water_n: int) -> bool:
	if Game.nation and Game.nation.has_method("keeps_combo_on_water"):
		return Game.nation.keeps_combo_on_water(water_n)
	return false

## Sonar de linha (descarte padrao). Nao pontua.
func use_sonar_row(row: int) -> void:
	if not _active or sonar_left <= 0:
		return
	row = clampi(row, 0, gsize - 1)
	sonar_left -= 1
	for x in gsize:
		cells[Vector2i(x, row)].reveal_sonar()
	sonar_changed.emit(sonar_left)

## Sonar 3x3 (usado por nacoes tipo Japao).
func use_sonar_box(center: Vector2i) -> void:
	if not _active or sonar_left <= 0:
		return
	sonar_left -= 1
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var p: Vector2i = center + Vector2i(dx, dy)
			if cells.has(p):
				cells[p].reveal_sonar()
	sonar_changed.emit(sonar_left)

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
	for sh in Game.fleet:
		sh.on_round_end(ctx)
