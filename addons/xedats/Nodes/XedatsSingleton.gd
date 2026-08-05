class_name XedatsSingleton
extends Node

## Core Xedats audio system singleton for Godot 4.6+.
##
## XedatsSingleton is the main audio system providing:
## - 3D spatial audio with listener management
## - Player pooling for efficient audio playback
## - Custom audio buses for volume categorization
## - Audio event system for named audio triggers
## - Audio state persistence (save/load)
## - Crossfading between audio streams
## - Performance monitoring and profiling
##
## [b]DEPENDENCY NOTE:[/b] This standalone package owns its singleton lifecycle internally.
## The standalone copy no longer depends on AutoloadManager or AutoloadDocking for runtime bootstrapping.
##
## This singleton lazily instantiates itself and attaches to the active scene tree root.
## Access it from anywhere using [code]XedatsSingleton.instance()[/code]:
## [codeblock]
## var audio = XedatsSingleton.instance()
## if audio:
##     audio.play_audio_at_position(my_stream, world_position)
## [/codeblock]
##
## The system maintains a pool of pre-allocated audio players for efficient playback
## without frame rate hitches from constant allocation/deallocation.
##
## [b]COMMON USAGE PATTERNS:[/b]
##
## [b]1. Playing a simple sound at a position:[/b]
## [codeblock]
## var audio = XedatsSingleton.instance()
## if audio:
##     audio.play_audio_at_position(stream, global_position, 0.8, "SFX")
## [/codeblock]
##
## [b]2. Playing sounds from an AudioArrayContainer (with variations):[/b]
## [codeblock]
## var audio = XedatsSingleton.instance()
## if audio:
##     var player = audio.create_player_3d(global_position)
##     player.audio_category = "SFX"
##     player.play_random_from_container(footstep_container)
## [/codeblock]
##
## [b]3. Player footsteps with different surfaces:[/b]
## [codeblock]
## var footstep_grass = preload("res://audio/footsteps/grass.tres")
## func play_footstep() -> void:
##     var player = XedatsSingleton.instance().create_player_3d(global_position)
##     player.audio_category = "SFX"
##     player.play_random_from_container(footstep_grass)
## [/codeblock]
##
## [b]4. World object sounds (doors, chests, interactables):[/b]
## [codeblock]
## func play_door_open() -> void:
##     var audio = XedatsSingleton.instance()
##     var player = audio.create_player_3d(global_position)
##     player.audio_category = "SFX"
##     player.stream = door_open_sound
##     player.pitch_scale = randf_range(0.95, 1.05)
##     player.play()
## [/codeblock]
##
## [b]5. Using the audio event system:[/b]
## [codeblock]
## var audio = XedatsSingleton.instance()
## audio.trigger_audio_event("player_jump", global_position)
## [/codeblock]
##
## See Xedats.md for comprehensive usage documentation and examples.

#region Static Helper

## Static singleton instance reference for the standalone runtime.
static var _instance_ref: XedatsSingleton = null

## Static guard flag to prevent recursive singleton creation during initialization.
@warning_ignore("unused_private_class_variable")
static var _instantiation_in_progress: bool = false

## Test hook for simulating an unavailable runtime singleton.
static var _instance_creation_blocked_for_tests: bool = false

## Incrementing counters for unique node naming (replaces randi() to avoid collisions).
static var _next_player_id: int = 0
static var _next_player_2d_id: int = 0
static var _next_listener_id: int = 0
static var _next_listener_2d_id: int = 0

## Returns the current instance of XedatsSingleton.
##
## If the singleton hasn't been instantiated yet, it will be created lazily on first access.
## The standalone package attaches the singleton directly to the scene tree root.
##
## [return] The XedatsSingleton instance, or null if no scene tree is available.
static func instance() -> XedatsSingleton:
	var live_instance: XedatsSingleton = peek_instance()
	if live_instance != null:
		return live_instance

	if _instance_creation_blocked_for_tests or _instantiation_in_progress:
		return null

	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree == null or scene_tree.root == null:
		return null

	_instantiation_in_progress = true
	var new_instance: XedatsSingleton = XedatsSingleton.new()
	new_instance.name = "XedatsSingleton"
	_instance_ref = new_instance
	scene_tree.root.add_child(new_instance)
	if _instantiation_in_progress:
		_instantiation_in_progress = false
	return peek_instance()


static func peek_instance() -> XedatsSingleton:
	if _instance_ref != null and is_instance_valid(_instance_ref):
		return _instance_ref
	_instance_ref = null
	return null


static func _set_instance_creation_blocked_for_tests(blocked: bool) -> void:
	_instance_creation_blocked_for_tests = blocked
	if not blocked:
		_instantiation_in_progress = false

#endregion

#region Variables

## @var _player_pool
## Pool of pre-allocated XedatsPlayer3D instances for efficient audio playback.
## Players are reused to avoid frame rate hitches from constant allocation/deallocation.
var _player_pool: Array[XedatsPlayer3D] = []

## @var _active_players
## Currently active audio players that are playing sounds.
## These players are returned to the pool when they finish playing.
var _active_players: Array[XedatsPlayer3D] = []

## @export var max_pool_size
## Maximum number of players to keep in the pool.
## Increase for MIDI-heavy projects where orchestration can produce 100+ concurrent notes.
## @default 32
@export var max_pool_size: int = 32

## @export var max_pool_size_2d
## Maximum number of 2D players to keep in the pool.
## @default 32
@export var max_pool_size_2d: int = 32

## @var _player_2d_pool
## Pool of pre-allocated XedatsPlayer2D instances for 2D audio.
var _player_2d_pool: Array = []

## @var _active_players_2d
## Currently active 2D audio players.
var _active_players_2d: Array = []

## @var _active_listeners_2d
## Array of all registered XedatsListener2D instances.
var _active_listeners_2d: Array = []

## @var _current_listener_2d
## The currently active 2D audio listener.
var _current_listener_2d: Node = null

## @var _active_listeners
## Array of all registered XedatsListener3D instances in the scene.
## Only one listener can be active at a time for 3D audio mixing.
var _active_listeners: Array[XedatsListener3D] = []

