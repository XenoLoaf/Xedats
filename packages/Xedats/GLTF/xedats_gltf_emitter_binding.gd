## Runtime audio emitter node created by [GLTFDocumentExtensionXedatsAudio] for
## every glTF node that carries a [code]KHR_audio_emitter[/code] extension.
##
## Lifecycle:
##   1. [method configure] is called during import with the fully-resolved
##      emitter payload (event name, gain, loop, source paths, category).
##   2. [method _ready] fires at scene instantiation and drives playback through
##      whichever Xedats service is available, in priority order:
##        a. [AudioEventSystem] named event   (event_name present + registered).
##        b. [AudioArrayContainer] multi-play  (2 or more source paths).
##        c. [XedatsSingleton.play_audio_at_position]  (single source path).
##        d. Plain [AudioStreamPlayer3D] fallback  (Xedats unavailable).
##   3. If the payload contains [code]xedats_portal_source_path[/code], a deferred
##      call to [method _auto_bind_portal_source] resolves that path in the live
##      scene tree and automatically calls [method bind_dynamic_portal_state_source].
##      The most common value is [code]"."[/code] (parent node = the door mesh).
##
## The binding node is parented to the imported [Node3D] and its [code]owner[/code]
## is set to the scene root so it appears in the Godot editor hierarchy.
class_name XedatsGLTFAudioEmitterBinding
extends Node3D

const DEFAULT_CATEGORY: String = "SFX"
## Maximum volume spread (half-range) applied by [code]xedats_texture_variance[/code]
## at its maximum value of 1.0.  Range is [code]center_gain ± TEXTURE_MAX_SPREAD[/code],
## clamped to [code][0.0, 1.0][/code].
const TEXTURE_MAX_SPREAD: float = 0.25
## Minimum cadence interval (seconds) used for Group B texture re-trigger flow.
const TEXTURE_CADENCE_MIN_SECONDS: float = 0.25
## Maximum cadence interval (seconds) used for Group B texture re-trigger flow.
const TEXTURE_CADENCE_MAX_SECONDS: float = 2.0
## Default cadence interval (seconds) used when density/profile data is missing.
const TEXTURE_CADENCE_DEFAULT_SECONDS: float = 1.0
## Script reference for the distance-band policy utility.
## Loaded as a [Script] constant to remain re-entrant-safe in headless contexts.
const DISTANCE_BAND_POLICY_SCRIPT: Script = preload("xedats_distance_band_policy.gd")
const PORTAL_STATE_POLL_INTERVAL: float = 0.1
const DEFAULT_PORTAL_STATE_OPEN_PROPERTY: StringName = &"is_open"
const DEFAULT_PORTAL_STATE_OPENNESS_PROPERTY: StringName = &"portal_openness"
const SIGNAL_PORTAL_OPENNESS_CHANGED: StringName = &"portal_openness_changed"
const SIGNAL_OPEN_STATE_CHANGED: StringName = &"open_state_changed"
const SIGNAL_OPENED: StringName = &"opened"
const SIGNAL_CLOSED: StringName = &"closed"

static var _precomputed_bus_configured: Dictionary = {}

var _resolved_payload: Dictionary = {}
var _fallback_player: AudioStreamPlayer3D = null
var _runtime_warning_seen: Dictionary = {}
## Lazily loaded distance band profile resource.  Populated on first use by
## [method _get_distance_band_profile].
var _distance_band_profile: Resource = null
var _portal_state_source_ref: WeakRef = null
var _portal_state_open_property: StringName = DEFAULT_PORTAL_STATE_OPEN_PROPERTY
var _portal_state_openness_property: StringName = DEFAULT_PORTAL_STATE_OPENNESS_PROPERTY
var _portal_state_poll_elapsed: float = 0.0
var _last_bound_portal_openness: float = -1.0
var _texture_cadence_enabled: bool = false
var _texture_cadence_seconds: float = 0.0
var _texture_cadence_elapsed: float = 0.0
var _texture_cadence_container: AudioArrayContainer = null
var _texture_cadence_category: String = DEFAULT_CATEGORY
var _suppress_runtime_warnings: bool = false


## Stores a deep copy of [param payload] for use during [method _ready].
## Must be called before the node enters the scene tree.
## [param payload] keys: [code]event_name[/code], [code]gain[/code],
## [code]loop[/code], [code]source_paths[/code], [code]category[/code],
## [code]source_indices[/code], [code]emitter_index[/code].
func configure(payload: Dictionary) -> void:
	_resolved_payload = payload.duplicate(true)
	_runtime_warning_seen.clear()
	_suppress_runtime_warnings = bool(_resolved_payload.get("xedats_suppress_runtime_warnings", false))


