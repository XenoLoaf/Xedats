class_name XedatsDynamicApproximationService
extends Node

## Bounded-tick runtime service for dynamic distance-band gain approximation.
##
## Tracks [XedatsGLTFAudioEmitterBinding] nodes that author
## [code]xedats_distance_policy = "texture"[/code] and re-evaluates their
## listener distance at a fixed tick rate, applying a band-gain scale to any
## persistent (looping) player that is still alive in the pool.
##
## [b]Lifecycle:[/b]
## [codeblock]
## # Binding's _ready registers itself:
## XedatsDynamicApproximationService.get_or_create(self).register_emitter(...)
##
## # Binding's _exit_tree unregisters:
## XedatsDynamicApproximationService.instance().unregister_emitter(self)
## [/codeblock]
##
## [b]Skeleton note:[/b]
## Player [code]volume_db[/code] writes are active for looping emitters when a
## valid [XedatsPlayer3D] reference is supplied at registration time.
## Non-looping (one-shot) registrations participate in distance tracking only
## and will be pruned automatically once the emitter node is freed.
##
## [b]Work budget:[/b]
## [constant MAX_EMITTERS_PER_TICK] records are evaluated each tick in
## round-robin order so per-frame cost stays bounded regardless of emitter count.
## Stale records (freed nodes) are pruned during the tick they are first detected.

## Tick interval in seconds (≈ 10 Hz).
const TICK_INTERVAL: float = 0.1
## Maximum emitter records evaluated per tick.
const MAX_EMITTERS_PER_TICK: int = 8
## Minimum listener movement (metres) required before processing a normal tick.
## If the listener is below this threshold, records are only refreshed at
## [constant LISTENER_IDLE_REFRESH_INTERVAL] cadence.
const LISTENER_MOTION_THRESHOLD: float = 0.15
## Maximum seconds to defer updates when listener motion is below threshold.
const LISTENER_IDLE_REFRESH_INTERVAL: float = 0.8
## Minimum world-space listener distance change (metres) before re-evaluating band gain.
const DISTANCE_CHANGE_THRESHOLD: float = 0.5
## Minimum gain-scale delta before writing [code]volume_db[/code]
## to suppress micro-update audio pumping.
const GAIN_CHANGE_THRESHOLD: float = 0.02
## Default per-emitter cooldown window between dynamic updates.
const DEFAULT_EMITTER_COOLDOWN_SECONDS: float = 0.2
## Minimum allowed per-emitter cooldown.
const MIN_EMITTER_COOLDOWN_SECONDS: float = 0.05
## Maximum allowed per-emitter cooldown.
const MAX_EMITTER_COOLDOWN_SECONDS: float = 2.0
## Default attack time for dynamic gain smoothing when target gain increases.
const DEFAULT_ATTACK_SECONDS: float = 0.12
## Default release time for dynamic gain smoothing when target gain decreases.
const DEFAULT_RELEASE_SECONDS: float = 0.28
## Minimum allowed smoothing time constant.
const MIN_SMOOTHING_SECONDS: float = 0.01
## Maximum allowed smoothing time constant.
const MAX_SMOOTHING_SECONDS: float = 2.0
## Snap-to-target epsilon for smoothed gain scale.
const SMOOTHING_EPSILON: float = 0.005
## Linear interpolation smoothing mode identifier.
const SMOOTHING_MODE_LINEAR: String = "linear"
## Exponential interpolation smoothing mode identifier.
const SMOOTHING_MODE_EXP: String = "exp"
## Default smoothing mode used when payload key is missing or invalid.
const DEFAULT_SMOOTHING_MODE: String = SMOOTHING_MODE_LINEAR
## Default gain scale applied when a linked portal/opening is fully closed.
const DEFAULT_PORTAL_CLOSED_GAIN_SCALE: float = 0.35
## Minimum allowed gain scale for fully closed portal state.
const MIN_PORTAL_CLOSED_GAIN_SCALE: float = 0.0
## Maximum allowed gain scale for fully closed portal state.
const MAX_PORTAL_CLOSED_GAIN_SCALE: float = 1.0
## Project setting key for Group D dynamic approximation quality preset.
const PROJECT_SETTING_DYNAMIC_QUALITY: String = "xedats/gltf/dynamic_approximation_quality"
const QUALITY_PRESET_LOW: String = "low"
const QUALITY_PRESET_MEDIUM: String = "medium"
const QUALITY_PRESET_HIGH: String = "high"
const DEFAULT_QUALITY_PRESET: String = QUALITY_PRESET_MEDIUM