## @var _current_listener
## The currently active audio listener that determines the 3D audio perspective.
## All spatial audio is mixed relative to this listener's position.
var _current_listener: XedatsListener3D = null

const BUILTIN_BASE_BUSES: PackedStringArray = ["Master", "SFX", "Music", "VoiceLines", "Ambient"]
const BUILTIN_EFFECT_BUS_SENDS: Dictionary = {
	"MasterEffects": "Master",
	"SFXEffects": "SFX",
	"MusicEffects": "Music",
	"VoiceLinesEffects": "VoiceLines",
	"AmbientEffects": "Ambient"
}
const CATEGORY_EFFECT_BUS_MAP: Dictionary = {
	"Master": "MasterEffects",
	"SFX": "SFXEffects",
	"Music": "MusicEffects",
	"VoiceLines": "VoiceLinesEffects",
	"Ambient": "AmbientEffects"
}

## @var _custom_buses
## Dictionary mapping tracked audio bus names to their AudioServer bus indices.
## Used for dynamic routing and effect-chain management.
var _custom_buses: Dictionary = {} # bus_name -> bus_index

## @var _bus_effects
## Dictionary mapping bus names to arrays of effect data.
## Each effect data contains the effect instance and its index on the bus.
var _bus_effects: Dictionary = {} # bus_name -> Array[effect_data]

## @var _category_volumes
## Volume levels for different audio categories (Master, SFX, Music, VoiceLines, Ambient).
## Values range from 0.0 (silent) to 1.0 (full volume).
var _category_volumes: Dictionary = {
	"Master": 1.0,
	"SFX": 1.0,
	"Music": 1.0,
	"VoiceLines": 1.0,
	"Ambient": 1.0
}

## @var _audio_event_system
## Reference to the AudioEventSystem subsystem for named audio triggers.
var _audio_event_system: AudioEventSystem

## @var _audio_state_manager
## Reference to the AudioStateManager subsystem for saving/loading audio settings.
var _audio_state_manager: AudioStateManager

## @var _audio_crossfade
## Reference to the AudioCrossfade subsystem for smooth audio transitions.
var _audio_crossfade: AudioCrossfade

## @var _performance_stats
## Dictionary containing real-time performance metrics for monitoring audio system health.
var _performance_stats: Dictionary = {
	"frame_times": [],
	"active_player_count": 0,
	"peak_active_players": 0,
	"active_player_2d_count": 0,
	"peak_active_players_2d": 0,
	"total_playbacks": 0,
	"effect_processing_time": 0.0
}

## @var MAX_PERF_HISTORY
## Maximum number of performance samples to store for historical analysis.
## At 60fps, this stores approximately 5 seconds of performance data.
const MAX_PERF_HISTORY: int = 300 # Store ~5 seconds at 60fps

# Configuration

## @export var default_player_pool_size
## @brief Initial number of audio players to pre-allocate in the pool.
## @description Higher values reduce allocation spikes but use more memory.
## @default 16
@export var default_player_pool_size: int = 16

## @export var default_player_2d_pool_size
## Initial number of 2D audio players to pre-allocate.
@export var default_player_2d_pool_size: int = 16

## @export var auto_cleanup_interval
## @brief Time in seconds between automatic cleanup of inactive audio players.
## @description Players that have finished playing are returned to the pool during cleanup.
## @default 30.0
@export var auto_cleanup_interval: float = 30.0

## @export var enable_debug_logging
## @brief Whether to print debug information to the console.
## @description Useful for development and troubleshooting audio issues.
## @default false
@export var enable_debug_logging: bool = false

## @export var enable_performance_monitoring
## @brief Whether to track and monitor audio system performance metrics.
## @description Performance data can be accessed via get_performance_metrics().
## @default true
@export var enable_performance_monitoring: bool = true

## @export var max_simultaneous_sounds
## @brief Maximum number of simultaneous audio players allowed.
## @description Prevents audio overload and performance issues.
## @default 64
@export var max_simultaneous_sounds: int = 64

#endregion

#region Functions

## Initializes singleton lifecycle, subsystems, and maintenance timers.
func _ready() -> void:
	_instance_ref = self
	
	# Initialize the audio system
	_initialize_audio_system()
	if ClassDB.class_exists(&"XedatsPlayer2D"):
		_initialize_audio_system_2d()
	_ensure_builtin_effect_buses()
	_ensure_builtin_base_buses()
	
	# Create subsystems (these might call XedatsSingleton.instance())
	_audio_event_system = AudioEventSystem.new()
	_audio_event_system.name = "AudioEventSystem"
	add_child(_audio_event_system)
	
	_audio_state_manager = AudioStateManager.new()
	_audio_state_manager.name = "AudioStateManager"
	add_child(_audio_state_manager)
	
	_audio_crossfade = AudioCrossfade.new()
	_audio_crossfade.name = "AudioCrossfade"
	add_child(_audio_crossfade)
	
	# Set up auto cleanup timer
	var timer: Timer = Timer.new()
	timer.wait_time = auto_cleanup_interval
	timer.autostart = true
	timer.timeout.connect(_cleanup_inactive_players)
	add_child(timer)
	
	# Set up 2D auto cleanup timer
	if ClassDB.class_exists(&"XedatsPlayer2D"):
		var timer_2d: Timer = Timer.new()
		timer_2d.wait_time = auto_cleanup_interval
		timer_2d.autostart = true
		timer_2d.timeout.connect(_cleanup_inactive_players_2d)
		add_child(timer_2d)
	
	# Clear the instantiation flag now that subsystems are initialized.
	_instantiation_in_progress = false


func _exit_tree() -> void:
	if _instance_ref == self:
		_instance_ref = null
	_instantiation_in_progress = false

## Initializes the player pool and startup state.
func _initialize_audio_system() -> void:
	# Pre-populate player pool
	for i in default_player_pool_size:
		var player: XedatsPlayer3D = _create_player()
		_player_pool.append(player)
	
	if enable_debug_logging:
		print("Xedats: Audio system initialized with %d pooled players" % _player_pool.size())

