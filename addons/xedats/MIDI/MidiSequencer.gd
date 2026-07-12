class_name MidiSequencer
extends Node

## Consumes a [MidiSequence] and dispatches note events through [AudioEventSystem].
##
## Manages real-time playback with tempo control, looping, and per-note
## event resolution via [MidiNoteMap]. Supports pitch shifting and
## velocity-to-volume conversion.
##
## Usage:
## [codeblock]
## var seq: MidiSequencer = MidiSequencer.new()
## seq.sequence = preload("res://music/theme.mid")
## seq.note_map = preload("res://music/theme_map.tres")
## add_child(seq)
## seq.play()
## [/codeblock]

## The parsed MIDI sequence to play.
@export var sequence: MidiSequence

## Maps MIDI notes/programs to Xedats audio events.
@export var note_map: MidiNoteMap

## Playback tempo override in BPM. Set to 0 to use the sequence's embedded tempo.
@export var tempo_override: float = 0.0

## Whether playback loops after reaching the end.
@export var loop: bool = false

## Global volume multiplier applied to all dispatched events.
@export var volume_scale: float = 1.0

## Global pitch shift in semitones added to per-note pitch offsets.
@export var pitch_shift: int = 0

## Spatial position for dispatched 3D audio events.
@export var spatial_position: Vector3 = Vector3.ZERO

## Whether to dispatch through 2D players instead of 3D.
@export var is_2d: bool = false

## Spatial position for dispatched 2D audio events (used when [member is_2d] is true).
@export var spatial_position_2d: Vector2 = Vector2.ZERO

## Audio category for dispatched events.
@export var audio_category: String = "Music"

## Whether the sequencer is currently playing.
var is_playing: bool = false

## Whether playback is paused.
var is_paused: bool = false

## Current playback position in ticks.
var current_tick: int = 0

## Track-specific current tick positions. Key = track index, Value = tick position.
var _track_ticks: Dictionary = {}

## Track-specific event indices. Key = track index, Value = current event index.
var _track_event_indices: Dictionary = {}

## Per-channel current program number.
var _channel_programs: Dictionary = {}

## Active note players tracked for potential early-release. Key = (channel << 8 | note), Value = player node.
var _active_notes: Dictionary = {}

## Signal emitted on each beat boundary.
signal beat(beat_number: int)

## Signal emitted on each bar boundary.
signal bar(bar_number: int)

## Signal emitted when playback reaches the end of the sequence.
signal playback_finished()

## Signal emitted when a note event is dispatched.
signal note_dispatched(note: int, velocity: int, channel: int)


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not is_playing or is_paused:
		return
	if sequence == null or sequence.tracks.is_empty():
		stop()
		return

	var tempo: int = _get_current_tempo()
	var usec_per_beat: float = float(tempo)
	var usec_per_tick: float = usec_per_beat / float(sequence.division)
	var seconds_per_tick: float = usec_per_tick / 1000000.0

	if seconds_per_tick <= 0.0:
		return

	var delta_ticks: float = delta / seconds_per_tick
	current_tick += int(delta_ticks)

	if current_tick >= sequence.duration_ticks:
		if loop:
			current_tick = current_tick % sequence.duration_ticks
			_reset_track_positions()
		else:
			stop()
			playback_finished.emit()
			return

	_process_events_up_to(current_tick)


func play() -> void:
	if sequence == null:
		push_warning("MidiSequencer: No sequence assigned.")
		return

	current_tick = 0
	_track_ticks.clear()
	_track_event_indices.clear()
	_channel_programs.clear()
	_active_notes.clear()

	for i: int in range(sequence.tracks.size()):
		_track_ticks[i] = 0
		_track_event_indices[i] = 0

	is_playing = true
	is_paused = false
	set_process(true)


func stop() -> void:
	is_playing = false
	is_paused = false
	set_process(false)
	_release_active_notes()


func pause() -> void:
	if not is_playing:
		return
	is_paused = true


func resume() -> void:
	if not is_playing:
		return
	is_paused = false


