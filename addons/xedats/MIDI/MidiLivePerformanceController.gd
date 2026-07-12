class_name MidiLivePerformanceController
extends XedatsMIDIInput

## Extends [XedatsMIDIInput] with MIDI learn mode for real-time
## binding of hardware controllers to Xedats mixing parameters.
##
## When learn mode is active, the next incoming MIDI message is bound
## to the last-configured target. This enables console-based or
## inspector-based configuration workflows for live mixing.
##
## Usage:
## [codeblock]
## var controller: MidiLivePerformanceController = MidiLivePerformanceController.new()
## controller.set_cc_volume(7, "Master")
## controller.set_learn_target("SFX", MidiLivePerformanceController.TargetType.CATEGORY_VOLUME)
## controller.start_learn()
## # Move any hardware fader → it binds to SFX category volume
## [/codeblock]

enum LearnTargetType {
	CATEGORY_VOLUME,
	BUS_EFFECT,
	EVENT_TRIGGER,
}

## Whether learn mode is active. When enabled, the next incoming MIDI message
## is bound to the configured learn target.
var learn_mode: bool = false

var _learn_cc: bool = true
var _learn_target_name: String = ""
var _learn_target_type: LearnTargetType = LearnTargetType.CATEGORY_VOLUME

## Signal emitted when learn mode captures a binding.
signal learned(cc: int, channel: int, target_name: String)


func start_learn() -> void:
	learn_mode = true


func stop_learn() -> void:
	learn_mode = false


func set_learn_target(target_name: String, target_type: LearnTargetType) -> void:
	_learn_target_name = target_name
	_learn_target_type = target_type


func set_learn_cc_mode(cc_mode: bool) -> void:
	_learn_cc = cc_mode


func _handle_cc(midi: InputEventMIDI) -> void:
	if learn_mode:
		_apply_learn(midi.controller, midi.channel)
		return
	super._handle_cc(midi)


func _handle_note_on(midi: InputEventMIDI) -> void:
	if learn_mode and not _learn_cc:
		_apply_learn(midi.pitch, midi.channel)
		return
	super._handle_note_on(midi)


func _apply_learn(control: int, channel: int) -> void:
	learn_mode = false

	match _learn_target_type:
		LearnTargetType.CATEGORY_VOLUME:
			cc_volumes[control] = _learn_target_name
		LearnTargetType.EVENT_TRIGGER:
			if note_map != null:
				note_map.set_note_event(control, _learn_target_name)
		_:
			pass

	learned.emit(control, channel, _learn_target_name)
