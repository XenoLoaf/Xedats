class_name XedatsPrecomputedPropagationResolver
extends RefCounted


static func resolution_key(precomputed_id: String, probe_region: Variant) -> String:
	var normalized_id: String = precomputed_id.strip_edges()
	if not normalized_id.is_empty():
		return normalized_id
	return probe_region_key(probe_region)


static func resolution_source(precomputed_id: String, probe_region: Variant) -> String:
	var normalized_id: String = precomputed_id.strip_edges()
	if not normalized_id.is_empty():
		return "precomputed_id"
	if not probe_region_key(probe_region).is_empty():
		return "probe_region"
	return ""


static func probe_region_key(probe_region: Variant) -> String:
	if probe_region is String:
		return String(probe_region).strip_edges()
	if probe_region is Dictionary:
		var region_dict: Dictionary = probe_region
		for candidate_key: String in ["id", "region_id", "name"]:
			if region_dict.has(candidate_key):
				var candidate_value: Variant = region_dict[candidate_key]
				if candidate_value is String:
					var normalized_value: String = String(candidate_value).strip_edges()
					if not normalized_value.is_empty():
						return normalized_value
	return ""


static func profile_path_for_key(profile_key: String) -> String:
	return XedatsGLTFConfig.precomputed_propagation_root() + "/%s.tres" % profile_key


static func flatten_profile(profile: Resource) -> Dictionary:
	if profile == null or not profile.has_method("to_payload"):
		return {}
	var payload_variant: Variant = profile.call("to_payload")
	if payload_variant is Dictionary:
		return payload_variant
	return {}