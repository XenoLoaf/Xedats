class_name AudioStateManager
extends Node

## AudioStateManager handles persistence of audio settings and state for Xedats.
##
## Audio preferences are automatically saved to disk (user://AudioConfig/audio_state.json)
## and can be restored, allowing users' volume and mute settings to persist across sessions.
##
## Features:
## - Automatic saving and loading of audio state
## - Per-category volume storage
## - Category mute tracking
## - Master mute state
## - Metadata export/import for debugging
## - Automatic directory and file creation
##
## [b]COMMON USAGE PATTERNS:[/b]
##
## [b]1. Save user audio settings:[/b]
## [codeblock]
## func save_audio_settings() -> void:
##     var audio = XedatsSingleton.instance()
##     var state_manager = audio.get_state_manager()
##     state_manager.save_audio_state()
##     print("Audio settings saved to disk")
## [/codeblock]
##
## [b]2. Load user audio settings:[/b]
## [codeblock]
## func load_audio_settings() -> void:
##     var audio = XedatsSingleton.instance()
##     var state_manager = audio.get_state_manager()
##     state_manager.load_audio_state()
##     print("Audio settings restored")
## [/codeblock]
##
## [b]3. Mute/unmute categories:[/b]
## [codeblock]
## var state_manager = audio.get_state_manager()
## 
## # Mute SFX category
## state_manager.mute_category("SFX")
## audio.set_category_volume("SFX", 0.0)
##
## # Unmute SFX category
## state_manager.unmute_category("SFX")
## audio.set_category_volume("SFX", 1.0)
## [/codeblock]
##
## [b]4. Reset to defaults:[/b]
## [codeblock]
## var state_manager = audio.get_state_manager()
## state_manager.reset_audio_state()
## print("Audio settings reset to defaults")
## [/codeblock]
##
## [b]5. Update category volumes in settings menu:[/b]
## [codeblock]
## func on_sfx_volume_changed(volume: float) -> void:
##     var audio = XedatsSingleton.instance()
##     audio.set_category_volume("SFX", volume)
##
## func on_apply_settings() -> void:
##     var state_manager = audio.get_state_manager()
##     state_manager.save_audio_state()  # Persist user's choices
## [/codeblock]
##
## See Xedats.md for comprehensive usage documentation and examples.

#region Static Helper

## Gets the current AudioStateManager instance from XedatsSingleton.
## @return AudioStateManager Current state subsystem, or null.
static func instance() -> AudioStateManager:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats:
		return xedats.get_state_manager()
	return null

#endregion

## @const CONFIG_DIR
## Directory path where audio state files are stored.
const CONFIG_DIR: String = "user://AudioConfig/"

## @const CONFIG_FILE
## File path used for serialized audio state data.
const CONFIG_FILE: String = "user://AudioConfig/audio_state.json"

## @var _audio_state
## In-memory audio state data persisted to CONFIG_FILE.
var _audio_state: Dictionary = {
	"version": 1,
	"master_volume": 1.0,
	"category_volumes": {
		"SFX": 1.0,
		"Music": 1.0,
		"VoiceLines": 1.0,
		"Ambient": 1.0
	},
	"muted_categories": [],
	"master_muted": false,
	"timestamp": 0
}

## @signal state_loaded
## Emitted after audio state is successfully loaded from disk.
signal state_loaded

## @signal state_saved
## Emitted after current audio state is successfully written to disk.
signal state_saved

## @signal state_reset
## Emitted after state is reset to defaults.
signal state_reset

## Initializes state manager and attempts automatic state load.
func _ready() -> void:
	# Create config directory if it doesn't exist
	if not DirAccess.dir_exists_absolute("user://AudioConfig"):
		DirAccess.make_dir_absolute(CONFIG_DIR)
	
	# Auto-load on ready
	load_audio_state()

