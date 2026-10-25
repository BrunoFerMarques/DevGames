extends Control
class_name GameOver
## Tela de fim de run: mostra quando os tiros acabam sem bater a meta.
## Reiniciar aqui zera a run inteira (dinheiro, almirantes, ante) - quem faz
## o reset de verdade e' quem escuta o sinal `restart` (Main chama
## Game.reset_run()).

signal restart

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var stats_label: Label = $Panel/VBox/Stats
@onready var restart_btn: Button = $Panel/VBox/Restart

func _ready() -> void:
	restart_btn.pressed.connect(func(): restart.emit())

func open(score: int, target: int) -> void:
	stats_label.text = "Pontuacao final: %d / %d" % [score, target]
	# Entra com "pop" (escurece o fundo, painel cresce passando um pouco do
	# tamanho e assenta) em vez de aparecer seco.
	dim.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2.ONE * 0.85
	var tw := create_tween().set_parallel()
	# Dim pela metade: o mar do naufragio ja e' escuro, e escurecer tudo
	# apagaria o "Rodada perdida" com fogo que fica atras do painel.
	tw.tween_property(dim, "modulate:a", 0.5, 0.3)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
