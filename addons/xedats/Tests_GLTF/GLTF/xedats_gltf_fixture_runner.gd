extends Node

static var FIXTURE_RELATIVE_URI: String = XedatsGLTFConfig.fixtures_root() + "/khr_audio_emitter_relative_uri.gltf"
static var FIXTURE_DEFAULT_CATEGORY: String = XedatsGLTFConfig.fixtures_root() + "/khr_audio_emitter_default_category.gltf"
static var FIXTURE_EVENT_NAME: String = XedatsGLTFConfig.fixtures_root() + "/khr_audio_emitter_event_name.gltf"
static var FIXTURE_NAME_FALLBACK: String = XedatsGLTFConfig.fixtures_root() + "/khr_audio_emitter_name_fallback.gltf"
static var FIXTURE_XEDATS_EXTRAS_VALID: String = XedatsGLTFConfig.fixtures_root() + "/khr_audio_emitter_xedats_extras_valid.gltf"
static var FIXTURE_XEDATS_EXTRAS_INVALID: String = XedatsGLTFConfig.fixtures_root() + "/khr_audio_emitter_xedats_extras_invalid.gltf"
static var FIXTURE_REFLECTION_BUDGET_CAP: String = XedatsGLTFConfig.fixtures_root() + "/khr_audio_emitter_reflection_budget_cap.gltf"
static var FIXTURE_TEXTURE_MODULATION: String = XedatsGLTFConfig.fixtures_root() + "/khr_audio_emitter_texture_modulation.gltf"
static var FIXTURE_DISTANCE_POLICY: String = XedatsGLTFConfig.fixtures_root() + "/khr_audio_emitter_distance_policy.gltf"
static var FIXTURE_PORTAL_SOURCE_PATH_DOT: String = XedatsGLTFConfig.fixtures_root() + "/khr_audio_emitter_portal_source_path_dot.gltf"
static var FIXTURE_PORTAL_SOURCE_PATH_BAD: String = XedatsGLTFConfig.fixtures_root() + "/khr_audio_emitter_portal_source_path_bad.gltf"
static var FIXTURE_PRECOMPUTED_MISSING: String = XedatsGLTFConfig.fixtures_root() + "/khr_audio_emitter_precomputed_missing.gltf"
static var FIXTURE_PRECOMPUTED_PROBE_REGION: String = XedatsGLTFConfig.fixtures_root() + "/khr_audio_emitter_precomputed_probe_region.gltf"
static var FIXTURE_OMI_MATERIAL: String = XedatsGLTFConfig.fixtures_root() + "/omi_audio_material_node_extension.gltf"
static var FIXTURE_OMI_MATERIAL_EXTREMES: String = XedatsGLTFConfig.fixtures_root() + "/omi_audio_material_extremes.gltf"
static var FIXTURE_OMI_MATERIAL_INDEX: String = XedatsGLTFConfig.fixtures_root() + "/omi_audio_material_material_index.gltf"
static var FIXTURE_OMI_MATERIAL_PRECEDENCE: String = XedatsGLTFConfig.fixtures_root() + "/omi_audio_material_precedence.gltf"
static var FIXTURE_OMI_MATERIAL_DEFAULT_BUS: String = XedatsGLTFConfig.fixtures_root() + "/omi_audio_material_default_bus.gltf"
const PORTAL_STATE_STUB_SCRIPT: Script = preload("res://ProjectHelix/Xedats/Tests/GLTF/fixture_portal_state_stub.gd")
# Expected volume_variation for texture modulation fixture:
# gain=1.0, density=0.5 -> center=0.75; variance=0.4, max_spread=0.25 -> half=0.1
const EXPECTED_TEXTURE_VOL_MIN: float = 0.65
const EXPECTED_TEXTURE_VOL_MAX: float = 0.85
static var EXPECTED_RELATIVE_STREAM: String = XedatsGLTFConfig.project_root() + "/Sound/Test_/Other/open_gate_sfx.wav"
const EXPECTED_RELATIVE_EVENT: String = "fixture_relative_uri_emitter"
const EXPECTED_EVENT_NAME: String = "fixture_gate_event"
const EXPECTED_NAME_FALLBACK_EVENT: String = "fixture_name_fallback_event"
const EXPECTED_OMI_NODE_NAME: String = "FixtureOMIAudioMaterialNode"
const EXPECTED_OMI_BUS_NAME: String = "FixtureOMIBus"
const EXPECTED_OMI_EXTREME_LOW_NODE: String = "FixtureOMIExtremesLowNode"
const EXPECTED_OMI_EXTREME_HIGH_NODE: String = "FixtureOMIExtremesHighNode"
const EXPECTED_OMI_EXTREME_LOW_BUS: String = "FixtureOMIExtremesLowBus"
const EXPECTED_OMI_EXTREME_HIGH_BUS: String = "FixtureOMIExtremesHighBus"
const EXPECTED_OMI_MATERIAL_INDEX_NODE: String = "FixtureOMIMaterialIndexedNode"
const EXPECTED_OMI_MATERIAL_INDEX_BUS: String = "FixtureOMIMaterialIndexBus"
const EXPECTED_OMI_PRECEDENCE_NODE: String = "FixtureOMIPrecedenceNode"
const EXPECTED_OMI_PRECEDENCE_NODE_BUS: String = "FixtureOMIPrecedenceNodeBus"
const EXPECTED_OMI_DEFAULT_BUS_NODE: String = "FixtureOMIDefaultBusNode"
const EXPECTED_OMI_DEFAULT_BUS_NAME: String = "XedatsOMI_FixtureOMIDefaultBusNode"
static var EXPECTED_CAP_PATH_0: String = XedatsGLTFConfig.project_root() + "/Sound/Test_/Other/door_unlock_sfx.wav"
static var EXPECTED_CAP_PATH_1: String = XedatsGLTFConfig.project_root() + "/Sound/Test_/Other/open_gate_sfx.wav"
static var EVENT_AUDIO_PATH: String = XedatsGLTFConfig.project_root() + "/Sound/Test_/Other/door_unlock_sfx.wav"

var _extension: GLTFDocumentExtensionXedatsAudio = null
var _event_hits: Array[String] = []
var _fixture_roots: Array[Node] = []
var _failures: Array[String] = []
var _registered_event_names: Array[String] = []
var _teardown_complete: bool = false


func _ready() -> void:
	_register_runtime_extension()
	call_deferred("_run_fixture_suite")


func _exit_tree() -> void:
	_teardown_runner()


func _teardown_runner() -> void:
	if _teardown_complete:
		return
	_teardown_complete = true

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats != null:
		var event_system: AudioEventSystem = xedats.get_event_system()
		if event_system != null and event_system.event_triggered.is_connected(_on_event_triggered):
			event_system.event_triggered.disconnect(_on_event_triggered)
		if event_system != null:
			for event_name: String in _registered_event_names:
				if event_system.get_event(event_name) != null:
					event_system.unregister_event(event_name)
	_registered_event_names.clear()

	for fixture_root: Node in _fixture_roots:
		if is_instance_valid(fixture_root):
			if fixture_root.get_parent() == self:
				remove_child(fixture_root)
			fixture_root.free()
	_fixture_roots.clear()

	_teardown_dynamic_service()

	if _extension != null:
		GLTFDocument.unregister_gltf_document_extension(_extension)
		_extension = null


func _teardown_dynamic_service() -> void:
	var service: XedatsDynamicApproximationService = XedatsDynamicApproximationService.instance()
	if service == null:
		return

	if service.get_parent() != null:
		service.get_parent().remove_child(service)
	service.free()


func _run_fixture_suite() -> void:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	_expect(xedats != null, "XedatsSingleton instance should be available for fixture imports.")
	if xedats == null:
		_print_summary()
		return

	_prepare_event_system(xedats)

	_validate_relative_uri_fixture()
	await get_tree().process_frame

	_validate_default_category_fixture()
	await get_tree().process_frame

	_validate_emitter_ready_mute_gate_fixture()
	await get_tree().process_frame

	_validate_event_name_fixture()
	await get_tree().process_frame

	_validate_name_fallback_fixture()
	await get_tree().process_frame

	_validate_xedats_extras_validation_fixtures()
	await get_tree().process_frame

	_validate_reflection_budget_cap_fixture()
	await get_tree().process_frame

	_validate_texture_modulation_fixture()
	await get_tree().process_frame

	_validate_distance_policy_fixture()
	await get_tree().process_frame

	_validate_portal_source_path_auto_bind_fixtures()
	await get_tree().process_frame

	_validate_dynamic_approximation_service()
	await get_tree().process_frame

	_validate_precomputed_propagation_fixtures()
	await get_tree().process_frame

	_validate_omi_material_fixture(xedats)
	await get_tree().process_frame

	_validate_omi_material_extremes_fixture(xedats)
	await get_tree().process_frame

	_validate_omi_material_index_fixture(xedats)
	await get_tree().process_frame

	_validate_omi_material_precedence_fixture(xedats)
	await get_tree().process_frame

	_validate_omi_material_default_bus_fixture(xedats)
	await get_tree().process_frame

	_validate_xedats_unavailable_fallback_fixture()
	await get_tree().process_frame

	_print_summary()


func _register_runtime_extension() -> void:
	_extension = GLTFDocumentExtensionXedatsAudio.new()
	GLTFDocument.register_gltf_document_extension(_extension)


func _prepare_event_system(xedats: XedatsSingleton) -> void:
	var event_system: AudioEventSystem = xedats.get_event_system()
	_expect(event_system != null, "AudioEventSystem should be available for fixture validation.")
	if event_system == null:
		return

	if not event_system.event_triggered.is_connected(_on_event_triggered):
		event_system.event_triggered.connect(_on_event_triggered)

	_register_fixture_event(event_system, EXPECTED_RELATIVE_EVENT)
	_register_fixture_event(event_system, EXPECTED_EVENT_NAME)
	_register_fixture_event(event_system, EXPECTED_NAME_FALLBACK_EVENT)


func _register_fixture_event(event_system: AudioEventSystem, event_name: String) -> void:
	if event_system.get_event(event_name) != null:
		event_system.unregister_event(event_name)

	var stream_resource: Resource = load(EVENT_AUDIO_PATH)
	_expect(stream_resource is AudioStream, "Fixture event stream should load as AudioStream for '%s'." % event_name)
	if not (stream_resource is AudioStream):
		return

	var container: AudioArrayContainer = AudioArrayContainer.new()
	container.container_name = "%s_container" % event_name
	container.StreamContainer = [stream_resource as AudioStream]
	container.playback_mode = AudioArrayContainer.PlaybackMode.SEQUENTIAL
	container.volume_variation = Vector2(1.0, 1.0)
	container.pitch_variation = Vector2(1.0, 1.0)

	var registered: bool = event_system.register_event(event_name, container, 1.0, 1.0, "SFX")
	_expect(registered, "Fixture event '%s' should register successfully." % event_name)
	if registered and not _registered_event_names.has(event_name):
		_registered_event_names.append(event_name)


func _validate_relative_uri_fixture() -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_RELATIVE_URI)
	if fixture_root == null:
		return

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixtureRelativeUriEmitter")
	_expect(emitter_node != null, "Relative URI fixture should contain FixtureRelativeUriEmitter node.")
	if emitter_node == null:
		return

	_expect(emitter_node.has_meta(&"xedats_khr_audio_emitter"), "Relative URI fixture node should expose resolved emitter payload metadata.")
	if not emitter_node.has_meta(&"xedats_khr_audio_emitter"):
		return

	var payload_variant: Variant = emitter_node.get_meta(&"xedats_khr_audio_emitter")
	_expect(payload_variant is Dictionary, "Relative URI fixture payload should be a Dictionary.")
	if not (payload_variant is Dictionary):
		return

	var payload: Dictionary = payload_variant
	var source_paths_variant: Variant = payload.get("source_paths", [])
	_expect(source_paths_variant is Array, "Relative URI fixture payload should contain source_paths array.")
	if not (source_paths_variant is Array):
		return

	var source_paths: Array = source_paths_variant
	_expect(source_paths.size() == 1, "Relative URI fixture should resolve exactly one source path.")
	if source_paths.size() != 1:
		return

	var resolved_path: String = String(source_paths[0])
	_expect(resolved_path == EXPECTED_RELATIVE_STREAM, "Relative URI fixture resolved '%s' instead of '%s'." % [resolved_path, EXPECTED_RELATIVE_STREAM])
	var binding_node: Node = _find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding")
	_expect(binding_node != null, "Relative URI fixture should attach emitter binding child.")
	_expect_runtime_path_meta(binding_node, "Relative URI fixture")