## Initializes the 2D player pool.
func _initialize_audio_system_2d() -> void:
	if not ClassDB.class_exists(&"XedatsPlayer2D"):
		return
	for i in default_player_2d_pool_size:
		var player_2d: Node = _create_player_2d()
		_player_2d_pool.append(player_2d)

	if enable_debug_logging:
		print("Xedats: 2D audio system initialized with %d pooled players" % _player_2d_pool.size())

#endregion

# Audio Player Pooling

## Returns a pre-allocated audio player from the pool for efficient playback.
## @return XedatsPlayer3D: A ready-to-use audio player instance.
func get_player_from_pool() -> XedatsPlayer3D:
	var player: XedatsPlayer3D
	
	if _player_pool.is_empty():
		# Create new player if pool is empty
		player = _create_player()
		if enable_debug_logging:
			print("Xedats: Created new player (pool empty)")
	else:
		# Get player from pool
		player = _player_pool.pop_back()
	
	player._set_pool_info(true, _active_players.size())
	_active_players.append(player)
	
	return player

## Returns an audio player to the pool after it finishes playing.
## @param player: The XedatsPlayer3D instance to return to the pool.
func return_player_to_pool(player: XedatsPlayer3D) -> void:
	if not player._is_from_pool:
		push_error("Xedats: Attempted to return non-pooled player to pool")
		return
	
	# Reset player state
	player._reset_for_pool()
	
	# Remove from active list
	_active_players.erase(player)
	
	# Return to pool if not at max size
	if _player_pool.size() < max_pool_size:
		_player_pool.append(player)
	else:
		# Destroy if pool is full
		player.queue_free()
		if enable_debug_logging:
			print("Xedats: Destroyed player (pool full)")

## Creates a new pooled player node and adds it under the singleton.
## @return XedatsPlayer3D Newly created player instance.
func _create_player() -> XedatsPlayer3D:
	var player: XedatsPlayer3D = XedatsPlayer3D.new()
	player.name = "XedatsPlayer_%d" % _next_player_id
	_next_player_id += 1
	add_child(player)
	return player

## Returns a pre-allocated 2D audio player from the pool.
## @return Node A ready-to-use 2D audio player, or null if 2D is unavailable.
func get_player_2d_from_pool() -> Node:
	if not ClassDB.class_exists(&"XedatsPlayer2D"):
		return null

	var player: Node

	if _player_2d_pool.is_empty():
		player = _create_player_2d()
		if enable_debug_logging:
			print("Xedats: Created new 2D player (pool empty)")
	else:
		player = _player_2d_pool.pop_back() as Node

	player._set_pool_info(true, _active_players_2d.size())
	_active_players_2d.append(player)

	return player

## Returns a 2D audio player to the pool after it finishes playing.
## @param player The player node to return to the pool (duck-typed — requires _is_from_pool, _reset_for_pool).
func return_player_2d_to_pool(player: Node) -> void:
	if not player.has_method("_set_pool_info"):
		push_error("Xedats: Attempted to return non-pooled 2D player to pool")
		return

	if not player._is_from_pool:
		push_error("Xedats: Attempted to return non-pooled 2D player to pool")
		return

	player._reset_for_pool()

	_active_players_2d.erase(player)

	if _player_2d_pool.size() < max_pool_size_2d:
		_player_2d_pool.append(player)
	else:
		player.queue_free()
		if enable_debug_logging:
			print("Xedats: Destroyed 2D player (pool full)")

## Creates a new pooled 2D player node and adds it under the singleton.
## @return Node Newly created 2D player node.
func _create_player_2d() -> Node:
	var player: Node = ClassDB.instantiate(&"XedatsPlayer2D") as Node
	player.name = "XedatsPlayer2D_%d" % _next_player_2d_id
	_next_player_2d_id += 1
	add_child(player)
	return player

## Automatically cleans up inactive 2D audio players and returns them to the pool.
func _cleanup_inactive_players_2d() -> void:
	var to_remove: Array = []
	for player in _active_players_2d:
		if not player.playing:
			to_remove.append(player)

	for player in to_remove:
		return_player_2d_to_pool(player as Node)

	if enable_debug_logging and not to_remove.is_empty():
		print("Xedats: Cleaned up %d inactive 2D players" % to_remove.size())

## Automatically cleans up inactive audio players and returns them to the pool.
func _cleanup_inactive_players() -> void:
	var to_remove: Array[XedatsPlayer3D] = []
	for player in _active_players:
		if not player.playing:
			to_remove.append(player)
	
	for player in to_remove:
		return_player_to_pool(player)
	
	if enable_debug_logging and not to_remove.is_empty():
		print("Xedats: Cleaned up %d inactive players" % to_remove.size())

# On Demand "Xedats Player" creation
## Creates or retrieves a pooled 3D player at the specified world position.
## @param position World position for the player.
## @param parent Optional parent node to attach the player to.
## @return XedatsPlayer3D Ready-to-use player.
func create_player_3d(position: Vector3 = Vector3.ZERO, parent: Node = null) -> XedatsPlayer3D:
	var player: XedatsPlayer3D = get_player_from_pool()
	player.global_position = position
	
	if parent:
		parent.add_child(player)
	
	return player

## Creates or retrieves a pooled 2D player at the specified screen position.
## @param position Screen position for the player.
## @param parent Optional parent node to attach the player to.
## @return Node Ready-to-use 2D player node, or null if 2D is unavailable.
func create_player_2d(position: Vector2 = Vector2.ZERO, parent: Node = null) -> Node:
	var player: Node = get_player_2d_from_pool()
	if player == null:
		return null
	player.global_position = position

	if parent:
		parent.add_child(player)

	return player

# On Demand "Xedats Listener" creation
## Creates a new 3D audio listener at the specified position.
## @param position: The world position where the listener should be placed.
## @param parent: Optional parent node to attach the listener to. If null, listener is added to this node.
## @return XedatsListener3D: A ready-to-use audio listener positioned at the specified location.
func create_listener_3d(position: Vector3 = Vector3.ZERO, parent: Node = null) -> XedatsListener3D:
	var listener: XedatsListener3D = XedatsListener3D.new()
	listener.name = "XedatsListener_%d" % _next_listener_id
	_next_listener_id += 1
	listener.global_position = position
	
	if parent:
		parent.add_child(listener)
	else:
		add_child(listener)
	
	_register_listener(listener)
	
	if not _current_listener:
		set_current_listener(listener)
	
	return listener

