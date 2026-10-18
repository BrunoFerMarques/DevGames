extends Control
class_name GameOver
## Tela de fim de run: mostra quando os tiros acabam sem bater a meta.
## Reiniciar aqui zera a run inteira (dinheiro, almirantes, ante) - quem faz
## o reset de verdade e' quem escuta o sinal `restart` (Main chama
## Game.reset_run()).

signal restart

@onready var stats_label: Label = $Panel/VBox/Stats
@onready var restart_btn: Button = $Panel/VBox/Restart

func _ready() -> void:
	restart_btn.pressed.connect(func(): restart.emit())

func open(score: int, target: int, ante: int, round_in_ante: int) -> void:
	stats_label.text = "Pontuacao final: %d / %d\nAnte %d, rodada %d" % [
		score, target, ante, round_in_ante]