## Returns a debug-friendly snapshot of the binding's resolved payload,
## runtime-path metadata, fallback-player state, and dynamic-service record.
## This is intended for HUD/inspector tooling and remains safe when Xedats
## services are unavailable.
func get_debug_snapshot() -> Dictionary:
	var warning_keys: PackedStringArray = PackedStringArray()
	for warning_key: Variant in _runtime_warning_seen.keys():
		warning_keys.append(String(warning_key))

	var snapshot: Dictionary = {
		"binding_name": String(name),
		"binding_path": String(get_path()) if is_inside_tree() else "",
		"parent_name": String(get_parent().name) if get_parent() != null else "",
		"parent_path": String(get_parent().get_path()) if get_parent() != null and get_parent().is_inside_tree() else "",
		"payload": _resolved_payload.duplicate(true),
		"runtime_path": String(get_meta(&"xedats_runtime_path", "")),
		"runtime_event_fallback": String(get_meta(&"xedats_runtime_event_fallback", "")),
		"fallback_player_present": is_instance_valid(_fallback_player),
		"fallback_player_playing": is_instance_valid(_fallback_player) and _fallback_player.playing,
		"fallback_player_bus": _fallback_player.bus if is_instance_valid(_fallback_player) else "",
		"dynamic_registered": bool(get_meta(&"xedats_dynamic_registered", false)),
		"dynamic_player_attached": bool(get_meta(&"xedats_dynamic_player_attached", false)),
		"portal_adapter_bound": bool(get_meta(&"xedats_dynamic_portal_adapter_bound", false)),
		"portal_bound_openness": float(get_meta(&"xedats_dynamic_portal_bound_openness", -1.0)),
		"portal_auto_bind_resolved_path": String(get_meta(&"xedats_portal_auto_bind_resolved_path", "")),
		"texture_cadence_enabled": bool(get_meta(&"xedats_texture_cadence_enabled", false)),
		"texture_cadence_seconds": float(get_meta(&"xedats_texture_cadence_seconds", 0.0)),
		"texture_volume_variation": get_meta(&"xedats_texture_volume_variation", Vector2.ZERO),
		"distance_volume_variation": get_meta(&"xedats_distance_volume_variation", Vector2.ZERO),
		"precomputed_resolution_source": String(get_meta(&"xedats_precomputed_resolution_source", "")),
		"precomputed_resolution_key": String(get_meta(&"xedats_precomputed_resolution_key", "")),
		"precomputed_profile_path": String(get_meta(&"xedats_precomputed_profile_path", "")),
		"precomputed_bus": String(get_meta(&"xedats_precomputed_bus", "")),
		"runtime_warning_keys": warning_keys,
	}

	var service: XedatsDynamicApproximationService = XedatsDynamicApproximationService.instance()
	if service != null:
		snapshot["dynamic_record"] = service.get_record_debug_state(self )

	return snapshot


## Entry point: fires once when the scene containing this binding enters the
## scene tree.  Resolves playback path in priority order (see class docstring).
## Short-circuits silently when the payload is empty or the category is muted.
func _ready() -> void:
	# Defer portal source auto-bind so the entire scene tree is settled first.
	if _resolved_payload.has("xedats_portal_source_path"):
		call_deferred(&"_auto_bind_portal_source")

	if _resolved_payload.is_empty():
		return

	var category: String = String(_resolved_payload.get("category", DEFAULT_CATEGORY))
	if category.is_empty():
		category = DEFAULT_CATEGORY

	var base_gain: float = clamp(float(_resolved_payload.get("gain", 1.0)), 0.0, 1.0)
	var effective_gain: float = _effective_gain(base_gain)
	_record_precomputed_binding_metadata(base_gain, effective_gain)

	if _is_category_muted(category):
		set_meta(&"xedats_runtime_path", "muted_skip")
		return

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		_warn_runtime_once(
			"missing_xedats_singleton",
			"Xedats glTF: XedatsSingleton unavailable for '%s'; using local AudioStreamPlayer3D fallback"
			% String(name)
		)
		_fallback_play(effective_gain, category)
		return

	var event_system: AudioEventSystem = xedats.get_event_system()
	var event_name: String = String(_resolved_payload.get("event_name", ""))
	if event_system == null and not event_name.is_empty():
		_warn_runtime_once(
			"missing_event_system",
			"Xedats glTF: AudioEventSystem unavailable for event '%s'; falling back to clip playback"
			% event_name
		)

	if event_system != null and not event_name.is_empty():
		var event: AudioEventSystem.AudioEvent = event_system.get_event(event_name)
		if event != null:
			var player: XedatsPlayer3D = event_system.trigger_event(event_name, global_position, effective_gain, -1.0)
			if player != null:
				player.audio_category = category
				_apply_loop_if_possible(player)
				_apply_precomputed_player_overrides(player)
				_apply_precomputed_bus_routing(player)
				_register_with_dynamic_service(player)
				set_meta(&"xedats_runtime_path", "xedats_event")
				return
			_warn_runtime_once(
				"event_trigger_failed",
				"Xedats glTF: event '%s' trigger returned null player; falling back to clip playback"
				% event_name
			)
		set_meta(&"xedats_runtime_event_fallback", event_name)

	var streams: Array[AudioStream] = _resolve_streams()
	if streams.is_empty():
		push_warning("Xedats glTF: emitter has no loadable audio streams, skipping playback")
		set_meta(&"xedats_runtime_path", "no_streams")
		return

	if streams.size() > 1:
		var container: AudioArrayContainer = AudioArrayContainer.new()
		container.container_name = "gltf_emitter_%s" % String(name)
		container.playback_mode = AudioArrayContainer.PlaybackMode.RANDOM_NO_REPEAT
		container.StreamContainer = streams
		container.loop = bool(_resolved_payload.get("loop", false))
		var base_vol_var: Vector2 = _texture_volume_variation(effective_gain)
		var final_vol_var: Vector2 = _apply_distance_band_modulation(base_vol_var)
		container.volume_variation = final_vol_var
		container.pitch_variation = Vector2(1.0, 1.0)
		set_meta(&"xedats_texture_volume_variation", base_vol_var)
		# Only record the distance-modulated variation when the distance policy is active
		# so that the "none" policy leaves no distance meta (test-observable sentinel).
		if String(_resolved_payload.get("xedats_distance_policy", "")) == "texture":
			set_meta(&"xedats_distance_volume_variation", final_vol_var)

		var cadence_seconds: float = _resolve_texture_cadence_seconds()
		if cadence_seconds > 0.0:
			_start_texture_cadence(container, category, cadence_seconds)
			var cadence_player: XedatsPlayer3D = _play_texture_cadence_tick(xedats)
			if cadence_player != null:
				set_meta(&"xedats_runtime_path", "xedats_texture_cadence")
				return
			_warn_runtime_once(
				"texture_cadence_player_failed",
				"Xedats glTF: texture cadence tick failed; falling back to single container playback"
			)
			_stop_texture_cadence()

		var pooled_player: XedatsPlayer3D = xedats.play_audio_container_at_position(container, global_position, category)
		if pooled_player != null:
			_apply_loop_if_possible(pooled_player)
			_apply_precomputed_player_overrides(pooled_player)
			_apply_precomputed_bus_routing(pooled_player)
			_register_with_dynamic_service(pooled_player)
			set_meta(&"xedats_runtime_path", "xedats_container")
			return
		_warn_runtime_once(
			"container_player_failed",
			"Xedats glTF: play_audio_container_at_position returned null; using local fallback"
		)
		_fallback_play(effective_gain, category, streams)
		return

	var stream: AudioStream = streams[0]
	var direct_player: XedatsPlayer3D = xedats.play_audio_at_position(stream, global_position, effective_gain, category)
	if direct_player != null:
		_apply_loop_if_possible(direct_player)
		_apply_precomputed_player_overrides(direct_player)
		_apply_precomputed_bus_routing(direct_player)
		_register_with_dynamic_service(direct_player)
		set_meta(&"xedats_runtime_path", "xedats_direct")
		return

	_warn_runtime_once(
		"direct_player_failed",
		"Xedats glTF: play_audio_at_position returned null; using local fallback"
	)
	_fallback_play(effective_gain, category, streams)