## Registers a listener in the active listener collection.
## @param listener Listener instance to register.
func _register_listener(listener: XedatsListener3D) -> void:
	if not _active_listeners.has(listener):
		_active_listeners.append(listener)

## Unregisters a listener and clears current listener if it matches.
## @param listener Listener instance to unregister.
func _unregister_listener(listener: XedatsListener3D) -> void:
	_active_listeners.erase(listener)
	if _current_listener == listener:
		_current_listener = null

## Sets the active 3D audio listener, making it the spatial audio origin point.
## All positional audio is mixed relative to this listener's position and orientation.
## Calls [code]make_current()[/code] on the listener to register it with the AudioServer.
##
## If [param listener] is [code]null[/code], a warning is emitted and state is unchanged.
##
## @param listener The [XedatsListener3D] instance to activate as the current listener.
func set_current_listener(listener: XedatsListener3D) -> void:
	if listener == null:
		push_warning("Xedats: Attempting to set current listener to null")
		return
	
	_current_listener = listener
	listener.make_current()

## Gets the current active listener.
## @return XedatsListener3D Current listener, or null.
func get_current_listener() -> XedatsListener3D:
	return _current_listener

## Creates a new 2D audio listener at the specified position.
## @param position The screen position where the listener should be placed.
## @param parent Optional parent node to attach the listener to.
## @return Node A ready-to-use 2D audio listener, or null if 2D is unavailable.
func create_listener_2d(position: Vector2 = Vector2.ZERO, parent: Node = null) -> Node:
	if not ClassDB.class_exists(&"XedatsListener2D"):
		return null

	var listener: Node = ClassDB.instantiate(&"XedatsListener2D") as Node
	listener.name = "XedatsListener2D_%d" % _next_listener_2d_id
	_next_listener_2d_id += 1
	listener.global_position = position

	if parent:
		parent.add_child(listener)
	else:
		add_child(listener)

	_register_listener_2d(listener)

	if not _current_listener_2d:
		set_current_listener_2d(listener)

	return listener

## Registers a 2D listener in the active listener collection.
func _register_listener_2d(listener: Node) -> void:
	if not _active_listeners_2d.has(listener):
		_active_listeners_2d.append(listener)

## Unregisters a 2D listener and clears current listener if it matches.
func _unregister_listener_2d(listener: Node) -> void:
	_active_listeners_2d.erase(listener)
	if _current_listener_2d == listener:
		_current_listener_2d = null

## Sets the active 2D audio listener.
func set_current_listener_2d(listener: Node) -> void:
	if listener == null:
		push_warning("Xedats: Attempting to set current 2D listener to null")
		return

	_current_listener_2d = listener
	if listener.has_method("make_current"):
		listener.make_current()

## Gets the current active 2D listener.
## @return Node Current 2D listener node, or null.
func get_current_listener_2d() -> Node:
	return _current_listener_2d

## Gets a copy of all configured category volumes.
## @return Dictionary Category to volume map.
func get_all_category_volumes() -> Dictionary:
	return _category_volumes.duplicate()


## Returns [code]true[/code] when a bus with [param bus_name] exists in [AudioServer].
func has_audio_bus(bus_name: String) -> bool:
	return AudioServer.get_bus_index(bus_name) >= 0


## Returns a designer-facing list of known bus names.
## Built-in buses are listed first, followed by any dynamically created buses.
func get_audio_bus_names(include_builtin: bool = true) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if include_builtin:
		for bus_name: String in BUILTIN_BASE_BUSES:
			if has_audio_bus(bus_name):
				names.append(bus_name)
		for effect_bus_name: String in BUILTIN_EFFECT_BUS_SENDS.keys():
			if has_audio_bus(effect_bus_name):
				names.append(effect_bus_name)
	for tracked_bus_name: Variant in _custom_buses.keys():
		var custom_bus_name: String = String(tracked_bus_name)
		if not names.has(custom_bus_name) and has_audio_bus(custom_bus_name):
			names.append(custom_bus_name)
	return names


## Resolves a route to a real bus name with a stable fallback path.
## [param requested_bus] takes priority when it exists. Otherwise a category bus or
## paired category effect bus is used, falling back to [code]Master[/code].
func resolve_bus_name(category: String = "SFX", use_effect_bus: bool = false, requested_bus: String = "") -> String:
	var normalized_category: String = category.strip_edges()
	if normalized_category.is_empty():
		normalized_category = "SFX"

	var normalized_requested_bus: String = requested_bus.strip_edges()
	if not normalized_requested_bus.is_empty() and has_audio_bus(normalized_requested_bus):
		return normalized_requested_bus

	if use_effect_bus and CATEGORY_EFFECT_BUS_MAP.has(normalized_category):
		var effect_bus_name: String = String(CATEGORY_EFFECT_BUS_MAP[normalized_category])
		if has_audio_bus(effect_bus_name):
			return effect_bus_name

	if has_audio_bus(normalized_category):
		return normalized_category

	return "Master"

