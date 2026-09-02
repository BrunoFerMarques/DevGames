# Batalha Naval — Design

Data: 2026-09-01
Engine: Godot 4.7 (GL Compatibility, 2D)

## Visão

Roguelike de tiro em tabuleiro. Sem IA inimiga. O jogador atira em navios
escondidos num tabuleiro procedural, precisa bater uma meta de pontos por
rodada, e entre rodadas evolui a frota comprando "navios-coringa" numa loja.
Estrutura de progressão inspirada em Balatro (antes, blinds, loja, boss).

## Loop central (uma rodada)

1. Tabuleiro gerado: grade (8x8 no ante 1), navios inimigos posição aleatória.
2. Jogador tem **tiros limitados** (equivale às "mãos" do Balatro).
3. Jogador tem **cargas de sonar limitadas** (equivale aos "descartes").
   Sonar revela uma linha (ou 3x3 em algumas nações). Não pontua, só informação.
4. Cada clique numa célula = um tiro. Resolve na hora.
5. Bateu a meta de pontos -> rodada vencida -> loja.
6. Acabaram os tiros sem bater a meta -> rodada perdida -> fim da run.

## Pontuação

Cada tiro resolve individualmente:

```
pontos_do_tiro = chips * mult

chips = BASE_HIT (10)  + SINK_BONUS (50, se esse tiro afundou o navio)
        (água = 0 chips)

mult  = 1
      + mult_combo   (acertos seguidos: streak 2 => +1, streak 3 => +2, ...;
                      água zera o streak, salvo efeito de nação)
      + mult_efeitos (passivos de navios e da nação)
```

Água zera o combo e vale 0. Meta da rodada = soma dos pontos de todos os tiros.

Números iniciais para balancear depois:
- `BASE_HIT_CHIPS = 10`
- `SINK_BONUS_CHIPS = 50`
- Meta ante 1 rodada 1 = 300; escala `300 * 1.6^(ante-1) * (1 + 0.5*(rodada-1))`

## Economia

Dinheiro no fim da rodada vencida (proposto, ajustar):
- +1 por tiro não usado
- + bônus por navio afundado
- + efeitos de navios ("tesoureiro": +X fixo) e nações (China: +25%)

Gasto na loja: comprar navios-coringa e upgrades.

## Estrutura da run


| Setor / oceano. Dificuldade sobe a cada um.                |
| 3 rodadas por ante. A 3ª é rodada-boss com modificador.    |
| Meta de pontos no tabuleiro.                               |
| Tiros por rodada.                                          |
| Cargas de sonar por rodada.                                |
| Entre rodadas: navios-coringa + upgrades.                  |
| Regra chata: névoa, navios blindados, grade maior, etc.    |

### Curva de dificuldade (grade + frota por ante)

Antes iniciais: grade pequena + navios grandes (alvo denso, fácil acertar).
Depois: grade cresce, navios encolhem e se multiplicam.

| Ante | Grade | Navios inimigos      | Densidade |
|------|-------|----------------------|-----------|
| 1    | 6x6   | [5, 4, 4]            | ~36%      |
| 2    | 7x7   | [5, 4, 3, 3]         | ~31%      |
| 3    | 8x8   | [4, 3, 3, 3, 2]      | ~23%      |
| 4    | 9x9   | [4, 3, 2, 2, 2]      | ~16%      |
| 5+   | 10x10 | [3, 3, 2, 2, 2, 2]   | ~14%      |

Em `Game.gd`: `_grid_for_ante(a)` e `_sizes_for_ante(a)`, aplicados em
`configure_round()`. `GRID_SIZE = 10` é o teto (layout). Números pra balancear.

## Navios-coringa

Coringas passivos/ativos. Cada um é um `ShipDef` (Resource) que herda de
`Effect` e sobrescreve hooks. Exemplos:

- **Porta-aviões**: +4 tiros base.
- **Fragata sonar**: +1 carga de sonar.
- **Tesoureiro**: +N dinheiro no fim da rodada.
- **Encouraçado**: +2 mult sempre.
- **Franco-atirador**: +3 mult em acerto feito sem ter usado sonar na linha.
- **Contra-torpedeiro**: x2 no bônus de afundar.

(Lista final e balanceamento vêm na fase de conteúdo.)

## Nações (decks)