## Holds per-emitter tracking state for one registered binding.
class EmitterRecord:
	## Weak reference to the [Node3D] emitter binding node.
	var emitter_ref: WeakRef
	## Weak reference to the associated [XedatsPlayer3D], or [code]null[/code]
	## when no live player is tracked (position-tracking-only registration).
	var player_ref: Variant = null
	## Deep copy of the resolved emitter payload (carries the distance-policy key
	## and gain so the service does not depend on the binding node's internal state).
	var payload: Dictionary
	## Duck-typed [XedatsDistanceBandProfile] resource.  May be [code]null[/code]
	## when registration was made without a valid profile; gain updates are skipped
	## when [code]null[/code].
	var profile: Resource
	## Last measured straight-line distance to listener (metres).
	## Sentinel -2.0 = not yet measured.
	var last_distance: float = -2.0
	## Last applied band gain scale.  1.0 = full gain / no scaling applied yet.
	var last_gain_scale: float = 1.0
	## Whether this emitter is looping.  Only looping emitters receive
	## [code]volume_db[/code] pushes (one-shot players return to pool too quickly).
	var is_looping: bool = false
	## Per-emitter cooldown interval used to bound dynamic update cadence.
	var cooldown_seconds: float = DEFAULT_EMITTER_COOLDOWN_SECONDS
	## Service-time timestamp when this emitter can be evaluated again.
	var next_allowed_update_time: float = 0.0
	## Attack smoothing time in seconds for upward gain transitions.
	var attack_seconds: float = DEFAULT_ATTACK_SECONDS
	## Release smoothing time in seconds for downward gain transitions.
	var release_seconds: float = DEFAULT_RELEASE_SECONDS
	## Current smoothed gain scale applied to this emitter.
	var smoothed_gain_scale: float = 1.0
	## Target gain scale sampled from the profile at current listener distance.
	var target_gain_scale: float = 1.0
	## Last service-time when smoothing was advanced.
	var last_update_time: float = 0.0
	## Smoothing interpolation mode: [code]linear[/code] or [code]exp[/code].
	var smoothing_mode: String = DEFAULT_SMOOTHING_MODE
	## Category used for runtime mute-state checks.
	var category: String = "SFX"
	## Runtime-controlled openness for optional door/window/portal integration.
	## 0.0 = fully closed, 1.0 = fully open.
	var portal_openness: float = 1.0
	## Gain scale applied when portal_openness = 0.0.
	var portal_closed_gain_scale: float = DEFAULT_PORTAL_CLOSED_GAIN_SCALE
	## Number of runtime portal-state changes applied to this emitter.
	var portal_state_change_count: int = 0
	## Number of updates skipped due to category mute state.
	var muted_skip_count: int = 0


## Static weak reference to the live service instance.
## Cleared automatically in [method _exit_tree] so the next caller creates a fresh one.
static var _service_ref: WeakRef = null

## Whether the service is processing ticks.  Set via [method set_enabled].
var enabled: bool = true

var _records: Array[EmitterRecord] = []
## Round-robin cursor: next record index to start from on the following tick.
var _tick_cursor: int = 0
## Delta accumulator for tick-interval gating.
var _tick_accumulator: float = 0.0
## Monotonic service-time accumulator in seconds.
var _service_time_seconds: float = 0.0
## Last listener position used for motion-throttle gating.
var _last_listener_position: Vector3 = Vector3.ZERO
## Sentinel for whether [member _last_listener_position] is initialized.
var _listener_position_initialized: bool = false
## Elapsed idle-listener time since last forced refresh tick.
var _listener_idle_elapsed: float = 0.0
## Active quality preset controlling dynamic runtime budgets.
var _quality_preset: String = DEFAULT_QUALITY_PRESET
## Runtime tick interval derived from the active quality preset.
var _tick_interval_seconds: float = TICK_INTERVAL
## Runtime emitter-per-tick budget derived from quality preset.
var _max_emitters_per_tick: int = MAX_EMITTERS_PER_TICK
## Runtime listener motion threshold derived from quality preset.
var _listener_motion_threshold: float = LISTENER_MOTION_THRESHOLD
## Runtime idle refresh interval derived from quality preset.
var _listener_idle_refresh_interval: float = LISTENER_IDLE_REFRESH_INTERVAL
## Runtime default cooldown derived from quality preset.
var _default_emitter_cooldown_seconds: float = DEFAULT_EMITTER_COOLDOWN_SECONDS
## Runtime default attack time derived from quality preset.
var _default_attack_seconds: float = DEFAULT_ATTACK_SECONDS
## Runtime default release time derived from quality preset.
var _default_release_seconds: float = DEFAULT_RELEASE_SECONDS
## State manager currently connected for Phase 9 refresh hooks.
var _connected_state_manager: AudioStateManager = null
## Number of times an immediate refresh has been requested.
var _refresh_request_count: int = 0
## Current active listener instance id, or 0 when no listener is active.
var _tracked_listener_instance_id: int = 0
## Number of immediate refreshes triggered specifically by listener transitions.
var _listener_refresh_count: int = 0
## Last recorded immediate refresh reason.
var _last_refresh_reason: String = ""


## Initializes runtime quality preset from project settings.
func _ready() -> void:
	_load_quality_preset_from_project_settings()
	_sync_state_manager_connection()


## Returns the live service instance if one exists, otherwise [code]null[/code].
static func instance() -> XedatsDynamicApproximationService:
	if _service_ref == null:
		return null
	var ref: Object = _service_ref.get_ref()
	if ref == null:
		_service_ref = null
		return null
	return ref as XedatsDynamicApproximationService


