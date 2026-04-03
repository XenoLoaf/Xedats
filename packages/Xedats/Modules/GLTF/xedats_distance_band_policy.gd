class_name XedatsDistanceBandPolicy
extends RefCounted

## Static helpers for distance-band policy evaluation at binding time.
## See [XedatsGLTFConfig] for the root path configuration.
##
## This utility is designed to be called once per [XedatsGLTFAudioEmitterBinding]
## [code]_ready[/code] invocation when [code]xedats_distance_policy = "texture"[/code]
## is present in the resolved payload.  It does [b]not[/b] install a per-frame update.
##
## All methods are pure, accept a profile resource via duck-typed [Resource] to
## avoid parse-order class dependency, and return safe defaults when inputs are invalid.

## Valid values for the [code]xedats_distance_policy[/code] extras key.
static var VALID_POLICIES: PackedStringArray = PackedStringArray(["none", "texture"])

## Returns the world-space straight-line distance from [param emitter_position]
## to the active listener.  Returns -1.0 when no listener is available so
## callers can detect the missing-listener case without a separate query.
static func distance_to_listener(emitter_position: Vector3) -> float:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return -1.0
	var listener: XedatsListener3D = xedats.get_current_listener()
	if listener == null:
		return -1.0
	return emitter_position.distance_to(listener.global_position)


## Builds the band-modulated [Vector2] [code]volume_variation[/code] for an
## [AudioArrayContainer] given the current listener distance.
##
## [param base_variation]   — existing volume range before distance scaling.
## [param distance]         — pre-computed listener distance (use [method distance_to_listener]).
## [param profile]          — duck-typed [XedatsDistanceBandProfile] resource.
##
## Returns [param base_variation] unchanged when [param distance] < 0
## (listener unavailable) or when [param profile] does not expose [code]gain_scale_at[/code].
static func modulate_volume_variation(
		base_variation: Vector2,
		distance: float,
		profile: Resource
) -> Vector2:
	if distance < 0.0:
		return base_variation
	if profile == null or not profile.has_method("gain_scale_at"):
		return base_variation
	var gain_scale: float = float(profile.call("gain_scale_at", distance))
	var center: float = (base_variation.x + base_variation.y) * 0.5 * gain_scale
	var half_spread: float = (base_variation.y - base_variation.x) * 0.5
	return Vector2(
		max(0.0, center - half_spread),
		min(1.0, center + half_spread)
	)


## Loads the default distance band profile from [param profile_path], falling back
## to a freshly constructed in-memory instance from [param fallback_script_path]
## when the file is missing.
## Both paths are provided by the caller so this utility remains project-agnostic.
static func load_default_profile(profile_path: String, fallback_script_path: String) -> Resource:
	var loaded: Resource = ResourceLoader.load(profile_path)
	if loaded != null and loaded.has_method("gain_scale_at"):
		return loaded
	push_warning(
		"Xedats glTF: distance band profile missing at '%s'; using built-in defaults"
		% profile_path
	)
	var fallback_script: Script = ResourceLoader.load(fallback_script_path)
	return fallback_script.new()
