extends Control
class_name Board
## Tabuleiro alvo: monta a grade, posiciona a frota inimiga oculta,
## resolve cada tiro (pontuacao chips * mult + combo) e o sonar.
## Tiros/sonar sao consumidos da carga do PlayerShip selecionado (frota do
## jogador), nao de um pool global solto.
## Regra de logica (batalha naval classica): navios nunca se encostam, nem na
## diagonal. Por isso a diagonal de um acerto e a borda de um afundado viram
## agua deduzida, e cada linha/coluna mostra quantas casas de navio faltam.

signal score_changed(score: int, target: int)
signal shots_changed(left: int)
signal sonar_changed(left: int)
signal combo_changed(streak: int, combo_mult: int)
signal shot_resolved(info: Dictionary)
signal ship_selected(ship: PlayerShip)
signal fleet_changed
## Frota inimiga posicionada ou um navio afundou (lista do HUD).
signal enemy_fleet_changed
signal round_started
signal round_won
signal round_lost

const BASE_HIT_CHIPS := 10
const SINK_BONUS_CHIPS := 50
const BOSS_ADJUST_COST := 5
## Vitoria paga a municao da proxima rodada (tiro custa Shop.SHOT_PRICE).
const ROUND_BASE_REWARD := 8
const SONAR_SPAN := 3   # casas que o sonar base revela na linha clicada
const CellScene: PackedScene = preload("res://scenes/Cell.tscn")
const COORD_COLOR := Color(0.184, 0.749, 0.69, 0.85)   # Sonar, levemente apagado
const SUB_TINT := Color(0.7, 0.92, 0.85)   # segmento de submarino quando aparece
const MINE_SHOT_PENALTY := 1                # tiros extras que a mina tira do navio
const PLACE_TRIES := 50                     # recomecos da frota antes de desistir de um navio
const DIAGONALS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
const COUNT_COLOR := Color("#f3c44b")
const COUNT_DONE := Color(0.6, 0.63, 0.68, 0.45)   # linha/coluna sem navio a achar
# Celula encolhe pra grade caber entre a FleetBar (embaixo) e o Hud (direita).
const CELL_MAX := 56
const CELL_MIN := 32
const COORD_SIZE := 24       # coluna/linha de letras, numeros e contagens
const CELL_GAP := 4          # separacao padrao do GridContainer
const FRAME_PAD := 52        # moldura: 26 de cada lado
const RESERVED_TOP := 24
const RESERVED_BOTTOM := 170 # FleetBar + dica da regra (Hint) embaixo da grade
const RESERVED_SIDE := 340   # Hud (316 + margem); grade centralizada reserva dos dois lados

# Sprites do casco inimigo ja danificado - so aparecem no HIT/SUNK da celula.
const ENEMY_BOW: Texture2D = preload("res://sprites/inimigo/ship_bow_hit.png")
const ENEMY_MID: Texture2D = preload("res://sprites/inimigo/ship_mid_hit.png")
const ENEMY_STERN: Texture2D = preload("res://sprites/inimigo/ship_stern_hit.png")

@onready var grid: GridContainer = $Margin/VBox/GridFrame/GridPanel/Grid

var gsize: int = Game.grid_size
var cells: Dictionary = {}                 # Vector2i -> Cell
var enemy_ships: Array[Dictionary] = []    # { def: EnemyShipDef, cells: Array[Vector2i], hits: int, size: int }

var score: int = 0
var target: int = 0
var shots_left: int = 0    # derivado: soma de charges dos navios SHOT
var sonar_left: int = 0    # derivado: soma de charges dos navios SONAR
var streak: int = 0
var selected_ship: PlayerShip = null
## Animacao do tiro (Main liga). Sem ela o tiro resolve na hora.
var shot_fx: ShotFx = null