func _validate_default_category_fixture() -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_DEFAULT_CATEGORY)
	if fixture_root == null:
		return

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixtureDefaultCategoryEmitter")
	_expect(emitter_node != null, "Default-category fixture should contain FixtureDefaultCategoryEmitter node.")
	if emitter_node == null:
		return

	_expect(emitter_node.has_meta(&"xedats_khr_audio_emitter"),
		"Default-category fixture node should expose resolved emitter payload metadata.")
	if not emitter_node.has_meta(&"xedats_khr_audio_emitter"):
		return

	var payload_variant: Variant = emitter_node.get_meta(&"xedats_khr_audio_emitter")
	_expect(payload_variant is Dictionary, "Default-category fixture payload should be a Dictionary.")
	if not (payload_variant is Dictionary):
		return

	var payload: Dictionary = payload_variant
	_expect(String(payload.get("category", "")) == "SFX",
		"Default-category fixture should resolve category fallback to 'SFX' when metadata is absent.")

	var binding_node: Node = _find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding")
	_expect(binding_node != null, "Default-category fixture should attach emitter binding child.")
	_expect_runtime_path_meta(binding_node, "Default-category fixture")


func _validate_emitter_ready_mute_gate_fixture() -> void:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	_expect(xedats != null, "Mute-gate fixture requires XedatsSingleton instance.")
	if xedats == null:
		return

	var state_manager: AudioStateManager = xedats.get_state_manager()
	_expect(state_manager != null, "Mute-gate fixture requires AudioStateManager.")
	if state_manager == null:
		return

	var was_muted: bool = state_manager.is_category_muted("SFX")
	var previous_volume: float = xedats.get_category_volume("SFX")
	state_manager.mute_category("SFX")
	xedats.set_category_volume("SFX", 1.0)

	var fixture_root: Node = _import_fixture(FIXTURE_DEFAULT_CATEGORY)
	if fixture_root == null:
		xedats.set_category_volume("SFX", previous_volume)
		if was_muted:
			state_manager.mute_category("SFX")
		else:
			state_manager.unmute_category("SFX")
		return

	await get_tree().process_frame

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixtureDefaultCategoryEmitter")
	_expect(emitter_node != null, "Mute-gate fixture should contain FixtureDefaultCategoryEmitter node.")
	if emitter_node != null:
		var binding_node: Node = _find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding")
		_expect(binding_node != null, "Mute-gate fixture should attach emitter binding child.")
		if binding_node != null:
			_expect(binding_node.has_meta(&"xedats_runtime_path"),
				"Mute-gate binding should expose runtime path metadata.")
			var runtime_path: String = String(binding_node.get_meta(&"xedats_runtime_path", ""))
			_expect(runtime_path == "muted_skip",
				"Mute-gate fixture should skip playback at _ready when category is muted.")

	xedats.set_category_volume("SFX", previous_volume)
	if was_muted:
		state_manager.mute_category("SFX")
	else:
		state_manager.unmute_category("SFX")


