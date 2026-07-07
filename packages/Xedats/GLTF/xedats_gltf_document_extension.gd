## Xedats GLTFDocumentExtension — XEDATS_audio_emitter + XEDATS_audio_material importer bridge.
##
## Registered at editor startup by [XedatsGLTFPlugin].  During a glTF import the
## Godot [GLTFDocument] pipeline calls into this extension at each lifecycle
## stage; this class handles only the two Xedats-relevant extensions and returns
## [constant ERR_SKIP] for everything else so other extensions remain unaffected.
##
## Supported extensions
##   • XEDATS_audio_emitter  — document-level sources/emitters array; node-level
##     emitter index.  Resolved into an [XedatsGLTFAudioEmitterBinding] child
##     node that fires at runtime via [AudioEventSystem] / [XedatsSingleton] or
##     falls back to a plain [AudioStreamPlayer3D].
##   • XEDATS_audio_material — node or material-level absorption/transmission/
##     reflection values.  Converted deterministically into an [EffectChain]
##     stored as node metadata and applied to a named Xedats bus.
##
## Lifecycle order (Godot glTF pipeline):
##   _import_preflight → _get_supported_extensions → _parse_node_extensions
##     → _import_node
##
## Parse state is threaded through [GLTFState.set_additional_data] under the
## key [constant DATA_KEY] so every stage can read/write a shared cache without
## requiring class-level mutable state (keeps the extension re-entrant-safe).
@tool
class_name GLTFDocumentExtensionXedatsAudio
extends GLTFDocumentExtension

const EXT_XEDATS_AUDIO_EMITTER: String = "XEDATS_audio_emitter"
const EXT_XEDATS_AUDIO_MATERIAL: String = "XEDATS_audio_material"
## Key used to store the per-import parse cache inside [GLTFState] additional data.
const DATA_KEY: StringName = &"XedatsGLTFAudioData"
const DATA_KEY_SUPPRESS_WARNINGS: StringName = &"XedatsGLTFSuppressWarnings"
## Fallback audio category when the glTF payload does not specify one.
const DEFAULT_CATEGORY: String = "SFX"
const DEFAULT_REFLECTION_BUDGET: String = "medium"
static var VALID_REFLECTION_BUDGETS: PackedStringArray = PackedStringArray(["low", "medium", "high"])
const REFLECTION_SALIENCE_SCRIPT: Script = preload("xedats_reflection_salience.gd")
const DEFAULT_DISTANCE_POLICY: String = "none"
static var VALID_DISTANCE_POLICIES: PackedStringArray = PackedStringArray(["none", "texture"])
const DISTANCE_BAND_POLICY_SCRIPT: Script = preload("xedats_distance_band_policy.gd")
const DEFAULT_DYNAMIC_PORTAL_OPENNESS: float = 1.0
const DEFAULT_DYNAMIC_PORTAL_CLOSED_GAIN_SCALE: float = 0.35
static var VALID_XEDATS_EMITTER_EXTRA_KEYS: PackedStringArray = PackedStringArray([
	"xedats_event",
	"xedats_category",
	"xedats_reflection_budget",
	"xedats_texture_profile",
	"xedats_texture_density",
	"xedats_texture_variance",
	"xedats_precomputed_id",
	"xedats_probe_region",
	"xedats_distance_policy",
	"xedats_dynamic_portal_openness",
	"xedats_dynamic_portal_closed_gain_scale",
	"xedats_portal_source_path",
])

var _warning_rate_limit_seen: Dictionary = {}
var _reflection_budget_profile: Resource = null
var _omi_effect_mapping_profile: Resource = null
var _suppress_warnings: bool = false


## [b]Lifecycle — Stage 1.[/b]  Called once per document before any nodes are
## parsed.  If neither supported extension is present the import is skipped
## entirely ([constant ERR_SKIP]) so other extensions are unaffected.
## Otherwise builds the document-level parse cache (sources, emitters, material
## map) and stores it in [param state] additional data under [constant DATA_KEY].
func _import_preflight(state: GLTFState, extensions: PackedStringArray) -> Error:
	if not extensions.has(EXT_XEDATS_AUDIO_EMITTER) and not extensions.has(EXT_XEDATS_AUDIO_MATERIAL):
		return ERR_SKIP

	_warning_rate_limit_seen.clear()
	_suppress_warnings = bool(state.get_additional_data(DATA_KEY_SUPPRESS_WARNINGS))

	var parse_cache: Dictionary = {
		"khr_sources": [],
		"khr_emitters": [],
		"omi_materials": {}
	}

	_parse_document_extensions(state, parse_cache)
	state.set_additional_data(DATA_KEY, parse_cache)
	return OK


## [b]Lifecycle — Stage 2.[/b]  Declares the extension names this class
## handles so that Godot routes the relevant JSON blocks to it.
func _get_supported_extensions() -> PackedStringArray:
	return PackedStringArray([EXT_XEDATS_AUDIO_EMITTER, EXT_XEDATS_AUDIO_MATERIAL])


