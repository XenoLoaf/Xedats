@tool
extends EditorPlugin

var _inspector_plugin: EditorInspectorPlugin = null
var _midi_inspector_plugin: EditorInspectorPlugin = null
var _baking_dock: Control = null
var _midi_device_dock: Control = null


func _enter_tree() -> void:
	_load_gltf_distance_band_inspector()
	_load_gltf_propagation_baking_panel()
	_load_midi_note_map_inspector()
	_load_midi_device_panel()


func _exit_tree() -> void:
	if _inspector_plugin != null:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null

	if _midi_inspector_plugin != null:
		remove_inspector_plugin(_midi_inspector_plugin)
		_midi_inspector_plugin = null

	if _baking_dock != null:
		remove_control_from_docks(_baking_dock)
		_baking_dock.queue_free()
		_baking_dock = null

	if _midi_device_dock != null:
		remove_control_from_bottom_panel(_midi_device_dock)
		_midi_device_dock.queue_free()
		_midi_device_dock = null


func _load_gltf_distance_band_inspector() -> void:
	var script_path: String = "res://addons/xedats/editor/distance_band_profile_inspector_plugin.gd"
	if not ResourceLoader.exists(script_path):
		return
	var script: Script = load(script_path) as Script
	if script == null:
		return
	_inspector_plugin = script.new() as EditorInspectorPlugin
	if _inspector_plugin != null:
		add_inspector_plugin(_inspector_plugin)


func _load_gltf_propagation_baking_panel() -> void:
	var script_path: String = "res://addons/xedats/editor/propagation_baking_panel.gd"
	if not ResourceLoader.exists(script_path):
		return
	var script: Script = load(script_path) as Script
	if script == null:
		return
	_baking_dock = script.new() as Control
	if _baking_dock != null:
		_baking_dock.name = "Propagation Baker"
		add_control_to_dock(DOCK_SLOT_RIGHT_UL, _baking_dock)


func _load_midi_note_map_inspector() -> void:
	var script_path: String = "res://addons/xedats/editor/midi_note_map_inspector_plugin.gd"
	if not ResourceLoader.exists(script_path):
		return
	var script: Script = load(script_path) as Script
	if script == null:
		return
	_midi_inspector_plugin = script.new() as EditorInspectorPlugin
	if _midi_inspector_plugin != null:
		add_inspector_plugin(_midi_inspector_plugin)


func _load_midi_device_panel() -> void:
	var script_path: String = "res://addons/xedats/editor/midi_device_panel.gd"
	if not ResourceLoader.exists(script_path):
		return
	var script: Script = load(script_path) as Script
	if script == null:
		return
	_midi_device_dock = script.new() as Control
	if _midi_device_dock != null:
		_midi_device_dock.name = "MIDI Manager"
		add_control_to_bottom_panel(_midi_device_dock, "MIDI Manager")