func _process(delta: float) -> void:
	_process_texture_cadence(delta)
	if _portal_state_source_ref == null:
		return
	var source: Node = _portal_state_source_ref.get_ref() as Node
	if not is_instance_valid(source):
		clear_dynamic_portal_state_source()
		return
	_portal_state_poll_elapsed += delta
	if _portal_state_poll_elapsed < PORTAL_STATE_POLL_INTERVAL:
		return
	_portal_state_poll_elapsed = 0.0
	_sync_bound_portal_state(source)


## Registers this binding with [XedatsDynamicApproximationService] when
## [code]xedats_distance_policy = "texture"[/code] is in the resolved payload.
## Pass [param player] to enable dynamic gain updates for looping emitters.
func _register_with_dynamic_service(player: XedatsPlayer3D) -> void:
	if String(_resolved_payload.get("xedats_distance_policy", "")) != "texture":
		return
	var service: XedatsDynamicApproximationService = XedatsDynamicApproximationService.get_or_create(self )
	if service == null:
		return
	set_meta(&"xedats_dynamic_player_attached", player != null)

	if has_meta(&"xedats_dynamic_registered"):
		service.update_emitter_player(self , player)
		return

	var profile: Resource = _get_distance_band_profile()
	if service.register_emitter(self , player, _resolved_payload, profile):
		set_meta(&"xedats_dynamic_registered", true)


## Applies a runtime portal openness factor to this emitter's dynamic
## approximation record. Useful for door/window systems that want immediate
## audio response without owning the service directly.
##
## [param openness] 0.0 = fully closed, 1.0 = fully open.
## [return]         [code]true[/code] when the dynamic service is present and this
##                  binding is registered.
func set_dynamic_portal_openness(openness: float) -> bool:
	var service: XedatsDynamicApproximationService = XedatsDynamicApproximationService.instance()
	if service == null:
		return false
	return service.set_emitter_portal_openness(self , openness)


## Applies a runtime gain scale used when this emitter's linked portal is fully
## closed. This keeps the binding API generic for future door/window adapters.
##
## [param gain_scale] Gain scale at portal_openness = 0.0.
## [return]           [code]true[/code] when the dynamic service is present and this
##                    binding is registered.
func set_dynamic_portal_closed_gain_scale(gain_scale: float) -> bool:
	var service: XedatsDynamicApproximationService = XedatsDynamicApproximationService.instance()
	if service == null:
		return false
	return service.set_emitter_portal_closed_gain_scale(self , gain_scale)


