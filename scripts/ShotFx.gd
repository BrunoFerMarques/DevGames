extends Control
class_name ShotFx
## Camada de efeito do tiro, por cima do tabuleiro e da frota: a mira trava na
## celula, sai o clarao no card do navio e o projetil voa em arco ate o alvo.
## Board da `await fire(...)` antes de resolver o tiro, entao pontuacao e
## animacao de acerto/agua so acontecem quando o projetil chega.
## Visao de cima: o arco e' fingido - o projetil sobe (desloca pra cima e
## cresce) enquanto a sombra segue reta pelo "chao".

const RETICLE_TEX: Texture2D = preload("res://sprites/tabuleiro/mira.png")
const PROJECTILE_TEX: Texture2D = preload("res://sprites/efeitos/projetil.png")
const FLASH_SHEET: Texture2D = preload("res://sprites/efeitos/clarao_disparo_sheet.png")
const TRAIL_SHEET: Texture2D = preload("res://sprites/efeitos/rastro_sheet.png")

const LOCK_TIME := 0.12      # mira fechando na celula
const FLIGHT_TIME := 0.32    # voo do projetil (tiro inteiro fica < 0.5s)
const TRAIL_EVERY := 0.12    # fracao do voo entre fiapos de rastro
const ARC_PER_PX := 0.25     # altura do arco por pixel de distancia
const ARC_MAX := 120.0

## Origem dos disparos (Main liga). Sem ela o tiro sai de baixo do alvo.
var fleet_bar: FleetBar = null

var _next_trail: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Mira -> clarao -> voo. Retorna quando o projetil atinge `target` (rect global da celula).
func fire(ship: PlayerShip, target: Rect2) -> void:
	var to := _local(target.get_center())
	var from := _local(fleet_bar.muzzle_point(ship)) if fleet_bar else to + Vector2(0, 300)

	var reticle := _new_rect(RETICLE_TEX)
	reticle.size = target.size
	reticle.pivot_offset = target.size / 2.0
	reticle.position = _local(target.position)
	reticle.scale = Vector2.ONE * 1.8
	reticle.modulate.a = 0.0
	var lock := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lock.tween_property(reticle, "scale", Vector2.ONE, LOCK_TIME)
	lock.tween_property(reticle, "modulate:a", 1.0, LOCK_TIME)
	await lock.finished

	_spawn_flash(from, (to - from).angle())
	await _fly(from, to)
	reticle.queue_free()

func _fly(from: Vector2, to: Vector2) -> void:
	var shadow := _new_rect(PROJECTILE_TEX)
	shadow.modulate = Color(0, 0, 0, 0.35)
	var shell := _new_rect(PROJECTILE_TEX)
	var arc := minf(from.distance_to(to) * ARC_PER_PX, ARC_MAX)
	_next_trail = TRAIL_EVERY
	var tw := create_tween()
	tw.tween_method(_fly_step.bind(from, to, arc, shell, shadow), 0.0, 1.0, FLIGHT_TIME)
	await tw.finished
	shell.queue_free()
	shadow.queue_free()

func _fly_step(t: float, from: Vector2, to: Vector2, arc: float, shell: TextureRect, shadow: TextureRect) -> void:
	var ground := from.lerp(to, t)
	var lift := arc * sin(PI * t)
	shadow.position = ground - shadow.pivot_offset
	shadow.rotation = (to - from).angle()
	shell.position = ground - Vector2(0, lift) - shell.pivot_offset
	shell.scale = Vector2.ONE * (1.0 + 0.4 * sin(PI * t))
	# Bico acompanha a curva: sobe no disparo, desce no impacto.
	shell.rotation = ((to - from) - Vector2(0, arc * PI * cos(PI * t))).angle()
	if t >= _next_trail:
		_next_trail += TRAIL_EVERY
		_spawn_trail(ground - Vector2(0, lift))

## Clarao nasce na borda esquerda do quadro, entao o pivo fica nela.
func _spawn_flash(at: Vector2, angle: float) -> void:
	var flash := _new_sheet(FLASH_SHEET, 4, 20.0)
	flash.pivot_offset = Vector2(0, flash.size.y / 2.0)
	flash.position = at - flash.pivot_offset
	flash.rotation = angle
	flash.play()

func _spawn_trail(at: Vector2) -> void:
	var puff := _new_sheet(TRAIL_SHEET, 4, 16.0)
	move_child(puff, 0)   # fumaca fica por baixo do projetil
	puff.position = at - puff.size / 2.0
	puff.play()

func _new_rect(tex: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = tex
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sem isso o tamanho minimo e' o da textura e a mira nao encolhe pra celula.
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(rect)
	rect.size = tex.get_size()
	rect.pivot_offset = rect.size / 2.0
	return rect

## Efeito avulso: toca uma vez e se apaga sozinho.
func _new_sheet(sheet: Texture2D, frames: int, fps: float) -> SpriteSheetPlayer:
	var player := SpriteSheetPlayer.new()
	player.sheet = sheet
	player.frame_count = frames
	player.fps = fps
	player.fill_parent = false
	add_child(player)
	player.size = Vector2.ONE * sheet.get_height()
	player.finished.connect(player.queue_free)
	return player

func _local(global_point: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_point
