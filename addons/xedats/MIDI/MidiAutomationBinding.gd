class_name MidiAutomationBinding
extends Resource

## Maps a MIDI CC (controller change) number and channel to a Xedats audio parameter.
##
## Used by [MidiParameterAutomationLane] to drive real-time mixing from
## MIDI CC lanes embedded in a [MidiSequence].

enum TargetType {
	CATEGORY_VOLUME,
	BUS_VOLUME,
	BUS_EFFECT_PARAM,
}

## MIDI CC number to listen for (0-127).
@export var cc_number: int = 7

## MIDI channel to listen on (0-15). -1 means any channel.
@export var channel: int = -1

## What to control with this CC.
@export var target_type: TargetType = TargetType.CATEGORY_VOLUME

## Target parameter name. For CATEGORY_VOLUME: the category name (e.g. "SFX").
## For BUS_VOLUME: the bus name. For BUS_EFFECT_PARAM: unused (future).
@export var target_name: String = "Master"

## Minimum output value (CC 0 maps to this).
@export var min_value: float = 0.0

## Maximum output value (CC 127 maps to this).
@export var max_value: float = 1.0


func matches(cc: int, midi_channel: int) -> bool:
	if cc != cc_number:
		return false
	if channel >= 0 and midi_channel != channel:
		return false
	return true


func apply(value: int) -> void:
	var normalized: float = clamp(float(value) / 127.0, 0.0, 1.0)
	var mapped: float = lerp(min_value, max_value, normalized)

	if not ClassDB.class_exists(&"XedatsSingleton"):
		return

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return

	match target_type:
		TargetType.CATEGORY_VOLUME:
			if not target_name.is_empty():
				xedats.set_category_volume(target_name, mapped)
		TargetType.BUS_VOLUME:
			if not target_name.is_empty():
				var bus_index: int = AudioServer.get_bus_index(target_name)
				if bus_index >= 0:
					AudioServer.set_bus_volume_db(bus_index, linear_to_db(clamp(mapped, 0.001, 1.0)))
		_:
			pass