Modificador inicial escolhido antes da run, na tela `NationSelect`. É um
`NationDef` (Resource) que também herda de `Effect`. Roda `on_run_start(game)`
uma vez e participa dos mesmos cálculos de tiro/sonar que os navios.

| Nação        | Efeito                                   | Custo                 |
|--------------|------------------------------------------|-----------------------|
| EUA          | +2 tiros base                            | -1 carga de sonar     |
| França       | Começa com 1 navio-coringa extra aleat.  | —                     |
| China        | +25% dinheiro toda rodada                | —                     |
| Japão        | Sonar revela 3x3 em vez de linha         | -1 carga de sonar     |
| Reino Unido  | 1ª água da rodada não zera o combo       | —                     |
| Alemanha     | mult_base = 2                            | meta de pontos +20%   |
| URSS         | Acerto causa dano dobrado (afunda antes) | -2 tiros base         |

Sabor primeiro, balanceamento depois.

## Arquitetura Godot

**Autoload**
- `Game.gd` (as `Game`) — estado da run: `nation`, `fleet`, `money`, `ante`,
  `round_in_ante`, e a config recalculada por rodada (`target_score`,
  `base_shots`, `base_sonar`, `enemy_ship_sizes`).

**Classe base de efeito**
- `Effect.gd` (`class_name Effect`, extends Resource) — hooks virtuais:
  `on_run_start(game)`, `modify_shots(n)`, `modify_sonar(n)`, `on_shot(ctx)`,
  `on_round_end(ctx)`. `ShipDef` e `NationDef` herdam disto.

**Cenas**
| Cena              | Papel                                                          |
|-------------------|---------------------------------------------------------------|
| `Main.tscn`       | Raiz. Máquina de estado entre telas.                          |
| `NationSelect`    | Escolha de nação antes da run. (fase 2)                       |
| `Board.tscn`      | Grade de células, frota inimiga oculta, resolução de tiro +   |
|                   | pontuação, sonar. Emite `round_won` / `round_lost`.           |
| `Cell.tscn`       | Botão. Estados: oculto / água / acerto / afundado / sonar.    |
| `RoundHUD.tscn`   | Placar, meta, tiros, sonar, combo/mult. (fase 2, hoje inline) |
| `Shop.tscn`       | Comprar navios/upgrades. (fase 2)                             |
| `ShipCard.tscn`   | Exibe um coringa. (fase 2)                                    |

**Fluxo do ctx de tiro**: `Board` monta um `Dictionary` com
`coord/is_hit/sank/ship_size/streak/chips/mult`, passa por `Game.nation.on_shot`
e depois por cada `ship.on_shot` da frota, e finaliza `pontos = chips * mult`.

## Ordem de implementação

1. `Game` autoload — esqueleto do estado. **(feito no scaffold)**
2. `Effect` base. **(feito no scaffold)**
3. `Cell.tscn` + script — estados visuais, emite `shot_requested`. **(feito)**
4. `Board.tscn` — grade, frota, resolução de tiro, sonar. **(feito)**
5. `Main.tscn` mínimo jogável — labels de placar/tiros/sonar + sonar de linha.
   **(feito no scaffold, versão debug)**
6. `ScoreEngine` isolado + teste (GUT) — extrair a fórmula do `Board`.
7. `RoundHUD` de verdade (popups de pontuação, animação de mult).
8. `ShipDef` + 3-4 navios iniciais ligados ao `ctx`.
9. `Shop.tscn` + economia.
10. `NationDef` + `NationSelect.tscn`.
11. Modificadores de ante/boss.
12. Save / meta-progressão (unlocks).

## Pendências / decisões abertas

- Sonar revela células exatas do navio na linha, ou só "há navio na linha"?
  Scaffold revela exato (`SONAR_SHIP`). Nerfar depois se ficar fácil demais.
- Fonte de dinheiro (fórmula exata).
- Meta-progressão: roguelike puro primeiro; unlocks depois.
- Curva grade/frota definida (ver tabela acima); falta balancear números.

## MVP (fatia vertical)

Uma rodada jogável de ponta a ponta: tabuleiro 6x6 (ante 1), navios [5,4,4],
tiros e sonar limitados, pontuação `chips * mult + combo`, telas de
vitória/derrota. Sem loja, sem antes, sem nações. É o que o scaffold entrega.
