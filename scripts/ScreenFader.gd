extends ColorRect
class_name ScreenFader
## Cortina pra trocar de tela sem corte seco: escurece pro azul-marinho,
## roda a troca com a tela coberta e clareia. Fica por cima de tudo no Main
## e so bloqueia clique enquanto anima.

const FADE_TIME := 0.25

var _busy: bool = false

func _ready() -> void:
	color = Color("#0a1b33")
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Escurece, chama `change` com a tela coberta e clareia de novo.
func swap(change: Callable) -> void:
	# Troca pedida no meio de outra (ex.: pulou a doca enquanto clareava) espera a vez.
	while _busy:
		await get_tree().process_frame
	_busy = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade_to(1.0)
	change.call()
	await _fade_to(0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func _fade_to(alpha: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "modulate:a", alpha, FADE_TIME)
	await tw.finished