static func peek_instance() -> XedatsDynamicApproximationService:
	return instance()


## Returns the live instance if one exists; otherwise creates a new service node
## and adds it to the scene tree root accessible from [param anchor_node].
##
## Safe to call from [method Node._ready] when [param anchor_node] is inside the
## scene tree.  When anchor has no scene tree the service is returned un-parented
## (no tick processing until added to any tree).
##
## [param anchor_node]  Any in-tree [Node] whose scene root is used as parent.
## [return]             The live or freshly created service instance.
static func get_or_create(anchor_node: Node) -> XedatsDynamicApproximationService:
	var inst: XedatsDynamicApproximationService = instance()
	if inst != null:
		return inst
	inst = XedatsDynamicApproximationService.new()
	inst.name = "XedatsDynamicApproximationService"
	_service_ref = weakref(inst)
	if anchor_node != null and anchor_node.is_inside_tree():
		anchor_node.get_tree().get_root().add_child(inst)
	return inst


## Registers [param emitter_node] for per-tick distance tracking.
##
## [param emitter_node]  [Node3D] binding node; its [code]global_position[/code]
##                       is sampled each tick.
## [param player]        Optional [XedatsPlayer3D].  When non-null and the emitter
##                       is looping, [code]volume_db[/code] is pushed on band changes.
##                       Pass [code]null[/code] for position-track-only registration.
## [param payload]       Deep copy of the resolved emitter payload.
## [param profile]       Duck-typed [XedatsDistanceBandProfile] resource.  May be
##                       [code]null[/code]; gain updates are skipped when absent.
## [return]              [code]true[/code] on success; [code]false[/code] when
##                       [param emitter_node] is invalid or already registered.
func register_emitter(
		emitter_node: Node3D,
		player: XedatsPlayer3D,
		payload: Dictionary,
		profile: Resource
) -> bool:
	if not is_instance_valid(emitter_node):
		return false
	for record: EmitterRecord in _records:
		var obj: Object = record.emitter_ref.get_ref()
		if is_instance_valid(obj) and obj == emitter_node:
			return false
	var record: EmitterRecord = EmitterRecord.new()
	record.emitter_ref = weakref(emitter_node)
	record.player_ref = weakref(player) if player != null else null
	record.payload = payload.duplicate(true)
	record.profile = profile
	record.is_looping = bool(payload.get("loop", false))
	record.cooldown_seconds = _parse_emitter_cooldown_seconds(payload)
	record.attack_seconds = _parse_attack_seconds(payload)
	record.release_seconds = _parse_release_seconds(payload)
	record.smoothing_mode = _parse_smoothing_mode(payload)
	record.category = _parse_category(payload)
	record.portal_openness = _parse_portal_openness(payload)
	record.portal_closed_gain_scale = _parse_portal_closed_gain_scale(payload)
	record.next_allowed_update_time = 0.0
	record.last_update_time = _service_time_seconds
	_records.append(record)
	return true


## Updates the tracked live [XedatsPlayer3D] reference for an existing emitter
## registration entry.
##
## [param emitter_node] Registered binding node.
## [param player]       Current live player, or [code]null[/code] to clear.
## [return]             [code]true[/code] when a matching record is found.
func update_emitter_player(emitter_node: Node3D, player: XedatsPlayer3D) -> bool:
	for record: EmitterRecord in _records:
		var obj: Object = record.emitter_ref.get_ref()
		if is_instance_valid(obj) and obj == emitter_node:
			record.player_ref = weakref(player) if player != null else null
			return true
	return false


## Updates portal openness for a registered emitter.
##
## [param emitter_node] Registered binding node.
## [param openness]     0.0 = fully closed, 1.0 = fully open.
## [return]             [code]true[/code] when a matching record is found.
func set_emitter_portal_openness(emitter_node: Node3D, openness: float) -> bool:
	for record: EmitterRecord in _records:
		var obj: Object = record.emitter_ref.get_ref()
		if is_instance_valid(obj) and obj == emitter_node:
			record.portal_openness = clampf(openness, 0.0, 1.0)
			record.portal_state_change_count += 1
			_request_record_refresh(record, "portal_openness_changed")
			return true
	return false


## Updates the fully-closed gain scale for a registered emitter's portal state.
##
## [param emitter_node] Registered binding node.
## [param gain_scale]   Gain scale applied when portal_openness = 0.0.
## [return]             [code]true[/code] when a matching record is found.
func set_emitter_portal_closed_gain_scale(emitter_node: Node3D, gain_scale: float) -> bool:
	for record: EmitterRecord in _records:
		var obj: Object = record.emitter_ref.get_ref()
		if is_instance_valid(obj) and obj == emitter_node:
			record.portal_closed_gain_scale = clampf(
				gain_scale,
				MIN_PORTAL_CLOSED_GAIN_SCALE,
				MAX_PORTAL_CLOSED_GAIN_SCALE
			)
			record.portal_state_change_count += 1
			_request_record_refresh(record, "portal_closed_gain_changed")
			return true
	return false