var _active: bool = false
var _busy: bool = false              # projetil no ar: ignora cliques
var _round_id: int = 0               # muda a cada start_round (tiro em voo de rodada velha e' descartado)
var _water_count: int = 0
var mines_total: int = 0
var mines_exploded: int = 0
var _round_committed: bool = false   # true apos o 1o tiro/sonar da rodada
var _row_counts: Array[Label] = []
var _col_counts: Array[Label] = []

## Chamado pelo Main quando a loja fecha (inclusive antes da 1a rodada),
## porque os tiros sao comprados antes de cada rodada.
func start_round() -> void:
	gsize = Game.grid_size
	target = Game.target_score
	Game.refill_player_ships()
	score = 0
	streak = 0
	_water_count = 0
	_round_committed = false
	_active = true
	_busy = false
	_round_id += 1
	selected_ship = null
	_build_grid()
	_place_fleet(Game.enemy_fleet)
	_place_mines(Game.mine_count)
	_refresh_line_counts()
	enemy_fleet_changed.emit()
	_recalc_pools()
	score_changed.emit(score, target)
	combo_changed.emit(streak, _combo_mult())
	round_started.emit()
	# Saiu da loja sem comprar tiro: nao ha o que jogar, a rodada acaba.
	if shots_left == 0:
		_check_end.call_deferred()

## Seleciona o navio que vai disparar no proximo clique de celula.
func select_ship(ship: PlayerShip) -> void:
	if not _active or ship == null or not ship.has_charge():
		return
	selected_ship = ship
	ship_selected.emit(selected_ship)

func _build_grid() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	cells.clear()
	_row_counts.clear()
	_col_counts.clear()
	var cs := _cell_size()
	# Letras em cima e numeros na esquerda; na direita e embaixo, quantas casas
	# de navio ainda faltam achar naquela linha/coluna.
	grid.columns = gsize + 2
	grid.add_child(_coord_label(""))
	for x in gsize:
		grid.add_child(_coord_label(char(65 + x)))
	grid.add_child(_coord_label(""))
	for y in gsize:
		grid.add_child(_coord_label(str(y + 1)))
		for x in gsize:
			var cell: Cell = CellScene.instantiate()
			grid.add_child(cell)
			cell.setup(Vector2i(x, y), false)
			# Depois do add_child: o _ready da Cell poe o tamanho maximo.
			cell.custom_minimum_size = Vector2(cs, cs)
			cell.shot_requested.connect(_on_cell_shot)
			cells[Vector2i(x, y)] = cell
		_row_counts.append(_coord_label(""))
		grid.add_child(_row_counts[y])
	grid.add_child(_coord_label(""))
	for x in gsize:
		_col_counts.append(_coord_label(""))
		grid.add_child(_col_counts[x])
	grid.add_child(_coord_label(""))

func _cell_size() -> int:
	var labels := COORD_SIZE * 2 + CELL_GAP * (gsize + 1)
	var avail_h := size.y - RESERVED_TOP - RESERVED_BOTTOM - FRAME_PAD - labels
	var avail_w := size.x - RESERVED_SIDE * 2 - FRAME_PAD - labels
	return clampi(int(minf(avail_h, avail_w) / gsize), CELL_MIN, CELL_MAX)

## Casas de navio ainda nao acertadas por linha/coluna. Submarino nao entra:
## ele escapa do sonar e da contagem (a conta "nao fechar" e' a pista dele).
func _refresh_line_counts() -> void:
	var rows: Array[int] = []
	var cols: Array[int] = []
	rows.resize(gsize)
	cols.resize(gsize)
	for p: Vector2i in cells:
		var c: Cell = cells[p]
		if c.has_ship and not c.sonar_proof and c.state != Cell.State.HIT and c.state != Cell.State.SUNK:
			rows[p.y] += 1
			cols[p.x] += 1
	for i in gsize:
		_set_count(_row_counts[i], rows[i])
		_set_count(_col_counts[i], cols[i])