func _validate_event_name_fixture() -> void:
	_event_hits.clear()
	var fixture_root: Node = _import_fixture(FIXTURE_EVENT_NAME)
	if fixture_root == null:
		return

	await get_tree().process_frame
	_expect(_event_hits.has(EXPECTED_EVENT_NAME), "Event-name fixture should trigger registered event '%s'." % EXPECTED_EVENT_NAME)

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixtureEventNameEmitter")
	_expect(emitter_node != null, "Event-name fixture should contain FixtureEventNameEmitter node.")
	if emitter_node == null or not emitter_node.has_meta(&"xedats_khr_audio_emitter"):
		return
	_expect_runtime_path_meta(_find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding"), "Event-name fixture")

	var payload_variant: Variant = emitter_node.get_meta(&"xedats_khr_audio_emitter")
	if payload_variant is Dictionary:
		var payload: Dictionary = payload_variant
		var event_name: String = String(payload.get("event_name", ""))
		_expect(event_name == EXPECTED_EVENT_NAME, "Event-name fixture should resolve explicit xedats_event value.")


func _validate_name_fallback_fixture() -> void:
	_event_hits.clear()
	var fixture_root: Node = _import_fixture(FIXTURE_NAME_FALLBACK)
	if fixture_root == null:
		return

	await get_tree().process_frame
	_expect(_event_hits.has(EXPECTED_NAME_FALLBACK_EVENT), "Name-fallback fixture should trigger event resolved from emitter name '%s'." % EXPECTED_NAME_FALLBACK_EVENT)

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixtureNameFallbackEmitter")
	_expect(emitter_node != null, "Name-fallback fixture should contain FixtureNameFallbackEmitter node.")
	if emitter_node == null or not emitter_node.has_meta(&"xedats_khr_audio_emitter"):
		return
	_expect_runtime_path_meta(_find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding"), "Name-fallback fixture")

	var payload_variant: Variant = emitter_node.get_meta(&"xedats_khr_audio_emitter")
	if payload_variant is Dictionary:
		var payload: Dictionary = payload_variant
		var event_name: String = String(payload.get("event_name", ""))
		_expect(event_name == EXPECTED_NAME_FALLBACK_EVENT, "Name-fallback fixture should resolve event_name from emitter name.")


func _validate_xedats_extras_validation_fixtures() -> void:
	_validate_xedats_extras_valid_fixture()
	_validate_xedats_extras_invalid_fixture()


func _validate_xedats_extras_valid_fixture() -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_XEDATS_EXTRAS_VALID)
	if fixture_root == null:
		return

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixtureXedatsExtrasValidEmitter")
	_expect(emitter_node != null, "Valid xedats extras fixture should contain FixtureXedatsExtrasValidEmitter node.")
	if emitter_node == null:
		return
	_expect_runtime_path_meta(_find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding"), "Valid xedats extras fixture")

	_expect(emitter_node.has_meta(&"xedats_khr_audio_emitter"), "Valid xedats extras fixture should expose resolved emitter payload metadata.")
	if not emitter_node.has_meta(&"xedats_khr_audio_emitter"):
		return

	var payload_variant: Variant = emitter_node.get_meta(&"xedats_khr_audio_emitter")
	_expect(payload_variant is Dictionary, "Valid xedats extras payload should be a Dictionary.")
	if not (payload_variant is Dictionary):
		return

	var payload: Dictionary = payload_variant
	_expect(String(payload.get("xedats_reflection_budget", "")) == "medium", "Valid extras should preserve xedats_reflection_budget='medium'.")
	_expect(String(payload.get("xedats_texture_profile", "")) == "rain_dense", "Valid extras should preserve xedats_texture_profile.")
	_expect(_is_close(float(payload.get("xedats_texture_density", -1.0)), 0.35), "Valid extras should preserve xedats_texture_density=0.35.")
	_expect(_is_close(float(payload.get("xedats_texture_variance", -1.0)), 0.5), "Valid extras should preserve xedats_texture_variance=0.5.")
	_expect(_is_close(float(payload.get("xedats_dynamic_portal_openness", -1.0)), 0.4),
		"Valid extras should preserve xedats_dynamic_portal_openness=0.4.")
	_expect(_is_close(float(payload.get("xedats_dynamic_portal_closed_gain_scale", -1.0)), 0.2),
		"Valid extras should preserve xedats_dynamic_portal_closed_gain_scale=0.2.")
	_expect(String(payload.get("xedats_precomputed_id", "")) == "zone_a", "Valid extras should preserve xedats_precomputed_id.")
	_expect(String(payload.get("xedats_probe_region", "")) == "region_a", "Valid extras should preserve xedats_probe_region string.")
	_expect(String(payload.get("xedats_precomputed_resolution_source", "")) == "precomputed_id",
		"Valid extras should resolve precomputed propagation by xedats_precomputed_id.")
	_expect(String(payload.get("xedats_precomputed_resolution_key", "")) == "zone_a",
		"Valid extras should resolve precomputed key 'zone_a'.")
	_expect(_is_close(float(payload.get("xedats_precomputed_gain_multiplier", -1.0)), 0.8),
		"Valid extras should load gain multiplier 0.8 from the precomputed profile.")
	_expect(_is_close(float(payload.get("xedats_precomputed_lowpass_hz", -1.0)), 3200.0),
		"Valid extras should load low-pass hint from the precomputed profile.")

	var known_keys_variant: Variant = payload.get("xedats_extras_known_keys", PackedStringArray())
	_expect(known_keys_variant is PackedStringArray or known_keys_variant is Array,
		"Valid extras payload should include xedats_extras_known_keys breadcrumb.")
	if known_keys_variant is PackedStringArray:
		var known_keys: PackedStringArray = known_keys_variant
		_expect(known_keys.has("xedats_reflection_budget"),
			"Valid extras breadcrumb should list xedats_reflection_budget as known key.")
		_expect(known_keys.has("xedats_precomputed_id"),
			"Valid extras breadcrumb should list xedats_precomputed_id as known key.")

	_expect(int(payload.get("xedats_extras_warning_count", -1)) == 0,
		"Valid extras breadcrumb should report zero warning count.")

	var binding_node: Node = null
	for child: Node in emitter_node.get_children():
		if child.name == &"XedatsGLTFAudioEmitterBinding":
			binding_node = child
			break
	_expect(binding_node != null, "Valid xedats extras fixture should attach an XedatsGLTFAudioEmitterBinding child.")
	if binding_node != null:
		_expect(String(binding_node.get_meta(&"xedats_precomputed_resolution_key", "")) == "zone_a",
			"Binding should expose resolved precomputed key 'zone_a'.")
		_expect(_is_close(float(binding_node.get_meta(&"xedats_precomputed_effective_gain", -1.0)), 0.56),
			"Binding should apply precomputed gain multiplier to authored gain (0.7 -> 0.56).")
		_expect(bool(binding_node.get_meta(&"xedats_precomputed_enable_occlusion", true)) == false,
			"Binding should expose occlusion override from the precomputed profile.")
		var precomputed_bus: String = String(binding_node.get_meta(&"xedats_precomputed_bus", ""))
		_expect(precomputed_bus == "FixturePrecomputedZoneA",
			"Binding should route profile zone_a through explicit precomputed bus name.")
		var xedats: XedatsSingleton = XedatsSingleton.instance()
		if xedats != null and not precomputed_bus.is_empty():
			var bus_info: Dictionary = xedats.get_bus_info()
			_expect(bus_info.has(precomputed_bus),
				"Precomputed zone_a bus should be created in Xedats bus registry.")
			if bus_info.has(precomputed_bus):
				var info_variant: Variant = bus_info[precomputed_bus]
				if info_variant is Dictionary:
					var info: Dictionary = info_variant
					_expect(int(info.get("effects", 0)) == 3,
						"Precomputed zone_a bus should have 3 effects (low-pass, high-pass, reverb).")


func _validate_xedats_extras_invalid_fixture() -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_XEDATS_EXTRAS_INVALID)
	if fixture_root == null:
		return

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixtureXedatsExtrasInvalidEmitter")
	_expect(emitter_node != null, "Invalid xedats extras fixture should contain FixtureXedatsExtrasInvalidEmitter node.")
	if emitter_node == null:
		return
	_expect_runtime_path_meta(_find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding"), "Invalid xedats extras fixture")

	_expect(emitter_node.has_meta(&"xedats_khr_audio_emitter"), "Invalid xedats extras fixture should expose resolved emitter payload metadata.")
	if not emitter_node.has_meta(&"xedats_khr_audio_emitter"):
		return

	var payload_variant: Variant = emitter_node.get_meta(&"xedats_khr_audio_emitter")
	_expect(payload_variant is Dictionary, "Invalid xedats extras payload should be a Dictionary.")
	if not (payload_variant is Dictionary):
		return

	var payload: Dictionary = payload_variant
	_expect(String(payload.get("xedats_reflection_budget", "")) == "medium", "Invalid xedats_reflection_budget should fallback to 'medium'.")
	_expect(_is_close(float(payload.get("xedats_texture_density", -1.0)), 1.0), "Out-of-range xedats_texture_density should clamp to 1.0.")
	_expect(_is_close(float(payload.get("xedats_texture_variance", -1.0)), 0.0), "Out-of-range xedats_texture_variance should clamp to 0.0.")
	_expect(_is_close(float(payload.get("xedats_dynamic_portal_openness", -1.0)), 1.0),
		"Out-of-range xedats_dynamic_portal_openness should clamp to 1.0.")
	_expect(_is_close(float(payload.get("xedats_dynamic_portal_closed_gain_scale", -1.0)), 0.0),
		"Out-of-range xedats_dynamic_portal_closed_gain_scale should clamp to 0.0.")
	_expect(not payload.has("xedats_texture_profile"), "Empty xedats_texture_profile should be ignored.")
	_expect(not payload.has("xedats_precomputed_id"), "Empty xedats_precomputed_id should be ignored.")
	_expect(not payload.has("xedats_probe_region"), "Wrong-type xedats_probe_region should be ignored.")

	var warning_keys_variant: Variant = payload.get("xedats_extras_warning_keys", PackedStringArray())
	_expect(warning_keys_variant is PackedStringArray or warning_keys_variant is Array,
		"Invalid extras payload should include xedats_extras_warning_keys breadcrumb.")
	if warning_keys_variant is PackedStringArray:
		var warning_keys: PackedStringArray = warning_keys_variant
		_expect(warning_keys.has("xedats_reflection_budget"),
			"Invalid extras breadcrumb should include xedats_reflection_budget warning key.")
		_expect(warning_keys.has("xedats_probe_region"),
			"Invalid extras breadcrumb should include xedats_probe_region warning key.")
	_expect(int(payload.get("xedats_extras_warning_count", 0)) >= 2,
		"Invalid extras breadcrumb should report warning count >= 2.")


func _validate_reflection_budget_cap_fixture() -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_REFLECTION_BUDGET_CAP)
	if fixture_root == null:
		return

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixtureReflectionBudgetCapEmitter")
	_expect(emitter_node != null, "Reflection budget cap fixture should contain FixtureReflectionBudgetCapEmitter node.")
	if emitter_node == null:
		return
	_expect_runtime_path_meta(_find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding"), "Reflection budget cap fixture")

	_expect(emitter_node.has_meta(&"xedats_khr_audio_emitter"), "Reflection budget cap fixture should expose resolved emitter payload metadata.")
	if not emitter_node.has_meta(&"xedats_khr_audio_emitter"):
		return

	var payload_variant: Variant = emitter_node.get_meta(&"xedats_khr_audio_emitter")
	_expect(payload_variant is Dictionary, "Reflection budget cap payload should be a Dictionary.")
	if not (payload_variant is Dictionary):
		return

	var payload: Dictionary = payload_variant
	_expect(String(payload.get("xedats_reflection_budget", "")) == "low", "Reflection budget cap fixture should preserve xedats_reflection_budget='low'.")
	_expect(int(payload.get("xedats_reflection_max_sources", -1)) == 2, "Low reflection budget should resolve to max source cap of 2.")
	_expect(bool(payload.get("xedats_reflection_capped", false)), "Reflection budget cap fixture should report capped=true.")

	var ranked_variant: Variant = payload.get("xedats_reflection_ranked_sources", [])
	_expect(ranked_variant is Array, "Reflection budget cap payload should expose ranked sources array.")
	if ranked_variant is Array:
		var ranked_sources: Array = ranked_variant
		_expect(ranked_sources.size() == 3, "Reflection budget cap payload should keep 3 ranked source entries before capping.")

	var source_paths_variant: Variant = payload.get("source_paths", [])
	_expect(source_paths_variant is Array, "Reflection budget cap payload should expose capped source_paths array.")
	if not (source_paths_variant is Array):
		return

	var source_paths: Array = source_paths_variant
	_expect(source_paths.size() == 2, "Reflection budget cap payload should cap source_paths to 2 entries.")
	if source_paths.size() >= 2:
		_expect(String(source_paths[0]) == EXPECTED_CAP_PATH_0, "Reflection budget cap first source should be door_unlock_sfx.wav.")
		_expect(String(source_paths[1]) == EXPECTED_CAP_PATH_1, "Reflection budget cap second source should be open_gate_sfx.wav.")


## Validates that [code]xedats_texture_density[/code] and
## [code]xedats_texture_variance[/code] in a multi-source emitter produce the
## expected [code]volume_variation[/code] on the [AudioArrayContainer] at
## binding time.  Also verifies the safe no-op path: when both extras are
## absent, [code]volume_variation[/code] collapses to [code]Vector2(gain, gain)[/code].
func _validate_texture_modulation_fixture() -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_TEXTURE_MODULATION)
	if fixture_root == null:
		return

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixtureTextureModulationEmitter")
	_expect(emitter_node != null, "Texture modulation fixture should contain FixtureTextureModulationEmitter node.")
	if emitter_node == null:
		return
	_expect_runtime_path_meta(_find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding"), "Texture modulation fixture")

	# Validate that importer wrote texture extras into payload metadata.
	_expect(emitter_node.has_meta(&"xedats_khr_audio_emitter"), "Texture modulation fixture should expose resolved emitter payload metadata.")
	if emitter_node.has_meta(&"xedats_khr_audio_emitter"):
		var payload: Dictionary = emitter_node.get_meta(&"xedats_khr_audio_emitter") as Dictionary
		_expect(String(payload.get("xedats_texture_profile", "")) == "rain_dense",
			"Texture modulation payload should carry xedats_texture_profile='rain_dense'.")
		_expect(absf(float(payload.get("xedats_texture_density", -1.0)) - 0.5) < 0.001,
			"Texture modulation payload should carry xedats_texture_density=0.5.")
		_expect(absf(float(payload.get("xedats_texture_variance", -1.0)) - 0.4) < 0.001,
			"Texture modulation payload should carry xedats_texture_variance=0.4.")

	# Locate the binding child node to inspect the computed volume_variation.
	var binding_node: Node = null
	for child: Node in emitter_node.get_children():
		if child.name == &"XedatsGLTFAudioEmitterBinding":
			binding_node = child
			break
	_expect(binding_node != null, "Texture modulation fixture emitter should have an XedatsGLTFAudioEmitterBinding child.")
	if binding_node == null:
		return

	_expect(binding_node.has_meta(&"xedats_texture_volume_variation"),
		"Binding node should record computed volume_variation as xedats_texture_volume_variation metadata.")
	_expect(binding_node.has_meta(&"xedats_texture_cadence_enabled"),
		"Binding node should expose texture cadence enabled metadata.")
	_expect(binding_node.has_meta(&"xedats_texture_cadence_seconds"),
		"Binding node should expose texture cadence interval metadata.")
	if not binding_node.has_meta(&"xedats_texture_volume_variation"):
		return
	if binding_node.has_meta(&"xedats_texture_cadence_enabled"):
		_expect(bool(binding_node.get_meta(&"xedats_texture_cadence_enabled", false)),
			"Texture modulation fixture should enable cadence when texture extras are authored.")
	if binding_node.has_meta(&"xedats_texture_cadence_seconds"):
		_expect(float(binding_node.get_meta(&"xedats_texture_cadence_seconds", 0.0)) > 0.0,
			"Texture modulation fixture cadence interval should be > 0.")

	var vol_var: Vector2 = binding_node.get_meta(&"xedats_texture_volume_variation")
	_expect(absf(vol_var.x - EXPECTED_TEXTURE_VOL_MIN) < 0.001,
		"Texture volume variation min should be ~%.2f (got %.4f)." % [EXPECTED_TEXTURE_VOL_MIN, vol_var.x])
	_expect(absf(vol_var.y - EXPECTED_TEXTURE_VOL_MAX) < 0.001,
		"Texture volume variation max should be ~%.2f (got %.4f)." % [EXPECTED_TEXTURE_VOL_MAX, vol_var.y])
	_expect(vol_var.x < vol_var.y,
		"Texture volume variation min should be less than max.")


## Validates Group D distance-band policy parsing and binding-time application.
##
## Two emitters are tested:
## 1. [code]xedats_distance_policy = "texture"[/code] — policy key should appear
##    in payload; binding should expose [code]xedats_distance_volume_variation[/code]
##    metadata.  Since no listener is active in headless tests, the distance
##    sampler returns -1 and the modulated result must equal the base texture
##    variation (safe no-op for missing listener).
## 2. [code]xedats_distance_policy = "none"[/code] — binding should NOT set the
##    [code]xedats_distance_volume_variation[/code] meta because the policy gate
##    returns before reaching the distance query.
func _validate_distance_policy_fixture() -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_DISTANCE_POLICY)
	if fixture_root == null:
		return

	# --- Emitter 1: policy = "texture" ---
	var texture_node: Node = _find_node_by_name(fixture_root, "FixtureDistancePolicyTextureEmitter")
	_expect(texture_node != null,
		"Distance policy fixture should contain FixtureDistancePolicyTextureEmitter node.")
	_expect_runtime_path_meta(_find_node_by_name(texture_node, "XedatsGLTFAudioEmitterBinding"), "Distance policy texture fixture")
	if texture_node != null:
		_expect(texture_node.has_meta(&"xedats_khr_audio_emitter"),
			"Distance policy texture emitter should expose payload metadata.")
		if texture_node.has_meta(&"xedats_khr_audio_emitter"):
			var payload: Dictionary = texture_node.get_meta(&"xedats_khr_audio_emitter") as Dictionary
			_expect(String(payload.get("xedats_distance_policy", "")) == "texture",
				"Distance policy fixture should preserve xedats_distance_policy='texture' in payload.")

		var binding_node: Node = null
		for child: Node in texture_node.get_children():
			if child.name == &"XedatsGLTFAudioEmitterBinding":
				binding_node = child
				break
		_expect(binding_node != null,
			"Distance policy texture emitter should have an XedatsGLTFAudioEmitterBinding child.")
		if binding_node != null:
			_expect(binding_node.has_meta(&"xedats_texture_volume_variation"),
				"Distance policy texture binding should record base texture volume variation metadata.")
			_expect(binding_node.has_meta(&"xedats_distance_volume_variation"),
				"Distance policy texture binding should record distance-modulated volume variation metadata.")
			if binding_node.has_meta(&"xedats_texture_volume_variation") \
					and binding_node.has_meta(&"xedats_distance_volume_variation"):
				var base_var: Vector2 = binding_node.get_meta(&"xedats_texture_volume_variation")
				var dist_var: Vector2 = binding_node.get_meta(&"xedats_distance_volume_variation")
				# No listener in headless context → distance = -1 → no-op modulation.
				_expect(absf(dist_var.x - base_var.x) < 0.001,
					"With no listener, distance volume variation min should equal base texture min.")
				_expect(absf(dist_var.y - base_var.y) < 0.001,
					"With no listener, distance volume variation max should equal base texture max.")

	# --- Emitter 2: policy = "none" ---
	var none_node: Node = _find_node_by_name(fixture_root, "FixtureDistancePolicyNoneEmitter")
	_expect(none_node != null,
		"Distance policy fixture should contain FixtureDistancePolicyNoneEmitter node.")
	_expect_runtime_path_meta(_find_node_by_name(none_node, "XedatsGLTFAudioEmitterBinding"), "Distance policy none fixture")
	if none_node != null:
		var binding_node: Node = null
		for child: Node in none_node.get_children():
			if child.name == &"XedatsGLTFAudioEmitterBinding":
				binding_node = child
				break
		_expect(binding_node != null,
			"Distance policy none emitter should have an XedatsGLTFAudioEmitterBinding child.")
		if binding_node != null:
			_expect(not binding_node.has_meta(&"xedats_distance_volume_variation"),
				"Distance policy='none' binding should NOT set xedats_distance_volume_variation metadata.")


func _validate_portal_source_path_auto_bind_fixtures() -> void:
	_validate_portal_source_path_dot_fixture()
	_validate_portal_source_path_bad_fixture()


func _validate_portal_source_path_dot_fixture() -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_PORTAL_SOURCE_PATH_DOT)
	if fixture_root == null:
		return

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixturePortalSourcePathDotEmitter")
	_expect(emitter_node != null,
		"Portal source-path dot fixture should contain FixturePortalSourcePathDotEmitter node.")
	if emitter_node == null:
		return
	_expect_runtime_path_meta(_find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding"), "Portal source-path dot fixture")

	# Assign a test script that exposes `is_open` + `open_state_changed` before the
	# binding's deferred auto-bind runs.
	emitter_node.set_script(PORTAL_STATE_STUB_SCRIPT)

	if emitter_node.has_meta(&"xedats_khr_audio_emitter"):
		var payload: Dictionary = emitter_node.get_meta(&"xedats_khr_audio_emitter") as Dictionary
		_expect(String(payload.get("xedats_portal_source_path", "")) == ".",
			"Portal source-path dot fixture should preserve xedats_portal_source_path='.'.")

	await get_tree().process_frame

	var binding_node: Node = null
	for child: Node in emitter_node.get_children():
		if child.name == &"XedatsGLTFAudioEmitterBinding":
			binding_node = child
			break
	_expect(binding_node != null,
		"Portal source-path dot emitter should have an XedatsGLTFAudioEmitterBinding child.")
	if binding_node == null:
		return

	_expect(binding_node.has_meta(&"xedats_portal_auto_bind_resolved_path"),
		"Dot path auto-bind should record xedats_portal_auto_bind_resolved_path metadata.")
	if binding_node.has_meta(&"xedats_portal_auto_bind_resolved_path"):
		_expect(String(binding_node.get_meta(&"xedats_portal_auto_bind_resolved_path", "")) == ".",
			"Dot path auto-bind should resolve and preserve path '.'.")

	_expect(bool(binding_node.get_meta(&"xedats_dynamic_portal_adapter_bound", false)),
		"Dot path auto-bind should set xedats_dynamic_portal_adapter_bound=true.")

	var service: XedatsDynamicApproximationService = XedatsDynamicApproximationService.instance()
	_expect(service != null, "Dynamic approximation service should exist for portal auto-bind validation.")
	if service == null:
		return

	var binding_node_3d: Node3D = binding_node as Node3D
	_expect(binding_node_3d != null,
		"Dot path binding node should be a Node3D for dynamic service state queries.")
	if binding_node_3d == null:
		return

	var initial_state: Dictionary = service.get_record_debug_state(binding_node_3d)
	_expect(not initial_state.is_empty(),
		"Dot path binding should be registered in dynamic approximation service.")
	if not initial_state.is_empty():
		_expect(_is_close(float(initial_state.get("portal_openness", -1.0)), 0.0),
			"Dot path auto-bind should sample stub is_open=false as portal_openness=0.0.")

	emitter_node.call("set_open_state", true)
	await get_tree().process_frame

	var opened_state: Dictionary = service.get_record_debug_state(binding_node_3d)
	_expect(not opened_state.is_empty(),
		"Dot path binding should remain registered after open_state_changed signal.")
	if not opened_state.is_empty():
		_expect(_is_close(float(opened_state.get("portal_openness", -1.0)), 1.0),
			"Dot path auto-bind should react to open_state_changed(true) with portal_openness=1.0.")


func _validate_portal_source_path_bad_fixture() -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_PORTAL_SOURCE_PATH_BAD)
	if fixture_root == null:
		return

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixturePortalSourcePathBadEmitter")
	_expect(emitter_node != null,
		"Portal source-path bad fixture should contain FixturePortalSourcePathBadEmitter node.")
	if emitter_node == null:
		return
	_expect_runtime_path_meta(_find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding"), "Portal source-path bad fixture")

	if emitter_node.has_meta(&"xedats_khr_audio_emitter"):
		var payload: Dictionary = emitter_node.get_meta(&"xedats_khr_audio_emitter") as Dictionary
		_expect(String(payload.get("xedats_portal_source_path", "")) == "Missing/Portal/Node",
			"Portal source-path bad fixture should preserve xedats_portal_source_path='Missing/Portal/Node'.")

	await get_tree().process_frame

	var binding_node: Node = null
	for child: Node in emitter_node.get_children():
		if child.name == &"XedatsGLTFAudioEmitterBinding":
			binding_node = child
			break
	_expect(binding_node != null,
		"Portal source-path bad emitter should have an XedatsGLTFAudioEmitterBinding child.")
	if binding_node == null:
		return

	_expect(not binding_node.has_meta(&"xedats_portal_auto_bind_resolved_path"),
		"Bad path auto-bind should not set xedats_portal_auto_bind_resolved_path metadata.")
	_expect(not bool(binding_node.get_meta(&"xedats_dynamic_portal_adapter_bound", false)),
		"Bad path auto-bind should leave xedats_dynamic_portal_adapter_bound unset/false.")

	var service: XedatsDynamicApproximationService = XedatsDynamicApproximationService.instance()
	_expect(service != null, "Dynamic approximation service should exist for bad-path portal validation.")
	if service == null:
		return

	var binding_node_3d: Node3D = binding_node as Node3D
	_expect(binding_node_3d != null,
		"Bad path binding node should be a Node3D for dynamic service state queries.")
	if binding_node_3d == null:
		return

	var record_state: Dictionary = service.get_record_debug_state(binding_node_3d)
	_expect(not record_state.is_empty(),
		"Bad path binding should still be registered in dynamic approximation service.")
	if not record_state.is_empty():
		_expect(_is_close(float(record_state.get("portal_openness", -1.0)), 0.55),
			"Bad path auto-bind should keep authored xedats_dynamic_portal_openness=0.55 (warning path, no bind).")


## Validates the [XedatsDynamicApproximationService] skeleton API contract:
## service creation, registration, duplicate rejection, unregistration,
## and enable/disable toggle — all without requiring an active listener or
## GLTF scene import.
func _validate_dynamic_approximation_service() -> void:
	# --- Service lifecycle ---
	var service: XedatsDynamicApproximationService = XedatsDynamicApproximationService.get_or_create(self )
	_expect(service != null, "Dynamic approximation service should be created via get_or_create.")
	if service == null:
		return
	_expect(service.enabled, "Dynamic approximation service should default to enabled.")
	_expect(XedatsDynamicApproximationService.instance() == service,
		"instance() should return the same object as get_or_create.")

	# --- Registration ---
	var dummy_emitter: Node3D = Node3D.new()
	add_child(dummy_emitter)
	var pre_count: int = service.get_record_count()

	var registered: bool = service.register_emitter(
		dummy_emitter,
		null,
		{
			"loop": false,
			"gain": 1.0,
			"xedats_dynamic_update_cooldown": 0.001,
			"xedats_dynamic_attack_seconds": 0.005,
			"xedats_dynamic_release_seconds": 9.0,
			"xedats_dynamic_smoothing_mode": "exp"
		},
		null
	)
	_expect(registered, "register_emitter should return true for a valid Node3D.")
	_expect(service.get_record_count() == pre_count + 1,
		"Record count should increase by 1 after registration.")

	# --- Phase 3 tuning surface + cooldown clamp ---
	var tuning: Dictionary = service.get_runtime_tuning()
	_expect(String(tuning.get("quality_preset", "")) == "medium",
		"Runtime tuning should default to quality preset 'medium'.")
	_expect(bool(tuning.get("runtime_master_mute_enabled", false)),
		"Runtime tuning should report runtime_master_mute_enabled=true.")
	_expect(bool(tuning.get("state_signal_hooks_enabled", false)),
		"Runtime tuning should report state_signal_hooks_enabled=true.")
	_expect(bool(tuning.get("listener_transition_hooks_enabled", false)),
		"Runtime tuning should report listener_transition_hooks_enabled=true.")
	_expect(bool(tuning.get("portal_state_hooks_enabled", false)),
		"Runtime tuning should report portal_state_hooks_enabled=true.")
	_expect(_is_close(float(tuning.get("listener_motion_threshold", -1.0)), 0.15),
		"Runtime tuning should expose listener_motion_threshold=0.15.")
	_expect(_is_close(float(tuning.get("listener_idle_refresh_interval", -1.0)), 0.8),
		"Runtime tuning should expose listener_idle_refresh_interval=0.8s.")
	_expect(_is_close(float(tuning.get("default_emitter_cooldown_seconds", -1.0)), 0.2),
		"Runtime tuning should expose default emitter cooldown of 0.2s.")
	_expect(_is_close(float(tuning.get("default_attack_seconds", -1.0)), 0.12),
		"Runtime tuning should expose default attack smoothing of 0.12s.")
	_expect(_is_close(float(tuning.get("default_release_seconds", -1.0)), 0.28),
		"Runtime tuning should expose default release smoothing of 0.28s.")
	_expect(_is_close(float(tuning.get("default_portal_closed_gain_scale", -1.0)), 0.35),
		"Runtime tuning should expose default portal closed gain scale of 0.35.")
	_expect(_is_close(float(tuning.get("min_smoothing_seconds", -1.0)), 0.01),
		"Runtime tuning should expose minimum smoothing of 0.01s.")
	_expect(_is_close(float(tuning.get("max_smoothing_seconds", -1.0)), 2.0),
		"Runtime tuning should expose maximum smoothing of 2.0s.")
	_expect(_is_close(float(tuning.get("min_portal_closed_gain_scale", -1.0)), 0.0),
		"Runtime tuning should expose minimum portal closed gain scale of 0.0.")
	_expect(_is_close(float(tuning.get("max_portal_closed_gain_scale", -1.0)), 1.0),
		"Runtime tuning should expose maximum portal closed gain scale of 1.0.")
	_expect(String(tuning.get("default_smoothing_mode", "")) == "linear",
		"Runtime tuning should expose default smoothing mode 'linear'.")
	var valid_modes: PackedStringArray = PackedStringArray(tuning.get("valid_smoothing_modes", PackedStringArray()))
	_expect(valid_modes.has("linear") and valid_modes.has("exp"),
		"Runtime tuning should expose valid smoothing modes [linear, exp].")

	# --- Phase 6 quality preset transitions ---
	_expect(service.set_quality_preset("low"),
		"set_quality_preset('low') should succeed.")
	var low_tuning: Dictionary = service.get_runtime_tuning()
	_expect(String(low_tuning.get("quality_preset", "")) == "low",
		"Runtime tuning should report quality preset 'low' after set_quality_preset('low').")
	_expect(_is_close(float(low_tuning.get("tick_interval", -1.0)), 0.16),
		"Low preset should set tick_interval to 0.16s.")
	_expect(int(low_tuning.get("max_emitters_per_tick", -1)) == 4,
		"Low preset should set max_emitters_per_tick to 4.")
	_expect(_is_close(float(low_tuning.get("default_emitter_cooldown_seconds", -1.0)), 0.30),
		"Low preset should set default cooldown to 0.30s.")

	_expect(service.set_quality_preset("high"),
		"set_quality_preset('high') should succeed.")
	var high_tuning: Dictionary = service.get_runtime_tuning()
	_expect(String(high_tuning.get("quality_preset", "")) == "high",
		"Runtime tuning should report quality preset 'high' after set_quality_preset('high').")
	_expect(_is_close(float(high_tuning.get("tick_interval", -1.0)), 0.08),
		"High preset should set tick_interval to 0.08s.")
	_expect(int(high_tuning.get("max_emitters_per_tick", -1)) == 16,
		"High preset should set max_emitters_per_tick to 16.")
	_expect(_is_close(float(high_tuning.get("default_emitter_cooldown_seconds", -1.0)), 0.10),
		"High preset should set default cooldown to 0.10s.")

	_expect(not service.set_quality_preset("ultra"),
		"Unknown quality preset should return false.")
	_expect(String(service.get_quality_preset()) == "high",
		"Invalid quality preset should not change the current preset.")

	_expect(service.set_quality_preset("medium"),
		"set_quality_preset('medium') should restore baseline defaults.")

	# --- Phase 7 runtime mute-state checks ---
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	_expect(xedats != null, "Phase 7 mute-state check requires XedatsSingleton instance.")
	if xedats != null:
		var state_manager: AudioStateManager = xedats.get_state_manager()
		_expect(state_manager != null, "Phase 7 mute-state check requires AudioStateManager instance.")
		if state_manager != null:
			var pre_refresh_count: int = int(service.get_runtime_tuning().get("refresh_request_count", -1))
			service.request_immediate_refresh()
			var requested_refresh_count: int = int(service.get_runtime_tuning().get("refresh_request_count", -1))
			_expect(requested_refresh_count == pre_refresh_count + 1,
				"request_immediate_refresh should increment refresh_request_count.")
			var refreshed_state: Dictionary = service.get_record_debug_state(dummy_emitter)
			_expect(_is_close(float(refreshed_state.get("next_allowed_update_time", -1.0)), 0.0),
				"Immediate refresh should clear per-record next_allowed_update_time.")
			_expect(bool(service.get_runtime_tuning().get("state_signal_connected", false)),
				"Service should report active AudioStateManager signal connection when state manager exists.")

			var before_signal_count: int = int(service.get_runtime_tuning().get("refresh_request_count", -1))
			state_manager.state_reset.emit()
			var after_signal_count: int = int(service.get_runtime_tuning().get("refresh_request_count", -1))
			_expect(after_signal_count == before_signal_count + 1,
				"AudioStateManager state_reset signal should trigger immediate refresh hook.")

			# --- Phase 10 listener transition hooks ---
			var previous_listener: XedatsListener3D = xedats.get_current_listener()
			var listener_refresh_before: int = int(service.get_runtime_tuning().get("listener_refresh_count", -1))
			var listener_a: XedatsListener3D = _make_test_listener(Vector3.ZERO)
			xedats.set_current_listener(listener_a)
			service._do_tick()
			var after_listener_a: Dictionary = service.get_runtime_tuning()
			_expect(int(after_listener_a.get("listener_refresh_count", -1)) == listener_refresh_before + 1,
				"First listener acquisition should increment listener_refresh_count.")
			_expect(String(after_listener_a.get("last_refresh_reason", "")) == "listener_changed",
				"Listener acquisition should set last_refresh_reason='listener_changed'.")

			var listener_b: XedatsListener3D = _make_test_listener(Vector3(1.0, 0.0, 0.0))
			xedats.set_current_listener(listener_b)
			service._do_tick()
			var after_listener_b: Dictionary = service.get_runtime_tuning()
			_expect(int(after_listener_b.get("listener_refresh_count", -1)) == listener_refresh_before + 2,
				"Listener swap should increment listener_refresh_count again.")
			_expect(String(after_listener_b.get("last_refresh_reason", "")) == "listener_changed",
				"Listener swap should keep last_refresh_reason='listener_changed'.")

			if previous_listener != null and is_instance_valid(previous_listener):
				xedats.set_current_listener(previous_listener)
			else:
				xedats.set_current_listener(listener_a)
			_dispose_node(listener_a)
			_dispose_node(listener_b)

			var previous_muted: bool = state_manager.is_category_muted("SFX")
			var previous_volume: float = xedats.get_category_volume("SFX")
			var previous_master_muted: bool = state_manager.is_master_muted()
			var previous_master_volume: float = xedats.get_category_volume("Master")

			state_manager.set_master_muted(false)
			xedats.set_category_volume("Master", 1.0)

			state_manager.unmute_category("SFX")
			xedats.set_category_volume("SFX", 1.0)
			_expect(not service.is_category_runtime_muted("SFX"),
				"Unmuted category with volume 1.0 should report runtime mute=false.")
			_expect(not service.is_master_runtime_muted(),
				"Master unmuted with volume 1.0 should report runtime master mute=false.")
			_expect(not service.is_runtime_audio_suppressed("SFX"),
				"Master+category unmuted should report runtime suppression=false.")

			state_manager.mute_category("SFX")
			_expect(service.is_category_runtime_muted("SFX"),
				"Muted category should report runtime mute=true.")

			state_manager.unmute_category("SFX")
			xedats.set_category_volume("SFX", 0.0)
			_expect(service.is_category_runtime_muted("SFX"),
				"Category volume 0.0 should report runtime mute=true.")

			state_manager.set_master_muted(true)
			xedats.set_category_volume("SFX", 1.0)
			_expect(service.is_master_runtime_muted(),
				"Explicit master mute should report runtime master mute=true.")
			_expect(service.is_runtime_audio_suppressed("SFX"),
				"Explicit master mute should suppress runtime audio even when category is unmuted.")

			state_manager.set_master_muted(false)
			xedats.set_category_volume("Master", 0.0)
			_expect(service.is_master_runtime_muted(),
				"Master volume 0.0 should report runtime master mute=true.")
			_expect(service.is_runtime_audio_suppressed("SFX"),
				"Master volume 0.0 should suppress runtime audio.")

			state_manager.set_master_muted(previous_master_muted)
			xedats.set_category_volume("Master", previous_master_volume)
			xedats.set_category_volume("SFX", previous_volume)
			if previous_muted:
				state_manager.mute_category("SFX")
			else:
				state_manager.unmute_category("SFX")

	# --- Phase 11 portal state integration ---
	var profile_stub: Resource = load(
		XedatsGLTFConfig.resources_root() + "/GLTF/xedats_distance_band_profile_default.tres"
	)
	var portal_emitter: Node3D = Node3D.new()
	add_child(portal_emitter)
	portal_emitter.global_position = Vector3.ZERO
	var portal_registered: bool = service.register_emitter(
		portal_emitter,
		null,
		{
			"loop": false,
			"gain": 1.0,
			"xedats_dynamic_portal_openness": - 0.5,
			"xedats_dynamic_portal_closed_gain_scale": 1.4
		},
		profile_stub
	)
	_expect(portal_registered, "Portal-state emitter should register successfully.")
	var portal_initial_state: Dictionary = service.get_record_debug_state(portal_emitter)
	_expect(_is_close(float(portal_initial_state.get("portal_openness", -1.0)), 0.0),
		"Portal openness should clamp to 0.0 when authored below range.")
	_expect(_is_close(float(portal_initial_state.get("portal_closed_gain_scale", -1.0)), 1.0),
		"Portal closed gain scale should clamp to 1.0 when authored above range.")

	var xedats_portal: XedatsSingleton = XedatsSingleton.instance()
	if xedats_portal != null:
		var previous_listener_portal: XedatsListener3D = xedats_portal.get_current_listener()
		var portal_listener: XedatsListener3D = _make_test_listener(Vector3.ZERO)
		xedats_portal.set_current_listener(portal_listener)
		service._do_tick()
		var portal_closed_state: Dictionary = service.get_record_debug_state(portal_emitter)
		_expect(_is_close(float(portal_closed_state.get("target_gain_scale", -1.0)), 1.0),
			"Clamped portal closed gain scale of 1.0 should preserve target gain scale.")

		_expect(service.set_emitter_portal_closed_gain_scale(portal_emitter, 0.25),
			"set_emitter_portal_closed_gain_scale should succeed for registered emitter.")
		_expect(service.set_emitter_portal_openness(portal_emitter, 0.0),
			"set_emitter_portal_openness should succeed for registered emitter.")
		service._do_tick()
		var portal_updated_state: Dictionary = service.get_record_debug_state(portal_emitter)
		_expect(_is_close(float(portal_updated_state.get("portal_closed_gain_scale", -1.0)), 0.25),
			"Portal closed gain scale should update to 0.25 at runtime.")
		_expect(_is_close(float(portal_updated_state.get("portal_gain_scale", -1.0)), 0.25),
			"Portal gain scale should evaluate to 0.25 when fully closed.")
		_expect(_is_close(float(portal_updated_state.get("target_gain_scale", -1.0)), 0.25),
			"Target gain scale should include portal attenuation when fully closed.")
		_expect(int(portal_updated_state.get("portal_state_change_count", -1)) == 2,
			"Portal state change count should increment for both runtime updates.")

		_expect(service.set_emitter_portal_openness(portal_emitter, 1.0),
			"set_emitter_portal_openness should allow reopening the portal.")
		service._do_tick()
		var portal_open_state: Dictionary = service.get_record_debug_state(portal_emitter)
		_expect(_is_close(float(portal_open_state.get("portal_gain_scale", -1.0)), 1.0),
			"Portal gain scale should return to 1.0 when fully open.")
		_expect(_is_close(float(portal_open_state.get("target_gain_scale", -1.0)), 1.0),
			"Target gain scale should return to 1.0 when the portal is fully open.")

		if previous_listener_portal != null and is_instance_valid(previous_listener_portal):
			xedats_portal.set_current_listener(previous_listener_portal)
		else:
			xedats_portal.set_current_listener(portal_listener)
		_dispose_node(portal_listener)

	var unknown_portal_emitter: Node3D = Node3D.new()
	_expect(not service.set_emitter_portal_openness(unknown_portal_emitter, 0.5),
		"set_emitter_portal_openness should return false for unknown emitters.")
	_expect(not service.set_emitter_portal_closed_gain_scale(unknown_portal_emitter, 0.5),
		"set_emitter_portal_closed_gain_scale should return false for unknown emitters.")
	unknown_portal_emitter.free()

	# --- Phase 12 portal source adapter ---
	var adapter_binding: XedatsGLTFAudioEmitterBinding = XedatsGLTFAudioEmitterBinding.new()
	add_child(adapter_binding)
	var adapter_registered: bool = service.register_emitter(
		adapter_binding,
		null,
		{"loop": false, "gain": 1.0},
		profile_stub
	)
	_expect(adapter_registered,
		"Portal adapter binding should register successfully.")
	var signal_source: _PortalSignalSource = _PortalSignalSource.new()
	add_child(signal_source)
	signal_source.is_open = false
	_expect(adapter_binding.bind_dynamic_portal_state_source(signal_source),
		"bind_dynamic_portal_state_source should accept a source with open-state signals.")
	var adapter_initial_state: Dictionary = service.get_record_debug_state(adapter_binding)
	_expect(_is_close(float(adapter_initial_state.get("portal_openness", -1.0)), 0.0),
		"Portal adapter should apply the initial closed state from the source node.")
	signal_source.set_open(true)
	var adapter_open_state: Dictionary = service.get_record_debug_state(adapter_binding)
	_expect(_is_close(float(adapter_open_state.get("portal_openness", -1.0)), 1.0),
		"Portal adapter should react immediately to open_state_changed(true).")
	signal_source.set_open(false)
	var adapter_closed_state: Dictionary = service.get_record_debug_state(adapter_binding)
	_expect(_is_close(float(adapter_closed_state.get("portal_openness", -1.0)), 0.0),
		"Portal adapter should react immediately to open_state_changed(false).")

	var polling_binding: XedatsGLTFAudioEmitterBinding = XedatsGLTFAudioEmitterBinding.new()
	add_child(polling_binding)
	var polling_registered: bool = service.register_emitter(
		polling_binding,
		null,
		{"loop": false, "gain": 1.0},
		profile_stub
	)
	_expect(polling_registered,
		"Polling portal adapter binding should register successfully.")
	var polling_source: _PortalPollingSource = _PortalPollingSource.new()
	add_child(polling_source)
	polling_source.is_open = false
	_expect(polling_binding.bind_dynamic_portal_state_source(polling_source),
		"bind_dynamic_portal_state_source should accept a source that exposes only is_open.")
	polling_source.is_open = true
	polling_binding._process(0.11)
	var polling_open_state: Dictionary = service.get_record_debug_state(polling_binding)
	_expect(_is_close(float(polling_open_state.get("portal_openness", -1.0)), 1.0),
		"Portal adapter should poll is_open when no signal is available.")
	polling_binding.clear_dynamic_portal_state_source()
	polling_source.is_open = false
	polling_binding._process(0.11)
	var polling_after_clear_state: Dictionary = service.get_record_debug_state(polling_binding)
	_expect(_is_close(float(polling_after_clear_state.get("portal_openness", -1.0)), 1.0),
		"Cleared portal adapter should stop applying source polling updates.")

	var invalid_portal_source: Node = Node.new()
	_expect(not polling_binding.bind_dynamic_portal_state_source(invalid_portal_source, &"is_open", &"portal_openness", false),
		"bind_dynamic_portal_state_source should reject nodes with no usable portal state surface.")
	invalid_portal_source.free()

	var record_state: Dictionary = service.get_record_debug_state(dummy_emitter)
	_expect(not record_state.is_empty(),
		"get_record_debug_state should return data for a registered emitter.")
	var adapter_binding_snapshot: Dictionary = adapter_binding.get_debug_snapshot()
	_expect(bool(adapter_binding_snapshot.get("portal_adapter_bound", false)),
		"Binding debug snapshot should expose portal adapter bind state.")
	_expect(adapter_binding_snapshot.has("dynamic_record"),
		"Binding debug snapshot should include dynamic service record data when registered.")
	var all_record_states: Array[Dictionary] = service.get_all_record_debug_states()
	_expect(all_record_states.size() == service.get_record_count(),
		"get_all_record_debug_states should return one snapshot per registered emitter.")
	var found_adapter_snapshot: bool = false
	for snapshot: Dictionary in all_record_states:
		if String(snapshot.get("emitter_name", "")) == String(adapter_binding.name):
			found_adapter_snapshot = true
			_expect(snapshot.has("binding_debug"),
				"Aggregate emitter debug snapshots should include binding_debug for binding emitters.")
			break
	_expect(found_adapter_snapshot,
		"Aggregate emitter debug snapshots should include the registered adapter binding.")
	_expect(_is_close(float(record_state.get("cooldown_seconds", -1.0)), 0.05),
		"Cooldown should clamp to minimum 0.05s when authored lower.")
	_expect(_is_close(float(record_state.get("attack_seconds", -1.0)), 0.01),
		"Attack smoothing should clamp to minimum 0.01s when authored lower.")
	_expect(_is_close(float(record_state.get("release_seconds", -1.0)), 2.0),
		"Release smoothing should clamp to maximum 2.0s when authored higher.")
	_expect(_is_close(float(record_state.get("smoothed_gain_scale", -1.0)), 1.0),
		"Initial smoothed_gain_scale should start at 1.0.")
	_expect(_is_close(float(record_state.get("target_gain_scale", -1.0)), 1.0),
		"Initial target_gain_scale should start at 1.0.")
	_expect(String(record_state.get("category", "")) == "SFX",
		"Record debug state should expose resolved category.")
	_expect(_is_close(float(record_state.get("portal_openness", -1.0)), 1.0),
		"Initial portal_openness should default to 1.0.")
	_expect(_is_close(float(record_state.get("portal_closed_gain_scale", -1.0)), 0.35),
		"Initial portal_closed_gain_scale should default to 0.35.")
	_expect(_is_close(float(record_state.get("portal_gain_scale", -1.0)), 1.0),
		"Initial portal_gain_scale should be 1.0 when the portal is fully open.")
	_expect(int(record_state.get("portal_state_change_count", -1)) == 0,
		"Initial portal_state_change_count should start at 0.")
	_expect(int(record_state.get("muted_skip_count", -1)) == 0,
		"Initial muted_skip_count should start at 0.")
	_expect(not bool(record_state.get("runtime_master_muted", true)),
		"Initial runtime_master_muted should be false under default fixture conditions.")
	_expect(not bool(record_state.get("runtime_audio_suppressed", true)),
		"Initial runtime_audio_suppressed should be false under default fixture conditions.")
	_expect(String(record_state.get("smoothing_mode", "")) == "exp",
		"Record smoothing mode should preserve authored 'exp' mode.")

	# --- Invalid smoothing mode fallback ---
	var fallback_emitter: Node3D = Node3D.new()
	add_child(fallback_emitter)
	var fallback_registered: bool = service.register_emitter(
		fallback_emitter,
		null,
		{"loop": false, "gain": 1.0, "xedats_dynamic_smoothing_mode": "cubic"},
		null
	)
	_expect(fallback_registered, "Fallback smoothing-mode fixture emitter should register.")
	var fallback_state: Dictionary = service.get_record_debug_state(fallback_emitter)
	_expect(String(fallback_state.get("smoothing_mode", "")) == "linear",
		"Unknown smoothing mode should deterministically fallback to 'linear'.")

	# --- Duplicate registration is rejected ---
	var registered_again: bool = service.register_emitter(dummy_emitter, null, {}, null)
	_expect(not registered_again, "Duplicate registration of the same node should return false.")
	_expect(service.get_record_count() == pre_count + 5,
		"Record count should not increase on duplicate registration.")

	# --- Live player update hook ---
	var dummy_player: XedatsPlayer3D = XedatsPlayer3D.new()
	add_child(dummy_player)
	var updated_player: bool = service.update_emitter_player(dummy_emitter, dummy_player)
	_expect(updated_player, "update_emitter_player should return true for registered emitter.")
	var player_state: Dictionary = service.get_record_debug_state(dummy_emitter)
	_expect(bool(player_state.get("has_player", false)),
		"Record debug state should reflect has_player=true after update_emitter_player.")
	var cleared_player: bool = service.update_emitter_player(dummy_emitter, null)
	_expect(cleared_player, "update_emitter_player should allow clearing player reference.")
	var cleared_state: Dictionary = service.get_record_debug_state(dummy_emitter)
	_expect(not bool(cleared_state.get("has_player", true)),
		"Record debug state should reflect has_player=false after clearing player ref.")
	var unknown_update_emitter: Node3D = Node3D.new()
	_expect(not service.update_emitter_player(unknown_update_emitter, dummy_player),
		"update_emitter_player should return false for unknown emitters.")
	unknown_update_emitter.free()

	# --- Unregistration ---
	var unregistered: bool = service.unregister_emitter(dummy_emitter)
	_expect(unregistered, "unregister_emitter should return true for a registered node.")
	_expect(service.get_record_count() == pre_count + 4,
		"Record count should return to pre-test value plus auxiliary portal/adapter/fallback emitters after unregistration.")

	# --- Unknown node unregistration returns false ---
	_expect(not service.unregister_emitter(dummy_emitter),
		"Unregistering an unknown node should return false.")
	_expect(service.unregister_emitter(portal_emitter),
		"Portal-state emitter should unregister cleanly.")
	_expect(service.unregister_emitter(adapter_binding),
		"Signal-driven portal adapter binding should unregister cleanly.")
	_expect(service.unregister_emitter(polling_binding),
		"Polling portal adapter binding should unregister cleanly.")
	_expect(service.unregister_emitter(fallback_emitter),
		"Fallback smoothing-mode emitter should unregister cleanly.")

	# --- Enable/disable toggle ---
	service.set_enabled(false)
	_expect(not service.enabled, "Service should reflect disabled state after set_enabled(false).")
	service.set_enabled(true)
	_expect(service.enabled, "Service should re-enable after set_enabled(true).")

	_dispose_node(dummy_emitter)
	_dispose_node(dummy_player)
	_dispose_node(portal_emitter)
	_dispose_node(adapter_binding)
	_dispose_node(signal_source)
	_dispose_node(polling_binding)
	_dispose_node(polling_source)
	_dispose_node(fallback_emitter)


func _dispose_node(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _make_test_listener(position: Vector3) -> XedatsListener3D:
	var listener: XedatsListener3D = XedatsListener3D.new()
	add_child(listener)
	listener.global_position = position
	return listener


class _PortalSignalSource:
	extends Node

	signal open_state_changed(is_open: bool)

	var is_open: bool = false

	func set_open(value: bool) -> void:
		if is_open == value:
			return
		is_open = value
		open_state_changed.emit(is_open)


class _PortalPollingSource:
	extends Node

	var is_open: bool = false


func _validate_precomputed_propagation_fixtures() -> void:
	_validate_precomputed_missing_fixture()
	_validate_precomputed_probe_region_fixture()


func _validate_precomputed_missing_fixture() -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_PRECOMPUTED_MISSING)
	if fixture_root == null:
		return

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixturePrecomputedMissingEmitter")
	_expect(emitter_node != null, "Precomputed-missing fixture should contain FixturePrecomputedMissingEmitter node.")
	_expect_runtime_path_meta(_find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding"), "Precomputed-missing fixture")
	if emitter_node == null or not emitter_node.has_meta(&"xedats_khr_audio_emitter"):
		return

	var payload_variant: Variant = emitter_node.get_meta(&"xedats_khr_audio_emitter")
	_expect(payload_variant is Dictionary, "Precomputed-missing payload should be a Dictionary.")
	if not (payload_variant is Dictionary):
		return

	var payload: Dictionary = payload_variant
	_expect(String(payload.get("xedats_precomputed_id", "")) == "missing_zone",
		"Precomputed-missing fixture should preserve the authored precomputed token.")
	_expect(not payload.has("xedats_precomputed_profile_path"),
		"Missing precomputed asset should not inject resolved profile metadata into payload.")

	var binding_node: Node = null
	for child: Node in emitter_node.get_children():
		if child.name == &"XedatsGLTFAudioEmitterBinding":
			binding_node = child
			break
	_expect(binding_node != null, "Precomputed-missing fixture should attach an XedatsGLTFAudioEmitterBinding child.")
	if binding_node != null:
		_expect(not binding_node.has_meta(&"xedats_precomputed_profile_path"),
			"Binding should not expose precomputed metadata when the asset lookup fails.")


func _validate_precomputed_probe_region_fixture() -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_PRECOMPUTED_PROBE_REGION)
	if fixture_root == null:
		return

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixturePrecomputedProbeRegionEmitter")
	_expect(emitter_node != null, "Precomputed probe-region fixture should contain FixturePrecomputedProbeRegionEmitter node.")
	_expect_runtime_path_meta(_find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding"), "Precomputed probe-region fixture")
	if emitter_node == null or not emitter_node.has_meta(&"xedats_khr_audio_emitter"):
		return

	var payload_variant: Variant = emitter_node.get_meta(&"xedats_khr_audio_emitter")
	_expect(payload_variant is Dictionary, "Precomputed probe-region payload should be a Dictionary.")
	if not (payload_variant is Dictionary):
		return

	var payload: Dictionary = payload_variant
	_expect(String(payload.get("xedats_precomputed_resolution_source", "")) == "probe_region",
		"Probe-region fixture should resolve precomputed propagation by xedats_probe_region.")
	_expect(String(payload.get("xedats_precomputed_resolution_key", "")) == "region_a",
		"Probe-region fixture should resolve key 'region_a'.")
	_expect(_is_close(float(payload.get("xedats_precomputed_gain_multiplier", -1.0)), 0.65),
		"Probe-region fixture should load gain multiplier 0.65 from region_a.tres.")

	var binding_node: Node = null
	for child: Node in emitter_node.get_children():
		if child.name == &"XedatsGLTFAudioEmitterBinding":
			binding_node = child
			break
	_expect(binding_node != null, "Probe-region fixture should attach an XedatsGLTFAudioEmitterBinding child.")
	if binding_node != null:
		_expect(_is_close(float(binding_node.get_meta(&"xedats_precomputed_effective_gain", -1.0)), 0.39),
			"Binding should apply region_a gain multiplier to authored gain (0.6 -> 0.39).")
		_expect(bool(binding_node.get_meta(&"xedats_precomputed_enable_distance_filtering", false)) == true,
			"Binding should expose distance-filtering override from the region profile.")
		var precomputed_bus: String = String(binding_node.get_meta(&"xedats_precomputed_bus", ""))
		_expect(precomputed_bus == "XedatsPrecomputed_region_a",
			"Probe-region fixture should route through generated deterministic precomputed bus name.")


func _validate_omi_material_fixture(xedats: XedatsSingleton) -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_OMI_MATERIAL)
	if fixture_root == null:
		return

	var material_node: Node = _find_node_by_name(fixture_root, EXPECTED_OMI_NODE_NAME)
	_expect(material_node != null, "OMI fixture should contain %s node." % EXPECTED_OMI_NODE_NAME)
	if material_node == null:
		return

	_expect(material_node.has_meta(&"omi_audio_material"), "OMI fixture node should expose parsed omi_audio_material metadata.")
	_expect(material_node.has_meta(&"xedats_omi_effect_chain"), "OMI fixture node should expose mapped EffectChain metadata.")
	_expect(material_node.has_meta(&"xedats_omi_bus"), "OMI fixture node should expose created bus metadata.")
	if not material_node.has_meta(&"omi_audio_material") or not material_node.has_meta(&"xedats_omi_effect_chain"):
		return

	var material_payload_variant: Variant = material_node.get_meta(&"omi_audio_material")
	_expect(material_payload_variant is Dictionary, "OMI fixture metadata payload should be a Dictionary.")
	if not (material_payload_variant is Dictionary):
		return

	var material_payload: Dictionary = material_payload_variant
	_expect(_is_close(float(material_payload.get("absorption", -1.0)), 0.25), "OMI fixture absorption should parse as 0.25.")
	_expect(_is_close(float(material_payload.get("transmission", -1.0)), 0.5), "OMI fixture transmission should parse as 0.5.")
	_expect(_is_close(float(material_payload.get("reflection", -1.0)), 0.75), "OMI fixture reflection should parse as 0.75.")

	var effect_chain_variant: Variant = material_node.get_meta(&"xedats_omi_effect_chain")
	_expect(effect_chain_variant is EffectChain, "OMI fixture should map to an EffectChain resource.")
	if not (effect_chain_variant is EffectChain):
		return

	var effect_chain: EffectChain = effect_chain_variant
	_expect(effect_chain.get_effect_count() == 3, "OMI fixture EffectChain should contain 3 effects.")

	var first_effect: AudioEffect = effect_chain.get_effect(0)
	var second_effect: AudioEffect = effect_chain.get_effect(1)
	var third_effect: AudioEffect = effect_chain.get_effect(2)
	_expect(first_effect is AudioEffectLowPassFilter, "OMI fixture first effect should be AudioEffectLowPassFilter.")
	_expect(second_effect is AudioEffectHighPassFilter, "OMI fixture second effect should be AudioEffectHighPassFilter.")
	_expect(third_effect is AudioEffectReverb, "OMI fixture third effect should be AudioEffectReverb.")

	if first_effect is AudioEffectLowPassFilter:
		var low_pass: AudioEffectLowPassFilter = first_effect
		_expect(_is_close(low_pass.cutoff_hz, 15300.0, 0.5), "OMI fixture low-pass cutoff should map to 15300 Hz.")

	if second_effect is AudioEffectHighPassFilter:
		var high_pass: AudioEffectHighPassFilter = second_effect
		_expect(_is_close(high_pass.cutoff_hz, 470.0, 0.5), "OMI fixture high-pass cutoff should map to 470 Hz.")

	if third_effect is AudioEffectReverb:
		var reverb: AudioEffectReverb = third_effect
		_expect(_is_close(reverb.wet, 0.75, 0.01), "OMI fixture reverb wet should map to 0.75.")
		_expect(_is_close(reverb.room_size, 0.725, 0.01), "OMI fixture reverb room_size should map to 0.725.")

	var bus_meta_variant: Variant = material_node.get_meta(&"xedats_omi_bus")
	var bus_meta_name: String = String(bus_meta_variant)
	_expect(bus_meta_name == EXPECTED_OMI_BUS_NAME, "OMI fixture should preserve configured xedats bus name.")

	var bus_info: Dictionary = xedats.get_bus_info()
	_expect(bus_info.has(EXPECTED_OMI_BUS_NAME), "OMI fixture should create custom bus '%s'." % EXPECTED_OMI_BUS_NAME)

	# Group F: verify omi dump fields — authored bus_name pass-through and effect chain identity.
	_expect(material_payload.has("bus_name"), "OMI fixture parsed payload should carry authored bus_name from extras.")
	_expect(String(material_payload.get("bus_name", "")) == EXPECTED_OMI_BUS_NAME,
		"OMI fixture parsed payload bus_name should match authored xedats_bus extras value.")
	if effect_chain_variant is EffectChain:
		var chain_for_name: EffectChain = effect_chain_variant
		_expect(chain_for_name.chain_name == "OMI_AudioMaterial",
			"OMI fixture EffectChain chain_name should be 'OMI_AudioMaterial'.")


func _validate_omi_material_extremes_fixture(xedats: XedatsSingleton) -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_OMI_MATERIAL_EXTREMES)
	if fixture_root == null:
		return

	var low_node: Node = _find_node_by_name(fixture_root, EXPECTED_OMI_EXTREME_LOW_NODE)
	var high_node: Node = _find_node_by_name(fixture_root, EXPECTED_OMI_EXTREME_HIGH_NODE)
	_expect(low_node != null, "OMI extremes fixture should contain %s node." % EXPECTED_OMI_EXTREME_LOW_NODE)
	_expect(high_node != null, "OMI extremes fixture should contain %s node." % EXPECTED_OMI_EXTREME_HIGH_NODE)
	if low_node == null or high_node == null:
		return

	_expect(low_node.has_meta(&"xedats_omi_effect_chain"), "OMI low-extreme node should expose mapped EffectChain metadata.")
	_expect(high_node.has_meta(&"xedats_omi_effect_chain"), "OMI high-extreme node should expose mapped EffectChain metadata.")
	if not low_node.has_meta(&"xedats_omi_effect_chain") or not high_node.has_meta(&"xedats_omi_effect_chain"):
		return

	var low_chain_variant: Variant = low_node.get_meta(&"xedats_omi_effect_chain")
	var high_chain_variant: Variant = high_node.get_meta(&"xedats_omi_effect_chain")
	_expect(low_chain_variant is EffectChain, "OMI low-extreme metadata should contain an EffectChain.")
	_expect(high_chain_variant is EffectChain, "OMI high-extreme metadata should contain an EffectChain.")
	if not (low_chain_variant is EffectChain) or not (high_chain_variant is EffectChain):
		return

	var low_chain: EffectChain = low_chain_variant
	var high_chain: EffectChain = high_chain_variant
	_expect(low_chain.get_effect_count() == 3, "OMI low-extreme EffectChain should contain 3 effects.")
	_expect(high_chain.get_effect_count() == 3, "OMI high-extreme EffectChain should contain 3 effects.")
	if low_chain.get_effect_count() < 3 or high_chain.get_effect_count() < 3:
		return

	var low_lp: AudioEffectLowPassFilter = low_chain.get_effect(0) as AudioEffectLowPassFilter
	var low_hp: AudioEffectHighPassFilter = low_chain.get_effect(1) as AudioEffectHighPassFilter
	var low_rv: AudioEffectReverb = low_chain.get_effect(2) as AudioEffectReverb
	var high_lp: AudioEffectLowPassFilter = high_chain.get_effect(0) as AudioEffectLowPassFilter
	var high_hp: AudioEffectHighPassFilter = high_chain.get_effect(1) as AudioEffectHighPassFilter
	var high_rv: AudioEffectReverb = high_chain.get_effect(2) as AudioEffectReverb

	_expect(low_lp != null, "OMI low-extreme first effect should be AudioEffectLowPassFilter.")
	_expect(low_hp != null, "OMI low-extreme second effect should be AudioEffectHighPassFilter.")
	_expect(low_rv != null, "OMI low-extreme third effect should be AudioEffectReverb.")
	_expect(high_lp != null, "OMI high-extreme first effect should be AudioEffectLowPassFilter.")
	_expect(high_hp != null, "OMI high-extreme second effect should be AudioEffectHighPassFilter.")
	_expect(high_rv != null, "OMI high-extreme third effect should be AudioEffectReverb.")
	if low_lp == null or low_hp == null or low_rv == null or high_lp == null or high_hp == null or high_rv == null:
		return

	_expect(_is_close(low_lp.cutoff_hz, 20000.0, 0.5), "OMI low-extreme low-pass cutoff should map to 20000 Hz.")
	_expect(_is_close(low_hp.cutoff_hz, 900.0, 0.5), "OMI low-extreme high-pass cutoff should map to 900 Hz.")
	_expect(_is_close(low_rv.wet, 0.0, 0.01), "OMI low-extreme reverb wet should map to 0.0.")
	_expect(_is_close(low_rv.room_size, 0.2, 0.01), "OMI low-extreme reverb room_size should map to 0.2.")

	_expect(_is_close(high_lp.cutoff_hz, 1200.0, 0.5), "OMI high-extreme low-pass cutoff should map to 1200 Hz.")
	_expect(_is_close(high_hp.cutoff_hz, 40.0, 0.5), "OMI high-extreme high-pass cutoff should map to 40 Hz.")
	_expect(_is_close(high_rv.wet, 1.0, 0.01), "OMI high-extreme reverb wet should map to 1.0.")
	_expect(_is_close(high_rv.room_size, 0.9, 0.01), "OMI high-extreme reverb room_size should map to 0.9.")

	var low_bus: String = String(low_node.get_meta(&"xedats_omi_bus", ""))
	var high_bus: String = String(high_node.get_meta(&"xedats_omi_bus", ""))
	_expect(low_bus == EXPECTED_OMI_EXTREME_LOW_BUS, "OMI low-extreme node should preserve configured xedats bus name.")
	_expect(high_bus == EXPECTED_OMI_EXTREME_HIGH_BUS, "OMI high-extreme node should preserve configured xedats bus name.")

	var bus_info: Dictionary = xedats.get_bus_info()
	_expect(bus_info.has(EXPECTED_OMI_EXTREME_LOW_BUS), "OMI low-extreme fixture should create custom bus '%s'." % EXPECTED_OMI_EXTREME_LOW_BUS)
	_expect(bus_info.has(EXPECTED_OMI_EXTREME_HIGH_BUS), "OMI high-extreme fixture should create custom bus '%s'." % EXPECTED_OMI_EXTREME_HIGH_BUS)