## Removes the registration entry for [param emitter_node].
## [return] [code]true[/code] when a matching record was found and removed.
func unregister_emitter(emitter_node: Node3D) -> bool:
	for i: int in _records.size():
		var record: EmitterRecord = _records[i]
		var obj: Object = record.emitter_ref.get_ref()
		if is_instance_valid(obj) and obj == emitter_node:
			_records.remove_at(i)
			if _tick_cursor > i:
				_tick_cursor -= 1
			if not _records.is_empty():
				_tick_cursor = _tick_cursor % _records.size()
			else:
				_tick_cursor = 0
			return true
	return false


## Returns the current number of registered records.
## Stale entries (freed nodes) are not pruned until the next tick,
## so this may briefly over-count.
func get_record_count() -> int:
	return _records.size()


## Sets the active dynamic approximation quality preset.
## Supported values: [code]low[/code], [code]medium[/code], [code]high[/code].
##
## [param preset] Requested quality preset.
## [return] True when applied; false when preset is invalid.
func set_quality_preset(preset: String) -> bool:
	var normalized: String = preset.to_lower().strip_edges()
	if not _is_valid_quality_preset(normalized):
		return false
	_apply_quality_preset(normalized)
	if ProjectSettings.has_setting(PROJECT_SETTING_DYNAMIC_QUALITY):
		ProjectSettings.set_setting(PROJECT_SETTING_DYNAMIC_QUALITY, normalized)
	return true


## Returns active quality preset string.
func get_quality_preset() -> String:
	return _quality_preset


## Returns current runtime throttling and cadence settings for debug tooling.
func get_runtime_tuning() -> Dictionary:
	return {
		"quality_preset": _quality_preset,
		"portal_state_hooks_enabled": true,
		"runtime_mute_state_enabled": true,
		"runtime_master_mute_enabled": true,
		"state_signal_hooks_enabled": true,
		"state_signal_connected": _connected_state_manager != null,
		"refresh_request_count": _refresh_request_count,
		"listener_refresh_count": _listener_refresh_count,
		"last_refresh_reason": _last_refresh_reason,
		"listener_transition_hooks_enabled": true,
		"tick_interval": _tick_interval_seconds,
		"max_emitters_per_tick": _max_emitters_per_tick,
		"listener_motion_threshold": _listener_motion_threshold,
		"listener_idle_refresh_interval": _listener_idle_refresh_interval,
		"distance_change_threshold": DISTANCE_CHANGE_THRESHOLD,
		"gain_change_threshold": GAIN_CHANGE_THRESHOLD,
		"default_emitter_cooldown_seconds": _default_emitter_cooldown_seconds,
		"min_emitter_cooldown_seconds": MIN_EMITTER_COOLDOWN_SECONDS,
		"max_emitter_cooldown_seconds": MAX_EMITTER_COOLDOWN_SECONDS,
		"default_attack_seconds": _default_attack_seconds,
		"default_release_seconds": _default_release_seconds,
		"default_portal_closed_gain_scale": DEFAULT_PORTAL_CLOSED_GAIN_SCALE,
		"min_portal_closed_gain_scale": MIN_PORTAL_CLOSED_GAIN_SCALE,
		"max_portal_closed_gain_scale": MAX_PORTAL_CLOSED_GAIN_SCALE,
		"min_smoothing_seconds": MIN_SMOOTHING_SECONDS,
		"max_smoothing_seconds": MAX_SMOOTHING_SECONDS,
		"default_smoothing_mode": DEFAULT_SMOOTHING_MODE,
		"valid_smoothing_modes": PackedStringArray([SMOOTHING_MODE_LINEAR, SMOOTHING_MODE_EXP]),
	}


## Returns debug state for a specific registered emitter node.
## When the emitter is unknown, returns an empty dictionary.
func get_record_debug_state(emitter_node: Node3D) -> Dictionary:
	for record: EmitterRecord in _records:
		var obj: Object = record.emitter_ref.get_ref()
		if is_instance_valid(obj) and obj == emitter_node:
			var has_player: bool = false
			if record.player_ref != null:
				var player_obj: Object = (record.player_ref as WeakRef).get_ref()
				has_player = is_instance_valid(player_obj)
			return {
				"is_looping": record.is_looping,
				"category": record.category,
				"cooldown_seconds": record.cooldown_seconds,
				"attack_seconds": record.attack_seconds,
				"release_seconds": record.release_seconds,
				"smoothing_mode": record.smoothing_mode,
				"portal_openness": record.portal_openness,
				"portal_closed_gain_scale": record.portal_closed_gain_scale,
				"portal_gain_scale": _portal_gain_scale(record),
				"portal_state_change_count": record.portal_state_change_count,
				"next_allowed_update_time": record.next_allowed_update_time,
				"last_distance": record.last_distance,
				"last_gain_scale": record.last_gain_scale,
				"smoothed_gain_scale": record.smoothed_gain_scale,
				"target_gain_scale": record.target_gain_scale,
				"muted_skip_count": record.muted_skip_count,
				"runtime_master_muted": is_master_runtime_muted(),
				"runtime_category_muted": is_category_runtime_muted(record.category),
				"runtime_audio_suppressed": is_runtime_audio_suppressed(record.category),
				"has_player": has_player,
			}
	return {}


