extends Node
## Audio do jogo (autoload "Sfx"): efeitos num pool de players e musica com
## troca suave (crossfade) entre duas faixas. Sons em audio/sfx/<nome>.wav e
## musicas em audio/music/<nome>.wav (8-bit, sintetizados por um script
## Python local que fica fora do git).
## Liga/desliga fica no Game (music_on/sfx_on, salvos com as opcoes) e vira
## mudo nos buses "Musica" e "Efeitos". O Game nao conhece o Sfx: quem chama
## sao as telas (Board, ShotFx, Shop, Main...).
## Todo botao do jogo faz "click" sozinho (menos as casas do tabuleiro, que
## ja tem o tiro/sonar).

const SFX_DIR := "res://audio/sfx/%s.wav"
const MUSIC_DIR := "res://audio/music/%s.wav"
const BUS_MUSIC := &"Musica"
const BUS_SFX := &"Efeitos"
const POOL_SIZE := 12
const MUSIC_DB := -10.0
const SILENT_DB := -60.0
const FADE_TIME := 0.9
## Volume de cada efeito (dB): os de onda quadrada soam mais alto que as
## explosoes de ruido com o mesmo pico, entao descem mais.
const VOLUME := {
	&"click": -13.0, &"lock": -11.0, &"cannon": 0.0, &"splash": 0.0,
	&"hit": 0.0, &"sink": 0.0, &"armor": -1.0, &"mine": 0.0,
	&"sonar": -7.0, &"coin": -10.0, &"buy": -8.0, &"sell": -8.0,
	&"load": -6.0, &"reroll": -9.0, &"shield": -5.0, &"horn": -5.0,
	&"win": -5.0, &"lose": -4.0, &"gameover": -3.0,
}
## Acerto sobe de tom a cada casa do combo (ate COMBO_PITCH_MAX passos).
const COMBO_PITCH_STEP := 0.05
const COMBO_PITCH_MAX := 10
const LOOT_DELAY := 0.2

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: Array[AudioStreamPlayer] = []
var _music_idx := 0
var _music_name: StringName = &""
var _music_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus(BUS_MUSIC)
	_make_bus(BUS_SFX)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = BUS_MUSIC
		m.volume_db = SILENT_DB
		add_child(m)
		_music.append(m)
	Game.audio_changed.connect(_apply_mutes)
	_apply_mutes()
	get_tree().node_added.connect(_on_node_added)
	_hook_existing(get_tree().root)

## Toca o efeito `sfx_name` (pitch 1 = normal).
func play(sfx_name: StringName, pitch: float = 1.0) -> void:
	var stream: AudioStream = _load(SFX_DIR % sfx_name)
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = VOLUME.get(sfx_name, 0.0)
	p.play()

func play_later(sfx_name: StringName, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(play.bind(sfx_name))

## Som do resultado de um tiro (Board.shot_resolved). `streak` e' o combo
## depois do tiro: o acerto sobe de tom junto com ele.
func shot_result(d: Dictionary, streak: int) -> void:
	if d.get("mine", false):
		play(&"mine")
	elif d.get("armor", false):
		play(&"armor")
	elif d.get("sank", false):
		play(&"sink")
	elif d.get("hit", false):
		play(&"hit", 1.0 + COMBO_PITCH_STEP * clampi(streak - 1, 0, COMBO_PITCH_MAX))
	else:
		play(&"splash")
		if d.get("shielded", false):
			play(&"shield")
	if int(d.get("loot", 0)) > 0:
		play_later(&"coin", LOOT_DELAY)

## Troca a musica com crossfade; a mesma que ja toca segue sem reiniciar.
func play_music(music_name: StringName) -> void:
	if music_name == _music_name:
		return
	var stream := _load_music(music_name)
	if stream == null:
		return
	_music_name = music_name
	var old := _music[_music_idx]
	_music_idx = 1 - _music_idx
	var new := _music[_music_idx]
	new.stream = stream
	new.volume_db = SILENT_DB
	new.play()
	_fade(old, new)

func stop_music() -> void:
	_music_name = &""
	_fade(_music[_music_idx], null)

func _fade(out_player: AudioStreamPlayer, in_player: AudioStreamPlayer) -> void:
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel()
	if out_player.playing:
		_music_tween.tween_property(out_player, "volume_db", SILENT_DB, FADE_TIME)
		_music_tween.chain().tween_callback(func():
			if out_player != _music[_music_idx] or _music_name == &"":
				out_player.stop()
		)
	if in_player:
		_music_tween.tween_property(in_player, "volume_db", MUSIC_DB, FADE_TIME)

func _load(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]

## Musica em loop: o .wav e' feito pra emendar o fim no comeco e o loop vem
## do import (edit/loop_mode=2 em audio/music/*.wav.import).
func _load_music(music_name: StringName) -> AudioStream:
	return _load(MUSIC_DIR % music_name)

func _make_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")

func _apply_mutes() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_MUSIC), not Game.music_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_SFX), not Game.sfx_on)

func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node is Cell:
		var click := play.bind(&"click")
		var btn := node as BaseButton
		if not btn.pressed.is_connected(click):
			btn.pressed.connect(click)

## Botoes que entraram na arvore antes do Sfx (ordem de autoload/cena).
func _hook_existing(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_hook_existing(child)