func _validate_omi_material_index_fixture(xedats: XedatsSingleton) -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_OMI_MATERIAL_INDEX)
	if fixture_root == null:
		return

	var material_node: Node = _find_node_by_name(fixture_root, EXPECTED_OMI_MATERIAL_INDEX_NODE)
	_expect(material_node != null, "OMI material-index fixture should contain %s node." % EXPECTED_OMI_MATERIAL_INDEX_NODE)
	if material_node == null:
		return

	_expect(material_node.has_meta(&"omi_audio_material"), "OMI material-index node should expose parsed omi_audio_material metadata.")
	_expect(material_node.has_meta(&"xedats_omi_effect_chain"), "OMI material-index node should expose mapped EffectChain metadata.")
	_expect(material_node.has_meta(&"xedats_omi_bus"), "OMI material-index node should expose created bus metadata.")
	if not material_node.has_meta(&"omi_audio_material") or not material_node.has_meta(&"xedats_omi_effect_chain"):
		return

	var material_payload: Dictionary = material_node.get_meta(&"omi_audio_material") as Dictionary
	_expect(_is_close(float(material_payload.get("absorption", -1.0)), 0.6), "OMI material-index absorption should parse as 0.6.")
	_expect(_is_close(float(material_payload.get("transmission", -1.0)), 0.2), "OMI material-index transmission should parse as 0.2.")
	_expect(_is_close(float(material_payload.get("reflection", -1.0)), 0.4), "OMI material-index reflection should parse as 0.4.")

	var effect_chain: EffectChain = material_node.get_meta(&"xedats_omi_effect_chain") as EffectChain
	_expect(effect_chain != null and effect_chain.get_effect_count() == 3,
		"OMI material-index fixture should map to a 3-effect chain.")

	var bus_name: String = String(material_node.get_meta(&"xedats_omi_bus", ""))
	_expect(bus_name == EXPECTED_OMI_MATERIAL_INDEX_BUS,
		"OMI material-index node should preserve configured xedats bus name.")

	var bus_info: Dictionary = xedats.get_bus_info()
	_expect(bus_info.has(EXPECTED_OMI_MATERIAL_INDEX_BUS),
		"OMI material-index fixture should create custom bus '%s'." % EXPECTED_OMI_MATERIAL_INDEX_BUS)