## Returns a snapshot for every currently registered emitter record.
## Each dictionary includes the regular record debug state plus stable emitter
## identification fields. When an emitter exposes [code]get_debug_snapshot[/code],
## that richer binding snapshot is included under [code]binding_debug[/code].
func get_all_record_debug_states() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for record: EmitterRecord in _records:
		var obj: Object = record.emitter_ref.get_ref()
		if not is_instance_valid(obj):
			continue
		var emitter_node: Node3D = obj as Node3D
		if emitter_node == null:
			continue
		var snapshot: Dictionary = get_record_debug_state(emitter_node)
		snapshot["emitter_name"] = String(emitter_node.name)
		snapshot["emitter_path"] = String(emitter_node.get_path()) if emitter_node.is_inside_tree() else ""
		snapshot["emitter_class"] = emitter_node.get_class()
		if emitter_node.has_method("get_debug_snapshot"):
			snapshot["binding_debug"] = emitter_node.call("get_debug_snapshot")
		snapshots.append(snapshot)
	return snapshots


## Requests an immediate refresh pass by clearing cooldown/idling gates and
## forcing the next processing step to run without waiting for listener-idle or
## emitter cooldown windows.
func request_immediate_refresh(reason: String = "manual") -> void:
	_refresh_request_count += 1
	_last_refresh_reason = reason
	_tick_accumulator = _tick_interval_seconds
	_listener_position_initialized = false
	_listener_idle_elapsed = 0.0
	for record: EmitterRecord in _records:
		record.next_allowed_update_time = 0.0
		record.last_update_time = _service_time_seconds


## Returns [code]true[/code] when master audio is muted according to
## [AudioStateManager] or when the Xedats master category volume is effectively zero.
## Returns [code]false[/code] when [XedatsSingleton] is unavailable.
func is_master_runtime_muted() -> bool:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return false
	var state_manager: AudioStateManager = xedats.get_state_manager()
	if state_manager != null and state_manager.is_master_muted():
		return true
	return xedats.get_category_volume("Master") <= 0.0001


## Returns [code]true[/code] when either master audio or the specific category
## is effectively muted at runtime.
func is_runtime_audio_suppressed(category: String) -> bool:
	return is_master_runtime_muted() or is_category_runtime_muted(category)


## Returns [code]true[/code] when [param category] is muted according to
## [AudioStateManager] or when category volume is effectively zero.
## Returns [code]false[/code] when [XedatsSingleton] is unavailable.
func is_category_runtime_muted(category: String) -> bool:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return false
	var state_manager: AudioStateManager = xedats.get_state_manager()
	if state_manager != null and state_manager.is_category_muted(category):
		return true
	return xedats.get_category_volume(category) <= 0.0001


## Enables or disables tick processing.
## When disabled [method _process] returns immediately; no record updates occur.
func set_enabled(value: bool) -> void:
	enabled = value


## Clears all records and invalidates the static service reference.
## Called automatically when this node exits the scene tree.
func _exit_tree() -> void:
	_disconnect_state_manager_signals()
	_records.clear()
	_service_ref = null
	_tracked_listener_instance_id = 0
	_listener_position_initialized = false
	_listener_idle_elapsed = 0.0


## Delta-accumulator gate; fires [method _do_tick] at [constant TICK_INTERVAL].
func _process(delta: float) -> void:
	_sync_state_manager_connection()
	if not enabled:
		return
	_service_time_seconds += delta
	_tick_accumulator += delta
	if _tick_accumulator >= _tick_interval_seconds:
		_tick_accumulator -= _tick_interval_seconds
		_do_tick()


## Evaluates up to [constant MAX_EMITTERS_PER_TICK] records in round-robin order.
## Collects stale-record indices during the pass and prunes them afterward to
## preserve index stability during the loop.
func _do_tick() -> void:
	if _records.is_empty():
		return
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		_tracked_listener_instance_id = 0
		return
	var listener: XedatsListener3D = xedats.get_current_listener()
	_sync_listener_transition(listener)
	if listener == null:
		_listener_position_initialized = false
		_listener_idle_elapsed = 0.0
		return
	if _should_skip_for_listener_motion(listener):
		return

	var count: int = mini(_max_emitters_per_tick, _records.size())
	var stale: PackedInt32Array = PackedInt32Array()

	for i: int in count:
		var index: int = (_tick_cursor + i) % _records.size()
		var record: EmitterRecord = _records[index]
		var obj: Object = record.emitter_ref.get_ref()
		if not is_instance_valid(obj):
			stale.append(index)
		else:
			_update_record(record, listener)

	# Advance round-robin cursor by work completed.
	_tick_cursor = (_tick_cursor + count) % _records.size() if not _records.is_empty() else 0

	# Prune stale records in descending index order to preserve lower indices.
	if stale.is_empty():
		return
	stale.sort()
	for i: int in range(stale.size() - 1, -1, -1):
		var stale_idx: int = stale[i]
		_records.remove_at(stale_idx)
		if _tick_cursor > stale_idx:
			_tick_cursor -= 1
	if _records.is_empty():
		_tick_cursor = 0
	else:
		_tick_cursor = _tick_cursor % _records.size()


