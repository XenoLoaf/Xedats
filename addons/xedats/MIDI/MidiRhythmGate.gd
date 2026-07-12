class_name MidiRhythmGate
extends Node

## Tempo-synchronized audio bus effect gating.
##
## Drives a rhythmic pattern of volume or effect modulation on a target
## audio bus, synchronized to a [MidiSequencer] beat grid or a free-running BPM.
##
## Usage:
## [codeblock]
## var gate: MidiRhythmGate = MidiRhythmGate.new()
## gate.sequencer = music_sequencer
## gate.pattern = [1.0, 0.0, 0.5, 0.0]  # quarter-note gate pattern
## gate.target_bus = "SFXEffects"
## gate.step_subdivision = 4  # 16th notes
## add_child(gate)
## [/codeblock]

## Pattern array of float values [0.0–1.0] defining the gate shape.
## Each value represents the volume/effect intensity for one step.
@export var pattern: Array[float] = [1.0, 0.0]

## Number of steps per beat. 1=quarter, 2=eighth, 4=sixteenth, etc.
@export var step_subdivision: int = 2

## Name of the audio bus to modulate.
@export var target_bus: String = "Master"

## Fallback BPM when no sequencer is connected.
@export var bpm: float = 120.0

## Smoothing factor for transitions between steps (0.0 = instant, 1.0 = no change).
@export var smoothing: float = 0.3

## Whether the gate is actively modulating.
@export var enabled: bool = true

var _current_step: int = 0
var _current_value: float = 1.0
var _target_value: float = 1.0
var _beat_count: int = 0
var _seconds_per_step: float = 0.0
var _step_timer: float = 0.0
var _connected_sequencer: MidiSequencer = null


func _ready() -> void:
	_recalculate_timing()
	set_process(enabled)


func _process(delta: float) -> void:
	if not enabled or pattern.is_empty():
		return

	_step_timer -= delta
	if _step_timer <= 0.0:
		_advance_step()
		_step_timer += _seconds_per_step

	_current_value = lerp(_current_value, _target_value, 1.0 - pow(smoothing, delta * 60.0))
	_apply_value()


func set_sequencer(seq: MidiSequencer) -> void:
	if _connected_sequencer != null and _connected_sequencer.beat.is_connected(_on_beat):
		_connected_sequencer.beat.disconnect(_on_beat)

	_connected_sequencer = seq
	if seq != null:
		if not seq.beat.is_connected(_on_beat):
			seq.beat.connect(_on_beat)


func _on_beat(_beat_number: int) -> void:
	_recalculate_timing()
	_step_timer = 0.0


func _advance_step() -> void:
	if pattern.is_empty():
		return

	_current_step = (_current_step + 1) % pattern.size()
	_target_value = pattern[_current_step]


func _recalculate_timing() -> void:
	if _connected_sequencer != null and _connected_sequencer.sequence != null:
		var tempo: int = _connected_sequencer.sequence.get_tempo_at_tick(_connected_sequencer.current_tick)
		var usec_per_beat: float = float(tempo)
		_seconds_per_step = (usec_per_beat / 1000000.0) / float(step_subdivision)
	else:
		_seconds_per_step = (60.0 / bpm) / float(step_subdivision)


func _apply_value() -> void:
	if target_bus.is_empty():
		return

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return

	if not xedats.has_audio_bus(target_bus):
		return

	var bus_index: int = AudioServer.get_bus_index(target_bus)
	if bus_index < 0:
		return

	var vol_db: float = linear_to_db(clamp(_current_value, 0.001, 1.0))
	AudioServer.set_bus_volume_db(bus_index, vol_db)


func set_pattern(p: Array[float]) -> void:
	pattern = p
	if pattern.size() > 0:
		_current_step = 0
		_target_value = pattern[0]