func _validate_omi_material_precedence_fixture(xedats: XedatsSingleton) -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_OMI_MATERIAL_PRECEDENCE)
	if fixture_root == null:
		return

	var material_node: Node = _find_node_by_name(fixture_root, EXPECTED_OMI_PRECEDENCE_NODE)
	_expect(material_node != null, "OMI precedence fixture should contain %s node." % EXPECTED_OMI_PRECEDENCE_NODE)
	if material_node == null:
		return

	_expect(material_node.has_meta(&"omi_audio_material"), "OMI precedence node should expose parsed omi_audio_material metadata.")
	_expect(material_node.has_meta(&"xedats_omi_effect_chain"), "OMI precedence node should expose mapped EffectChain metadata.")
	_expect(material_node.has_meta(&"xedats_omi_bus"), "OMI precedence node should expose created bus metadata.")
	if not material_node.has_meta(&"omi_audio_material") or not material_node.has_meta(&"xedats_omi_effect_chain"):
		return

	var material_payload: Dictionary = material_node.get_meta(&"omi_audio_material") as Dictionary
	_expect(_is_close(float(material_payload.get("absorption", -1.0)), 0.1),
		"OMI precedence fixture should use node-level absorption (0.1) over material-level value.")
	_expect(_is_close(float(material_payload.get("transmission", -1.0)), 0.8),
		"OMI precedence fixture should use node-level transmission (0.8) over material-level value.")
	_expect(_is_close(float(material_payload.get("reflection", -1.0)), 0.7),
		"OMI precedence fixture should use node-level reflection (0.7) over material-level value.")

	var bus_name: String = String(material_node.get_meta(&"xedats_omi_bus", ""))
	_expect(bus_name == EXPECTED_OMI_PRECEDENCE_NODE_BUS,
		"OMI precedence fixture should use node-level xedats bus name.")

	var effect_chain: EffectChain = material_node.get_meta(&"xedats_omi_effect_chain") as EffectChain
	_expect(effect_chain != null and effect_chain.get_effect_count() == 3,
		"OMI precedence fixture should map to a 3-effect chain from node-level payload.")

	if effect_chain != null and effect_chain.get_effect_count() >= 3:
		var low_pass: AudioEffectLowPassFilter = effect_chain.get_effect(0) as AudioEffectLowPassFilter
		var high_pass: AudioEffectHighPassFilter = effect_chain.get_effect(1) as AudioEffectHighPassFilter
		var reverb: AudioEffectReverb = effect_chain.get_effect(2) as AudioEffectReverb
		_expect(low_pass != null and _is_close(low_pass.cutoff_hz, 18120.0, 0.5),
			"OMI precedence low-pass should match node-level absorption mapping.")
		_expect(high_pass != null and _is_close(high_pass.cutoff_hz, 212.0, 0.5),
			"OMI precedence high-pass should match node-level transmission mapping.")
		_expect(reverb != null and _is_close(reverb.wet, 0.7, 0.01),
			"OMI precedence reverb wet should match node-level reflection mapping.")
		_expect(reverb != null and _is_close(reverb.room_size, 0.69, 0.01),
			"OMI precedence room_size should match node-level reflection mapping.")

	var bus_info: Dictionary = xedats.get_bus_info()
	_expect(bus_info.has(EXPECTED_OMI_PRECEDENCE_NODE_BUS),
		"OMI precedence fixture should create node-level custom bus '%s'." % EXPECTED_OMI_PRECEDENCE_NODE_BUS)