## Binds a live door/window/portal node as the source of runtime openness updates.
## Common state signals are connected for immediate changes, and a bounded poll
## keeps property-only sources in sync.
func bind_dynamic_portal_state_source(
		source_node: Node,
		open_property: StringName = DEFAULT_PORTAL_STATE_OPEN_PROPERTY,
		openness_property: StringName = DEFAULT_PORTAL_STATE_OPENNESS_PROPERTY,
		emit_warning: bool = true
) -> bool:
	if not is_instance_valid(source_node):
		return false
	if not _can_sample_portal_state(source_node, open_property, openness_property):
		if emit_warning and not _suppress_runtime_warnings:
			push_warning(
				"Xedats glTF: portal state source '%s' exposes neither '%s' nor '%s'; skipping adapter bind"
				% [String(source_node.name), String(open_property), String(openness_property)]
			)
		return false
	clear_dynamic_portal_state_source()
	_portal_state_source_ref = weakref(source_node)
	_portal_state_open_property = open_property
	_portal_state_openness_property = openness_property
	_portal_state_poll_elapsed = PORTAL_STATE_POLL_INTERVAL
	_last_bound_portal_openness = -1.0
	_connect_portal_state_signals(source_node)
	set_meta(&"xedats_dynamic_portal_source_name", String(source_node.name))
	set_meta(&"xedats_dynamic_portal_adapter_bound", true)
	_sync_bound_portal_state(source_node, true)
	_update_process_state()
	return true


## Clears any bound portal-state source and disconnects adapter hooks.
func clear_dynamic_portal_state_source() -> void:
	var source: Node = null
	if _portal_state_source_ref != null:
		source = _portal_state_source_ref.get_ref() as Node
	_disconnect_portal_state_signals(source)
	_portal_state_source_ref = null
	_portal_state_poll_elapsed = 0.0
	_last_bound_portal_openness = -1.0
	remove_meta(&"xedats_dynamic_portal_source_name")
	remove_meta(&"xedats_dynamic_portal_adapter_bound")
	_update_process_state()


## Resolves [code]xedats_portal_source_path[/code] from the importer payload
## and calls [method bind_dynamic_portal_state_source] automatically.
## Called deferred from [method _ready] so the full scene tree is available.[br]
## Search order:[br]
##   1. Relative to [b]parent[/b] node — [code]"."[/code] binds the parent itself,
##      which is the most common case (the glTF door node IS the portal source).[br]
##   2. Relative to [b]this[/b] binding node.[br]
##   3. Absolute from [b]scene root[/b] (path must start with [code]/[/code]).
func _auto_bind_portal_source() -> void:
	var path_string: String = String(_resolved_payload.get("xedats_portal_source_path", "")).strip_edges()
	if path_string.is_empty():
		return

	var node_path: NodePath = NodePath(path_string)
	var source: Node = null

	# 1. Relative to parent (covers "." → the door node itself, "../Sibling", etc.)
	var parent: Node = get_parent()
	if parent != null:
		source = parent.get_node_or_null(node_path)

	# 2. Relative to this binding
	if source == null:
		source = get_node_or_null(node_path)

	# 3. Absolute from scene root
	if source == null and path_string.begins_with("/"):
		source = get_tree().root.get_node_or_null(node_path)

	if source == null:
		if not _suppress_runtime_warnings:
			push_warning(
				"Xedats glTF: xedats_portal_source_path '%s' could not be resolved from '%s'; skipping auto-bind"
				% [path_string, String(name)]
			)
		return

	var bound: bool = bind_dynamic_portal_state_source(source)
	if not bound:
		if not _suppress_runtime_warnings:
			push_warning(
				"Xedats glTF: portal source '%s' (resolved from path '%s') does not expose a readable portal state; skipping auto-bind"
				% [String(source.name), path_string]
			)
		return

	set_meta(&"xedats_portal_auto_bind_resolved_path", path_string)


## Unregisters this binding from the dynamic approximation service when the node
## exits the scene tree.  No-op when this binding was never registered.
func _exit_tree() -> void:
	_stop_texture_cadence()
	clear_dynamic_portal_state_source()
	if not has_meta(&"xedats_dynamic_registered"):
		return
	var service: XedatsDynamicApproximationService = XedatsDynamicApproximationService.instance()
	if service != null:
		service.unregister_emitter(self )


## Loads all [code]source_paths[/code] from the payload as [AudioStream] resources
## and returns them as a typed array.  Streams that fail to load are skipped with
## a warning so partial failures do not silence valid clips.  Each stream is
## passed through [method _stream_with_loop] before being added.
func _resolve_streams() -> Array[AudioStream]:
	var resolved_streams: Array[AudioStream] = []
	var source_paths_variant: Variant = _resolved_payload.get("source_paths", [])
	if source_paths_variant is Array:
		for source_path_variant: Variant in source_paths_variant:
			var source_path: String = String(source_path_variant)
			if source_path.is_empty():
				continue
			var loaded: Resource = ResourceLoader.load(source_path)
			if loaded is AudioStream:
				resolved_streams.append(_stream_with_loop(loaded as AudioStream))
			else:
				push_warning("Xedats glTF: failed to load stream path '%s'" % source_path)
	return resolved_streams


## Minimal playback path used when [XedatsSingleton] is absent.  Picks one
## stream at random, attaches a fresh [AudioStreamPlayer3D] as a child, and
## calls [code]play()[/code].  Volume is mapped linearly via [method linear_to_db].
func _fallback_play(
		effective_gain: float,
		category: String = DEFAULT_CATEGORY,
		pre_resolved_streams: Array[AudioStream] = []
) -> void:
	var streams: Array[AudioStream] = pre_resolved_streams
	if streams.is_empty():
		streams = _resolve_streams()
	if streams.is_empty():
		set_meta(&"xedats_runtime_path", "fallback_no_streams")
		return

	var selected_stream: AudioStream = streams[randi() % streams.size()]

	_fallback_player = AudioStreamPlayer3D.new()
	_fallback_player.name = "GLTFAudioEmitterFallback"
	_fallback_player.bus = category if AudioServer.get_bus_index(category) >= 0 else "Master"
	_fallback_player.stream = selected_stream
	_fallback_player.volume_db = linear_to_db(effective_gain)
	add_child(_fallback_player)
	_fallback_player.play()
	set_meta(&"xedats_runtime_path", "fallback_local")


