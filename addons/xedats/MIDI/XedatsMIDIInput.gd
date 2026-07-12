class_name XedatsMIDIInput
extends Node

## Captures [InputEventMIDI] from hardware MIDI controllers and maps
## CC messages to Xedats category volumes and note messages to audio events.
##
## Platform-dependent — gated behind [code]OS.has_feature("midi")[/code].
## On platforms without MIDI support, this node is a silent no-op.
##
## Usage:
## [codeblock]
## var midi_input: XedatsMIDIInput = XedatsMIDIInput.new()
## midi_input.note_map = preload("res://midi/controller_map.tres")
## midi_input.set_cc_volume(7, "Master")      # CC 7 → Master volume
## midi_input.set_cc_volume(11, "SFX")        # CC 11 → SFX volume
## add_child(midi_input)
## [/codeblock]

## [MidiNoteMap] for note-to-event mapping.
@export var note_map: MidiNoteMap

## Per-CC category volume mappings. Key = CC number, Value = category name.
@export var cc_volumes: Dictionary = {}

## Whether MIDI input is enabled.
@export var enabled: bool = true

## Whether to use MIDI velocity as event volume override.
@export var use_velocity: bool = true

## Global volume scale applied to all MIDI-triggered events.
@export var volume_scale: float = 1.0

## Audio category for MIDI-triggered events.
@export var audio_category: String = "SFX"

## Spatial position for MIDI-triggered 3D events.
@export var spatial_position: Vector3 = Vector3.ZERO

## Whether to dispatch through 2D players instead of 3D.
@export var is_2d: bool = false

## Spatial position for MIDI-triggered 2D events (used when [member is_2d] is true).
@export var spatial_position_2d: Vector2 = Vector2.ZERO

## Signal emitted when a MIDI CC is received and processed.
signal cc_received(controller: int, value: int, channel: int)

## Signal emitted when a MIDI note triggers an audio event.
signal note_triggered(note: int, velocity: int, channel: int, event_name: String)


func _ready() -> void:
	set_process_input(enabled and _is_midi_supported())


func _is_midi_supported() -> bool:
	return OS.has_feature("midi")


func _input(event: InputEvent) -> void:
	if not enabled:
		return

	var midi_event: InputEventMIDI = event as InputEventMIDI
	if midi_event == null:
		return

	get_viewport().set_input_as_handled()

	match midi_event.message:
		MIDI_MESSAGE_CONTROL_CHANGE:
			_handle_cc(midi_event)
		MIDI_MESSAGE_NOTE_ON:
			_handle_note_on(midi_event)
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


func _handle_note_on(midi: InputEventMIDI) -> void:
	if midi.velocity == 0:
		return  # Note-on with velocity 0 = note-off, skip

	if note_map == null:
		return

	var program: int = 0
	var resolved: Dictionary = note_map.resolve(midi.pitch, midi.channel, program)

	var event_name: String = String(resolved.get("event", ""))
	var container: AudioArrayContainer = resolved.get("container") as AudioArrayContainer
	var pitch_offset: float = float(resolved.get("pitch_offset", 0.0))
	var note_volume_scale: float = float(resolved.get("volume_scale", 1.0))

	if event_name.is_empty() and container == null:
		return

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return

	var velocity_vol: float = clamp(float(midi.velocity) / 127.0, 0.0, 1.0) if use_velocity else 1.0
	var volume: float = clamp(velocity_vol * volume_scale * note_volume_scale, 0.0, 1.0)

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
		var shifted_freq: float = base_freq * pow(2.0, pitch_offset / 12.0)
		player.pitch_scale = shifted_freq / base_freq
		player.set_volume_linear_normalized(volume)
		if not audio_category.is_empty():
			player.route_to_audio_category(audio_category)

		note_triggered.emit(midi.pitch, midi.velocity, midi.channel, event_name)


func set_cc_volume(cc: int, category: String) -> void:
	cc_volumes[cc] = category


func remove_cc_volume(cc: int) -> void:
	cc_volumes.erase(cc)


func set_enabled(p_enabled: bool) -> void:
	enabled = p_enabled
	set_process_input(enabled and _is_midi_supported())
