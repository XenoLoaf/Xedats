class_name MidiParameterAutomationLane
extends Node

## Processes MIDI CC events from a [MidiSequence] and applies them
## through [MidiAutomationBinding] resources to drive real-time audio mixing.
##
## Can run standalone (free-running clock) or sync to a [MidiSequencer]'s
## current position for tempo-locked automation.
##
## Usage:
## [codeblock]
## var lane: MidiParameterAutomationLane = MidiParameterAutomationLane.new()
## lane.sequence = preload("res://music/track.mid")
## lane.bindings = [create_volume_binding(), create_reverb_binding()]
## lane.sync_to_sequencer(music_sequencer)
## add_child(lane)
## lane.play()
## [/codeblock]

## The MIDI sequence containing CC automation data.
@export var sequence: MidiSequence

## Array of [MidiAutomationBinding] resources defining CC→parameter mappings.
@export var bindings: Array[MidiAutomationBinding] = []

## Free-running BPM when no sync source is set.
@export var bpm: float = 120.0

## Whether the lane is actively processing.
var is_playing: bool = false

var _current_tick: int = 0
var _last_processed_tick: int = -1
var _sync_source: MidiSequencer = null
var _track_event_indices: Dictionary = {}


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not is_playing or sequence == null:
		return

	if _sync_source != null:
		_current_tick = _sync_source.current_tick
	else:
		var ticks_per_second: float = (bpm * float(sequence.division)) / 60.0
		_current_tick += int(delta * ticks_per_second)

	if _current_tick >= sequence.duration_ticks:
		_current_tick = sequence.duration_ticks
		stop()

	if _current_tick == _last_processed_tick:
		return
	_last_processed_tick = _current_tick

	_process_automation()


func play() -> void:
	if sequence == null:
		return

	_current_tick = 0
	_last_processed_tick = -1
	_track_event_indices.clear()
	set_process(true)
	is_playing = true


func stop() -> void:
	set_process(false)
	is_playing = false


func sync_to_sequencer(sequencer: MidiSequencer) -> void:
	_sync_source = sequencer


func unsync() -> void:
	_sync_source = null


func _process_automation() -> void:
	if sequence.tracks.is_empty():
		return

	for track_idx: int in range(sequence.tracks.size()):
		var track: MidiSequence.MidiTrack = sequence.tracks[track_idx] as MidiSequence.MidiTrack
		var event_idx: int = _track_event_indices.get(track_idx, 0)

		while event_idx < track.events.size():
			var event: MidiSequence.MidiEvent = track.events[event_idx] as MidiSequence.MidiEvent
			if event.absolute_time > _current_tick:
				break

			if event.event_type == MidiSequence.MidiEventType.CONTROL_CHANGE:
				for binding: MidiAutomationBinding in bindings:
					if binding.matches(event.controller, event.channel):
						binding.apply(event.value)

			event_idx += 1

		_track_event_indices[track_idx] = event_idx
