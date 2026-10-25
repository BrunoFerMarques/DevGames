extends TextureRect
class_name SpriteSheetPlayer
## Toca uma folha de sprites horizontal (frames lado a lado) como
## animacao simples dentro da arvore de Control, sem AnimatedSprite2D.

signal finished

@export var sheet: Texture2D
@export var frame_count: int = 1
## Largura de cada quadro; 0 = quadro quadrado (lado = altura da folha).
@export var frame_width: int = 0
@export var fps: float = 10.0
@export var loop: bool = false
## Estica pra ocupar o pai (celulas). Desligue pra posicionar a mao na cena.
@export var fill_parent: bool = true

var _frames: Array[AtlasTexture] = []
var _frame_i: int = 0
var _timer: Timer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if fill_parent:
		set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_frames()
	_timer = Timer.new()
	_timer.wait_time = 1.0 / maxf(fps, 1.0)
	_timer.timeout.connect(_advance)
	add_child(_timer)

func _build_frames() -> void:
	_frames.clear()
	if sheet == null or frame_count <= 0:
		return
	var fh: float = sheet.get_height()
	var fw: float = frame_width if frame_width > 0 else fh
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * fw, 0, fw, fh)
		_frames.append(atlas)

func play() -> void:
	if _frames.is_empty():
		return
	_frame_i = 0
	texture = _frames[0]
	visible = true
	_timer.start()

func stop() -> void:
	_timer.stop()
	visible = false

func _advance() -> void:
	_frame_i += 1
	if _frame_i >= _frames.size():
		if loop:
			_frame_i = 0
		else:
			_timer.stop()
			visible = false
			finished.emit()
			return
	texture = _frames[_frame_i]
