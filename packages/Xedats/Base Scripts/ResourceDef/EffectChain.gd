class_name EffectChain
extends Resource

## EffectChain manages a chain of audio effects that can be applied to audio buses.
##
## Use EffectChain to organize and apply audio effects (reverb, delay, distortion, etc.)
## to audio buses in a controlled, reusable way. Effects are applied in the order they
## appear in the chain.
##
## [b]COMMON USAGE PATTERNS:[/b]
##
## [b]1. Create an EffectChain resource:[/b]
## - In FileSystem (right-click) → New Resource → EffectChain
## - Set chain_name to something descriptive (e.g., "Cave Reverb")
## - Create and configure effects in the effect_nodes array
## - Save as .tres file
##
## [b]2. Apply effects to audio buses:[/b]
## [codeblock]
## var audio = XedatsSingleton.instance()
## var effect_chain = preload("res://audio/effects/cave_reverb.tres")
##
## # Create a bus and add effects from the chain
## audio.create_audio_bus("CaveAmbient", "Master")
## for effect in effect_chain.effect_nodes:
##     audio.add_bus_effect("CaveAmbient", effect)
## [/codeblock]
##
## [b]3. Enable/disable effect chains:[/b]
## [codeblock]
## var effect_chain = preload("res://audio/effects/cave_reverb.tres")
## effect_chain.is_enabled = false  # Disable all effects
## effect_chain.bypass_all = true   # Bypass without disabling
## [/codeblock]
##
## [b]4. Add effects dynamically:[/b]
## [codeblock]
## var effect_chain = EffectChain.new("MyEffects")
## var reverb = AudioEffectReverb.new()
## effect_chain.add_effect(reverb)
## [/codeblock]
##
## [b]AVAILABLE EFFECT TYPES:[/b]
## - REVERB: Room reflections and ambience
## - CHORUS: Thickening and layering effect
## - COMPRESSOR: Dynamic range compression
## - DELAY: Delayed echo of audio
## - DISTORTION: Harmonic distortion
## - EQ: Equalization for frequency shaping
## - HIGHPASS: Remove low frequencies
## - LOWPASS: Remove high frequencies
## - NOTCH: Narrow frequency rejection
## - PHASER: Sweeping comb filter effect
## - PITCH_SHIFT: Change pitch without changing speed
## - SPECTRUM_ANALYZER: Audio frequency analysis
##
## See Xedats.md for comprehensive usage documentation and examples.

# EffectChain manages a chain of audio effects that can be applied to audio buses
# Based on Godot's AudioEffect class and its inherited effect types

## @export var chain_name
## Human-readable name of this effect chain.
@export var chain_name: String = "EffectChain"

## @export var effect_nodes
## Ordered list of audio effects in this chain.
@export var effect_nodes: Array[AudioEffect] = []

## @export var is_enabled
## Master enable flag for this effect chain.
@export var is_enabled: bool = true

## @export var bypass_all
## If true, chain is bypassed even when is_enabled is true.
@export var bypass_all: bool = false

## @var _effect_metadata
## Metadata entries parallel to effect_nodes for diagnostics and tooling.
var _effect_metadata: Array[Dictionary] = []

## @signal effect_added(index, effect)
## Emitted when an effect is added.
signal effect_added(index: int, effect: AudioEffect)

## @signal effect_removed(index)
## Emitted when an effect is removed.
signal effect_removed(index: int)

## @signal effect_moved(from_index, to_index)
## Emitted when an effect changes position.
signal effect_moved(from_index: int, to_index: int)

## @signal chain_enabled_changed(enabled)
## Emitted when chain enabled state changes.
signal chain_enabled_changed(enabled: bool)

# Common Godot audio effect types that can be used
enum EffectType {
	REVERB, # AudioEffectReverb
	CHORUS, # AudioEffectChorus
	COMPRESSOR, # AudioEffectCompressor
	DELAY, # AudioEffectDelay
	DISTORTION, # AudioEffectDistortion
	EQ, # AudioEffectEQ
	HIGHPASS, # AudioEffectHighPassFilter
	LOWPASS, # AudioEffectLowPassFilter
	NOTCH, # AudioEffectNotchFilter
	PHASER, # AudioEffectPhaser
	PITCH_SHIFT, # AudioEffectPitchShift
	SPECTRUM_ANALYZER # AudioEffectSpectrumAnalyzer
}

## Initializes chain with optional custom name.
## @param p_chain_name Display/identifier name for chain.
func _init(p_chain_name: String = "EffectChain") -> void:
	chain_name = p_chain_name