## Saves current audio state to disk.
## @return bool True when save succeeds.
func save_audio_state() -> bool:
	# Update current state from XedatsSingleton
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats:
		_audio_state["master_volume"] = xedats.get_category_volume("Master")
		
		var all_volumes: Dictionary = xedats.get_all_category_volumes()
		for category in all_volumes.keys():
			_audio_state["category_volumes"][category] = all_volumes[category]
	
	_audio_state["timestamp"] = Time.get_ticks_msec()
	
	# Convert to JSON
	var json_string: String = JSON.stringify(_audio_state)
	
	# Write to file
	var file: FileAccess = FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if file == null:
		push_error("Xedats: Failed to open audio state file for writing: %s" % CONFIG_FILE)
		return false
	
	file.store_string(json_string)
	file.close()
	
	state_saved.emit()
	var _xedats_ref: XedatsSingleton = XedatsSingleton.peek_instance()
	if _xedats_ref and _xedats_ref.enable_debug_logging:
		print("Xedats: Audio state saved to %s" % CONFIG_FILE)
	
	return true

## Loads audio state from disk and applies category volumes.
## @return bool True when load and validation succeed.
func load_audio_state() -> bool:
	if not FileAccess.file_exists(CONFIG_FILE):
		var _xedats_ref: XedatsSingleton = XedatsSingleton.peek_instance()
		if _xedats_ref and _xedats_ref.enable_debug_logging:
			print("Xedats: No audio state file found, using defaults")
		return false
	
	var file: FileAccess = FileAccess.open(CONFIG_FILE, FileAccess.READ)
	if file == null:
		push_error("Xedats: Failed to open audio state file for reading: %s" % CONFIG_FILE)
		return false
	
	var json_string: String = file.get_as_text()
	file.close()
	
	# Parse JSON
	var json: JSON = JSON.new()
	var error: int = json.parse(json_string)
	
	if error != OK:
		push_error("Xedats: Failed to parse audio state JSON: %s" % json.get_error_message())
		return false
	
	_audio_state = json.data

	# Backward compatibility: migrate legacy Voice key to VoiceLines.
	if _audio_state.has("category_volumes") and _audio_state["category_volumes"] is Dictionary:
		var category_volumes: Dictionary = _audio_state["category_volumes"]
		if category_volumes.has("Voice") and not category_volumes.has("VoiceLines"):
			category_volumes["VoiceLines"] = category_volumes["Voice"]
			category_volumes.erase("Voice")
			_audio_state["category_volumes"] = category_volumes

	if _audio_state.has("muted_categories") and _audio_state["muted_categories"] is Array:
		var muted_categories: Array = _audio_state["muted_categories"]
		var voice_index: int = muted_categories.find("Voice")
		if voice_index >= 0 and not muted_categories.has("VoiceLines"):
			muted_categories[voice_index] = "VoiceLines"
			_audio_state["muted_categories"] = muted_categories
	
	# Verify structure
	if not _validate_state():
		push_warning("Xedats: Audio state structure invalid, using defaults")
		_reset_state()
		return false
	
	# Apply loaded state to XedatsSingleton
	if XedatsSingleton.instance():
		for category in _audio_state["category_volumes"].keys():
			var volume: float = _audio_state["category_volumes"][category]
			XedatsSingleton.instance().set_category_volume(category, volume)
	
	state_loaded.emit()
	var _xedats_ref: XedatsSingleton = XedatsSingleton.peek_instance()
	if _xedats_ref and _xedats_ref.enable_debug_logging:
		print("Xedats: Audio state loaded from %s" % CONFIG_FILE)
	
	return true

## Resets runtime state to defaults and emits state_reset.
func reset_audio_state() -> void:
	_reset_state()
	state_reset.emit()

## Internal helper that applies default state dictionary values.
func _reset_state() -> void:
	_audio_state = {
		"version": 1,
		"master_volume": 1.0,
		"category_volumes": {
			"SFX": 1.0,
			"Music": 1.0,
			"VoiceLines": 1.0,
			"Ambient": 1.0
		},
		"muted_categories": [],
		"master_muted": false,
		"timestamp": 0
	}

