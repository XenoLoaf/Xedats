class_name MidiNoteMap
extends Resource

## Maps MIDI note numbers and program changes to Xedats audio events.
##
## Used by [MidiSequencer] to dispatch MIDI notes through [AudioEventSystem].
## Supports per-track mappings, per-channel mappings, and a default catch-all.
##
## Usage:
## [codeblock]
## var map: MidiNoteMap = MidiNoteMap.new()
## map.default_event = "midi_note"
## map.set_note_event(60, "piano_c4")   # Middle C
## map.set_note_event(36, "kick_drum")  # Kick
## map.set_note_container(42, hihat_container)  # Use a container
## [/codeblock]

## Default event name used when no specific mapping exists.
@export var default_event: String = ""

## Optional default [AudioArrayContainer] for notes with no mapped event.
@export var default_container: AudioArrayContainer

## Per-note event name mappings. Key = MIDI note number (0-127), Value = event name.
@export var note_events: Dictionary = {}

## Per-note [AudioArrayContainer] mappings. Key = MIDI note number, Value = container resource.
@export var note_containers: Dictionary = {}

## Per-channel default event overrides. Key = channel (0-15), Value = event name.
@export var channel_events: Dictionary = {}

## Per-channel default container overrides.
@export var channel_containers: Dictionary = {}

## Per-program-change event mappings. Key = program number (0-127), Value = event name.
@export var program_events: Dictionary = {}

## Per-note pitch shift in semitones. Key = MIDI note number, Value = semitone offset.
@export var note_pitch_offsets: Dictionary = {}

## Per-note velocity scale. Key = MIDI note number, Value = multiplier (1.0 = normal).
@export var note_volume_scales: Dictionary = {}


func set_note_event(note: int, event_name: String) -> void:
	note_events[note] = event_name


func get_note_event(note: int) -> String:
	if note_events.has(note):
		return String(note_events[note])
	if channel_events.has(0):
		return String(channel_events[0])
	return default_event


func set_note_container(note: int, container: AudioArrayContainer) -> void:
	note_containers[note] = container


func get_note_container(note: int) -> AudioArrayContainer:
	if note_containers.has(note):
		return note_containers[note] as AudioArrayContainer
	if channel_containers.has(0):
		return channel_containers[0] as AudioArrayContainer
	return default_container


func set_channel_event(channel: int, event_name: String) -> void:
	channel_events[channel] = event_name


func set_channel_container(channel: int, container: AudioArrayContainer) -> void:
	channel_containers[channel] = container


func set_program_event(program: int, event_name: String) -> void:
	program_events[program] = event_name


func get_program_event(program: int) -> String:
	if program_events.has(program):
		return String(program_events[program])
	return default_event


func get_note_pitch_offset(note: int) -> float:
	if note_pitch_offsets.has(note):
		return float(note_pitch_offsets[note])
	return 0.0


func get_note_volume_scale(note: int) -> float:
	if note_volume_scales.has(note):
		return float(note_volume_scales[note])
	return 1.0


func resolve(note: int, channel: int, program: int) -> Dictionary:
	var event_name: String = ""
	var container: AudioArrayContainer = null

	if note_events.has(note):
		event_name = String(note_events[note])
	elif channel_events.has(channel):
		event_name = String(channel_events[channel])
	elif program_events.has(program):
		event_name = String(program_events[program])
	else:
		event_name = default_event

	if note_containers.has(note):
		container = note_containers[note] as AudioArrayContainer
	elif channel_containers.has(channel):
		container = channel_containers[channel] as AudioArrayContainer
	else:
		container = default_container

	return {
		"event": event_name,
		"container": container,
		"pitch_offset": get_note_pitch_offset(note),
		"volume_scale": get_note_volume_scale(note),
	}