func _validate_omi_material_default_bus_fixture(xedats: XedatsSingleton) -> void:
	var fixture_root: Node = _import_fixture(FIXTURE_OMI_MATERIAL_DEFAULT_BUS)
	if fixture_root == null:
		return

	var material_node: Node = _find_node_by_name(fixture_root, EXPECTED_OMI_DEFAULT_BUS_NODE)
	_expect(material_node != null, "OMI default-bus fixture should contain %s node." % EXPECTED_OMI_DEFAULT_BUS_NODE)
	if material_node == null:
		return

	_expect(material_node.has_meta(&"omi_audio_material"), "OMI default-bus node should expose parsed omi_audio_material metadata.")
	_expect(material_node.has_meta(&"xedats_omi_bus"), "OMI default-bus node should expose created bus metadata.")
	if not material_node.has_meta(&"omi_audio_material"):
		return

	var material_payload: Dictionary = material_node.get_meta(&"omi_audio_material") as Dictionary
	_expect(not material_payload.has("bus_name"),
		"OMI default-bus payload should omit bus_name when xedats_bus is not authored.")

	var bus_name: String = String(material_node.get_meta(&"xedats_omi_bus", ""))
	_expect(bus_name == EXPECTED_OMI_DEFAULT_BUS_NAME,
		"OMI default-bus fixture should use deterministic fallback bus name '%s'." % EXPECTED_OMI_DEFAULT_BUS_NAME)

	var bus_info: Dictionary = xedats.get_bus_info()
	_expect(bus_info.has(EXPECTED_OMI_DEFAULT_BUS_NAME),
		"OMI default-bus fixture should create fallback bus '%s'." % EXPECTED_OMI_DEFAULT_BUS_NAME)


