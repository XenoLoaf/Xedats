@tool
extends EditorPlugin

var _inspector_plugin: EditorInspectorPlugin = null
var _baking_dock: Control = null


func _enter_tree() -> void:
	_inspector_plugin = preload("editor/distance_band_profile_inspector_plugin.gd").new()
	add_inspector_plugin(_inspector_plugin)

	_baking_dock = preload("editor/propagation_baking_panel.gd").new()
	_baking_dock.name = "Propagation Baker"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _baking_dock)


func _exit_tree() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null

	if _baking_dock != null:
		remove_control_from_docks(_baking_dock)
		_baking_dock.queue_free()
		_baking_dock = null
