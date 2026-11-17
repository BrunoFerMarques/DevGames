extends Control
class_name Victory
## Tela de vitoria: aparece ao vencer o chefe do Game.FINAL_ANTE. Mostra o
## nivel de dificuldade vencido e o nivel liberado (se liberou). Dali a run
## pode seguir sem fim (`continue_run`) ou voltar pro menu (`to_menu`; o
## checkpoint do ante seguinte ja foi salvo, entao da pra continuar depois).

signal continue_run
signal to_menu

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Panel
@onready var stats_label: Label = $Panel/VBox/Stats
@onready var unlock_label: Label = $Panel/VBox/Unlock
@onready var continue_btn: Button = $Panel/VBox/Continue
@onready var menu_btn: Button = $Panel/VBox/Menu

func _ready() -> void:
	continue_btn.pressed.connect(func(): continue_run.emit())
	menu_btn.pressed.connect(func(): to_menu.emit())

func open() -> void:
	visible = true
	stats_label.text = "Chefe do Setor %d vencido!
%s" % [
		Game.FINAL_ANTE, DifficultyCatalog.title(Game.difficulty)]
	unlock_label.visible = Game.unlocked_now
	if Game.unlocked_now:
		var next := Game.unlocked_difficulty
		unlock_label.text = "%s liberado!\n%s" % [
			DifficultyCatalog.title(next), DifficultyCatalog.RULES[next - 1]]
	elif Game.difficulty >= DifficultyCatalog.count():
		unlock_label.visible = true
		unlock_label.text = "Último nível vencido. Lenda dos sete mares!"
	# Entra com "pop", igual ao fim de jogo.
	dim.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2.ONE * 0.85
	var tw := create_tween().set_parallel()
	tw.tween_property(dim, "modulate:a", 1.0, 0.3)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	continue_btn.grab_focus()
