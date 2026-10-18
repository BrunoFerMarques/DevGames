extends Resource
class_name Effect
## Base para ShipDef (navios-coringa) e NationDef (decks/nacoes).
## Sobrescreve so os hooks que o efeito precisa.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export_multiline var downside: String
@export var portrait: Texture2D = null

## Roda 1x no inicio da run (dar navio extra, mexer na config, etc).
func on_run_start(_game: Node) -> void:
	pass

## Ajusta a contagem de tiros base da rodada.
func modify_shots(n: int) -> int:
	return n

## Ajusta a contagem de cargas de sonar da rodada.
func modify_sonar(n: int) -> int:
	return n

## Ajusta a meta de pontos da rodada (usado por modificadores de boss).
func modify_target(n: int) -> int:
	return n

## Chamado a cada tiro. Muta o ctx (chips, mult, flags).
func on_shot(_ctx: Dictionary) -> void:
	pass

## Chamado ao fim de uma rodada vencida (dinheiro, bonus, etc).
func on_round_end(_ctx: Dictionary) -> void:
	pass

## True se o streak de combo nao deve zerar ao errar na agua.
func keeps_combo_on_water(_water_n: int) -> bool:
	return false

## True se o sonar deste efeito revela area 3x3 em vez da linha inteira.
func sonar_is_box() -> bool:
	return false
