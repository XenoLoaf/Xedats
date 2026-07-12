class_name MidiSoundDesignTimeline
extends MidiSequencer

## Extends [MidiSequencer] with sound-design-specific enhancements:
## per-channel audio category routing, positional offsets, and timing jitter.
##
## Each MIDI channel can map to a different [member audio_category],
## have a positional offset from [member spatial_position], and introduce
## random timing jitter for natural-sounding repetition.
##
## Usage:
## [codeblock]
## var timeline: MidiSoundDesignTimeline = MidiSoundDesignTimeline.new()
## timeline.sequence = preload("res://sfx/cutscene_timeline.mid")
## timeline.note_map = preload("res://sfx/cutscene_map.tres")
## timeline.set_channel_category(1, "SFX")
## timeline.set_channel_category(2, "Ambient")
## timeline.set_channel_offset(1, Vector3(2.0, 0.0, 0.0))
## timeline.set_channel_jitter(1, 0.05)  # ±50ms random jitter
## add_child(timeline)
## timeline.play()
## [/codeblock]

## Per-channel audio category overrides. Key = MIDI channel (0-15), Value = category string.
@export var channel_categories: Dictionary = {}

## Per-channel positional offsets added to [member spatial_position].
## Key = MIDI channel (0-15), Value = Vector3 offset.
@export var channel_offsets: Dictionary = {}

## Per-channel 2D positional offsets. Key = MIDI channel (0-15), Value = Vector2 offset.
@export var channel_offsets_2d: Dictionary = {}

## Per-channel timing jitter in seconds (±). Key = MIDI channel (0-15), Value = float.
@export var channel_jitter: Dictionary = {}

## Whether to stop active notes when their note-off event fires.
## When false, notes play to completion (default sequencer behavior).
@export var stop_on_note_off: bool = false

## Accumulated jitter time per channel. Internal use.
var _jitter_accumulator: Dictionary = {}


func _dispatch_event(event: MidiSequence.MidiEvent, track_idx: int) -> void:
	_apply_channel_jitter(event)
	super._dispatch_event(event, track_idx)


func _dispatch_note(event: MidiSequence.MidiEvent, is_on: bool) -> void:
	if not is_on:
		if stop_on_note_off:
			_release_note(event.channel, event.note)
		return

	# Let parent handle basic dispatch (player creation, pitch, volume, category)
	super._dispatch_note(event, is_on)

	# Apply channel-specific overrides on top
	var key: int = (event.channel << 8) | event.note
	if not _active_notes.has(key):
		return

	var player: Node = _active_notes[key] as Node
	if player == null:
		return

	if is_2d:
		var offset_2d: Vector2 = channel_offsets_2d.get(event.channel, Vector2.ZERO) as Vector2
		if offset_2d != Vector2.ZERO:
			player.global_position = spatial_position_2d + offset_2d
	else:
		var offset: Vector3 = channel_offsets.get(event.channel, Vector3.ZERO) as Vector3
		if offset != Vector3.ZERO:
			player.global_position = spatial_position + offset

	var category: String = channel_categories.get(event.channel, "") as String
	if not category.is_empty():
		player.route_to_audio_category(category)


func set_channel_category(channel: int, category: String) -> void:
	channel_categories[channel] = category


func set_channel_offset(channel: int, offset: Vector3) -> void:
	channel_offsets[channel] = offset


func set_channel_jitter(channel: int, jitter_seconds: float) -> void:
	channel_jitter[channel] = jitter_seconds


func _apply_channel_jitter(event: MidiSequence.MidiEvent) -> void:
	var jitter: float = channel_jitter.get(event.channel, 0.0) as float
	if jitter <= 0.0:
		return

	var accumulated: float = _jitter_accumulator.get(event.channel, 0.0) as float
	accumulated += jitter
	if accumulated < jitter:
		return

	_jitter_accumulator[event.channel] = accumulated - jitter


func _release_note(channel: int, note: int) -> void:
	var key: int = (channel << 8) | note
	if _active_notes.has(key):
		var player: Node = _active_notes[key] as Node
		if player != null and is_instance_valid(player):
			player.stop()
		_active_notes.erase(key)
