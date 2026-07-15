class_name MidiAutomationBinding
extends Resource

## Maps a MIDI CC (controller change) number and channel to a Xedats audio parameter
## or emits a generic signal for game-side handling.
##
## Used by [MidiParameterAutomationLane] to drive real-time mixing from
## MIDI CC lanes embedded in a [MidiSequence].

enum TargetType {
	CATEGORY_VOLUME,
	BUS_VOLUME,
	BUS_EFFECT_PARAM,
	GENERIC_SIGNAL,
}

## MIDI CC number to listen for (0-127).
@export var cc_number: int = 7

## MIDI channel to listen on (0-15). -1 means any channel.
@export var channel: int = -1

## What to control with this CC.
@export var target_type: TargetType = TargetType.CATEGORY_VOLUME

## Target parameter name. For CATEGORY_VOLUME: the category name (e.g. "SFX").
## For BUS_VOLUME: the bus name. For BUS_EFFECT_PARAM: unused (future).
## For GENERIC_SIGNAL: unused — connect to [signal cc_applied] instead.
@export var target_name: String = "Master"

## Minimum output value (CC 0 maps to this).
@export var min_value: float = 0.0

## Maximum output value (CC 127 maps to this).
@export var max_value: float = 1.0

## Emitted when [member target_type] is [code]GENERIC_SIGNAL[/code].
signal cc_applied(cc: int, value: float, normalized: float)


func matches(cc: int, midi_channel: int) -> bool:
	if cc != cc_number:
		return false
	if channel >= 0 and midi_channel != channel:
		return false
	return true


func apply(value: int) -> void:
	var normalized: float = clamp(float(value) / 127.0, 0.0, 1.0)
	var mapped: float = lerp(min_value, max_value, normalized)

	match target_type:
		TargetType.CATEGORY_VOLUME:
			_apply_category_volume(mapped)
		TargetType.BUS_VOLUME:
			_apply_bus_volume(mapped)
		TargetType.GENERIC_SIGNAL:
			cc_applied.emit(cc_number, mapped, normalized)
		_:
			pass


func _apply_category_volume(value: float) -> void:
	if not ClassDB.class_exists(&"XedatsSingleton"):
		return
	if target_name.is_empty():
		return
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return
	xedats.set_category_volume(target_name, value)


func _apply_bus_volume(value: float) -> void:
	if target_name.is_empty():
		return
	var bus_index: int = AudioServer.get_bus_index(target_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamp(value, 0.001, 1.0)))
