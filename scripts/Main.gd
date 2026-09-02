extends Control
## Casca minima jogavel: instancia o Board e mostra placar/tiros/sonar/combo
## num painel de debug. HUD de verdade + loja + antes vem nas fases seguintes.

@onready var board: Board = $Board
@onready var info: Label = $Panel/VBox/Info
@onready var result: Label = $Panel/VBox/Result
@onready var sonar_row: SpinBox = $Panel/VBox/SonarBox/Row
@onready var sonar_fire: Button = $Panel/VBox/SonarBox/Fire
@onready var restart_btn: Button = $Panel/VBox/Restart

func _ready() -> void:
	board.score_changed.connect(func(_s, _t): _refresh())
	board.shots_changed.connect(func(_l): _refresh())
	board.sonar_changed.connect(func(_l): _refresh())
	board.combo_changed.connect(func(_s, _m): _refresh())
	board.shot_resolved.connect(_on_shot)
	board.round_won.connect(func(): result.text = "RODADA VENCIDA")
	board.round_lost.connect(func(): result.text = "RODADA PERDIDA - sem tiros")

	sonar_row.min_value = 0
	sonar_row.max_value = board.gsize - 1
	sonar_row.step = 1
	sonar_fire.pressed.connect(func(): board.use_sonar_row(int(sonar_row.value)))
	restart_btn.pressed.connect(_on_restart)
	_refresh()

func _on_restart() -> void:
	result.text = ""
	Game.configure_round()
	board.start_round()
	sonar_row.max_value = board.gsize - 1
	_refresh()

func _refresh() -> void:
	info.text = "Pontos %d / %d\nTiros %d   Sonar %d\nCombo x%d (mult +%d)" % [
		board.score, board.target, board.shots_left, board.sonar_left,
		board.streak, maxi(0, board.streak - 1),
	]

func _on_shot(d: Dictionary) -> void:
	if d["hit"]:
		var extra: String = "  AFUNDOU!" if d["sank"] else ""
		result.text = "+%d  =  %d chips  x%d%s" % [d["gained"], d["chips"], d["mult"], extra]
	else:
		result.text = "agua - combo zerado"