# On Demand Audio Bus creation
## Creates and registers a new named audio bus, routing its output through [param parent_bus].
## The bus is available immediately for volume control and [AudioEffect] chains.
## If a bus with [param bus_name] already exists, its existing index is returned without creating a duplicate.
##
## @param bus_name Unique name for the new audio bus (e.g. [code]"Reverb"[/code]).
## @param parent_bus Name of the bus to send output to. Defaults to [code]"Master"[/code].
## @return The AudioServer bus index of the new or pre-existing bus.
func create_audio_bus(bus_name: String, parent_bus: String = "Master") -> int:
	var normalized_bus_name: String = bus_name.strip_edges()
	if normalized_bus_name.is_empty():
		push_error("Xedats: Audio bus name cannot be empty")
		return -1

	var normalized_parent_bus: String = parent_bus.strip_edges()
	if normalized_parent_bus.is_empty() or not has_audio_bus(normalized_parent_bus):
		normalized_parent_bus = "Master"

	var existing_index: int = AudioServer.get_bus_index(normalized_bus_name)
	if existing_index >= 0:
		_register_tracked_bus(normalized_bus_name, existing_index)
		if AudioServer.get_bus_send(existing_index) != normalized_parent_bus and normalized_bus_name != "Master":
			AudioServer.set_bus_send(existing_index, normalized_parent_bus)
		return existing_index
	
	var bus_index: int = AudioServer.bus_count
	AudioServer.add_bus(bus_index)
	AudioServer.set_bus_name(bus_index, normalized_bus_name)
	
	# Set parent bus
	var parent_index: int = AudioServer.get_bus_index(normalized_parent_bus)
	if parent_index >= 0 and normalized_bus_name != "Master":
		AudioServer.set_bus_send(bus_index, normalized_parent_bus)
	
	_register_tracked_bus(normalized_bus_name, bus_index)
	
	if enable_debug_logging:
		print("Xedats: Created audio bus '%s' at index %d" % [normalized_bus_name, bus_index])
	
	return bus_index


## Removes a dynamically created audio bus and refreshes tracked bus indices.
## Built-in buses and built-in effect buses are protected and will not be removed.
func remove_audio_bus(bus_name: String) -> bool:
	var normalized_bus_name: String = bus_name.strip_edges()
	if normalized_bus_name.is_empty():
		return false
	if BUILTIN_BASE_BUSES.has(normalized_bus_name) or BUILTIN_EFFECT_BUS_SENDS.has(normalized_bus_name):
		push_warning("Xedats: Refusing to remove protected built-in bus '%s'" % normalized_bus_name)
		return false

	var bus_index: int = AudioServer.get_bus_index(normalized_bus_name)
	if bus_index < 0:
		return false

	AudioServer.remove_bus(bus_index)
	_custom_buses.erase(normalized_bus_name)
	_bus_effects.erase(normalized_bus_name)
	_refresh_tracked_bus_indices()
	return true

# Audio Bus Effect Chain add/remove functionality
## Appends an [AudioEffect] to the end of the effect chain on the named bus.
## Effects are applied in insertion order. The bus must have been created via [method create_audio_bus].
## Returns [code]-1[/code] and logs an error if the bus does not exist.
##
## @param bus_name Name of the target bus (must exist in the custom bus registry).
## @param effect The [AudioEffect] to attach (e.g. [AudioEffectReverb], [AudioEffectCompressor]).
## @return Zero-based index of the effect on the bus, used later with [method remove_bus_effect].
func add_bus_effect(bus_name: String, effect: AudioEffect) -> int:
	var normalized_bus_name: String = bus_name.strip_edges()
	if not _custom_buses.has(normalized_bus_name):
		var existing_index: int = AudioServer.get_bus_index(normalized_bus_name)
		if existing_index >= 0:
			_register_tracked_bus(normalized_bus_name, existing_index)
	if not _custom_buses.has(normalized_bus_name):
		push_error("Xedats: Audio bus '%s' does not exist" % bus_name)
		return -1
	
	var bus_index: int = _custom_buses[normalized_bus_name]
	var effect_index: int = AudioServer.get_bus_effect_count(bus_index)
	
	AudioServer.add_bus_effect(bus_index, effect, effect_index)
	_bus_effects[normalized_bus_name].append({
		"effect": effect,
		"index": effect_index
	})
	
	if enable_debug_logging:
		print("Xedats: Added effect to bus '%s' at index %d" % [normalized_bus_name, effect_index])
	
	return effect_index

## Removes the [AudioEffect] at [param effect_index] from the named bus's effect chain.
## Internal index tracking is updated so remaining effects retain correct indices after removal.
## Logs an error if the bus name or effect index is invalid.
##
## @param bus_name Name of the bus to modify (must exist in the custom bus registry).
## @param effect_index Zero-based index of the effect to remove, as returned by [method add_bus_effect].
func remove_bus_effect(bus_name: String, effect_index: int) -> void:
	var normalized_bus_name: String = bus_name.strip_edges()
	if not _custom_buses.has(normalized_bus_name):
		push_error("Xedats: Audio bus '%s' does not exist" % bus_name)
		return
	
	var bus_index: int = _custom_buses[normalized_bus_name]
	if effect_index < 0 or effect_index >= AudioServer.get_bus_effect_count(bus_index):
		push_error("Xedats: Invalid effect index %d for bus '%s'" % [effect_index, bus_name])
		return
	
	AudioServer.remove_bus_effect(bus_index, effect_index)
	
	# Update stored effects
	var effects: Array = _bus_effects[normalized_bus_name]
	for i in range(effects.size()):
		if effects[i]["index"] == effect_index:
			effects.remove_at(i)
			break
		elif effects[i]["index"] > effect_index:
			effects[i]["index"] -= 1
	
	if enable_debug_logging:
		print("Xedats: Removed effect at index %d from bus '%s'" % [effect_index, normalized_bus_name])


## Removes every effect from the target bus.
func clear_bus_effects(bus_name: String) -> bool:
	var normalized_bus_name: String = bus_name.strip_edges()
	if not _custom_buses.has(normalized_bus_name):
		var existing_index: int = AudioServer.get_bus_index(normalized_bus_name)
		if existing_index >= 0:
			_register_tracked_bus(normalized_bus_name, existing_index)
	if not _custom_buses.has(normalized_bus_name):
		return false

	var bus_index: int = _custom_buses[normalized_bus_name]
	for effect_slot: int in range(AudioServer.get_bus_effect_count(bus_index) - 1, -1, -1):
		AudioServer.remove_bus_effect(bus_index, effect_slot)
	_bus_effects[normalized_bus_name] = []
	return true


## Applies an [EffectChain] to a bus, optionally clearing its existing effects first.
func apply_effect_chain_to_bus(bus_name: String, effect_chain: EffectChain, clear_existing: bool = true) -> bool:
	if effect_chain == null:
		return false
	if clear_existing:
		clear_bus_effects(bus_name)
	return effect_chain.apply_to_bus(bus_name, self )