## Validates current _audio_state structure.
## @return bool True when required keys are present.
func _validate_state() -> bool:
	if not _audio_state.has("version"):
		return false
	if not _audio_state.has("category_volumes"):
		return false
	if not _audio_state.has("master_volume"):
		return false
	
	return true

## Gets a deep copy of current state.
## @return Dictionary Cloned state payload.
func get_state() -> Dictionary:
	return _audio_state.duplicate(true)

## Sets category volume inside state dictionary.
## @param category Category key.
## @param volume Normalized volume [0.0, 1.0].
func set_state_category_volume(category: String, volume: float) -> void:
	if _audio_state["category_volumes"].has(category):
		_audio_state["category_volumes"][category] = clamp(volume, 0.0, 1.0)

## Gets category volume from state dictionary.
## @param category Category key.
## @return float Stored volume value or 1.0 fallback.
func get_state_category_volume(category: String) -> float:
	return _audio_state["category_volumes"].get(category, 1.0)

## Sets master mute state in persisted state.
## @param muted True to mute master.
func set_master_muted(muted: bool) -> void:
	_audio_state["master_muted"] = muted

## Gets master mute state.
## @return bool True when master is muted.
func is_master_muted() -> bool:
	return _audio_state["master_muted"]

## Adds category to muted list.
## @param category Category key.
func mute_category(category: String) -> void:
	if not _audio_state["muted_categories"].has(category):
		_audio_state["muted_categories"].append(category)

## Removes category from muted list.
## @param category Category key.
func unmute_category(category: String) -> void:
	_audio_state["muted_categories"].erase(category)

## Checks if category is marked muted.
## @param category Category key.
## @return bool True when category is muted.
func is_category_muted(category: String) -> bool:
	return category in _audio_state["muted_categories"]

## Gets all muted categories.
## @return Array Duplicated muted category list.
func get_muted_categories() -> Array:
	return _audio_state["muted_categories"].duplicate()

## Exports current state as JSON string.
## @return String Serialized JSON payload.
func export_state_as_json() -> String:
	return JSON.stringify(_audio_state)

## Imports state from JSON and applies values.
## @param json_string Serialized state JSON.
## @return bool True when parse/validation/apply succeed.
func import_state_from_json(json_string: String) -> bool:
	var json: JSON = JSON.new()
	var error: int = json.parse(json_string)
	
	if error != OK:
		push_error("Xedats: Failed to parse imported JSON: %s" % json.get_error_message())
		return false
	
	var imported_state: Dictionary = json.data
	if not _validate_state_structure(imported_state):
		push_error("Xedats: Imported state has invalid structure")
		return false
	
	_audio_state = imported_state
	
	# Apply to XedatsSingleton
	if XedatsSingleton.instance():
		for category in _audio_state["category_volumes"].keys():
			var volume: float = _audio_state["category_volumes"][category]
			XedatsSingleton.instance().set_category_volume(category, volume)
	
	return true

## Validates structure of a provided state dictionary.
## @param state Dictionary to validate.
## @return bool True when required keys are present.
func _validate_state_structure(state: Dictionary) -> bool:
	if not state.has("version"):
		return false
	if not state.has("category_volumes"):
		return false
	
	return true

## Deletes saved audio state file from disk.
## @return bool True on success or if file does not exist.
func delete_saved_state() -> bool:
	if FileAccess.file_exists(CONFIG_FILE):
		var error: Error = DirAccess.remove_absolute(CONFIG_FILE)
		if error == OK:
			var _xedats_ref: XedatsSingleton = XedatsSingleton.peek_instance()
			if _xedats_ref and _xedats_ref.enable_debug_logging:
				print("Xedats: Audio state file deleted")
			return true
		else:
			push_error("Xedats: Failed to delete audio state file")
			return false
	return true

## Gets config directory path.
## @return String User storage directory for audio config.
func get_config_dir() -> String:
	return CONFIG_DIR

## Gets config file path.
## @return String User storage file path for audio state.
func get_config_file() -> String:
	return CONFIG_FILE
