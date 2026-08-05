@tool
class_name MidiPianoKeyboardWindow
extends Window

## Piano keyboard window — visual widget with sound generation.
## Does NOT handle MIDI input directly. Use a relay scene
## (midi_keyboard_relay.tscn) to connect a XedatsMIDIInput.

const _MidiPianoKeyboardResource := preload("MidiPianoKeyboard.gd")

@export var note_map: MidiNoteMap = null
@export var audio_category: String = "SFX"
@export var use_velocity_volume: bool = true

## Range preset for the keyboard display.
@export var range_preset: MidiPianoKeyboard.RangePreset = MidiPianoKeyboard.RangePreset.PIANO_88

## Black key width fraction (passed to keyboard).
@export_range(0.2, 1.0, 0.01) var black_key_width_frac: float = 0.50:
	set(v):
		black_key_width_frac = v
		if keyboard != null:
			keyboard.black_key_width_frac = v

## Black key height fraction (passed to keyboard).
@export_range(0.2, 1.0, 0.01) var black_key_height_frac: float = 0.60:
	set(v):
		black_key_height_frac = v
		if keyboard != null:
			keyboard.black_key_height_frac = v

## Black key horizontal offset fraction (passed to keyboard).
@export_range(-0.5, 0.5, 0.001) var black_key_offset_x: float = 0.0:
	set(v):
		black_key_offset_x = v
		if keyboard != null:
			keyboard.black_key_offset_x = v

## Black key vertical offset fraction (passed to keyboard).
@export_range(-0.2, 0.2, 0.001) var black_key_offset_y: float = 0.0:
	set(v):
		black_key_offset_y = v
		if keyboard != null:
			keyboard.black_key_offset_y = v

var keyboard: Node = null

# ── Sound generation ──────────────────────────────

enum SoundMode {
	OFF,
	SAMPLE,
	SINE_440,
}

@export var sound_mode: SoundMode = SoundMode.SINE_440:
	set(v):
		sound_mode = v
		_sine_stream = null

@export var test_sample: AudioStream = null
@export var test_sample_base_note: int = 60
@export var polyphony: int = 8

var _active_voices: Dictionary = {}
var _raw_voices: Array = []
var _sine_stream: AudioStreamWAV = null


func _init() -> void:
	title = "MIDI Keyboard"
	wrap_controls = true
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS


func _ready() -> void:
	size = Vector2(1200, 200)
	min_size = Vector2(500, 120)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL

	keyboard = _MidiPianoKeyboardResource.new()
	keyboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	keyboard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	keyboard.key_pressed.connect(_on_key_pressed)
	keyboard.key_released.connect(_on_key_released)
	keyboard.range_preset = range_preset
	keyboard.black_key_width_frac = black_key_width_frac
	keyboard.black_key_height_frac = black_key_height_frac
	keyboard.black_key_offset_x = black_key_offset_x
	keyboard.black_key_offset_y = black_key_offset_y
	vbox.add_child(keyboard)
	add_child(vbox)

	if sound_mode == SoundMode.SINE_440:
		_get_sine_stream()


func _exit_tree() -> void:
	for note: int in _active_voices.keys():
		_release_voice(note)


func _on_key_pressed(note: int, velocity: int) -> void:
	if sound_mode != SoundMode.OFF:
		_play_note(note, velocity)
	if note_map != null:
		_dispatch_xedats_note(note, velocity)


func _on_key_released(note: int) -> void:
	if sound_mode != SoundMode.OFF:
		_release_voice(note)


func _play_note(note: int, velocity: int) -> void:
	var stream: AudioStream = _get_audio_stream()
	if stream == null:
		return

	var vel_norm: float = clamp(float(velocity) / 127.0, 0.0, 1.0)
	var pitch: float = pow(2.0, float(note - test_sample_base_note) / 12.0)

	if _active_voices.size() >= polyphony:
		var oldest_note: int = _active_voices.keys()[0] as int
		_release_voice(oldest_note)

	var asp: AudioStreamPlayer = AudioStreamPlayer.new()
	asp.stream = stream
	asp.bus = &"Master"
	asp.pitch_scale = pitch
	asp.volume_db = linear_to_db(vel_norm)
	add_child(asp)
	asp.play(0.0)

	_active_voices[note] = asp
	_raw_voices.append(asp)


func _release_voice(note: int) -> void:
	if not _active_voices.has(note):
		return
	var player: Node = _active_voices[note] as Node
	player.stop()
	player.queue_free()
	_active_voices.erase(note)
	var idx: int = _raw_voices.find(player)
	if idx >= 0:
		_raw_voices.remove_at(idx)


func _get_audio_stream() -> AudioStream:
	match sound_mode:
		SoundMode.SAMPLE:
			return test_sample
		SoundMode.SINE_440:
			return _get_sine_stream()
	return null


func _get_sine_stream() -> AudioStream:
	if _sine_stream != null:
		return _sine_stream

	var sample_rate: int = 44100
	var duration: float = 2.0
	var total_samples: int = int(duration * float(sample_rate))
	var data: PackedByteArray = PackedByteArray()
	data.resize(total_samples * 2)

	for i: int in range(total_samples):
		var val: float = sin(2.0 * PI * 440.0 * float(i) / float(sample_rate))
		var int_val: int = int(clamp(val * 32767.0, -32767, 32767))
		data.encode_s16(i * 2, int_val)

	_sine_stream = AudioStreamWAV.new()
	_sine_stream.data = data
	_sine_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_sine_stream.mix_rate = sample_rate
	_sine_stream.stereo = false
	_sine_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_sine_stream.loop_begin = 0
	_sine_stream.loop_end = total_samples

	push_warning("MidiPianoKeyboardWindow: synthesized 440 Hz sine tone (%d samples)" % total_samples)
	return _sine_stream


func _dispatch_xedats_note(note: int, velocity: int) -> void:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return

	var program: int = 0
	var channel: int = 0
	var resolved: Dictionary = note_map.resolve(note, channel, program)

	var event_name: String = String(resolved.get("event", ""))
	var container: AudioArrayContainer = resolved.get("container") as AudioArrayContainer
	var pitch_offset: float = float(resolved.get("pitch_offset", 0.0))
	var note_volume_scale: float = float(resolved.get("volume_scale", 1.0))

	var vel_vol: float = clamp(float(velocity) / 127.0, 0.0, 1.0) if use_velocity_volume else 1.0
	var volume: float = clamp(vel_vol * note_volume_scale, 0.0, 1.0)

	var player: Node = null
	if container != null:
		player = xedats.create_player_3d(Vector3.ZERO)
		if player != null:
			player.play_random_from_container(container)
	elif not event_name.is_empty():
		player = xedats.trigger_audio_event(event_name, Vector3.ZERO)

	if player != null:
		var base_freq: float = 440.0 * pow(2.0, float(note - 69) / 12.0)
		var shifted_freq: float = base_freq * pow(2.0, pitch_offset / 12.0)
		player.pitch_scale = shifted_freq / base_freq
		player.set_volume_linear_normalized(volume)
		if not audio_category.is_empty():
			player.route_to_audio_category(audio_category)