## [b]Lifecycle — Stage 3.[/b]  Called for each glTF node that carries
## extension data.  Extracts the KHR emitter index and/or OMI material values
## and stores them in [param gltf_node] additional data so [method _import_node]
## can retrieve them without re-parsing raw JSON.
func _parse_node_extensions(_state: GLTFState, gltf_node: GLTFNode, extensions: Dictionary) -> Error:
	var node_data: Dictionary = {}

	if extensions.has(EXT_XEDATS_AUDIO_EMITTER):
		var emitter_ext: Dictionary = extensions[EXT_XEDATS_AUDIO_EMITTER]
		if emitter_ext.has("emitter"):
			node_data["emitter_index"] = int(emitter_ext.get("emitter", -1))

	if extensions.has(EXT_XEDATS_AUDIO_MATERIAL):
		var parsed_material: Dictionary = _parse_omi_audio_material(extensions[EXT_XEDATS_AUDIO_MATERIAL])
		if not parsed_material.is_empty():
			node_data["omi_material"] = parsed_material

	if not node_data.is_empty():
		gltf_node.set_additional_data(DATA_KEY, node_data)

	return OK


## [b]Lifecycle — Stage 4.[/b]  Called for each instantiated [Node] after
## Godot has built it from the glTF data.  Orchestrates the full resolve→apply
## pipeline: emitter payload → [XedatsGLTFAudioEmitterBinding] child, and
## material payload → [EffectChain] + bus metadata.
func _import_node(state: GLTFState, gltf_node: GLTFNode, json: Dictionary, node: Node) -> Error:
	if node == null:
		return OK

	var parse_cache: Dictionary = _get_parse_cache(state)

	var emitter_payload: Dictionary = _resolve_emitter_payload(state, parse_cache, gltf_node, json)
	if not emitter_payload.is_empty():
		_attach_emitter_binding(node, emitter_payload)

	var material_payload: Dictionary = _resolve_material_payload(parse_cache, gltf_node, json)
	if not material_payload.is_empty():
		_apply_omi_material_to_node(node, material_payload)

	return OK


## Reads the document-level [code]extensions[/code] block from [param state].json
## and populates [param parse_cache] with:
##   [code]khr_sources[/code]  — Array[Dictionary] of glTF audio source entries.[br]
##   [code]khr_emitters[/code] — Array[Dictionary] of glTF audio emitter entries.[br]
##   [code]omi_materials[/code] — Dictionary mapping material index → parsed
##     absorption/transmission/reflection payload.[br]
## Also stores a reference to [code]state.json[/code] under [code]state_json[/code]
## so downstream helpers can resolve mesh→material links without re-querying state.
func _parse_document_extensions(state: GLTFState, parse_cache: Dictionary) -> void:
	var state_json: Dictionary = state.json
	if state_json.has("extensions"):
		var document_extensions: Dictionary = state_json["extensions"]
		if document_extensions.has(EXT_XEDATS_AUDIO_EMITTER):
			var khr_doc_ext: Dictionary = document_extensions[EXT_XEDATS_AUDIO_EMITTER]
			parse_cache["khr_sources"] = _as_dictionary_array(khr_doc_ext.get("sources", []))
			parse_cache["khr_emitters"] = _as_dictionary_array(khr_doc_ext.get("emitters", []))

	if state_json.has("materials"):
		var materials_array: Array = state_json["materials"]
		var parsed_materials: Dictionary = parse_cache.get("omi_materials", {})
		for material_index: int in range(materials_array.size()):
			var material_json: Variant = materials_array[material_index]
			if material_json is Dictionary:
				var material_dict: Dictionary = material_json
				if material_dict.has("extensions"):
					var material_extensions: Dictionary = material_dict["extensions"]
					if material_extensions.has(EXT_XEDATS_AUDIO_MATERIAL):
						var parsed_material: Dictionary = _parse_omi_audio_material(material_extensions[EXT_XEDATS_AUDIO_MATERIAL])
						if not parsed_material.is_empty():
							parsed_materials[material_index] = parsed_material
		parse_cache["omi_materials"] = parsed_materials