## Returns true when the listener has moved less than
## [constant LISTENER_MOTION_THRESHOLD] and the idle refresh interval has not
## elapsed yet.  This throttles work while the listener is effectively stationary.
func _should_skip_for_listener_motion(listener: XedatsListener3D) -> bool:
	var current_pos: Vector3 = listener.global_position
	if not _listener_position_initialized:
		_last_listener_position = current_pos
		_listener_position_initialized = true
		_listener_idle_elapsed = 0.0
		return false

	var moved_distance: float = current_pos.distance_to(_last_listener_position)
	if moved_distance >= _listener_motion_threshold:
		_last_listener_position = current_pos
		_listener_idle_elapsed = 0.0
		return false

	_listener_idle_elapsed += _tick_interval_seconds
	if _listener_idle_elapsed < _listener_idle_refresh_interval:
		return true

	_last_listener_position = current_pos
	_listener_idle_elapsed = 0.0
	return false


## Parses and clamps per-emitter cooldown seconds from resolved payload.
## Optional key: [code]xedats_dynamic_update_cooldown[/code].
func _parse_emitter_cooldown_seconds(payload: Dictionary) -> float:
	var requested: float = _default_emitter_cooldown_seconds
	if payload.has("xedats_dynamic_update_cooldown"):
		requested = float(payload.get("xedats_dynamic_update_cooldown", _default_emitter_cooldown_seconds))
	return clampf(
		requested,
		MIN_EMITTER_COOLDOWN_SECONDS,
		MAX_EMITTER_COOLDOWN_SECONDS
	)


## Parses and clamps attack smoothing time in seconds.
## Optional key: [code]xedats_dynamic_attack_seconds[/code].
func _parse_attack_seconds(payload: Dictionary) -> float:
	var requested: float = _default_attack_seconds
	if payload.has("xedats_dynamic_attack_seconds"):
		requested = float(payload.get("xedats_dynamic_attack_seconds", _default_attack_seconds))
	return clampf(requested, MIN_SMOOTHING_SECONDS, MAX_SMOOTHING_SECONDS)


## Parses and clamps release smoothing time in seconds.
## Optional key: [code]xedats_dynamic_release_seconds[/code].
func _parse_release_seconds(payload: Dictionary) -> float:
	var requested: float = _default_release_seconds
	if payload.has("xedats_dynamic_release_seconds"):
		requested = float(payload.get("xedats_dynamic_release_seconds", _default_release_seconds))
	return clampf(requested, MIN_SMOOTHING_SECONDS, MAX_SMOOTHING_SECONDS)


## Parses emitter category from payload with deterministic fallback.
func _parse_category(payload: Dictionary) -> String:
	var category: String = String(payload.get("category", "SFX")).strip_edges()
	if category.is_empty():
		return "SFX"
	return category


## Parses normalized portal openness from payload.
## Optional key: [code]xedats_dynamic_portal_openness[/code].
func _parse_portal_openness(payload: Dictionary) -> float:
	var requested: float = 1.0
	if payload.has("xedats_dynamic_portal_openness"):
		requested = float(payload.get("xedats_dynamic_portal_openness", 1.0))
	return clampf(requested, 0.0, 1.0)


## Parses the fully-closed portal gain scale from payload.
## Optional key: [code]xedats_dynamic_portal_closed_gain_scale[/code].
func _parse_portal_closed_gain_scale(payload: Dictionary) -> float:
	var requested: float = DEFAULT_PORTAL_CLOSED_GAIN_SCALE
	if payload.has("xedats_dynamic_portal_closed_gain_scale"):
		requested = float(
			payload.get(
				"xedats_dynamic_portal_closed_gain_scale",
				DEFAULT_PORTAL_CLOSED_GAIN_SCALE
			)
		)
	return clampf(
		requested,
		MIN_PORTAL_CLOSED_GAIN_SCALE,
		MAX_PORTAL_CLOSED_GAIN_SCALE
	)


## Keeps the connected [AudioStateManager] reference aligned with the current
## Xedats singleton instance so state-loaded/reset events can trigger refreshes.
func _sync_state_manager_connection() -> void:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	var next_state_manager: AudioStateManager = null
	if xedats != null:
		next_state_manager = xedats.get_state_manager()
	if next_state_manager == _connected_state_manager:
		return
	_disconnect_state_manager_signals()
	_connected_state_manager = next_state_manager
	if _connected_state_manager == null:
		return
	if not _connected_state_manager.state_loaded.is_connected(_on_audio_state_changed):
		_connected_state_manager.state_loaded.connect(_on_audio_state_changed)
	if not _connected_state_manager.state_reset.is_connected(_on_audio_state_changed):
		_connected_state_manager.state_reset.connect(_on_audio_state_changed)


