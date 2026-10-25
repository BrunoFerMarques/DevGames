extends RefCounted
class_name ShotTypeDef
## Armamento vendido na loja: troca o tipo de tiro de UM navio de tiro
## (PlayerShip.shot_type). Comprar outro substitui o anterior.

var id: StringName
var display_name: String
var description: String
var shot: PlayerShip.Shot = PlayerShip.Shot.NORMAL
var price: int = 6

func _init(p_id: StringName, p_name: String, p_desc: String, p_shot: PlayerShip.Shot, p_price: int) -> void:
	id = p_id
	display_name = p_name
	description = p_desc
	shot = p_shot
	price = p_price