## Adds an effect to this chain.
## @param effect AudioEffect instance to add.
## @param at_index Optional insertion index (-1 appends).
## @return int Final index where effect was inserted, or -1 on error.
func add_effect(effect: AudioEffect, at_index: int = -1) -> int:
	if not effect:
		push_error("Xedats: Cannot add null effect to chain '%s'" % chain_name)
		return -1
	
	var index: int
	if at_index < 0 or at_index >= effect_nodes.size():
		index = effect_nodes.size()
		effect_nodes.append(effect)
	else:
		index = at_index
		effect_nodes.insert(index, effect)
	
	_effect_metadata.insert(index, {
		"name": effect.resource_name if effect.resource_name else "Effect_%d" % index,
		"type": effect.get_class(),
		"enabled": true,
		"added_at": Time.get_ticks_msec()
	})
	
	effect_added.emit(index, effect)
	return index

## Removes effect at index.
## @param index Effect index to remove.
## @return bool True on success.
func remove_effect(index: int) -> bool:
	if index < 0 or index >= effect_nodes.size():
		push_error("Xedats: Invalid effect index %d for chain '%s'" % [index, chain_name])
		return false
	
	effect_nodes.remove_at(index)
	_effect_metadata.remove_at(index)
	
	effect_removed.emit(index)
	return true

## Gets effect at index.
## @param index Effect index.
## @return AudioEffect Effect instance or null.
func get_effect(index: int) -> AudioEffect:
	if index < 0 or index >= effect_nodes.size():
		return null
	return effect_nodes[index]

## Moves effect from one index to another.
## @param from_index Current effect index.
## @param to_index Target effect index.
## @return bool True on success.
func move_effect(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= effect_nodes.size():
		push_error("Xedats: Invalid from_index %d for chain '%s'" % [from_index, chain_name])
		return false
	if to_index < 0 or to_index >= effect_nodes.size():
		push_error("Xedats: Invalid to_index %d for chain '%s'" % [to_index, chain_name])
		return false
	
	var effect = effect_nodes[from_index]
	var metadata = _effect_metadata[from_index]
	
	effect_nodes.remove_at(from_index)
	_effect_metadata.remove_at(from_index)
	
	effect_nodes.insert(to_index, effect)
	_effect_metadata.insert(to_index, metadata)
	
	effect_moved.emit(from_index, to_index)
	return true

## Clears all effects and metadata from chain.
func clear_all() -> void:
	effect_nodes.clear()
	_effect_metadata.clear()

## Gets number of effects currently in chain.
## @return int Effect count.
func get_effect_count() -> int:
	return effect_nodes.size()

## Enables or disables this chain.
## @param enabled New enabled state.
func set_enabled(enabled: bool) -> void:
	is_enabled = enabled
	chain_enabled_changed.emit(enabled)

## Checks whether chain should currently be applied.
## @return bool True when enabled and not bypassed.
func is_active() -> bool:
	return is_enabled and not bypass_all

## Creates a built-in AudioEffect instance by enum type.
## @param effect_type Effect type enum value.
## @return AudioEffect Created effect instance or null.
static func create_effect(effect_type: EffectType) -> AudioEffect:
	match effect_type:
		EffectType.REVERB:
			return AudioEffectReverb.new()
		EffectType.CHORUS:
			return AudioEffectChorus.new()
		EffectType.COMPRESSOR:
			return AudioEffectCompressor.new()
		EffectType.DELAY:
			return AudioEffectDelay.new()
		EffectType.DISTORTION:
			return AudioEffectDistortion.new()
		EffectType.EQ:
			return AudioEffectEQ.new()
		EffectType.HIGHPASS:
			return AudioEffectHighPassFilter.new()
		EffectType.LOWPASS:
			return AudioEffectLowPassFilter.new()
		EffectType.NOTCH:
			return AudioEffectNotchFilter.new()
		EffectType.PHASER:
			return AudioEffectPhaser.new()
		EffectType.PITCH_SHIFT:
			return AudioEffectPitchShift.new()
		EffectType.SPECTRUM_ANALYZER:
			return AudioEffectSpectrumAnalyzer.new()
		_:
			push_error("Unknown effect type: %d" % effect_type)
			return null

## Gets metadata for effect at index.
## @param index Effect index.
## @return Dictionary Metadata dictionary or empty when invalid.
func get_effect_metadata(index: int) -> Dictionary:
	if index < 0 or index >= _effect_metadata.size():
		return {}
	return _effect_metadata[index]

## Gets deep copy of all effect metadata entries.
## @return Array[Dictionary] Metadata array copy.
func get_all_metadata() -> Array[Dictionary]:
	return _effect_metadata.duplicate(true)

## Applies active effects from chain to target bus via Xedats.
## @param bus_name Target bus name.
## @param xedats Node exposing add_bus_effect method.
## @return bool True when apply path is valid.
func apply_to_bus(bus_name: String, xedats: Node) -> bool:
	if not xedats or not xedats.has_method("add_bus_effect"):
		push_error("Xedats: Invalid XedatsSingleton reference")
		return false
	
	for i in range(effect_nodes.size()):
		var effect = effect_nodes[i]
		if effect and is_active():
			xedats.add_bus_effect(bus_name, effect)
	
	return true