func _validate_xedats_unavailable_fallback_fixture() -> void:
	var existing_singleton: XedatsSingleton = XedatsSingleton.peek_instance()
	var had_singleton: bool = existing_singleton != null
	if existing_singleton != null:
		existing_singleton.queue_free()
		await get_tree().process_frame

	XedatsSingleton._set_instance_creation_blocked_for_tests(true)

	var fixture_root: Node = _import_fixture(FIXTURE_RELATIVE_URI)
	if fixture_root == null:
		XedatsSingleton._set_instance_creation_blocked_for_tests(false)
		if had_singleton:
			XedatsSingleton.instance()
		return

	await get_tree().process_frame

	var emitter_node: Node = _find_node_by_name(fixture_root, "FixtureRelativeUriEmitter")
	_expect(emitter_node != null, "Xedats-unavailable fixture should contain FixtureRelativeUriEmitter node.")
	if emitter_node != null:
		var binding_node: Node = _find_node_by_name(emitter_node, "XedatsGLTFAudioEmitterBinding")
		_expect(binding_node != null, "Xedats-unavailable fixture should attach emitter binding child.")
		if binding_node != null:
			var runtime_path: String = String(binding_node.get_meta(&"xedats_runtime_path", ""))
			_expect(runtime_path == "fallback_local",
				"Xedats-unavailable fixture should use local fallback runtime path when singleton is unavailable.")

	XedatsSingleton._set_instance_creation_blocked_for_tests(false)
	if had_singleton:
		var restored: XedatsSingleton = XedatsSingleton.instance()
		_expect(restored != null, "XedatsSingleton should restore after unavailable fallback fixture.")