# Volume control
## Sets the master volume for a named audio category and immediately propagates the change
## to all active [XedatsPlayer3D] instances assigned to that category.
## Volume is clamped to [code][0.0, 1.0][/code] before storing.
## Built-in categories are [code]"Master"[/code], [code]"SFX"[/code], [code]"Music"[/code],
## [code]"VoiceLines"[/code], and [code]"Ambient"[/code].
##
## @param category The category name whose volume should be updated.
## @param volume Linear volume scalar in the range [code][0.0, 1.0][/code] (0 = silent, 1 = full).
func set_category_volume(category: String, volume: float) -> void:
	_category_volumes[category] = clamp(volume, 0.0, 1.0)
	_update_category_volumes()

## Gets current volume for a category.
## @param category Category name.
## @return float Category volume, defaulting to 1.0.
func get_category_volume(category: String) -> float:
	return _category_volumes.get(category, 1.0)

## Applies current category volume values to all active players.
func _update_category_volumes() -> void:
	for player in _active_players:
		if player.audio_category in _category_volumes:
			var base_volume: float = get_category_volume(player.audio_category)
			player.volume_db = linear_to_db(base_volume)

	for player_2d in _active_players_2d:
		if is_instance_valid(player_2d) and player_2d.audio_category in _category_volumes:
			var base_volume: float = get_category_volume(player_2d.audio_category)
			player_2d.volume_db = linear_to_db(base_volume)


## Swaps an active player's bus directly, with safe fallback to [code]Master[/code].
## Returns the resolved bus name actually assigned.
func swap_player_bus(player: Node, bus_name: String, fallback_bus: String = "Master") -> String:
	if player == null:
		return resolve_bus_name("Master", false, fallback_bus)
	var resolved_bus_name: String = resolve_bus_name(player.audio_category, false, bus_name)
	if not has_audio_bus(resolved_bus_name):
		resolved_bus_name = resolve_bus_name("Master", false, fallback_bus)
	player.bus = resolved_bus_name
	return resolved_bus_name


## Routes a player through either the category bus or its paired effect bus.
## Returns the resolved bus name actually assigned.
func route_player_to_category(
		player: Node,
		category: String,
		use_effect_bus: bool = false,
		requested_bus: String = ""
) -> String:
	if player == null:
		return resolve_bus_name(category, use_effect_bus, requested_bus)
	var normalized_category: String = category.strip_edges()
	if normalized_category.is_empty():
		normalized_category = player.audio_category
	if normalized_category.is_empty():
		normalized_category = "SFX"
	player.audio_category = normalized_category
	var resolved_bus_name: String = resolve_bus_name(normalized_category, use_effect_bus, requested_bus)
	player.bus = resolved_bus_name
	return resolved_bus_name

# Utility functions
## Plays an [AudioStream] at a world-space position using a pooled [XedatsPlayer3D].
## The player is automatically reclaimed when playback ends.
## For randomized multi-clip playback use [method play_audio_container_at_position] instead.
##
## @param stream The [AudioStream] resource to play.
## @param position World-space position where the sound originates.
## @param volume Linear volume scalar applied to the player (converted to dB internally). Defaults to [code]1.0[/code].
## @param category Audio category for volume grouping. Defaults to [code]"SFX"[/code].
## @return The [XedatsPlayer3D] used for playback; returned to the pool once playback ends.
func play_audio_at_position(stream: AudioStream, position: Vector3, volume: float = 1.0, category: String = "SFX") -> XedatsPlayer3D:
	var player: XedatsPlayer3D = create_player_3d(position)
	player.stream = stream
	player.volume_db = linear_to_db(volume)
	player.audio_category = category
	player.bus = resolve_bus_name(category)
	player.play()
	return player

## Plays a stream selected from an [AudioArrayContainer] at a world-space position.
## Stream selection follows the container's [enum AudioArrayContainer.PlaybackMode]
## (sequential, random, or non-repeating random). Volume and pitch variations defined on
## the container are applied automatically.
##
## @param container The [AudioArrayContainer] resource to draw a stream from.
## @param position World-space position where the sound should originate.
## @param category Audio category for volume grouping. Defaults to [code]"SFX"[/code].
## @return The [XedatsPlayer3D] used for playback; returned to the pool once playback ends.
func play_audio_container_at_position(container: AudioArrayContainer, position: Vector3, category: String = "SFX") -> XedatsPlayer3D:
	var player: XedatsPlayer3D = create_player_3d(position)
	player.audio_category = category
	player.bus = resolve_bus_name(category)
	player.play_random_from_container(container)
	return player

## Plays an [AudioStream] at a 2D screen position using a pooled [XedatsPlayer2D].
## @param stream The [AudioStream] resource to play.
## @param position Screen-space position where the sound originates.
## @param volume Linear volume scalar (0.0-1.0). Defaults to 1.0.
## @param category Audio category for volume grouping. Defaults to "SFX".
## @return The [XedatsPlayer2D] used for playback.
func play_audio_at_position_2d(stream: AudioStream, position: Vector2, volume: float = 1.0, category: String = "SFX") -> Node:
	var player: Node = create_player_2d(position)
	if player == null:
		return null
	player.stream = stream
	player.volume_db = linear_to_db(volume)
	player.audio_category = category
	player.bus = resolve_bus_name(category)
	player.play()
	return player

## Plays a stream selected from an [AudioArrayContainer] at a 2D screen position.
## @param container The [AudioArrayContainer] resource to draw a stream from.
## @param position Screen-space position where the sound should originate.
## @param category Audio category for volume grouping. Defaults to "SFX".
## @return The [XedatsPlayer2D] used for playback.
func play_audio_container_at_position_2d(container: AudioArrayContainer, position: Vector2, category: String = "SFX") -> Node:
	var player: Node = create_player_2d(position)
	if player == null:
		return null
	player.audio_category = category
	player.bus = resolve_bus_name(category)
	player.play_random_from_container(container)
	return player

# Debug functions
## Returns current player pool stats.
## @return Dictionary Pooled/active/total counts.
func get_pool_stats() -> Dictionary:
	return {
		"pooled": _player_pool.size(),
		"active": _active_players.size(),
		"total": _player_pool.size() + _active_players.size(),
		"pooled_2d": _player_2d_pool.size(),
		"active_2d": _active_players_2d.size(),
		"total_2d": _player_2d_pool.size() + _active_players_2d.size()
	}