## Builds the runtime payload Dictionary for a XEDATS_audio_emitter node.[br]
## Resolution priority:[br]
##   1. Emitter index from [param gltf_node] additional data (set in preflight).[br]
##   2. Emitter index from raw [param node_json] extensions block (fallback).[br]
## Returns an empty Dictionary when no emitter is found so callers can guard
## cheaply with [method Dictionary.is_empty].
func _resolve_emitter_payload(state: GLTFState, parse_cache: Dictionary, gltf_node: GLTFNode, node_json: Dictionary) -> Dictionary:
	var emitter_index: int = -1
	var node_data_variant: Variant = gltf_node.get_additional_data(DATA_KEY)
	if node_data_variant is Dictionary:
		var node_data: Dictionary = node_data_variant
		emitter_index = int(node_data.get("emitter_index", -1))

	if emitter_index < 0 and node_json.has("extensions"):
		var json_ext: Dictionary = node_json["extensions"]
		if json_ext.has(EXT_XEDATS_AUDIO_EMITTER):
			var emitter_ext: Dictionary = json_ext[EXT_XEDATS_AUDIO_EMITTER]
			emitter_index = int(emitter_ext.get("emitter", -1))

	if emitter_index < 0:
		return {}

	var emitters: Array[Dictionary] = parse_cache.get("khr_emitters", [])
	if emitter_index >= emitters.size():
		push_warning("Xedats glTF: emitter index %d is out of range" % emitter_index)
		return {}

	var emitter_data: Dictionary = emitters[emitter_index]
	var validated_extras: Dictionary = _parse_xedats_emitter_extras(emitter_data, emitter_index)
	var precomputed_payload: Dictionary = _resolve_precomputed_propagation_payload(validated_extras, emitter_index)
	var source_indices: Array[int] = _get_emitter_source_indices(emitter_data)
	var source_paths: Array[String] = []
	for source_index: int in source_indices:
		var source_path: String = _resolve_source_path(state, parse_cache, source_index)
		if not source_path.is_empty():
			source_paths.append(source_path)

	if source_paths.is_empty() and emitter_data.has("uri"):
		var direct_uri: String = String(emitter_data.get("uri", ""))
		if not direct_uri.is_empty():
			source_paths.append(_normalize_resource_uri(state, direct_uri))

	var ranked_sources: Array[Dictionary] = REFLECTION_SALIENCE_SCRIPT.rank_sources(source_paths, source_indices)
	var resolved_event_name: String = _resolve_event_name(emitter_data)
	if validated_extras.has("xedats_event"):
		resolved_event_name = String(validated_extras.get("xedats_event", resolved_event_name))

	var resolved_category: String = _resolve_category(emitter_data)
	if validated_extras.has("xedats_category"):
		resolved_category = String(validated_extras.get("xedats_category", resolved_category))
	if resolved_category.is_empty():
		resolved_category = DEFAULT_CATEGORY

	var reflection_budget_tier: String = String(validated_extras.get("xedats_reflection_budget", ""))
	var reflection_max_sources: int = 0
	if not reflection_budget_tier.is_empty():
		var budget_profile: Resource = _get_reflection_budget_profile()
		if budget_profile != null and budget_profile.has_method("get_budget_cap"):
			reflection_max_sources = int(budget_profile.call("get_budget_cap", reflection_budget_tier))
	if reflection_max_sources > 0 and source_paths.size() > reflection_max_sources:
		source_paths = REFLECTION_SALIENCE_SCRIPT.top_paths(ranked_sources, reflection_max_sources)

	var payload: Dictionary = {
		"emitter_index": emitter_index,
		"event_name": resolved_event_name,
		"category": resolved_category,
		"gain": clamp(float(emitter_data.get("gain", 1.0)), 0.0, 1.0),
		"loop": bool(emitter_data.get("loop", false)),
		"source_indices": source_indices,
		"source_paths": source_paths,
		"xedats_suppress_runtime_warnings": _suppress_warnings,
		"xedats_reflection_ranked_sources": ranked_sources,
		"xedats_reflection_max_sources": reflection_max_sources,
		"xedats_reflection_capped": reflection_max_sources > 0 and ranked_sources.size() > source_paths.size()
	}
	for key: Variant in validated_extras.keys():
		payload[String(key)] = validated_extras[key]
	for key: Variant in precomputed_payload.keys():
		payload[String(key)] = precomputed_payload[key]
	return payload


func _get_reflection_budget_profile() -> Resource:
	if _reflection_budget_profile != null:
		return _reflection_budget_profile

	var profile_path: String = XedatsGLTFConfig.resources_root() \
		+"/GLTF/xedats_reflection_budget_profile_default.tres"
	var loaded_resource: Resource = ResourceLoader.load(profile_path)
	if loaded_resource != null and loaded_resource.has_method("get_budget_cap"):
		_reflection_budget_profile = loaded_resource
		return _reflection_budget_profile

	push_warning("Xedats glTF: reflection budget profile missing at '%s'; using built-in defaults" % profile_path)
	var fallback_script: Script = ResourceLoader.load(
		XedatsGLTFConfig.modules_root() + "/GLTF/xedats_reflection_budget_profile.gd"
	)
	_reflection_budget_profile = fallback_script.new()
	return _reflection_budget_profile


