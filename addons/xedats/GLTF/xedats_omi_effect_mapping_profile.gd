class_name XedatsOMIEffectMappingProfile
extends Resource

@export var chain_name: String = "OMI_AudioMaterial"
@export_range(20.0, 22000.0) var low_pass_max_hz: float = 20000.0
@export_range(20.0, 22000.0) var low_pass_min_hz: float = 1200.0
@export_range(20.0, 22000.0) var high_pass_min_hz: float = 40.0
@export_range(20.0, 22000.0) var high_pass_max_hz: float = 900.0
@export_range(0.0, 1.0) var reverb_room_size_base: float = 0.2
@export_range(0.0, 1.0) var reverb_room_size_scale: float = 0.7


func create_effect_chain_from_material(material_payload: Dictionary) -> EffectChain:
	var absorption: float = clamp(float(material_payload.get("absorption", 0.0)), 0.0, 1.0)
	var transmission: float = clamp(float(material_payload.get("transmission", 0.0)), 0.0, 1.0)
	var reflection: float = clamp(float(material_payload.get("reflection", 0.0)), 0.0, 1.0)

	var effect_chain: EffectChain = EffectChain.new(chain_name)

	var low_pass: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	low_pass.cutoff_hz = lerpf(low_pass_max_hz, low_pass_min_hz, absorption)
	effect_chain.add_effect(low_pass)

	var high_pass: AudioEffectHighPassFilter = AudioEffectHighPassFilter.new()
	high_pass.cutoff_hz = lerpf(high_pass_min_hz, high_pass_max_hz, 1.0 - transmission)
	effect_chain.add_effect(high_pass)

	var reverb: AudioEffectReverb = AudioEffectReverb.new()
	reverb.wet = reflection
	reverb.room_size = clampf(reverb_room_size_base + (reflection * reverb_room_size_scale), 0.0, 1.0)
	effect_chain.add_effect(reverb)

	return effect_chain
