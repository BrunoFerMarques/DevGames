# Frota do Jogador (navios-carta + Almirante) — Design

Data: 2026-09-17
Engine: Godot 4.7

## Contexto

O design original (`2026-09-01-batalha-naval-balatro-design.md`) tratava
"navio-coringa" como o equivalente do joker do Balatro: efeito passivo
comprado na loja, sem representação visual, modificando um pool global de
tiros/sonar (`Game.shots_for_round()` / `Game.sonar_for_round()`).

Essa sessão muda o mapeamento:

- **Navio** = carta da mão do Balatro. Objeto concreto, visível, com carga
  própria (tiros ou usos de sonar). O jogador seleciona um navio e usa a
  habilidade dele clicando no tabuleiro alvo.
- **Almirante** = o coringa de fato. Efeito passivo/ativo comprado na loja
  (o que antes se chamava `ShipDef`/`Game.fleet` no design antigo).

Motivação do jogador: cada navio ter carga própria (em vez de um pool global
único) abre espaço pra depois cada navio carregar bônus próprio de
chips/mult quando dispara — igual carta com enhancement no Balatro — sem
precisar remodelar a arquitetura de novo.

## Frota inicial (MVP, fixa — sem loja ainda)

| Navio          | Sprites (sprites/)      | Tipo  | Cargas |
|----------------|--------------------------|-------|--------|
| Encouraçado    | bow + mid + stern        | SHOT  | 4      |
| Destroyer A    | bow + stern              | SHOT  | 2      |
| Destroyer B    | bow + stern              | SHOT  | 2      |
| Navio-sonar    | sonar                    | SONAR | 3      |

Soma bate com os valores atuais de `base_shots = 8` e `base_sonar = 3`.

## Modelo de dados

`scripts/PlayerShip.gd` — `extends Resource`, `class_name PlayerShip`:
- `id: StringName`, `display_name: String`
- `kind: enum { SHOT, SONAR }`
- `segments: Array[Texture2D]` (sprites que compõem o navio, em ordem)
- `max_charges: int`, `charges: int` (atual)

Sem campos de bônus por disparo ainda (YAGNI) — estrutura já comporta
adicionar depois.

`Game.gd`:
- Renomeia `fleet` -> `admirals` (Array de `Effect`, os coringas de verdade).
- Novo `player_ships: Array[PlayerShip]`, montado uma vez com a frota fixa
  acima (fábrica interna, sem `.tres` no editor por enquanto).
- Novo `refill_player_ships()`: reseta `charges = max_charges` em cada navio.
  Chamado por `Board.start_round()`, mesmo momento que hoje recalcula
  `shots_for_round()`.

## Board — seleção e disparo

`Board.gd`:
- `var selected_ship: PlayerShip = null`
- `signal ship_selected(ship)`, `signal fleet_changed`
- `select_ship(ship)`: só aceita se `ship.charges > 0`; emite `ship_selected`.
- `_on_cell_shot(coord)` passa a checar `selected_ship` antes de agir:
  - nulo -> ignora o clique.
  - `SHOT` -> fluxo de tiro atual (chips/mult/streak), decrementa
    `selected_ship.charges`.
  - `SONAR` -> chama `use_sonar_row`/`use_sonar_box` (linha/3x3 da célula
    clicada, mesma regra de nação que hoje), decrementa `selected_ship.charges`.
- `charges` chega a 0 -> `fleet_changed` emitido; se era o selecionado,
  `selected_ship = null`.
- `shots_left` / `sonar_left` continuam existindo como valores **derivados**
  (soma de `charges` por `kind`), recalculados a cada disparo. Sinais
  (`shots_changed`, `sonar_changed`) continuam disparando igual — `Main.gd`
  não precisa saber da mudança interna.
- Fim de rodada: perde quando soma de cargas `SHOT` chega a 0 (equivalente
  exato à regra atual `shots_left <= 0`).

## UI — FleetBar

Cena nova `scenes/FleetBar.tscn` + `scripts/FleetBar.gd`: HBoxContainer com
um card por navio de `Game.player_ships`. Cada card monta o sprite
concatenando `segments` (HBoxContainer de `TextureRect`, 64x64 cada) +
label de carga restante, borda dourada quando selecionado (mesma cor da
moldura do tabuleiro), acinzentado/desabilitado quando `charges == 0`.

Clique no card chama `board.select_ship(ship)`. Ouve `board.fleet_changed`
e `board.ship_selected` pra atualizar visual.

Instanciado em `Main.tscn`. Remove o `SonarBox` (SpinBox + botão Fire) —
sonar agora é só selecionar o navio-sonar e clicar a célula alvo no
tabuleiro, mesma interação de atirar.

## Fora de escopo (não faz agora)

- Loja / compra de Almirante ou navio novo.
- Bônus de chips/mult por navio.
- Persistência de frota entre rodadas além do reset de carga (frota fixa,
  4 navios sempre os mesmos por enquanto).