## Disconnects any existing state-manager signal hooks.
func _disconnect_state_manager_signals() -> void:
	if _connected_state_manager == null:
		return
	if _connected_state_manager.state_loaded.is_connected(_on_audio_state_changed):
		_connected_state_manager.state_loaded.disconnect(_on_audio_state_changed)
	if _connected_state_manager.state_reset.is_connected(_on_audio_state_changed):
		_connected_state_manager.state_reset.disconnect(_on_audio_state_changed)
	_connected_state_manager = null


## Phase 9 signal hook: audio-state load/reset should apply immediately rather
## than waiting for cooldown or listener-idle gates to expire.
func _on_audio_state_changed() -> void:
	request_immediate_refresh("audio_state_changed")


## Detects listener swaps/loss/reacquisition and converts them into immediate
## refresh requests so dynamic approximation responds without waiting for normal
## cooldown or listener-idle cadence.
func _sync_listener_transition(listener: XedatsListener3D) -> void:
	var current_listener_id: int = 0
	if listener != null and is_instance_valid(listener):
		current_listener_id = listener.get_instance_id()
	if current_listener_id == _tracked_listener_instance_id:
		return
	if current_listener_id == 0 and _tracked_listener_instance_id != 0:
		_tracked_listener_instance_id = 0
		_listener_refresh_count += 1
		request_immediate_refresh("listener_lost")
		return
	if current_listener_id != 0:
		_tracked_listener_instance_id = current_listener_id
		_listener_refresh_count += 1
		request_immediate_refresh("listener_changed")


## Clears local throttling for a specific record and requests a near-immediate
## service refresh so stateful opening/closing changes apply without waiting for
## normal listener-idle or cooldown cadence.
func _request_record_refresh(record: EmitterRecord, reason: String) -> void:
	record.next_allowed_update_time = 0.0
	record.last_distance = -2.0
	record.last_update_time = _service_time_seconds
	request_immediate_refresh(reason)


## Returns the gain scale implied by the record's portal openness state.
## 0.0 openness maps to portal_closed_gain_scale, 1.0 maps to 1.0.
func _portal_gain_scale(record: EmitterRecord) -> float:
	return lerpf(record.portal_closed_gain_scale, 1.0, record.portal_openness)


## Returns true when [param preset] is one of the supported quality tiers.
func _is_valid_quality_preset(preset: String) -> bool:
	return preset == QUALITY_PRESET_LOW or preset == QUALITY_PRESET_MEDIUM or preset == QUALITY_PRESET_HIGH


## Loads the quality preset from project settings with deterministic fallback.
func _load_quality_preset_from_project_settings() -> void:
	var requested: String = DEFAULT_QUALITY_PRESET
	if ProjectSettings.has_setting(PROJECT_SETTING_DYNAMIC_QUALITY):
		requested = String(ProjectSettings.get_setting(PROJECT_SETTING_DYNAMIC_QUALITY, DEFAULT_QUALITY_PRESET)).to_lower().strip_edges()
	if not _is_valid_quality_preset(requested):
		requested = DEFAULT_QUALITY_PRESET
	if not ProjectSettings.has_setting(PROJECT_SETTING_DYNAMIC_QUALITY):
		ProjectSettings.set_setting(PROJECT_SETTING_DYNAMIC_QUALITY, requested)
	_apply_quality_preset(requested)


## Applies runtime quality preset values to cadence and default tuning.
func _apply_quality_preset(preset: String) -> void:
	_quality_preset = preset
	match preset:
		QUALITY_PRESET_LOW:
			_tick_interval_seconds = 0.16
			_max_emitters_per_tick = 4
			_listener_motion_threshold = 0.20
			_listener_idle_refresh_interval = 1.00
			_default_emitter_cooldown_seconds = 0.30
			_default_attack_seconds = 0.18
			_default_release_seconds = 0.40
		QUALITY_PRESET_HIGH:
			_tick_interval_seconds = 0.08
			_max_emitters_per_tick = 16
			_listener_motion_threshold = 0.10
			_listener_idle_refresh_interval = 0.50
			_default_emitter_cooldown_seconds = 0.10
			_default_attack_seconds = 0.08
			_default_release_seconds = 0.22
		_:
			_tick_interval_seconds = TICK_INTERVAL
			_max_emitters_per_tick = MAX_EMITTERS_PER_TICK
			_listener_motion_threshold = LISTENER_MOTION_THRESHOLD
			_listener_idle_refresh_interval = LISTENER_IDLE_REFRESH_INTERVAL
			_default_emitter_cooldown_seconds = DEFAULT_EMITTER_COOLDOWN_SECONDS
			_default_attack_seconds = DEFAULT_ATTACK_SECONDS
			_default_release_seconds = DEFAULT_RELEASE_SECONDS


