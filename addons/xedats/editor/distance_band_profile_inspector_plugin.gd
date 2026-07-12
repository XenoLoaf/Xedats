@tool
extends EditorInspectorPlugin

func _can_handle(object: Object) -> bool:
	return object is XedatsDistanceBandProfile


func _parse_begin(object: Object) -> void:
	var profile: XedatsDistanceBandProfile = object as XedatsDistanceBandProfile
	if profile == null:
		return
	var preview: Control = preload("distance_band_profile_preview.gd").new()
	preview.profile = profile
	add_custom_control(preview)