func seek_to_tick(tick: int) -> void:
	current_tick = clampi(tick, 0, sequence.duration_ticks)
	_reset_track_positions()
	_process_events_up_to(current_tick)


func seek_to_seconds(seconds: float) -> void:
	var tick: int = sequence.seconds_to_ticks(seconds, tempo_override)
	seek_to_tick(tick)


func get_current_time_seconds() -> float:
	return sequence.ticks_to_seconds(current_tick, tempo_override)


func get_duration_seconds() -> float:
	return sequence.ticks_to_seconds(sequence.duration_ticks, tempo_override)


func _get_current_tempo() -> int:
	if tempo_override > 0.0:
		return int(60000000.0 / tempo_override)
	return sequence.get_tempo_at_tick(current_tick)


func _process_events_up_to(target_tick: int) -> void:
	if note_map == null:
		return

	for track_idx: int in range(sequence.tracks.size()):
		var track: MidiSequence.MidiTrack = sequence.tracks[track_idx] as MidiSequence.MidiTrack
		var event_idx: int = _track_event_indices.get(track_idx, 0)

		while event_idx < track.events.size():
			var event: MidiSequence.MidiEvent = track.events[event_idx] as MidiSequence.MidiEvent
			if event.absolute_time > target_tick:
				break

			_dispatch_event(event, track_idx)
			event_idx += 1

		_track_event_indices[track_idx] = event_idx


func _dispatch_event(event: MidiSequence.MidiEvent, _track_idx: int) -> void:
	match event.event_type:
		MidiSequence.MidiEventType.NOTE_ON:
			_dispatch_note(event, true)
		MidiSequence.MidiEventType.NOTE_OFF:
			_dispatch_note(event, false)
		MidiSequence.MidiEventType.PROGRAM_CHANGE:
			_channel_programs[event.channel] = event.program


func _dispatch_note(event: MidiSequence.MidiEvent, is_on: bool) -> void:
	if not is_on:
		return  # Note-off: players auto-release on finished

	var program: int = _channel_programs.get(event.channel, 0)
	var resolved: Dictionary = note_map.resolve(event.note, event.channel, program)

	var event_name: String = String(resolved.get("event", ""))
	var container: AudioArrayContainer = resolved.get("container") as AudioArrayContainer
	var pitch_offset: float = float(resolved.get("pitch_offset", 0.0))
	var note_volume_scale: float = float(resolved.get("volume_scale", 1.0))

	if event_name.is_empty() and container == null:
		return

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return

	var volume: float = clamp(float(event.velocity) / 127.0 * volume_scale * note_volume_scale, 0.0, 1.0)
	var pitch: float = _note_to_frequency(event.note) * pow(2.0, (pitch_offset + float(pitch_shift)) / 12.0)

	var player: Node = null
	if is_2d:
		if container != null:
			player = xedats.create_player_2d(spatial_position_2d)
			if player != null:
				player.play_random_from_container(container)
		elif not event_name.is_empty():
			var pos_3d: Vector3 = Vector3(spatial_position_2d.x, spatial_position_2d.y, 0.0)
			player = xedats.trigger_audio_event(event_name, pos_3d)
	else:
		if container != null:
			player = xedats.create_player_3d(spatial_position)
			if player != null:
				player.play_random_from_container(container)
		elif not event_name.is_empty():
			player = xedats.trigger_audio_event(event_name, spatial_position)

	if player != null:
		player.pitch_scale = pitch / _note_to_frequency(event.note)
		player.set_volume_linear_normalized(volume)
		if not audio_category.is_empty():
			player.route_to_audio_category(audio_category)

		_active_notes[(event.channel << 8) | event.note] = player
		note_dispatched.emit(event.note, event.velocity, event.channel)


func _note_to_frequency(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)


func _reset_track_positions() -> void:
	for i: int in range(sequence.tracks.size()):
		_track_ticks[i] = 0
		_track_event_indices[i] = 0


func _release_active_notes() -> void:
	for key_variant: Variant in _active_notes.keys():
		var player: Node = _active_notes[key_variant] as Node
		if player != null and is_instance_valid(player):
			player.stop()
	_active_notes.clear()
