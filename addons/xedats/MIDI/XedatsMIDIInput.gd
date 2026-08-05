class_name XedatsMIDIInput
extends Node

## Captures [InputEventMIDI] from hardware MIDI controllers and maps
## CC messages to Xedats category volumes and note messages to audio events.
##
## Calls [method OS.open_midi_inputs] automatically in [method _ready].
## Device names can be queried with [method get_connected_devices].

@export var note_map: MidiNoteMap
@export var cc_volumes: Dictionary = {}
@export var enabled: bool = true
@export var use_velocity: bool = true
@export var volume_scale: float = 1.0
@export var audio_category: String = "SFX"
@export var spatial_position: Vector3 = Vector3.ZERO
@export var is_2d: bool = false
@export var spatial_position_2d: Vector2 = Vector2.ZERO
@export var auto_open: bool = true
@export var channel_filter: int = -1
@export var verbose_log: bool = false

signal cc_received(controller: int, value: int, channel: int)
signal note_triggered(note: int, velocity: int, channel: int, event_name: String)
signal note_off(note: int, channel: int)
signal midi_opened(devices: Array)
signal message_discarded(note: int, channel: int, reason: String)

var _midi_open: bool = false

const _NOTE_NAMES: Array[String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


func _ready() -> void:
	if enabled and auto_open:
		open_midi()


func open_midi() -> void:
	if _midi_open:
		return

	OS.open_midi_inputs()
	_midi_open = true
	set_process_input(enabled)

	var raw: PackedStringArray = OS.get_connected_midi_inputs()
	var devices: Array = []
	for d: String in raw:
		devices.append(d)
	print("[XedatsMIDIInput] open_midi: devices=%s" % var_to_str(devices))
	midi_opened.emit(devices)

	if devices.is_empty():
		push_warning("XedatsMIDIInput: MIDI driver opened but no devices detected.")


func close_midi() -> void:
	if not _midi_open:
		return
	OS.close_midi_inputs()
	_midi_open = false
	set_process_input(false)


func _exit_tree() -> void:
	pass


func get_connected_devices() -> Array:
	if not _midi_open:
		return []
	var raw: PackedStringArray = OS.get_connected_midi_inputs()
	var devices: Array = []
	for d: String in raw:
		devices.append(d)
	return devices


func _print_midi_event(midi: InputEventMIDI) -> void:
	match midi.message:
		MIDI_MESSAGE_NOTE_ON:
			var octave: int = midi.pitch / 12 - 1
			print("[MIDI] Note ON:  %s%d  ch=%d  vel=%d" % [_NOTE_NAMES[midi.pitch % 12], octave, midi.channel, midi.velocity])
		MIDI_MESSAGE_NOTE_OFF:
			var octave: int = midi.pitch / 12 - 1
			print("[MIDI] Note OFF: %s%d  ch=%d" % [_NOTE_NAMES[midi.pitch % 12], octave, midi.channel])
		MIDI_MESSAGE_CONTROL_CHANGE:
			print("[MIDI] CC:  %d = %d  ch=%d" % [midi.controller_number, midi.controller_value, midi.channel])
		_:
			print("[MIDI] msg=%d  ch=%d" % [midi.message, midi.channel])


func _input(event: InputEvent) -> void:
	if not enabled:
		return

	var midi_event: InputEventMIDI = event as InputEventMIDI
	if midi_event == null:
		return

	if verbose_log:
		_print_midi_event(midi_event)

	if channel_filter >= 0 and midi_event.channel != channel_filter:
		message_discarded.emit(midi_event.pitch, midi_event.channel, "channel_filter")
		return

	get_viewport().set_input_as_handled()

	match midi_event.message:
		MIDI_MESSAGE_CONTROL_CHANGE:
			_handle_cc(midi_event)
		MIDI_MESSAGE_NOTE_ON:
			if midi_event.velocity == 0:
				_handle_note_off(midi_event)
			else:
				_handle_note_on(midi_event)
		MIDI_MESSAGE_NOTE_OFF:
			_handle_note_off(midi_event)
		_:
			pass


func _handle_cc(midi: InputEventMIDI) -> void:
	cc_received.emit(midi.controller, midi.value, midi.channel)

	if not cc_volumes.has(midi.controller):
		return

	var category: String = String(cc_volumes[midi.controller])
	if category.is_empty():
		return

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return

	var volume: float = clamp(float(midi.controller_value) / 127.0, 0.0, 1.0)
	xedats.set_category_volume(category, volume)


func _handle_note_off(midi: InputEventMIDI) -> void:
	note_off.emit(midi.pitch, midi.channel)


func _handle_note_on(midi: InputEventMIDI) -> void:
	var event_name: String = ""
	var resolved_pitch_offset: float = 0.0
	var resolved_volume_scale: float = 1.0
	var container: AudioArrayContainer = null

	if note_map != null:
		var program: int = 0
		var resolved: Dictionary = note_map.resolve(midi.pitch, midi.channel, program)
		event_name = String(resolved.get("event", ""))
		container = resolved.get("container") as AudioArrayContainer
		resolved_pitch_offset = float(resolved.get("pitch_offset", 0.0))
		resolved_volume_scale = float(resolved.get("volume_scale", 1.0))

	# Emit signal regardless of note_map
	note_triggered.emit(midi.pitch, midi.velocity, midi.channel, event_name)

	if event_name.is_empty() and container == null:
		return

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return

	var velocity_vol: float = clamp(float(midi.velocity) / 127.0, 0.0, 1.0) if use_velocity else 1.0
	var volume: float = clamp(velocity_vol * volume_scale * resolved_volume_scale, 0.0, 1.0)

	var player: Node = null
	if is_2d:
		if container != null:
			player = xedats.create_player_2d(spatial_position_2d)
			if player != null:
				player.play_random_from_container(container)
		elif not event_name.is_empty():
			player = xedats.trigger_audio_event(event_name, Vector3(spatial_position_2d.x, spatial_position_2d.y, 0.0))
	else:
		if container != null:
			player = xedats.create_player_3d(spatial_position)
			if player != null:
				player.play_random_from_container(container)
		elif not event_name.is_empty():
			player = xedats.trigger_audio_event(event_name, spatial_position)

	if player != null:
		var base_freq: float = 440.0 * pow(2.0, float(midi.pitch - 69) / 12.0)
		var shifted_freq: float = base_freq * pow(2.0, resolved_pitch_offset / 12.0)
		player.pitch_scale = shifted_freq / base_freq
		player.set_volume_linear_normalized(volume)
		if not audio_category.is_empty():
			player.route_to_audio_category(audio_category)


func set_cc_volume(cc: int, category: String) -> void:
	cc_volumes[cc] = category


func remove_cc_volume(cc: int) -> void:
	cc_volumes.erase(cc)


func set_enabled(p_enabled: bool) -> void:
	enabled = p_enabled
	set_process_input(enabled and _midi_open)