## Returns active 3D player routing snapshots for debugging and live inspection.
func get_active_player_bus_routes() -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	for player: XedatsPlayer3D in _active_players:
		if not is_instance_valid(player):
			continue
		var bus_name: String = String(player.bus)
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		var send_target: String = ""
		if bus_index >= 0 and bus_name != "Master":
			send_target = String(AudioServer.get_bus_send(bus_index))

		routes.append({
			"player_name": String(player.name),
			"player_path": String(player.get_path()) if player.is_inside_tree() else "",
			"player_type": "3D",
			"category": String(player.audio_category),
			"bus": bus_name,
			"bus_exists": bus_index >= 0,
			"send": send_target,
			"effect_lane": BUILTIN_EFFECT_BUS_SENDS.has(bus_name) or bus_name.ends_with("Effects"),
			"playing": player.playing,
		})
	return routes

## Returns active 2D player routing snapshots for debugging and live inspection.
func get_active_player_bus_routes_2d() -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	for player in _active_players_2d:
		if not is_instance_valid(player):
			continue
		var bus_name: String = String(player.bus)
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		var send_target: String = ""
		if bus_index >= 0 and bus_name != "Master":
			send_target = String(AudioServer.get_bus_send(bus_index))

		routes.append({
			"player_name": String(player.name),
			"player_path": String(player.get_path()) if player.is_inside_tree() else "",
			"player_type": "2D",
			"category": String(player.audio_category),
			"bus": bus_name,
			"bus_exists": bus_index >= 0,
			"send": send_target,
			"playing": player.playing,
		})
	return routes

## Returns custom bus metadata and effect counts.
## @return Dictionary Bus info keyed by bus name.
func get_bus_info() -> Dictionary:
	var info: Dictionary = {}
	for bus_name: String in get_audio_bus_names():
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			continue
		info[bus_name] = {
			"index": bus_index,
			"send": AudioServer.get_bus_send(bus_index) if bus_name != "Master" else "",
			"effects": AudioServer.get_bus_effect_count(bus_index),
			"builtin": BUILTIN_BASE_BUSES.has(bus_name) or BUILTIN_EFFECT_BUS_SENDS.has(bus_name),
			"effect_bus": BUILTIN_EFFECT_BUS_SENDS.has(bus_name)
		}
	return info


func _register_tracked_bus(bus_name: String, bus_index: int) -> void:
	_custom_buses[bus_name] = bus_index
	if not _bus_effects.has(bus_name):
		_bus_effects[bus_name] = []


func _refresh_tracked_bus_indices() -> void:
	var tracked_names: Array = _custom_buses.keys().duplicate()
	for tracked_name_variant: Variant in tracked_names:
		var tracked_name: String = String(tracked_name_variant)
		var current_index: int = AudioServer.get_bus_index(tracked_name)
		if current_index < 0:
			_custom_buses.erase(tracked_name)
			_bus_effects.erase(tracked_name)
			continue
		_custom_buses[tracked_name] = current_index


func _ensure_builtin_effect_buses() -> void:
	for effect_bus_name_variant: Variant in BUILTIN_EFFECT_BUS_SENDS.keys():
		var effect_bus_name: String = String(effect_bus_name_variant)
		create_audio_bus(effect_bus_name, String(BUILTIN_EFFECT_BUS_SENDS[effect_bus_name]))


func _ensure_builtin_base_buses() -> void:
	for base_bus_name: String in BUILTIN_BASE_BUSES:
		if base_bus_name != "Master":
			create_audio_bus(base_bus_name, "Master")

# ============ PERFORMANCE MONITORING ============

## Called every frame. Drives performance monitoring when enabled.
func _process(_delta: float) -> void:
	_update_performance_stats()

## Updates rolling performance history and peak counters.
func _update_performance_stats() -> void:
	if not enable_performance_monitoring:
		return
	
	# Update active player count
	_performance_stats["active_player_count"] = _active_players.size()
	_performance_stats["active_player_2d_count"] = _active_players_2d.size()

	# Track peak
	if _active_players.size() > _performance_stats["peak_active_players"]:
		_performance_stats["peak_active_players"] = _active_players.size()
	if _active_players_2d.size() > _performance_stats["peak_active_players_2d"]:
		_performance_stats["peak_active_players_2d"] = _active_players_2d.size()

	# Get frame time from the performance monitor
	var frame_time: int = Engine.get_frames_drawn()
	_performance_stats["frame_times"].append({
		"frame": frame_time,
		"active_players": _active_players.size(),
		"pooled_players": _player_pool.size(),
		"active_players_2d": _active_players_2d.size(),
		"pooled_players_2d": _player_2d_pool.size(),
		"timestamp": Time.get_ticks_msec()
	})
	
	# Keep history size manageable
	if _performance_stats["frame_times"].size() > MAX_PERF_HISTORY:
		_performance_stats["frame_times"].pop_front()

## Gets aggregated performance metrics snapshot.
## @return Dictionary Aggregated metric values.
func get_performance_metrics() -> Dictionary:
	var metrics: Dictionary = {
		"active_players": _performance_stats["active_player_count"],
		"pooled_players": _player_pool.size(),
		"peak_active_players": _performance_stats["peak_active_players"],
		"total_players": _player_pool.size() + _active_players.size(),
		"active_players_2d": _performance_stats["active_player_2d_count"],
		"pooled_players_2d": _player_2d_pool.size(),
		"peak_active_players_2d": _performance_stats["peak_active_players_2d"],
		"total_players_2d": _player_2d_pool.size() + _active_players_2d.size(),
		"max_simultaneous_sounds": max_simultaneous_sounds,
		"available_capacity_percent": (float(_player_pool.size()) / max_pool_size) * 100.0,
		"listener_count": _active_listeners.size(),
		"listener_count_2d": _active_listeners_2d.size(),
		"custom_bus_count": _custom_buses.size(),
		"frame_history_size": _performance_stats["frame_times"].size()
	}
	
	# Calculate averages from recent frame history
	if _performance_stats["frame_times"].size() > 0:
		var recent_frames: Array = _performance_stats["frame_times"].slice(-60) # Last ~1 second at 60fps
		var total_players: int = 0
		for frame_data in recent_frames:
			total_players += frame_data["active_players"]
		metrics["average_active_players"] = float(total_players) / recent_frames.size()
	
	return metrics

