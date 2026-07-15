class_name MidiDirector
extends Node

## Owns multiple [MidiSequencer] instances and crossfades between them
## based on game phase or section changes.
##
## Each phase has a named [MidiSequencer]. When [method set_phase] is called,
## the director fades out the current sequencer and fades in the target
## sequencer over the transition duration.
##
## Usage:
## [codeblock]
## var director: MidiDirector = MidiDirector.new()
## add_child(director)
## director.add_phase("exploration", exploration_seq)
## director.add_phase("combat", combat_seq)
## director.set_phase("exploration", 2.0)
## # Later:
## director.set_phase("combat", 0.5)
## [/codeblock]

## Named phase sequencers. Key = phase name (String), Value = [MidiSequencer].
@export var phases: Dictionary = {}

## Default transition duration in seconds when none is specified.
@export var default_transition_duration: float = 1.0

## The currently active phase name.
var current_phase: String = ""

## Whether a transition between phases is in progress.
var is_transitioning: bool = false

## Emitted when a phase transition begins.
signal transition_started(from_phase: String, to_phase: String, duration: float)

## Emitted when the active phase changes (immediate — transition may still be running).
signal phase_changed(from_phase: String, to_phase: String)

## Emitted when a transition fully completes.
signal transition_completed(to_phase: String)


func add_phase(name: String, sequencer: MidiSequencer) -> void:
	phases[name] = sequencer
	if sequencer.get_parent() == null:
		add_child(sequencer)
	sequencer.volume_scale = 0.0
	sequencer.set_process(false)


func remove_phase(name: String) -> void:
	if not phases.has(name):
		return
	var sequencer: MidiSequencer = phases[name] as MidiSequencer
	if sequencer != null and sequencer.get_parent() == self:
		sequencer.stop()
		remove_child(sequencer)
		sequencer.queue_free()
	phases.erase(name)
	if current_phase == name:
		current_phase = ""


func get_sequencer(phase_name: String) -> MidiSequencer:
	return phases.get(phase_name) as MidiSequencer


func get_current_sequencer() -> MidiSequencer:
	return phases.get(current_phase) as MidiSequencer


func set_phase(name: String, duration: float = -1.0) -> void:
	if not phases.has(name):
		push_warning("MidiDirector: Phase '%s' not found." % name)
		return

	var from_phase: String = current_phase
	if from_phase == name:
		return

	var transition_time: float = duration if duration >= 0.0 else default_transition_duration
	current_phase = name
	is_transitioning = true

	transition_started.emit(from_phase, name, transition_time)
	phase_changed.emit(from_phase, name)

	var from_seq: MidiSequencer = phases.get(from_phase) as MidiSequencer
	var to_seq: MidiSequencer = phases.get(name) as MidiSequencer

	if to_seq == null:
		is_transitioning = false
		transition_completed.emit(name)
		return

	to_seq.volume_scale = 0.0
	to_seq.play()

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	if from_seq != null and from_seq != to_seq:
		tween.tween_property(from_seq, "volume_scale", 0.0, transition_time)

	tween.tween_property(to_seq, "volume_scale", 1.0, transition_time)

	tween.finished.connect(_on_transition_finished.bind(from_seq, to_seq, name))
	tween.play()


func stop_all() -> void:
	for key_variant: Variant in phases.keys():
		var seq: MidiSequencer = phases[key_variant] as MidiSequencer
		if seq != null:
			seq.stop()
	current_phase = ""
	is_transitioning = false


func _on_transition_finished(from_seq: MidiSequencer, to_seq: MidiSequencer, phase_name: String) -> void:
	if from_seq != null and from_seq != to_seq:
		from_seq.stop()

	is_transitioning = false
	transition_completed.emit(phase_name)
