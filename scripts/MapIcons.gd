extends RefCounted
class_name MapIcons
## Icones desenhados por codigo (a fonte pixel nao tem estrela/coroa) usados
## no mapa de fases, na trilha do HUD e nas estrelas da doca.

static func star(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	# Estrela nascendo (animacao da doca) com raio ~0 vira poligono degenerado.
	if r < 1.0:
		return
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.45
		var ang := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(ang), sin(ang)) * rad)
	ci.draw_colored_polygon(pts, color)

## Fileira de `total` estrelas centrada em `c`, as primeiras `filled` cheias.
static func star_row(ci: CanvasItem, c: Vector2, r: float, filled: int, total: int,
		on: Color, off: Color) -> void:
	var gap := r * 2.3
	var x0 := c.x - gap * (total - 1) / 2.0
	for i in total:
		star(ci, Vector2(x0 + gap * i, c.y), r, on if i < filled else off)

static func crown(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var pts := PackedVector2Array([
		Vector2(-16, 10), Vector2(-18, -10), Vector2(-8, -1),
		Vector2(0, -14), Vector2(8, -1), Vector2(18, -10), Vector2(16, 10),
	])
	for i in pts.size():
		pts[i] = c + pts[i] * s
	ci.draw_colored_polygon(pts, color)

## Bandeira de checkpoint/recorde: mastro + flamula.
static func flag(ci: CanvasItem, base: Vector2, s: float, color: Color, pole: Color) -> void:
	var top := base + Vector2(0, -26) * s
	ci.draw_line(base, top, pole, 3.0 * s, true)
	ci.draw_colored_polygon(PackedVector2Array([
		top, top + Vector2(18, 6) * s, top + Vector2(0, 12) * s,
	]), color)