## Parses smoothing interpolation mode.
## Optional key: [code]xedats_dynamic_smoothing_mode[/code].
## Supported values: [code]linear[/code], [code]exp[/code].
func _parse_smoothing_mode(payload: Dictionary) -> String:
	if not payload.has("xedats_dynamic_smoothing_mode"):
		return DEFAULT_SMOOTHING_MODE
	var requested: String = String(payload.get("xedats_dynamic_smoothing_mode", DEFAULT_SMOOTHING_MODE)).to_lower()
	if requested == SMOOTHING_MODE_LINEAR or requested == SMOOTHING_MODE_EXP:
		return requested
	return DEFAULT_SMOOTHING_MODE


## Advances [member EmitterRecord.smoothed_gain_scale] toward
## [member EmitterRecord.target_gain_scale] using attack/release time constants.
##
## [param record]    Emitter record to mutate.
## [param delta_t]   Elapsed seconds since previous smoothing step.
## [return]          Updated smoothed gain scale.
func _advance_smoothed_gain_scale(record: EmitterRecord, delta_t: float) -> float:
	var delta: float = record.target_gain_scale - record.smoothed_gain_scale
	if absf(delta) <= SMOOTHING_EPSILON:
		record.smoothed_gain_scale = record.target_gain_scale
		return record.smoothed_gain_scale

	var smoothing_seconds: float = record.attack_seconds if delta > 0.0 else record.release_seconds
	if smoothing_seconds <= 0.0:
		record.smoothed_gain_scale = record.target_gain_scale
		return record.smoothed_gain_scale

	if record.smoothing_mode == SMOOTHING_MODE_EXP:
		var alpha: float = clampf(1.0 - exp(-delta_t / smoothing_seconds), 0.0, 1.0)
		record.smoothed_gain_scale += delta * alpha
	else:
		var step_ratio: float = clampf(delta_t / smoothing_seconds, 0.0, 1.0)
		record.smoothed_gain_scale += delta * step_ratio

	if absf(record.target_gain_scale - record.smoothed_gain_scale) <= SMOOTHING_EPSILON:
		record.smoothed_gain_scale = record.target_gain_scale
	return record.smoothed_gain_scale


## Evaluates a single [EmitterRecord] against the current listener position.
## Skips the update when the distance change is below [constant DISTANCE_CHANGE_THRESHOLD]
## or the gain-scale change is below [constant GAIN_CHANGE_THRESHOLD] (pumping guard).
## Pushes [code]volume_db[/code] only for looping emitters with a live player ref.
func _update_record(record: EmitterRecord, listener: XedatsListener3D) -> void:
	if _service_time_seconds < record.next_allowed_update_time:
		return

	var elapsed_since_last: float = maxf(_service_time_seconds - record.last_update_time, _tick_interval_seconds)
	record.last_update_time = _service_time_seconds

	var emitter_obj: Object = record.emitter_ref.get_ref()
	if not is_instance_valid(emitter_obj):
		return
	var emitter_node: Node3D = emitter_obj as Node3D
	if is_runtime_audio_suppressed(record.category):
		record.muted_skip_count += 1
		record.next_allowed_update_time = _service_time_seconds + record.cooldown_seconds
		return

	var distance: float = emitter_node.global_position.distance_to(listener.global_position)
	if record.last_distance >= 0.0 and absf(distance - record.last_distance) < DISTANCE_CHANGE_THRESHOLD:
		record.next_allowed_update_time = _service_time_seconds + record.cooldown_seconds
		return
	record.last_distance = distance

	if record.profile == null or not record.profile.has_method("gain_scale_at"):
		record.next_allowed_update_time = _service_time_seconds + record.cooldown_seconds
		return
	var new_gain_scale: float = float(record.profile.call("gain_scale_at", distance))
	if absf(new_gain_scale - record.last_gain_scale) >= GAIN_CHANGE_THRESHOLD:
		record.last_gain_scale = new_gain_scale
	record.target_gain_scale = clampf(record.last_gain_scale * _portal_gain_scale(record), 0.0, 1.0)

	var smoothed_gain_scale: float = _advance_smoothed_gain_scale(record, elapsed_since_last)
	record.next_allowed_update_time = _service_time_seconds + record.cooldown_seconds

	# Only push volume_db to persistent (looping) players to avoid writing to
	# a pooled player that has already started a different clip.
	if not record.is_looping or record.player_ref == null:
		return
	var player_obj: Object = (record.player_ref as WeakRef).get_ref()
	if not is_instance_valid(player_obj):
		return
	var player: XedatsPlayer3D = player_obj as XedatsPlayer3D
	var authored_gain: float = clampf(float(record.payload.get("gain", 1.0)), 0.0, 1.0)
	var precomputed_gain_multiplier: float = clampf(
		float(record.payload.get("xedats_precomputed_gain_multiplier", 1.0)),
		0.0,
		2.0
	)
	var effective_gain: float = clampf(authored_gain * precomputed_gain_multiplier, 0.0, 1.0)
	player.volume_db = linear_to_db(clampf(effective_gain * smoothed_gain_scale, 0.0, 1.0))