func _resolve_precomputed_propagation_payload(validated_extras: Dictionary, emitter_index: int) -> Dictionary:
	var precomputed_id: String = String(validated_extras.get("xedats_precomputed_id", ""))
	var probe_region: Variant = validated_extras.get("xedats_probe_region", null)
	if precomputed_id.is_empty() and probe_region == null:
		return {}

	var resolver_script: Script = _get_precomputed_propagation_resolver()
	if resolver_script == null:
		return {}

	var resolution_key: String = String(resolver_script.call("resolution_key", precomputed_id, probe_region))
	if resolution_key.is_empty():
		return {}

	var context: String = "XEDATS_audio_emitter[%d] extras" % emitter_index
	var lookup_key: String = "xedats_precomputed_id"
	var lookup_value: Variant = precomputed_id
	if precomputed_id.is_empty():
		lookup_key = "xedats_probe_region"
		lookup_value = probe_region

	var profile_path: String = String(resolver_script.call("profile_path_for_key", resolution_key))
	if not ResourceLoader.exists(profile_path):
		_warn_invalid_extra(
			lookup_key,
			lookup_value,
			context,
			"precomputed profile not found at '%s'; using runtime fallback" % profile_path
		)
		return {}

	var profile_resource: Resource = ResourceLoader.load(profile_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if profile_resource == null:
		_warn_invalid_extra(
			lookup_key,
			lookup_value,
			context,
			"precomputed profile at '%s' failed to load; using runtime fallback" % profile_path
		)
		return {}

	var flattened: Dictionary = resolver_script.call("flatten_profile", profile_resource)
	if flattened.is_empty():
		_warn_invalid_extra(
			lookup_key,
			lookup_value,
			context,
			"precomputed profile at '%s' is invalid; using runtime fallback" % profile_path
		)
		return {}

	flattened["xedats_precomputed_profile_path"] = profile_path
	flattened["xedats_precomputed_resolution_key"] = resolution_key
	flattened["xedats_precomputed_resolution_source"] = String(
		resolver_script.call("resolution_source", precomputed_id, probe_region)
	)
	return flattened


func _get_precomputed_propagation_resolver() -> Script:
	var resolver_path: String = XedatsGLTFConfig.modules_root() + "/GLTF/xedats_precomputed_propagation_resolver.gd"
	var resolver_script: Script = ResourceLoader.load(resolver_path)
	if resolver_script == null:
		push_warning(
			"Xedats glTF: precomputed propagation resolver missing at '%s'; skipping precomputed lookup"
			% resolver_path
		)
	return resolver_script


## Resolves an XEDATS_audio_material payload for [param gltf_node].[br]
## Checks in order:[br]
##   1. Per-node additional data written during [method _parse_node_extensions].[br]
##   2. Material index referenced by the node's mesh primitives (for materials
##      that carry OMI at the material level rather than the node level).[br]
## Returns an empty Dictionary when no material is found.
func _resolve_material_payload(parse_cache: Dictionary, gltf_node: GLTFNode, node_json: Dictionary) -> Dictionary:
	var node_data_variant: Variant = gltf_node.get_additional_data(DATA_KEY)
	if node_data_variant is Dictionary:
		var node_data: Dictionary = node_data_variant
		if node_data.has("omi_material"):
			return node_data["omi_material"]

	if not node_json.has("mesh"):
		return {}

	var mesh_index: int = int(node_json.get("mesh", -1))
	if mesh_index < 0:
		return {}

	var material_map: Dictionary = parse_cache.get("omi_materials", {})
	if material_map.is_empty():
		return {}

	var state_json: Dictionary = parse_cache.get("state_json", {})
	if state_json.is_empty() or not state_json.has("meshes"):
		return {}

	var meshes: Array = state_json["meshes"]
	if mesh_index >= meshes.size():
		return {}

	var mesh_json_variant: Variant = meshes[mesh_index]
	if not (mesh_json_variant is Dictionary):
		return {}

	var mesh_json: Dictionary = mesh_json_variant
	if not mesh_json.has("primitives"):
		return {}

	var primitives: Array = mesh_json["primitives"]
	for primitive_variant: Variant in primitives:
		if primitive_variant is Dictionary:
			var primitive: Dictionary = primitive_variant
			if primitive.has("material"):
				var material_index: int = int(primitive.get("material", -1))
				if material_map.has(material_index):
					return material_map[material_index]

	return {}


## Adds an [XedatsGLTFAudioEmitterBinding] child to [param node] and stamps
## the resolved [param payload] as [code]xedats_khr_audio_emitter[/code] metadata
## for inspector/debug visibility.  Skips with a warning when [param node] is
## not a [Node3D] since spatial audio requires a world transform.
func _attach_emitter_binding(node: Node, payload: Dictionary) -> void:
	if not (node is Node3D):
		push_warning("Xedats glTF: XEDATS_audio_emitter node '%s' is not Node3D; skipping emitter binding" % node.name)
		return

	node.set_meta(&"xedats_khr_audio_emitter", payload)

	var binding: XedatsGLTFAudioEmitterBinding = XedatsGLTFAudioEmitterBinding.new()
	binding.name = "XedatsGLTFAudioEmitterBinding"
	binding.configure(payload)
	(node as Node3D).add_child(binding)

	if node.owner != null:
		binding.owner = node.owner


## Applies the parsed OMI material to [param node]:[br]
##   • [code]omi_audio_material[/code] metadata — raw parsed values (absorption,
##     transmission, reflection, optional category/bus_name).[br]
##   • [code]xedats_omi_effect_chain[/code] metadata — the resolved [EffectChain].[br]
##   • [code]xedats_omi_bus[/code] metadata — the bus name the chain was applied to.[br]
## If [XedatsSingleton] is unavailable the chain is stored in metadata only and
## a warning is emitted; the node import still succeeds.
func _apply_omi_material_to_node(node: Node, material_payload: Dictionary) -> void:
	node.set_meta(&"omi_audio_material", material_payload)

	var effect_chain: EffectChain = _create_effect_chain_from_material(material_payload)
	node.set_meta(&"xedats_omi_effect_chain", effect_chain)

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		push_warning("Xedats glTF: XedatsSingleton unavailable; OMI material mapped to metadata only")
		return

	var bus_name: String = String(material_payload.get("bus_name", ""))
	if bus_name.is_empty():
		bus_name = "XedatsOMI_%s" % String(node.name)

	xedats.create_audio_bus(bus_name, "Master")
	effect_chain.apply_to_bus(bus_name, xedats)
	node.set_meta(&"xedats_omi_bus", bus_name)


## Converts parsed OMI material values into a deterministic three-effect
## [EffectChain] named [code]"OMI_AudioMaterial"[/code]:[br]
##   [b]Low-pass filter[/b]  — cutoff = lerp(20 000 Hz, 1 200 Hz, absorption).[br]
##     Higher absorption → tighter filter → duller, more muffled sound.[br]
##   [b]High-pass filter[/b] — cutoff = lerp(40 Hz, 900 Hz, 1 − transmission).[br]
##     Lower transmission → higher cutoff → thinner, less bass bleed-through.[br]
##   [b]Reverb[/b]           — wet = reflection; room_size = 0.2 + reflection × 0.7.[br]
##     Higher reflection → wetter, larger perceived space.
func _create_effect_chain_from_material(material_payload: Dictionary) -> EffectChain:
	var mapping_profile: Resource = _get_omi_effect_mapping_profile()
	if mapping_profile != null and mapping_profile.has_method("create_effect_chain_from_material"):
		return mapping_profile.call("create_effect_chain_from_material", material_payload)

	var absorption: float = clamp(float(material_payload.get("absorption", 0.0)), 0.0, 1.0)
	var transmission: float = clamp(float(material_payload.get("transmission", 0.0)), 0.0, 1.0)
	var reflection: float = clamp(float(material_payload.get("reflection", 0.0)), 0.0, 1.0)

	var effect_chain: EffectChain = EffectChain.new("OMI_AudioMaterial")

	var low_pass: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	low_pass.cutoff_hz = lerpf(20000.0, 1200.0, absorption)
	effect_chain.add_effect(low_pass)

	var high_pass: AudioEffectHighPassFilter = AudioEffectHighPassFilter.new()
	high_pass.cutoff_hz = lerpf(40.0, 900.0, 1.0 - transmission)
	effect_chain.add_effect(high_pass)

	var reverb: AudioEffectReverb = AudioEffectReverb.new()
	reverb.wet = reflection
	reverb.room_size = clampf(0.2 + (reflection * 0.7), 0.0, 1.0)
	effect_chain.add_effect(reverb)

	return effect_chain


func _get_omi_effect_mapping_profile() -> Resource:
	if _omi_effect_mapping_profile != null:
		return _omi_effect_mapping_profile

	var profile_path: String = XedatsGLTFConfig.resources_root() \
		+"/GLTF/xedats_omi_effect_mapping_profile_default.tres"
	var loaded_resource: Resource = ResourceLoader.load(profile_path)
	if loaded_resource != null and loaded_resource.has_method("create_effect_chain_from_material"):
		_omi_effect_mapping_profile = loaded_resource
		return _omi_effect_mapping_profile

	push_warning("Xedats glTF: OMI effect mapping profile missing at '%s'; using built-in defaults" % profile_path)
	var fallback_script: Script = ResourceLoader.load(
		XedatsGLTFConfig.modules_root() + "/GLTF/xedats_omi_effect_mapping_profile.gd"
	)
	if fallback_script != null:
		_omi_effect_mapping_profile = fallback_script.new()
		return _omi_effect_mapping_profile

	return null


## Parses a raw XEDATS_audio_material extension block into a normalized Dictionary
## with float fields [code]absorption[/code], [code]transmission[/code],
## [code]reflection[/code] (all clamped 0–1), plus optional [code]category[/code]
## and [code]bus_name[/code] sourced from the [code]extras[/code] block using
## keys [code]xedats_category[/code] and [code]xedats_bus[/code].
func _parse_omi_audio_material(raw_material: Variant) -> Dictionary:
	if not (raw_material is Dictionary):
		return {}

	var material_dict: Dictionary = raw_material
	var parsed: Dictionary = {
		"absorption": _parse_weight_value(material_dict.get("absorption", 0.0)),
		"transmission": _parse_weight_value(material_dict.get("transmission", 0.0)),
		"reflection": _parse_weight_value(material_dict.get("reflection", 0.0))
	}

	if material_dict.has("extras"):
		var extras: Variant = material_dict.get("extras")
		if extras is Dictionary:
			var extras_dict: Dictionary = extras
			if extras_dict.has("xedats_category"):
				var category: String = _validate_nonempty_string(
					"xedats_category",
					extras_dict.get("xedats_category", ""),
					"",
					"XEDATS_audio_material extras"
				)
				if not category.is_empty():
					parsed["category"] = category
			if extras_dict.has("xedats_bus"):
				var bus_name: String = _validate_nonempty_string(
					"xedats_bus",
					extras_dict.get("xedats_bus", ""),
					"",
					"XEDATS_audio_material extras"
				)
				if not bus_name.is_empty():
					parsed["bus_name"] = bus_name

	return parsed


func _parse_xedats_emitter_extras(emitter_data: Dictionary, emitter_index: int) -> Dictionary:
	if not emitter_data.has("extras"):
		return {}

	var extras_variant: Variant = emitter_data.get("extras")
	var extras: Dictionary = _validate_optional_object(
		"extras",
		extras_variant,
		"XEDATS_audio_emitter[%d]" % emitter_index
	)
	if extras.is_empty():
		return {}

	var context: String = "XEDATS_audio_emitter[%d] extras" % emitter_index
	var normalized: Dictionary = {}
	var present_known_keys: PackedStringArray = PackedStringArray()
	var present_unknown_keys: PackedStringArray = PackedStringArray()
	var raw_keys: PackedStringArray = PackedStringArray()
	var warning_keys_before: PackedStringArray = _collect_warning_keys_for_context(context)

	for key_variant: Variant in extras.keys():
		var key_text: String = String(key_variant)
		raw_keys.append(key_text)
		if VALID_XEDATS_EMITTER_EXTRA_KEYS.has(key_text):
			present_known_keys.append(key_text)
			continue
		if key_text.begins_with("xedats_"):
			present_unknown_keys.append(key_text)
			_warn_invalid_extra(
				key_text,
				extras.get(key_variant),
				context,
				"unknown xedats extra key ignored"
			)

	if extras.has("xedats_reflection_budget"):
		normalized["xedats_reflection_budget"] = _validate_string_enum(
			"xedats_reflection_budget",
			extras.get("xedats_reflection_budget", DEFAULT_REFLECTION_BUDGET),
			VALID_REFLECTION_BUDGETS,
			DEFAULT_REFLECTION_BUDGET,
			context
		)

	if extras.has("xedats_event"):
		var xedats_event: String = _validate_nonempty_string(
			"xedats_event",
			extras.get("xedats_event", ""),
			"",
			context
		)
		if not xedats_event.is_empty():
			normalized["xedats_event"] = xedats_event

	if extras.has("xedats_category"):
		var xedats_category: String = _validate_nonempty_string(
			"xedats_category",
			extras.get("xedats_category", DEFAULT_CATEGORY),
			DEFAULT_CATEGORY,
			context
		)
		if not xedats_category.is_empty():
			normalized["xedats_category"] = xedats_category

	if extras.has("xedats_texture_profile"):
		var texture_profile: String = _validate_nonempty_string(
			"xedats_texture_profile",
			extras.get("xedats_texture_profile", ""),
			"",
			context
		)
		if not texture_profile.is_empty():
			normalized["xedats_texture_profile"] = texture_profile

	if extras.has("xedats_texture_density"):
		normalized["xedats_texture_density"] = _validate_float_range(
			"xedats_texture_density",
			extras.get("xedats_texture_density", 0.0),
			0.0,
			1.0,
			0.0,
			context
		)

	if extras.has("xedats_texture_variance"):
		normalized["xedats_texture_variance"] = _validate_float_range(
			"xedats_texture_variance",
			extras.get("xedats_texture_variance", 0.0),
			0.0,
			1.0,
			0.0,
			context
		)

	if extras.has("xedats_precomputed_id"):
		var precomputed_id: String = _validate_nonempty_string(
			"xedats_precomputed_id",
			extras.get("xedats_precomputed_id", ""),
			"",
			context
		)
		if not precomputed_id.is_empty():
			normalized["xedats_precomputed_id"] = precomputed_id

	if extras.has("xedats_probe_region"):
		var probe_region_value: Variant = extras.get("xedats_probe_region")
		if probe_region_value is String:
			var probe_region_id: String = _validate_nonempty_string(
				"xedats_probe_region",
				probe_region_value,
				"",
				context
			)
			if not probe_region_id.is_empty():
				normalized["xedats_probe_region"] = probe_region_id
		elif probe_region_value is Dictionary:
			normalized["xedats_probe_region"] = _validate_optional_object(
				"xedats_probe_region",
				probe_region_value,
				context
			)
		else:
			_warn_invalid_extra(
				"xedats_probe_region",
				probe_region_value,
				context,
				"ignoring probe region override"
			)

	if extras.has("xedats_distance_policy"):
		normalized["xedats_distance_policy"] = _validate_string_enum(
			"xedats_distance_policy",
			extras.get("xedats_distance_policy", DEFAULT_DISTANCE_POLICY),
			VALID_DISTANCE_POLICIES,
			DEFAULT_DISTANCE_POLICY,
			context
		)

	if extras.has("xedats_dynamic_portal_openness"):
		normalized["xedats_dynamic_portal_openness"] = _validate_float_range(
			"xedats_dynamic_portal_openness",
			extras.get("xedats_dynamic_portal_openness", DEFAULT_DYNAMIC_PORTAL_OPENNESS),
			0.0,
			1.0,
			DEFAULT_DYNAMIC_PORTAL_OPENNESS,
			context
		)

	if extras.has("xedats_dynamic_portal_closed_gain_scale"):
		normalized["xedats_dynamic_portal_closed_gain_scale"] = _validate_float_range(
			"xedats_dynamic_portal_closed_gain_scale",
			extras.get(
				"xedats_dynamic_portal_closed_gain_scale",
				DEFAULT_DYNAMIC_PORTAL_CLOSED_GAIN_SCALE
			),
			0.0,
			1.0,
			DEFAULT_DYNAMIC_PORTAL_CLOSED_GAIN_SCALE,
			context
		)

	if extras.has("xedats_portal_source_path"):
		var portal_source_path: String = _validate_nonempty_string(
			"xedats_portal_source_path",
			extras.get("xedats_portal_source_path", ""),
			"",
			context
		)
		if not portal_source_path.is_empty():
			normalized["xedats_portal_source_path"] = portal_source_path

	var warning_keys_after: PackedStringArray = _collect_warning_keys_for_context(context)
	var new_warning_keys: PackedStringArray = _diff_string_lists(warning_keys_after, warning_keys_before)
	normalized["xedats_extras_raw_keys"] = raw_keys
	normalized["xedats_extras_known_keys"] = present_known_keys
	normalized["xedats_extras_unknown_keys"] = present_unknown_keys
	normalized["xedats_extras_warning_keys"] = new_warning_keys
	normalized["xedats_extras_warning_count"] = new_warning_keys.size()

	return normalized


func _validate_string_enum(key: String, value: Variant, allowed_values: PackedStringArray, fallback: String, context: String) -> String:
	if value is String:
		var value_text: String = String(value)
		if allowed_values.has(value_text):
			return value_text
	_warn_invalid_extra(
		key,
		value,
		context,
		"using fallback '%s'" % fallback
	)
	return fallback


func _validate_float_range(key: String, value: Variant, min_value: float, max_value: float, fallback: float, context: String) -> float:
	var numeric_value: float = fallback
	var has_numeric: bool = false
	if value is float or value is int:
		numeric_value = float(value)
		has_numeric = true
	if not has_numeric:
		_warn_invalid_extra(
			key,
			value,
			context,
			"using fallback %.3f" % fallback
		)
		return fallback

	var clamped_value: float = clamp(numeric_value, min_value, max_value)
	if not is_equal_approx(clamped_value, numeric_value):
		_warn_invalid_extra(
			key,
			value,
			context,
			"clamped to %.3f" % clamped_value
		)
	return clamped_value


func _validate_nonempty_string(key: String, value: Variant, fallback: String, context: String) -> String:
	if value is String:
		var value_text: String = String(value).strip_edges()
		if not value_text.is_empty():
			return value_text
	_warn_invalid_extra(
		key,
		value,
		context,
		"using fallback '%s'" % fallback
	)
	return fallback


func _validate_optional_object(key: String, value: Variant, context: String) -> Dictionary:
	if value is Dictionary:
		return value
	_warn_invalid_extra(
		key,
		value,
		context,
		"ignoring object override"
	)
	return {}


func _validate_optional_array(key: String, value: Variant, context: String) -> Array:
	if value is Array:
		return value
	_warn_invalid_extra(
		key,
		value,
		context,
		"ignoring array override"
	)
	return []


func _collect_warning_keys_for_context(context: String) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	var prefix: String = "%s|" % context
	for warning_id_variant: Variant in _warning_rate_limit_seen.keys():
		var warning_id: String = String(warning_id_variant)
		if not warning_id.begins_with(prefix):
			continue
		var key: String = warning_id.substr(prefix.length())
		if key.is_empty() or keys.has(key):
			continue
		keys.append(key)
	return keys


func _diff_string_lists(after_values: PackedStringArray, before_values: PackedStringArray) -> PackedStringArray:
	var diff: PackedStringArray = PackedStringArray()
	for key: String in after_values:
		if not before_values.has(key):
			diff.append(key)
	return diff


func _warn_invalid_extra(key: String, value: Variant, context: String, fallback_note: String) -> void:
	var warning_id: String = "%s|%s" % [context, key]
	if _warning_rate_limit_seen.has(warning_id):
		return
	_warning_rate_limit_seen[warning_id] = true
	if _suppress_warnings:
		return

	var value_type: int = typeof(value)
	push_warning(
		"Xedats glTF: %s invalid '%s' (%s) in %s; %s" % [
			key,
			str(value),
			value_type,
			context,
			fallback_note
		]
	)


## Normalises a glTF weight value to a scalar float in [0, 1].[br]
## Handles all forms that a JSON author might legitimately write:[br]
##   [code]float / int[/code]  — returned directly, clamped.[br]
##   [code]Array[/code]        — numeric elements averaged, clamped.[br]
##   [code]Dictionary[/code]   — channel keys (x/y/z/r/g/b) averaged, clamped.
func _parse_weight_value(value: Variant) -> float:
	if value is float:
		return clamp(float(value), 0.0, 1.0)
	if value is int:
		return clamp(float(value), 0.0, 1.0)
	if value is Array:
		var numeric_values: Array[float] = []
		for entry: Variant in value:
			if entry is float or entry is int:
				numeric_values.append(float(entry))
		if numeric_values.is_empty():
			return 0.0
		var total: float = 0.0
		for numeric_value: float in numeric_values:
			total += numeric_value
		return clamp(total / float(numeric_values.size()), 0.0, 1.0)
	if value is Dictionary:
		var dict_value: Dictionary = value
		var keys: Array[String] = ["x", "y", "z", "r", "g", "b"]
		var values: Array[float] = []
		for key: String in keys:
			if dict_value.has(key):
				var component: Variant = dict_value[key]
				if component is float or component is int:
					values.append(float(component))
		if values.is_empty():
			return 0.0
		var summed: float = 0.0
		for component_value: float in values:
			summed += component_value
		return clamp(summed / float(values.size()), 0.0, 1.0)
	return 0.0


## Returns the [code]res://[/code] path for a KHR source at [param source_index].[br]
## Resolution order:[br]
##   1. [code]extras.xedats_path[/code] — explicit override, skips URI resolution.[br]
##   2. [code]uri[/code] field — normalised through [method _normalize_resource_uri].
func _resolve_source_path(state: GLTFState, parse_cache: Dictionary, source_index: int) -> String:
	var sources: Array[Dictionary] = parse_cache.get("khr_sources", [])
	if source_index < 0 or source_index >= sources.size():
		return ""

	var source_data: Dictionary = sources[source_index]
	if source_data.has("extras"):
		var extras_variant: Variant = source_data.get("extras")
		if extras_variant is Dictionary:
			var extras: Dictionary = extras_variant
			var xedats_path: String = String(extras.get("xedats_path", ""))
			if not xedats_path.is_empty():
				return _normalize_resource_uri(state, xedats_path)

	if source_data.has("uri"):
		return _normalize_resource_uri(state, String(source_data.get("uri", "")))

	return ""


## Converts a glTF URI (relative or absolute filesystem path) to a Godot
## [code]res://[/code] or [code]user://[/code] path suitable for [ResourceLoader].[br]
## Resolution strategy:[br]
##   1. Already-rooted paths ([code]res://[/code], [code]user://[/code]) pass through unchanged.[br]
##   2. [code]state.base_path[/code] joined with the URI, then
##      [method ProjectSettings.localize_path] used to convert to [code]res://[/code].[br]
##   3. Falls back to [code]state.filename.get_base_dir()[/code] if base_path is empty.[br]
## The [code].simplify_path()[/code] call collapses any [code]../[/code] segments
## that result from relative URIs deep inside the project tree.
func _normalize_resource_uri(state: GLTFState, uri: String) -> String:
	if uri.is_empty():
		return ""
	if uri.begins_with("res://"):
		return uri
	if uri.begins_with("user://"):
		return uri

	var resolved_path: String = uri
	var base_path: String = state.base_path
	if not base_path.is_empty():
		resolved_path = base_path.path_join(uri).simplify_path()
		var localized_from_base: String = ProjectSettings.localize_path(resolved_path)
		if localized_from_base.begins_with("res://") or localized_from_base.begins_with("user://"):
			return localized_from_base
		return resolved_path

	var state_filename: String = state.filename
	if state_filename.is_empty():
		return uri

	var base_dir: String = state_filename.get_base_dir()
	if base_dir.is_empty():
		return uri

	resolved_path = base_dir.path_join(uri).simplify_path()
	var localized_from_filename: String = ProjectSettings.localize_path(resolved_path)
	if localized_from_filename.begins_with("res://") or localized_from_filename.begins_with("user://"):
		return localized_from_filename
	return resolved_path


## Extracts the Xedats event name from an emitter Dictionary.[br]
## Resolution priority:[br]
##   1. [code]extras.xedats_event[/code] — explicit Xedats event key.[br]
##   2. [code]extras.event[/code] — generic extras event fallback.[br]
##   3. Top-level [code]event[/code] field.[br]
##   4. Top-level [code]name[/code] field (used as event name by convention).[br]
## Returns an empty String when none of the above are present.
func _resolve_event_name(emitter_data: Dictionary) -> String:
	if emitter_data.has("extras"):
		var extras_variant: Variant = emitter_data.get("extras")
		if extras_variant is Dictionary:
			var extras: Dictionary = extras_variant
			var event_name: String = String(extras.get("xedats_event", ""))
			if not event_name.is_empty():
				return event_name
			event_name = String(extras.get("event", ""))
			if not event_name.is_empty():
				return event_name

	if emitter_data.has("event"):
		return String(emitter_data.get("event", ""))
	if emitter_data.has("name"):
		return String(emitter_data.get("name", ""))

	return ""


## Extracts the Xedats audio category from an emitter Dictionary.[br]
## Checks [code]extras.xedats_category[/code] then [code]extras.category[/code].[br]
## Returns [constant DEFAULT_CATEGORY] ([code]"SFX"[/code]) when no category is found.
func _resolve_category(emitter_data: Dictionary) -> String:
	if emitter_data.has("extras"):
		var extras_variant: Variant = emitter_data.get("extras")
		if extras_variant is Dictionary:
			var extras: Dictionary = extras_variant
			var category: String = String(extras.get("xedats_category", ""))
			if not category.is_empty():
				return category
			category = String(extras.get("category", ""))
			if not category.is_empty():
				return category

	return DEFAULT_CATEGORY


## Returns all source indices referenced by [param emitter_data].[br]
## Accepts both [code]int[/code] and [code]float[/code] values because Godot 4's
## JSON parser deserialises every JSON number as [code]float[/code]; the cast to
## [code]int[/code] is safe given glTF indices are always non-negative integers.[br]
## Handles both the multi-source [code]sources[/code] array and the legacy
## single-source [code]source[/code] field without double-counting.
func _get_emitter_source_indices(emitter_data: Dictionary) -> Array[int]:
	var indices: Array[int] = []
	if emitter_data.has("sources"):
		var sources_variant: Variant = emitter_data.get("sources")
		if sources_variant is Array:
			for source_variant: Variant in sources_variant:
				if source_variant is int or source_variant is float:
					indices.append(int(source_variant))
	if emitter_data.has("source"):
		var source_value: Variant = emitter_data.get("source")
		if source_value is int or source_value is float:
			var single_source: int = int(source_value)
			if not indices.has(single_source):
				indices.append(single_source)
	return indices


## Coerces a raw [Variant] (expected Array of Dictionaries) to a typed
## [code]Array[Dictionary][/code], silently dropping any non-Dictionary elements.
func _as_dictionary_array(raw_value: Variant) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	if raw_value is Array:
		for entry: Variant in raw_value:
			if entry is Dictionary:
				parsed.append(entry)
	return parsed


## Retrieves the parse cache from [param state] additional data.[br]
## Self-heals in two ways to guard against edge cases in the Godot pipeline:[br]
##   • If [code]state_json[/code] is missing it is injected from [code]state.json[/code].[br]
##   • If all three arrays are empty (possible when [method _import_preflight] was
##     called on an earlier import pass and the data was recycled) the document
##     extensions are re-parsed so downstream stages always have live data.[br]
## Returns a fallback empty-structure Dictionary when no cache exists at all.
func _get_parse_cache(state: GLTFState) -> Dictionary:
	var cache_variant: Variant = state.get_additional_data(DATA_KEY)
	if cache_variant is Dictionary:
		var cache: Dictionary = cache_variant
		if not cache.has("state_json"):
			cache["state_json"] = state.json
		if int((cache.get("khr_sources", []) as Array).size()) == 0 and int((cache.get("khr_emitters", []) as Array).size()) == 0 and int(cache.get("omi_materials", {}).size()) == 0:
			_parse_document_extensions(state, cache)
		return cache
	return {
		"khr_sources": [],
		"khr_emitters": [],
		"omi_materials": {},
		"state_json": state.json
	}