## Gets frame-by-frame performance history.
## @return Array Performance sample array.
func get_performance_history() -> Array:
	return _performance_stats["frame_times"].duplicate(true)

## Prints a formatted audio system performance snapshot to the Output console.
## Reports active player count vs. [member max_simultaneous_sounds], pooled player count,
## pool fill percentage, peak active players, active listener count, and custom bus count.
## Only available when [member enable_performance_monitoring] is [code]true[/code].
func print_performance_report() -> void:
	var metrics: Dictionary = get_performance_metrics()
	if not enable_debug_logging:
		return

	print("\n========== XEDATS PERFORMANCE REPORT ==========")
	print("Active 3D Players: %d / %d" % [metrics["active_players"], metrics["max_simultaneous_sounds"]])
	print("Pooled 3D Players: %d (Pool Fill: %.1f%%)" % [metrics["pooled_players"], metrics["available_capacity_percent"]])
	print("Peak Active 3D Players: %d" % metrics["peak_active_players"])
	print("Active 2D Players: %d" % metrics["active_players_2d"])
	print("Pooled 2D Players: %d" % metrics["pooled_players_2d"])
	print("Peak Active 2D Players: %d" % metrics["peak_active_players_2d"])
	if metrics.has("average_active_players"):
		print("Average Active Players (1s): %.1f" % metrics["average_active_players"])
	print("Active Listeners (3D): %d | (2D): %d" % [metrics["listener_count"], metrics["listener_count_2d"]])
	print("Custom Audio Buses: %d" % metrics["custom_bus_count"])
	print("============================================\n")

# ============ SUBSYSTEM INTEGRATION ============

## Registers the audio event subsystem reference.
## @param event_sys Event subsystem instance.
func _register_event_system(event_sys: AudioEventSystem) -> void:
	_audio_event_system = event_sys

## Gets the audio event subsystem.
## @return AudioEventSystem Event subsystem instance.
func get_event_system() -> AudioEventSystem:
	return _audio_event_system

## Gets the audio state subsystem.
## @return AudioStateManager State subsystem instance.
func get_state_manager() -> AudioStateManager:
	return _audio_state_manager

## Gets the audio crossfade subsystem.
## @return AudioCrossfade Crossfade subsystem instance.
func get_crossfade_system() -> AudioCrossfade:
	return _audio_crossfade

## Fires a named audio event registered with the [AudioEventSystem] subsystem.
## Returns [code]null[/code] if the event is not registered or the subsystem is unavailable.
## To pass custom overrides (volume, pitch, metadata), use [method get_event_system] then
## call [method AudioEventSystem.trigger_event_with_params] on the returned subsystem.
##
## @param event_name The registered event identifier string to fire.
## @param position Optional world-space position for 3D audio events. Defaults to [code]Vector3.ZERO[/code].
## @return The [Node] created by the event (XedatsPlayer3D or XedatsPlayer2D), or [code]null[/code].
func trigger_audio_event(event_name: String, position: Vector3 = Vector3.ZERO) -> Node:
	if _audio_event_system:
		return _audio_event_system.trigger_event(event_name, position)
	return null

## Starts a crossfade between two players (works with both 2D and 3D).
## @param source Source player to fade out.
## @param target Target player to fade in.
## @param duration Fade duration in seconds.
func crossfade_audio(source: Node, target: Node, duration: float = 1.0) -> void:
	if _audio_crossfade:
		_audio_crossfade.start_crossfade(source, target, duration)

## Saves the current audio configuration (category volumes and mute states) to disk
## via the [AudioStateManager] subsystem. The file is written to [code]user://audio_settings.cfg[/code].
## Returns [code]false[/code] if the state manager is unavailable.
##
## @return [code]true[/code] if the state was written successfully, [code]false[/code] on failure.
func save_audio_state() -> bool:
	if _audio_state_manager:
		return _audio_state_manager.save_audio_state()
	return false

## Restores audio configuration from the saved state file via the [AudioStateManager] subsystem.
## Applies saved category volumes and mute states immediately after loading.
## Returns [code]false[/code] if the state manager is unavailable or no save file exists yet.
##
## @return [code]true[/code] if state was loaded and applied successfully, [code]false[/code] on failure.
func load_audio_state() -> bool:
	if _audio_state_manager:
		return _audio_state_manager.load_audio_state()
	return false

## Builds a high-level system health report with warning list.
## @return Dictionary Health status and warning entries.
func get_system_health() -> Dictionary:
	var metrics: Dictionary = get_performance_metrics()
	var health: Dictionary = {
		"status": "healthy",
		"capacity_usage_percent": 0.0,
		"warnings": []
	}
	
	health["capacity_usage_percent"] = (float(metrics["active_players"]) / metrics["max_simultaneous_sounds"]) * 100.0
	
	# Check for potential issues
	if health["capacity_usage_percent"] > 80.0:
		health["status"] = "warning"
		health["warnings"].append("Audio capacity usage high (%.0f%%)" % health["capacity_usage_percent"])
	
	if _player_pool.size() < default_player_pool_size * 0.25:
		health["status"] = "warning"
		health["warnings"].append("3D player pool running low")

	if _player_2d_pool.size() < default_player_2d_pool_size * 0.25 and ClassDB.class_exists(&"XedatsPlayer2D"):
		health["status"] = "warning"
		health["warnings"].append("2D player pool running low")

	if metrics["listener_count"] == 0:
		health["warnings"].append("No 3D audio listeners registered")

	if metrics["listener_count_2d"] == 0 and ClassDB.class_exists(&"XedatsListener2D"):
		health["warnings"].append("No 2D audio listeners registered")
	
	if health["capacity_usage_percent"] > 95.0:
		health["status"] = "critical"
	
	return health


#
