class_name MidiStinger
extends Node

## Queues and plays short musical phrases at bar boundaries with
## background music ducking via [AudioCrossfade]-style volume transitions.
##
## Attach to a scene alongside a main [MidiSequencer]. Call [method queue_stinger]
## to schedule a stinger at the next bar boundary.
##
## Usage:
## [codeblock]
## var stinger_sys: MidiStinger = MidiStinger.new()
## stinger_sys.main_sequencer = background_music_sequencer
## stinger_sys.note_map = preload("res://music/stinger_map.tres")
## add_child(stinger_sys)
## stinger_sys.queue_stinger(victory_stinger_def)
## [/codeblock]

## The main background music sequencer whose beats/bars trigger stinger timing.
var main_sequencer: MidiSequencer = null

## [MidiNoteMap] used by the stinger's internal sequencer.
@export var note_map: MidiNoteMap

## Audio category for stinger playback (also ducked during stinger).
@export var stinger_category: String = "Music"

var _stinger_queue: Array = []  # Array[MidiStingerDefinition]
var _active_stinger: MidiSequencer = null
var _active_definition: MidiStingerDefinition = null
var _is_stinger_playing: bool = false
var _original_volume: float = 1.0
var _pending_trigger: bool = false
var _beat_count: int = 0
var _duck_pending: bool = false
var _duck_target: float = 1.0
var _duck_current: float = 1.0
var _duck_speed: float = 0.0


func _ready() -> void:
	if main_sequencer != null:
		if main_sequencer.bar.is_connected(_on_bar):
			return
		main_sequencer.bar.connect(_on_bar)
		main_sequencer.beat.connect(_on_beat)
		main_sequencer.playback_finished.connect(_on_main_finished)


func queue_stinger(definition: MidiStingerDefinition) -> void:
	if definition == null:
		return

	if _active_definition != null and definition.priority <= _active_definition.priority:
		return

	if _active_definition != null and definition.priority > _active_definition.priority:
		_duck_pending = true
		_cancel_active_stinger()

	_stinger_queue.append(definition)
	_stinger_queue.sort_custom(_sort_by_priority_desc)
	_pending_trigger = true


func _sort_by_priority_desc(a: MidiStingerDefinition, b: MidiStingerDefinition) -> bool:
	return a.priority > b.priority


func _on_beat(_beat_number: int) -> void:
	_beat_count += 1


func _on_bar(_bar_number: int) -> void:
	if not _pending_trigger or _stinger_queue.is_empty():
		return
	_trigger_next_stinger()


func _on_main_finished() -> void:
	_pending_trigger = false


func _trigger_next_stinger() -> void:
	if _stinger_queue.is_empty():
		return

	var definition: MidiStingerDefinition = _stinger_queue.pop_front() as MidiStingerDefinition
	if definition == null or definition.sequence == null:
		_pending_trigger = not _stinger_queue.is_empty()
		return

	_active_definition = definition
	_duck_background(true)
	_duck_pending = false

	if main_sequencer != null:
		main_sequencer.pause()

	_active_stinger = _create_stinger_sequencer(definition)
	if _active_stinger != null:
		add_child(_active_stinger)
		_active_stinger.playback_finished.connect(_on_stinger_finished)
		_active_stinger.play()
		_is_stinger_playing = true

	_pending_trigger = not _stinger_queue.is_empty()


func _create_stinger_sequencer(definition: MidiStingerDefinition) -> MidiSequencer:
	if not ClassDB.class_exists(&"MidiSoundDesignTimeline"):
		var seq: MidiSequencer = MidiSequencer.new()
		seq.sequence = definition.sequence
		seq.note_map = note_map
		seq.audio_category = stinger_category
		seq.volume_scale = 1.0
		seq.loop = false
		return seq

	var timeline: MidiSoundDesignTimeline = MidiSoundDesignTimeline.new()
	timeline.sequence = definition.sequence
	timeline.note_map = note_map
	timeline.audio_category = stinger_category
	timeline.volume_scale = 1.0
	timeline.loop = false
	return timeline


func _on_stinger_finished() -> void:
	_is_stinger_playing = false
	_duck_background(false)

	if main_sequencer != null and main_sequencer.is_paused:
		main_sequencer.resume()

	if _active_stinger != null:
		_active_stinger.queue_free()
		_active_stinger = null
	_active_definition = null


func _cancel_active_stinger() -> void:
	if _active_stinger != null:
		_active_stinger.playback_finished.disconnect(_on_stinger_finished)
		_active_stinger.stop()
		_active_stinger.queue_free()
		_active_stinger = null
	_is_stinger_playing = false
	_active_definition = null
	if _duck_pending:
		return
	_duck_background(false)
	if main_sequencer != null and main_sequencer.is_paused:
		main_sequencer.resume()


func _duck_background(duck: bool) -> void:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return

	if duck and _active_definition != null:
		_original_volume = xedats.get_category_volume(stinger_category)
		_duck_target = _original_volume * (1.0 - _active_definition.duck_amount)
		_duck_current = _original_volume
		_duck_speed = 1.0 / max(_active_definition.fade_duration, 0.01)
		set_process(true)
	elif not duck:
		_duck_target = _original_volume
		_duck_speed = 1.0 / max(_active_definition.fade_duration if _active_definition != null else 0.25, 0.01)
		if abs(_duck_current - _duck_target) < 0.01:
			xedats.set_category_volume(stinger_category, _duck_target)
			set_process(false)
		else:
			set_process(true)


func _process(delta: float) -> void:
	_duck_current = move_toward(_duck_current, _duck_target, delta * _duck_speed)

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats != null:
		xedats.set_category_volume(stinger_category, _duck_current)

	if abs(_duck_current - _duck_target) < 0.001:
		xedats.set_category_volume(stinger_category, _duck_target)
		set_process(false)
