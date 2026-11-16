extends RefCounted
class_name DifficultyCatalog
## Niveis de dificuldade (patentes), no estilo das apostas do Balatro: cada
## nivel soma a sua regra a de todos os anteriores. Vencer o chefe do ante
## Game.FINAL_ANTE num nivel libera o seguinte. As regras sao checadas com
## Game.rule(NIVEL) nos lugares que elas mexem (Game, Board, Shop).
## Nao referencia o Game (o Game depende deste script).

const GRUMETE := 1
## A 1a rodada de cada ante nao paga a recompensa base da vitoria.
const NO_FIRST_REWARD := 2
## Meta +TARGET_GROWTH por ante (composto: ante 8 fica ~1.95x).
const TARGET_GROWTH_RULE := 3
## +1 mina em toda rodada (inclusive no ante 1).
const EXTRA_MINE := 4
## -1 uso de sonar por rodada.
const LESS_SONAR := 5
## Blindagem e submarino desde o ante 1, e blindagem mais comum.
const HARD_HULLS := 6
## Meta do chefe x2.5 em vez de x2.
const BOSS_TARGET := 7
## Almirantes e melhorias custam +PRICE_UP.
const PRICEY_SHOP := 8

const TARGET_GROWTH := 0.10
const HARD_ARMOR_CHANCE := 0.5
const BOSS_TARGET_MULT := 2.5
const PRICE_UP := 2

const NAMES: Array[String] = [
	"Grumete", "Marinheiro", "Cabo", "Sargento",
	"Tenente", "Capitão", "Comandante", "Almirante",
]
const RULES: Array[String] = [
	"Sem regras extras: o jogo como ele é.",
	"A 1ª rodada de cada ante não paga a recompensa base.",
	"Metas sobem 10% a mais a cada ante.",
	"+1 mina em toda rodada.",
	"-1 uso de sonar por rodada.",
	"Blindados e submarinos desde o ante 1; blindagem mais comum.",
	"Meta do chefe é x2.5 em vez de x2.",
	"Almirantes e melhorias custam $%d a mais." % PRICE_UP,
]

static func count() -> int:
	return NAMES.size()

static func title(level: int) -> String:
	return "Nível %d · %s" % [level, NAMES[level - 1]]

## Regra propria do nivel; o "+" diz que soma as dos niveis anteriores.
static func rule_text(level: int) -> String:
	if level <= 1:
		return RULES[0]
	return "+ " + RULES[level - 1]