func _warn_runtime_once(warning_key: String, warning_text: String) -> void:
	if _runtime_warning_seen.has(warning_key):
		return
	_runtime_warning_seen[warning_key] = true
	push_warning(warning_text)


## Returns [param stream] unchanged when loop is [code]false[/code].  When loop
## is [code]true[/code] returns a duplicate with the loop flag/mode set:[br]
##   [b]AudioStreamWAV[/b]       — [code]loop_mode = LOOP_FORWARD[/code].[br]
##   [b]AudioStreamOggVorbis[/b] — [code]loop = true[/code].[br]
## Duplicating avoids mutating shared preloaded resources.
func _stream_with_loop(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null

	var should_loop: bool = bool(_resolved_payload.get("loop", false))
	if not should_loop:
		return stream

	if stream is AudioStreamWAV:
		var wav_stream: AudioStreamWAV = (stream as AudioStreamWAV).duplicate()
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		return wav_stream

	if stream is AudioStreamOggVorbis:
		var ogg_stream: AudioStreamOggVorbis = (stream as AudioStreamOggVorbis).duplicate()
		ogg_stream.loop = true
		return ogg_stream

	return stream


## Retrofits loop behaviour onto a pooled [XedatsPlayer3D] after playback has
## already been requested (i.e. when the pool had no idle player with the stream
## pre-set).  No-op when [param player] is null or loop is false.
func _apply_loop_if_possible(player: XedatsPlayer3D) -> void:
	if player == null:
		return

	if bool(_resolved_payload.get("loop", false)) and player.stream != null:
		player.stream = _stream_with_loop(player.stream)


## Applies distance-band gain scaling to [param base_variation] when
## [code]xedats_distance_policy = "texture"[/code] is in the resolved payload.
## Returns [param base_variation] unmodified when the policy is absent/"none",
## or when no listener is available, or when the band profile cannot be loaded.
func _apply_distance_band_modulation(base_variation: Vector2) -> Vector2:
	var policy: String = String(_resolved_payload.get("xedats_distance_policy", ""))
	if policy != "texture":
		return base_variation
	var distance: float = float(
		DISTANCE_BAND_POLICY_SCRIPT.distance_to_listener(global_position)
	)
	if distance < 0.0:
		# No listener available — safe no-op, distance band cannot be evaluated.
		return base_variation
	var profile: Resource = _get_distance_band_profile()
	return DISTANCE_BAND_POLICY_SCRIPT.modulate_volume_variation(
		base_variation,
		distance,
		profile
	)


## Lazily loads the distance band profile, caching the result for the
## lifetime of this binding node.  Falls back to a built-in default instance
## when the authored .tres file is absent.
func _get_distance_band_profile() -> Resource:
	if _distance_band_profile != null:
		return _distance_band_profile
	_distance_band_profile = DISTANCE_BAND_POLICY_SCRIPT.load_default_profile(
		XedatsGLTFConfig.resources_root() + "/GLTF/xedats_distance_band_profile_default.tres",
		XedatsGLTFConfig.modules_root() + "/GLTF/xedats_distance_band_profile.gd"
	)
	return _distance_band_profile


func _effective_gain(base_gain: float) -> float:
	var gain_multiplier: float = clamp(
		float(_resolved_payload.get("xedats_precomputed_gain_multiplier", 1.0)),
		0.0,
		2.0
	)
	return clamp(base_gain * gain_multiplier, 0.0, 1.0)


func _record_precomputed_binding_metadata(base_gain: float, effective_gain: float) -> void:
	if not _resolved_payload.has("xedats_precomputed_profile_path"):
		return
	set_meta(&"xedats_precomputed_profile_path", String(_resolved_payload.get("xedats_precomputed_profile_path", "")))
	set_meta(&"xedats_precomputed_resolution_key", String(_resolved_payload.get("xedats_precomputed_resolution_key", "")))
	set_meta(&"xedats_precomputed_resolution_source", String(_resolved_payload.get("xedats_precomputed_resolution_source", "")))
	set_meta(&"xedats_precomputed_gain_multiplier", float(_resolved_payload.get("xedats_precomputed_gain_multiplier", 1.0)))
	set_meta(&"xedats_precomputed_base_gain", base_gain)
	set_meta(&"xedats_precomputed_effective_gain", effective_gain)
	if _resolved_payload.has("xedats_precomputed_enable_occlusion"):
		set_meta(&"xedats_precomputed_enable_occlusion", bool(_resolved_payload.get("xedats_precomputed_enable_occlusion", true)))
	if _resolved_payload.has("xedats_precomputed_enable_distance_filtering"):
		set_meta(
			&"xedats_precomputed_enable_distance_filtering",
			bool(_resolved_payload.get("xedats_precomputed_enable_distance_filtering", true))
		)
	if _resolved_payload.has("xedats_precomputed_occlusion_intensity"):
		set_meta(
			&"xedats_precomputed_occlusion_intensity",
			float(_resolved_payload.get("xedats_precomputed_occlusion_intensity", 0.5))
		)
	if _resolved_payload.has("xedats_precomputed_lowpass_hz"):
		set_meta(&"xedats_precomputed_lowpass_hz", float(_resolved_payload.get("xedats_precomputed_lowpass_hz", -1.0)))
	if _resolved_payload.has("xedats_precomputed_highpass_hz"):
		set_meta(&"xedats_precomputed_highpass_hz", float(_resolved_payload.get("xedats_precomputed_highpass_hz", -1.0)))
	if _resolved_payload.has("xedats_precomputed_reverb_wet"):
		set_meta(&"xedats_precomputed_reverb_wet", float(_resolved_payload.get("xedats_precomputed_reverb_wet", -1.0)))
	if _resolved_payload.has("xedats_precomputed_reverb_room_size"):
		set_meta(&"xedats_precomputed_reverb_room_size", float(_resolved_payload.get("xedats_precomputed_reverb_room_size", -1.0)))


func _apply_precomputed_player_overrides(player: XedatsPlayer3D) -> void:
	if player == null:
		return
	if _resolved_payload.has("xedats_precomputed_enable_occlusion"):
		player.enable_occlusion = bool(_resolved_payload.get("xedats_precomputed_enable_occlusion", true))
	if _resolved_payload.has("xedats_precomputed_enable_distance_filtering"):
		player.enable_distance_filtering = bool(
			_resolved_payload.get("xedats_precomputed_enable_distance_filtering", true)
		)
	if _resolved_payload.has("xedats_precomputed_occlusion_intensity"):
		player.occlusion_intensity = clamp(
			float(_resolved_payload.get("xedats_precomputed_occlusion_intensity", 0.5)),
			0.0,
			1.0
		)


func _apply_precomputed_bus_routing(player: XedatsPlayer3D) -> void:
	if player == null:
		return
	if not _has_precomputed_effect_hints():
		return

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return

	var bus_name: String = _resolve_precomputed_bus_name()
	if bus_name.is_empty():
		return

	_ensure_precomputed_bus_configured(xedats, bus_name)
	player.bus = bus_name
	set_meta(&"xedats_precomputed_bus", bus_name)


func _has_precomputed_effect_hints() -> bool:
	return _resolved_payload.has("xedats_precomputed_lowpass_hz") \
		or _resolved_payload.has("xedats_precomputed_highpass_hz") \
		or _resolved_payload.has("xedats_precomputed_reverb_wet") \
		or _resolved_payload.has("xedats_precomputed_reverb_room_size")


func _resolve_precomputed_bus_name() -> String:
	var explicit_bus_name: String = String(_resolved_payload.get("xedats_precomputed_bus_name", "")).strip_edges()
	if not explicit_bus_name.is_empty():
		return explicit_bus_name
	var resolution_key: String = String(_resolved_payload.get("xedats_precomputed_resolution_key", "")).strip_edges()
	if resolution_key.is_empty():
		return ""
	return "XedatsPrecomputed_%s" % _sanitize_bus_suffix(resolution_key)


func _sanitize_bus_suffix(raw_value: String) -> String:
	var safe_value: String = raw_value.strip_edges().replace(" ", "_")
	var result: String = ""
	for i: int in range(safe_value.length()):
		var character: String = safe_value.substr(i, 1)
		var codepoint: int = character.unicode_at(0)
		var is_ascii_upper: bool = codepoint >= 65 and codepoint <= 90
		var is_ascii_lower: bool = codepoint >= 97 and codepoint <= 122
		var is_digit: bool = codepoint >= 48 and codepoint <= 57
		if is_ascii_upper or is_ascii_lower or is_digit or character == "_":
			result += character
		else:
			result += "_"
	if result.is_empty():
		return "Profile"
	return result


func _ensure_precomputed_bus_configured(xedats: XedatsSingleton, bus_name: String) -> void:
	if _precomputed_bus_configured.has(bus_name):
		return

	xedats.create_audio_bus(bus_name, "Master")

	if _resolved_payload.has("xedats_precomputed_lowpass_hz"):
		var low_pass: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
		low_pass.cutoff_hz = max(float(_resolved_payload.get("xedats_precomputed_lowpass_hz", 20000.0)), 20.0)
		xedats.add_bus_effect(bus_name, low_pass)

	if _resolved_payload.has("xedats_precomputed_highpass_hz"):
		var high_pass: AudioEffectHighPassFilter = AudioEffectHighPassFilter.new()
		high_pass.cutoff_hz = max(float(_resolved_payload.get("xedats_precomputed_highpass_hz", 20.0)), 20.0)
		xedats.add_bus_effect(bus_name, high_pass)

	if _resolved_payload.has("xedats_precomputed_reverb_wet") \
			or _resolved_payload.has("xedats_precomputed_reverb_room_size"):
		var reverb: AudioEffectReverb = AudioEffectReverb.new()
		reverb.wet = clamp(float(_resolved_payload.get("xedats_precomputed_reverb_wet", 0.0)), 0.0, 1.0)
		reverb.room_size = clamp(float(_resolved_payload.get("xedats_precomputed_reverb_room_size", 0.5)), 0.0, 1.0)
		xedats.add_bus_effect(bus_name, reverb)

	_precomputed_bus_configured[bus_name] = true


## Derives [code]volume_variation[/code] for an [AudioArrayContainer] from the
## resolved payload, factoring in [code]xedats_texture_density[/code] and
## [code]xedats_texture_variance[/code] when present.[br]
## When both extras are absent the returned [Vector2] equals
## [code]Vector2(gain, gain)[/code] — preserving prior behavior with no spread.
func _texture_volume_variation(gain: float) -> Vector2:
	var texture_density: float = float(_resolved_payload.get("xedats_texture_density", 1.0))
	var texture_variance: float = float(_resolved_payload.get("xedats_texture_variance", 0.0))
	var center_gain: float = gain * lerp(0.5, 1.0, texture_density)
	var half_spread: float = texture_variance * TEXTURE_MAX_SPREAD
	return Vector2(
		max(0.0, center_gain - half_spread),
		min(1.0, center_gain + half_spread)
	)


func _resolve_texture_cadence_seconds() -> float:
	var has_profile: bool = _resolved_payload.has("xedats_texture_profile") \
		and not String(_resolved_payload.get("xedats_texture_profile", "")).strip_edges().is_empty()
	var has_density: bool = _resolved_payload.has("xedats_texture_density")
	var has_variance: bool = _resolved_payload.has("xedats_texture_variance")
	var has_texture_extras: bool = has_profile or has_density or has_variance
	if not has_texture_extras:
		return 0.0
	if bool(_resolved_payload.get("loop", false)):
		return 0.0

	var density: float = clampf(float(_resolved_payload.get("xedats_texture_density", 0.5)), 0.0, 1.0)
	var variance: float = clampf(float(_resolved_payload.get("xedats_texture_variance", 0.0)), 0.0, 1.0)
	var profile: String = String(_resolved_payload.get("xedats_texture_profile", "")).strip_edges().to_lower()

	var cadence_seconds: float = lerpf(TEXTURE_CADENCE_MAX_SECONDS, TEXTURE_CADENCE_MIN_SECONDS, density)
	if profile.contains("dense"):
		cadence_seconds *= 0.75
	elif profile.contains("light"):
		cadence_seconds *= 1.2
	elif profile.contains("crowd"):
		cadence_seconds *= 0.9
	elif profile.contains("machinery"):
		cadence_seconds *= 0.6
	elif profile.is_empty():
		cadence_seconds = lerpf(TEXTURE_CADENCE_DEFAULT_SECONDS, TEXTURE_CADENCE_MIN_SECONDS, density)

	# Higher authored variance slightly increases trigger spacing to avoid clutter.
	cadence_seconds *= lerpf(1.0, 1.2, variance)
	return clampf(cadence_seconds, TEXTURE_CADENCE_MIN_SECONDS, TEXTURE_CADENCE_MAX_SECONDS)


func _start_texture_cadence(container: AudioArrayContainer, category: String, cadence_seconds: float) -> void:
	_texture_cadence_enabled = cadence_seconds > 0.0 and container != null
	_texture_cadence_seconds = cadence_seconds
	_texture_cadence_elapsed = cadence_seconds
	_texture_cadence_container = container
	_texture_cadence_category = category
	set_meta(&"xedats_texture_cadence_enabled", _texture_cadence_enabled)
	set_meta(&"xedats_texture_cadence_seconds", _texture_cadence_seconds)
	_update_process_state()


func _stop_texture_cadence() -> void:
	_texture_cadence_enabled = false
	_texture_cadence_seconds = 0.0
	_texture_cadence_elapsed = 0.0
	_texture_cadence_container = null
	_texture_cadence_category = DEFAULT_CATEGORY
	set_meta(&"xedats_texture_cadence_enabled", false)
	set_meta(&"xedats_texture_cadence_seconds", 0.0)
	_update_process_state()


func _process_texture_cadence(delta: float) -> void:
	if not _texture_cadence_enabled:
		return
	if _texture_cadence_container == null:
		_stop_texture_cadence()
		return
	if _is_category_muted(_texture_cadence_category):
		return

	_texture_cadence_elapsed += delta
	if _texture_cadence_elapsed < _texture_cadence_seconds:
		return
	_texture_cadence_elapsed = 0.0

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		_warn_runtime_once(
			"texture_cadence_missing_xedats",
			"Xedats glTF: XedatsSingleton unavailable during texture cadence updates; stopping cadence"
		)
		_stop_texture_cadence()
		return

	var cadence_player: XedatsPlayer3D = _play_texture_cadence_tick(xedats)
	if cadence_player == null:
		_warn_runtime_once(
			"texture_cadence_tick_failed",
			"Xedats glTF: texture cadence tick returned null player"
		)


func _play_texture_cadence_tick(xedats: XedatsSingleton) -> XedatsPlayer3D:
	if xedats == null or _texture_cadence_container == null:
		return null
	var player: XedatsPlayer3D = xedats.play_audio_container_at_position(
		_texture_cadence_container,
		global_position,
		_texture_cadence_category
	)
	if player == null:
		return null
	_apply_precomputed_player_overrides(player)
	_apply_precomputed_bus_routing(player)
	return player


func _update_process_state() -> void:
	set_process(_portal_state_source_ref != null or _texture_cadence_enabled)


## Returns [code]true[/code] when [param category] is muted according to
## [AudioStateManager] or when the category's master volume is effectively zero
## ([code]<= 0.0001[/code]).  Returns [code]false[/code] when [XedatsSingleton]
## is unavailable so the binding always attempts playback as a safe default.
func _is_category_muted(category: String) -> bool:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return false

	var state_manager: AudioStateManager = xedats.get_state_manager()
	if state_manager != null and state_manager.is_category_muted(category):
		return true

	return xedats.get_category_volume(category) <= 0.0001


func _connect_portal_state_signals(source_node: Node) -> void:
	if source_node == null:
		return
	if source_node.has_signal(SIGNAL_PORTAL_OPENNESS_CHANGED) and not source_node.is_connected(SIGNAL_PORTAL_OPENNESS_CHANGED, _on_portal_openness_changed):
		source_node.connect(SIGNAL_PORTAL_OPENNESS_CHANGED, _on_portal_openness_changed)
	if source_node.has_signal(SIGNAL_OPEN_STATE_CHANGED) and not source_node.is_connected(SIGNAL_OPEN_STATE_CHANGED, _on_portal_open_state_changed):
		source_node.connect(SIGNAL_OPEN_STATE_CHANGED, _on_portal_open_state_changed)
	if source_node.has_signal(SIGNAL_OPENED) and not source_node.is_connected(SIGNAL_OPENED, _on_portal_opened):
		source_node.connect(SIGNAL_OPENED, _on_portal_opened)
	if source_node.has_signal(SIGNAL_CLOSED) and not source_node.is_connected(SIGNAL_CLOSED, _on_portal_closed):
		source_node.connect(SIGNAL_CLOSED, _on_portal_closed)


func _disconnect_portal_state_signals(source_node: Node) -> void:
	if source_node == null or not is_instance_valid(source_node):
		return
	if source_node.has_signal(SIGNAL_PORTAL_OPENNESS_CHANGED) and source_node.is_connected(SIGNAL_PORTAL_OPENNESS_CHANGED, _on_portal_openness_changed):
		source_node.disconnect(SIGNAL_PORTAL_OPENNESS_CHANGED, _on_portal_openness_changed)
	if source_node.has_signal(SIGNAL_OPEN_STATE_CHANGED) and source_node.is_connected(SIGNAL_OPEN_STATE_CHANGED, _on_portal_open_state_changed):
		source_node.disconnect(SIGNAL_OPEN_STATE_CHANGED, _on_portal_open_state_changed)
	if source_node.has_signal(SIGNAL_OPENED) and source_node.is_connected(SIGNAL_OPENED, _on_portal_opened):
		source_node.disconnect(SIGNAL_OPENED, _on_portal_opened)
	if source_node.has_signal(SIGNAL_CLOSED) and source_node.is_connected(SIGNAL_CLOSED, _on_portal_closed):
		source_node.disconnect(SIGNAL_CLOSED, _on_portal_closed)


func _on_portal_openness_changed(openness: float) -> void:
	_apply_bound_portal_openness(clampf(openness, 0.0, 1.0), true)


func _on_portal_open_state_changed(is_open: bool) -> void:
	_apply_bound_portal_openness(1.0 if is_open else 0.0, true)


func _on_portal_opened() -> void:
	_apply_bound_portal_openness(1.0, true)


func _on_portal_closed() -> void:
	_apply_bound_portal_openness(0.0, true)


func _sync_bound_portal_state(source_node: Node, force: bool = false) -> void:
	var sampled_openness: float = _sample_portal_openness(source_node)
	if sampled_openness < 0.0:
		return
	_apply_bound_portal_openness(sampled_openness, force)


func _apply_bound_portal_openness(openness: float, force: bool = false) -> void:
	var normalized: float = clampf(openness, 0.0, 1.0)
	var current_dynamic_openness: float = _current_dynamic_portal_openness()
	if not force:
		if _last_bound_portal_openness >= 0.0 and is_equal_approx(_last_bound_portal_openness, normalized):
			return
		if current_dynamic_openness >= 0.0 and is_equal_approx(current_dynamic_openness, normalized):
			_last_bound_portal_openness = normalized
			return
	_last_bound_portal_openness = normalized
	set_meta(&"xedats_dynamic_portal_bound_openness", normalized)
	set_dynamic_portal_openness(normalized)


func _current_dynamic_portal_openness() -> float:
	var service: XedatsDynamicApproximationService = XedatsDynamicApproximationService.instance()
	if service == null:
		return -1.0
	var state: Dictionary = service.get_record_debug_state(self )
	if state.is_empty():
		return -1.0
	return float(state.get("portal_openness", -1.0))


func _sample_portal_openness(source_node: Node) -> float:
	if source_node == null or not is_instance_valid(source_node):
		return -1.0
	if source_node.has_method("get_portal_openness"):
		return clampf(float(source_node.call("get_portal_openness")), 0.0, 1.0)
	if _has_property(source_node, _portal_state_openness_property):
		return clampf(float(source_node.get(_portal_state_openness_property)), 0.0, 1.0)
	if _has_property(source_node, _portal_state_open_property):
		return 1.0 if bool(source_node.get(_portal_state_open_property)) else 0.0
	return -1.0


func _can_sample_portal_state(source_node: Node, open_property: StringName, openness_property: StringName) -> bool:
	if source_node.has_method("get_portal_openness"):
		return true
	return _has_property(source_node, openness_property) or _has_property(source_node, open_property)


func _has_property(target: Object, property_name: StringName) -> bool:
	for property_info: Dictionary in target.get_property_list():
		if StringName(property_info.get("name", &"")) == property_name:
			return true
	return false