func _set_count(lbl: Label, n: int) -> void:
	lbl.text = str(n)
	lbl.add_theme_color_override("font_color", COUNT_COLOR if n > 0 else COUNT_DONE)

func _coord_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(24, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", COORD_COLOR)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl

## Navios nunca se encostam, nem na diagonal: cada casa ocupada bloqueia as
## 8 vizinhas. Maiores primeiro, cada um num lugar sorteado entre todos os que
## cabem; se a sorte encurralar os ultimos, recomeca a frota do zero. As
## tabelas do Game sempre cabem - o descarte do menor e' so rede de seguranca.
func _place_fleet(fleet: Array[EnemyShipDef]) -> void:
	enemy_ships.clear()
	var order := fleet.duplicate()
	order.sort_custom(func(a: EnemyShipDef, b: EnemyShipDef) -> bool: return a.size > b.size)
	var layout: Array = []
	while not order.is_empty():
		for i in PLACE_TRIES:
			layout = _try_layout(order)
			if not layout.is_empty():
				break
		if not layout.is_empty():
			break
		push_warning("Frota nao coube sem encostar; removendo %s" % order.back().display_name)
		order.pop_back()
	for entry in layout:
		_put_ship(entry["def"], entry["body"], entry["horiz"])

## Uma tentativa de posicionar a frota inteira; [] se algum navio nao coube.
func _try_layout(order: Array) -> Array:
	var blocked: Dictionary = {}
	var out: Array = []
	for def: EnemyShipDef in order:
		var spots := _free_spots(def.size, blocked)
		if spots.is_empty():
			return []
		var pick: Dictionary = spots.pick_random()
		for p: Vector2i in pick["body"]:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					blocked[p + Vector2i(dx, dy)] = true
		out.append({"def": def, "body": pick["body"], "horiz": pick["horiz"]})
	return out

## Todos os lugares livres pra um navio de `s` casas: { body, horiz }.
func _free_spots(s: int, blocked: Dictionary) -> Array:
	var out: Array = []
	for horiz in ([true] if s == 1 else [true, false]):
		var span_x: int = s if horiz else 1
		var span_y: int = 1 if horiz else s
		for oy in gsize - span_y + 1:
			for ox in gsize - span_x + 1:
				var body: Array[Vector2i] = []
				for i in s:
					var p := Vector2i(ox + (i if horiz else 0), oy + (0 if horiz else i))
					if blocked.has(p):
						break
					body.append(p)
				if body.size() == s:
					out.append({"body": body, "horiz": horiz})
	return out

func _put_ship(def: EnemyShipDef, body: Array[Vector2i], horiz: bool) -> void:
	# Sprites apontam pra direita (popa arredondada na esquerda, proa afilada
	# na direita); 90 graus vira pra baixo. body cresce pra direita/baixo,
	# entao a popa e' o 1o segmento e a proa o ultimo. Bote de 1 casa e' so proa.
	var rot_deg := 0.0 if horiz else 90.0
	for i in body.size():
		var p: Vector2i = body[i]
		cells[p].has_ship = true
		cells[p].armor = def.armor
		cells[p].sonar_proof = def.sonar_proof
		if def.sonar_proof:
			cells[p].ship_tint = SUB_TINT
		var tex: Texture2D = ENEMY_MID
		if i == body.size() - 1:
			tex = ENEMY_BOW
		elif i == 0:
			tex = ENEMY_STERN
		cells[p].set_ship_sprite(tex, rot_deg)
	enemy_ships.append({"def": def, "cells": body, "hits": 0, "size": def.size})

func _touches_ship(p: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := p + Vector2i(dx, dy)
			if cells.has(q) and cells[q].has_ship:
				return true
	return false

## Minas em casas sem navio. Nao contam como navio: so cobram tiro e combo.
## Ficam longe dos navios, senao a agua deduzida em volta deles mentiria;
## colada em navio so se nao sobrar casa longe.
func _place_mines(n: int) -> void:
	mines_total = 0
	mines_exploded = 0
	var free: Array[Vector2i] = []
	var near: Array[Vector2i] = []
	for p in cells.keys():
		if cells[p].has_ship:
			continue
		if _touches_ship(p):
			near.append(p)
		else:
			free.append(p)
	free.shuffle()
	near.shuffle()
	free.append_array(near)
	for i in mini(n, free.size()):
		cells[free[i]].has_mine = true
		mines_total += 1

func is_sunk(ship: Dictionary) -> bool:
	return int(ship["hits"]) >= int(ship["size"])

func _ship_at(coord: Vector2i) -> Dictionary:
	for ship in enemy_ships:
		if coord in ship["cells"]:
			return ship
	return {}

func _combo_mult() -> int:
	return maxi(0, streak - 1)

func _on_cell_shot(coord: Vector2i) -> void:
	if not _active or _busy or selected_ship == null:
		return
	var cell: Cell = cells[coord]
	if not cell.is_shootable():
		return
	_round_committed = true

	var kind: int = selected_ship.kind
	var firing_ship: PlayerShip = selected_ship
	_consume_selected_charge()

	match kind:
		PlayerShip.Kind.SHOT:
			if shot_fx:
				_busy = true
				var round_id := _round_id
				await shot_fx.fire(firing_ship, cell.get_global_rect())
				# Rodada reiniciada durante o voo: celulas ja foram recriadas.
				if round_id != _round_id:
					return
				_busy = false
			_resolve_shot(coord, firing_ship)
		PlayerShip.Kind.SONAR:
			_resolve_sonar(coord)

## Um tiro pode atingir varias casas (salva, torpedo). Cada casa vira um
## "golpe"; a pontuacao junta tudo num ctx so, entao almirantes/boss/nacao
## continuam vendo um tiro por clique (is_hit/sank/chips/mult).
func _resolve_shot(coord: Vector2i, firing_ship: PlayerShip) -> void:
	var piercing := firing_ship.shot_type == PlayerShip.Shot.PIERCING
	var strikes: Array[Dictionary] = []
	for p in _shot_targets(coord, firing_ship.shot_type):
		strikes.append(_strike(p, piercing))
	_score_strikes(coord, strikes, firing_ship)

## Casas atingidas pelo tiro, a partir da casa clicada.
## SALVO: a casa + as 4 vizinhas (so as que ainda da pra atirar).
## TORPEDO: corre pra direita revelando agua ate bater em navio ou mina.
func _shot_targets(coord: Vector2i, shot: PlayerShip.Shot) -> Array[Vector2i]:
	var out: Array[Vector2i] = [coord]
	match shot:
		PlayerShip.Shot.SALVO:
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var p: Vector2i = coord + d
				if cells.has(p) and cells[p].is_shootable():
					out.append(p)
		PlayerShip.Shot.TORPEDO:
			out.clear()
			for x in range(coord.x, gsize):
				var p := Vector2i(x, coord.y)
				var c: Cell = cells[p]
				if not c.is_shootable():
					continue
				out.append(p)
				if c.has_ship or c.has_mine:
					break
	return out

## Aplica o tiro numa casa e diz o que aconteceu. Muda o estado visual na hora.
func _strike(p: Vector2i, piercing: bool) -> Dictionary:
	var cell: Cell = cells[p]
	if cell.has_mine:
		cell.has_mine = false
		mines_exploded += 1
		cell.set_state(Cell.State.MINE)
		return {"coord": p, "mine": true}
	var ship := _ship_at(p)
	if ship.is_empty():
		cell.set_state(Cell.State.WATER)
		return {"coord": p, "water": true}
	# Daqui pra baixo achou navio: a diagonal e' agua garantida.
	_mark_clear_around([p], DIAGONALS)
	if cell.armor > 0 and not piercing:
		cell.armor -= 1
		cell.set_state(Cell.State.ARMORED)
		return {"coord": p, "armor": true}
	cell.armor = 0
	ship["hits"] += 1
	var sank := is_sunk(ship)
	if sank:
		for q in ship["cells"]:
			cells[q].set_state(Cell.State.SUNK)
		# Afundou: a borda inteira do navio e' agua garantida.
		_mark_clear_around(ship["cells"], [
			Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT])
	else:
		cell.set_state(Cell.State.HIT)
	return {"coord": p, "hit": true, "sank": sank, "ship": ship}

## Marca agua deduzida nas casas `offsets` em volta de cada coord.
func _mark_clear_around(coords: Array, offsets: Array) -> void:
	for c: Vector2i in coords:
		for d: Vector2i in offsets:
			if cells.has(c + d):
				cells[c + d].mark_clear()

func _score_strikes(coord: Vector2i, strikes: Array[Dictionary], firing_ship: PlayerShip) -> void:
	var hits := 0
	var armor_blocks := 0
	var mines := 0
	var sunk_ships: Array[Dictionary] = []
	var first_ship: Dictionary = {}
	for s in strikes:
		if s.get("hit", false):
			hits += 1
			if first_ship.is_empty():
				first_ship = s["ship"]
			if s["sank"]:
				sunk_ships.append(s["ship"])
		elif s.get("armor", false):
			armor_blocks += 1
		elif s.get("mine", false):
			mines += 1
	var is_hit := hits > 0
	# Sem acerto, so blindagem/mina: nao conta como agua, nao pontua e nao
	# dispara efeitos de acerto/agua (ex.: almirante que paga tiro na agua).
	var no_score := not is_hit and (armor_blocks > 0 or mines > 0)

	# Mina zera o combo e tira tiro extra do navio que disparou.
	if mines > 0:
		streak = 0
		for i in mines * MINE_SHOT_PENALTY:
			if firing_ship.has_charge():
				firing_ship.charges -= 1
		if selected_ship == firing_ship and not firing_ship.has_charge():
			selected_ship = null
		_recalc_pools()
		enemy_fleet_changed.emit()
	if is_hit:
		streak += 1
	elif not no_score:
		_water_count += 1
		if not _keeps_combo_on_water(_water_count):
			streak = 0

	var base_chips := hits * BASE_HIT_CHIPS
	for ship in sunk_ships:
		base_chips += SINK_BONUS_CHIPS + (ship["def"] as EnemyShipDef).sink_bonus

	var ctx: Dictionary = {
		"coord": coord,
		"is_hit": is_hit,
		"sank": not sunk_ships.is_empty(),
		"ship_size": int(first_ship.get("size", 0)),
		"streak": streak,
		"chips": base_chips,
		"mult": 1 + _combo_mult(),
		"hits": hits,
	}
	if not no_score:
		if Game.boss_modifier:
			Game.boss_modifier.on_shot(ctx)
		firing_ship.apply_shot_upgrade(ctx)
		if Game.nation:
			Game.nation.on_shot(ctx)
		for adm in Game.admirals:
			adm.on_shot(ctx)

	var gained: int = int(floor(float(ctx["chips"]) * float(ctx["mult"])))
	score += gained

	var loot := 0
	for ship in sunk_ships:
		loot += (ship["def"] as EnemyShipDef).loot_money
	if loot > 0:
		Game.add_money(loot)
	if not sunk_ships.is_empty():
		enemy_fleet_changed.emit()

	shot_resolved.emit({
		"coord": coord,
		"gained": gained,
		"chips": int(ctx["chips"]),
		"mult": float(ctx["mult"]),
		"hit": is_hit,
		"sank": not sunk_ships.is_empty(),
		"loot": loot,
		"armor": not is_hit and armor_blocks > 0 and mines == 0,
		"mine": mines > 0,
		"hits": hits,
	})
	_refresh_line_counts()
	score_changed.emit(score, target)
	combo_changed.emit(streak, _combo_mult())
	_check_end()

func _resolve_sonar(coord: Vector2i) -> void:
	if _sonar_is_box():
		use_sonar_box(coord)
	else:
		use_sonar_segment(coord)

func _sonar_is_box() -> bool:
	if Game.nation and Game.nation.sonar_is_box():
		return true
	for adm in Game.admirals:
		if adm.sonar_is_box():
			return true
	return false

func _keeps_combo_on_water(water_n: int) -> bool:
	if Game.nation and Game.nation.keeps_combo_on_water(water_n):
		return true
	for adm in Game.admirals:
		if adm.keeps_combo_on_water(water_n):
			return true
	return false

## Sonar base (descarte padrao): SONAR_SPAN casas na linha clicada, centradas
## no clique; perto da borda desliza pra dentro e continua revelando SONAR_SPAN.
## Era a linha inteira - forte demais (metade do tabuleiro em 3 cargas virava
## acerto garantido alimentando combo). Nao pontua. Reveal puro: quem controla
## carga/ativacao e' _resolve_sonar / _on_cell_shot.
func use_sonar_segment(center: Vector2i) -> void:
	var span := mini(SONAR_SPAN, gsize)
	var start := clampi(center.x - int(span / 2.0), 0, gsize - span)
	for x in range(start, start + span):
		cells[Vector2i(x, center.y)].reveal_sonar()

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

## So termina a rodada quando os tiros acabam - bater a meta nao para na hora,
## deixa o jogador gastar os tiros restantes (pontuar mais / testar upgrades).
func _check_end() -> void:
	if shots_left > 0:
		return
	_active = false
	Game.clear_bought_shots()
	if score >= target:
		_run_round_end_effects()
		round_won.emit()
	else:
		round_lost.emit()

func _run_round_end_effects() -> void:
	var ctx: Dictionary = {"score": score, "target": target, "game": Game}
	var reward := ROUND_BASE_REWARD + int(floor(float(score - target) / 50.0))
	Game.add_money(maxi(reward, 0))
	if Game.nation:
		Game.nation.on_round_end(ctx)
	for adm in Game.admirals:
		adm.on_round_end(ctx)
	# Por ultimo: estrelas, bonus da rota e checkpoint (se era o chefe) ja
	# com todo o dinheiro da vitoria no bolso.
	Game.record_win(score, target)

## Atalho de teste (Main, so em build de debug): bate a meta e encerra a
## rodada como vitoria.
func debug_win() -> void:
	if not _active:
		return
	score = maxi(score, target)
	for ship in Game.player_ships:
		ship.charges = 0
	_recalc_pools()
	score_changed.emit(score, target)
	_check_end()

## Atalho de teste: marca no sonar onde estao os navios, sem gastar carga.
func debug_reveal() -> void:
	for cell: Cell in cells.values():
		cell.reveal_sonar()

func has_commodore_nevoa() -> bool:
	for adm in Game.admirals:
		if adm.id == &"commodore_nevoa":
			return true
	return false

## So pode trocar/remover o desafio antes do 1o tiro/sonar da rodada - depois
## disso a frota ja consumiu carga e recarregar do zero perderia progresso.
func can_adjust_boss() -> bool:
	return _active and not _round_committed and Game.boss_modifier != null and has_commodore_nevoa()

func reroll_boss() -> bool:
	if not can_adjust_boss() or not Game.spend_money(BOSS_ADJUST_COST):
		return false
	Game.reroll_boss()
	target = Game.target_score
	_recalc_pools()
	score_changed.emit(score, target)
	return true

func remove_boss() -> bool:
	if not can_adjust_boss() or not Game.spend_money(BOSS_ADJUST_COST):
		return false
	Game.remove_boss()
	target = Game.target_score
	_recalc_pools()
	score_changed.emit(score, target)
	return true