func _is_close(value: float, expected: float, tolerance: float = 0.001) -> bool:
	return absf(value - expected) <= tolerance


func _expect_runtime_path_meta(binding_node: Node, context: String) -> void:
	_expect(binding_node != null, "%s should attach an XedatsGLTFAudioEmitterBinding child." % context)
	if binding_node == null:
		return

	_expect(binding_node.has_meta(&"xedats_runtime_path"), "%s binding should expose runtime path metadata." % context)
	if not binding_node.has_meta(&"xedats_runtime_path"):
		return

	var runtime_path: String = String(binding_node.get_meta(&"xedats_runtime_path", ""))
	var valid_paths: PackedStringArray = PackedStringArray([
		"xedats_event",
		"xedats_container",
		"xedats_texture_cadence",
		"xedats_direct",
		"fallback_local",
		"no_streams",
		"fallback_no_streams",
		"muted_skip"
	])
	_expect(valid_paths.has(runtime_path),
		"%s binding runtime path '%s' should be one of %s." % [context, runtime_path, str(valid_paths)])


func _import_fixture(path: String) -> Node:
	var document: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	state.set_additional_data(
		StringName("XedatsGLTFSuppressWarnings"),
		_should_suppress_import_warnings(path)
	)
	var import_error: Error = document.append_from_file(path, state)
	_expect(import_error == OK, "GLTFDocument.append_from_file should succeed for '%s'." % path)
	if import_error != OK:
		return null

	var generated_scene: Node = document.generate_scene(state)
	_expect(generated_scene != null, "GLTFDocument.generate_scene should produce a node for '%s'." % path)
	if generated_scene == null:
		return null

	add_child(generated_scene)
	_fixture_roots.append(generated_scene)
	return generated_scene


func _should_suppress_import_warnings(path: String) -> bool:
	var noisy_negative_fixtures: PackedStringArray = PackedStringArray([
		FIXTURE_XEDATS_EXTRAS_INVALID,
		FIXTURE_PRECOMPUTED_MISSING,
		FIXTURE_PORTAL_SOURCE_PATH_BAD,
	])
	return noisy_negative_fixtures.has(path)


func _find_node_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root

	for child: Node in root.get_children():
		var matched: Node = _find_node_by_name(child, target_name)
		if matched != null:
			return matched

	return null


func _expect(condition: bool, message: String) -> void:
	if condition:
		return

	_failures.append(message)
	push_error("Xedats glTF Fixture: %s" % message)


func _print_summary() -> void:
	_teardown_runner()

	if _failures.is_empty():
		print("Xedats glTF Fixture: all fixture imports passed.")
		get_tree().quit(0)
		return

	print("Xedats glTF Fixture: %d failure(s)." % _failures.size())
	for failure: String in _failures:
		print(" - %s" % failure)
	get_tree().quit(1)


func _on_event_triggered(event_name: String, player: XedatsPlayer3D) -> void:
	_event_hits.append(event_name)
	if player != null:
		player.stop()
