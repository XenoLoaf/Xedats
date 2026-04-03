class_name XedatsPrecomputedPropagationProfile
extends Resource

## Deterministic import-time propagation hints authored offline and applied at
## emitter spawn/init time.  This MVP intentionally avoids per-frame updates.

## Human-readable or authored identifier used by glTF extras.
@export var propagation_id: String = ""

## Optional authored probe-region identifier associated with this profile.
@export var probe_region_id: String = ""

## Linear gain multiplier applied on top of the emitter's authored gain.
@export_range(0.0, 2.0, 0.01) var gain_multiplier: float = 1.0

## Whether this profile should override the player's occlusion toggle.
@export var override_enable_occlusion: bool = false

## Occlusion state to apply when [member override_enable_occlusion] is true.
@export var enable_occlusion: bool = true

## Whether this profile should override the player's distance-filtering toggle.
@export var override_enable_distance_filtering: bool = false

## Distance-filtering state to apply when [member override_enable_distance_filtering] is true.
@export var enable_distance_filtering: bool = true

## Scalar consumed by existing Xedats occlusion hooks.
@export_range(0.0, 1.0, 0.01) var occlusion_intensity: float = 0.5

## Optional explicit bus name for this precomputed profile.  When empty, the
## binding derives a deterministic bus name from the resolution key.
@export var target_bus_name: String = ""

## Optional low-pass cutoff hint in Hz.  Negative values disable this hint.
@export var lowpass_cutoff_hz: float = -1.0

## Optional high-pass cutoff hint in Hz.  Negative values disable this hint.
@export var highpass_cutoff_hz: float = -1.0

## Optional reverb wet hint in [0, 1].  Negative values disable this hint.
@export var reverb_wet: float = -1.0

## Optional reverb room-size hint in [0, 1].  Negative values disable this hint.
@export var reverb_room_size: float = -1.0


func to_payload() -> Dictionary:
	var payload: Dictionary = {
		"xedats_precomputed_gain_multiplier": clamp(gain_multiplier, 0.0, 2.0),
		"xedats_precomputed_occlusion_intensity": clamp(occlusion_intensity, 0.0, 1.0)
	}
	if not propagation_id.is_empty():
		payload["xedats_precomputed_profile_id"] = propagation_id
	if not probe_region_id.is_empty():
		payload["xedats_precomputed_profile_probe_region"] = probe_region_id
	if override_enable_occlusion:
		payload["xedats_precomputed_enable_occlusion"] = enable_occlusion
	if override_enable_distance_filtering:
		payload["xedats_precomputed_enable_distance_filtering"] = enable_distance_filtering
	if not target_bus_name.is_empty():
		payload["xedats_precomputed_bus_name"] = target_bus_name
	if lowpass_cutoff_hz >= 0.0:
		payload["xedats_precomputed_lowpass_hz"] = max(lowpass_cutoff_hz, 20.0)
	if highpass_cutoff_hz >= 0.0:
		payload["xedats_precomputed_highpass_hz"] = max(highpass_cutoff_hz, 20.0)
	if reverb_wet >= 0.0:
		payload["xedats_precomputed_reverb_wet"] = clamp(reverb_wet, 0.0, 1.0)
	if reverb_room_size >= 0.0:
		payload["xedats_precomputed_reverb_room_size"] = clamp(reverb_room_size, 0.0, 1.0)
	return payload