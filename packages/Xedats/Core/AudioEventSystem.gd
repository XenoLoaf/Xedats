class_name AudioEventSystem
extends Node

## AudioEventSystem manages named audio events that can be triggered throughout a game using Xedats.
##
## Events can have parameters like volume, pitch, position, and playback variations.
## This system centralizes audio management and makes it easy to trigger complex audio
## from any part of your codebase without requiring direct references to audio files.
##
## Features:
## - Named audio event registration and management
## - Per-event volume, pitch, and position defaults
## - Maximum playback count constraints
## - Event metadata storage for custom behavior
## - Playback history tracking and statistics
##
## [b]COMMON USAGE PATTERNS:[/b]
##
## [b]1. Register audio events at startup:[/b]
## [codeblock]
## func setup_audio_events() -> void:
##     var audio = XedatsSingleton.instance()
##     var event_system = audio.get_event_system()
##     
##     event_system.register_event(
##         "player_footstep",
##         preload("res://audio/footsteps/grass.tres"),
##         0.6,     # default volume
##         1.0,     # default pitch
##         "SFX"    # audio category
##     )
##     
##     event_system.register_event(
##         "door_open",
##         preload("res://audio/interactables/door.tres"),
##         0.7,
##         1.0,
##         "SFX"
##     )
## [/codeblock]
##
## [b]2. Trigger events from anywhere:[/b]
## [codeblock]
## func on_footstep() -> void:
##     var audio = XedatsSingleton.instance()
##     audio.trigger_audio_event("player_footstep", global_position)
##
## func on_door_open() -> void:
##     var audio = XedatsSingleton.instance()
##     audio.trigger_audio_event("door_open", door.global_position)
## [/codeblock]
##
## [b]3. Trigger events with parameter overrides:[/b]
## [codeblock]
## func on_quiet_door_open() -> void:
##     var audio = XedatsSingleton.instance()
##     var params = {
##         "position": door.global_position,
##         "volume": 0.3,    # Override default volume
##         "pitch": 0.9      # Override default pitch
##     }
##     audio.trigger_audio_event_with_params("door_open", params)
## [/codeblock]
##
## [b]4. Limit simultaneous playbacks:[/b]
## [codeblock]
## var event_system = audio.get_event_system()
## event_system.set_event_max_playback("player_footstep", 4)  # Max 4 footsteps at once
## [/codeblock]
##
## [b]5. Get event statistics:[/b]
## [codeblock]
## var event_system = audio.get_event_system()
## var stats = event_system.get_event_stats("player_footstep")
## print("Total playbacks: %d" % stats["total_playbacks"])
## print("Current active: %d" % stats["current_active"])
## [/codeblock]
##
## See Xedats.md for comprehensive usage documentation and examples.

#region Static Helper

## Gets the current AudioEventSystem instance from Xedats singleton.
## @return AudioEventSystem Current event subsystem, or null.
static func instance() -> AudioEventSystem:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats:
		return xedats.get_event_system()
	return null

#endregion

# Audio event structure
class AudioEvent:
	## @var event_name
	## Unique identifier used to trigger this event.
	var event_name: String
	## @var audio_container
	## Container holding one or more stream variations for this event.
	var audio_container: AudioArrayContainer
	## @var default_volume
	## Default normalized linear playback volume.
	var default_volume: float = 1.0
	## @var default_pitch
	## Default playback pitch multiplier.
	var default_pitch: float = 1.0
	## @var default_position
	## Optional default world position used by callers.
	var default_position: Vector3 = Vector3.ZERO
	## @var audio_category
	## Category assignment used for volume grouping.
	var audio_category: String = "SFX"
	## @var is_3d
	## Whether event playback should use spatial 3D player behavior.
	var is_3d: bool = true
	## @var max_playback_count
	## Maximum simultaneous playbacks (-1 means unlimited).
	var max_playback_count: int = -1 # -1 = unlimited
	## @var current_playback_count
	## Current number of active playbacks for this event.
	var current_playback_count: int = 0
	## @var metadata
	## Arbitrary metadata map for game-specific behavior.
	var metadata: Dictionary = {}
	
	## Initializes a new event with name and container.
	## @param p_name Event identifier.
	## @param p_container Source audio container.
	func _init(p_name: String, p_container: AudioArrayContainer) -> void:
		event_name = p_name
		audio_container = p_container

# Events dictionary
## @var _audio_events
## Registered event map keyed by event name.
var _audio_events: Dictionary[String, AudioEvent] = {}

# Performance tracking
## @var _event_playback_history
## Rolling list of playback history entries.
var _event_playback_history: Array[Dictionary] = []

## @var MAX_HISTORY_SIZE
## Maximum number of history entries kept in memory.
const MAX_HISTORY_SIZE: int = 100

## @signal event_registered(event_name)
## Emitted when an event is registered or updated.
signal event_registered(event_name: String)

## @signal event_unregistered(event_name)
## Emitted when an event is removed.
signal event_unregistered(event_name: String)

## @signal event_triggered(event_name, player)
## Emitted when an event successfully spawns and plays a player.
signal event_triggered(event_name: String, player: Node)

## @signal event_creation_failed(event_name, reason)
## Emitted when event playback cannot be created.
signal event_creation_failed(event_name: String, reason: String)

## Registers this subsystem with XedatsSingleton on ready.
func _ready() -> void:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats:
		xedats._register_event_system(self )

## Registers or updates an audio event definition.
## @param event_name Unique event name.
## @param audio_container Source container for playback.
## @param default_volume Default linear volume [0.0, 1.0].
## @param default_pitch Default pitch multiplier.
## @param audio_category Category name (e.g. SFX, Music).
## @return bool True if registration succeeds.
func register_event(event_name: String, audio_container: AudioArrayContainer,
					default_volume: float = 1.0, default_pitch: float = 1.0,
					audio_category: String = "SFX", is_3d: bool = true) -> bool:
	if not audio_container:
		push_error("Xedats: Cannot register event '%s' with null audio container" % event_name)
		return false
	
	if _audio_events.has(event_name):
		push_warning("Xedats: Event '%s' already registered, updating..." % event_name)
	
	var event: AudioEvent = AudioEvent.new(event_name, audio_container)
	event.default_volume = clamp(default_volume, 0.0, 1.0)
	event.default_pitch = clamp(default_pitch, 0.5, 2.0)
	event.audio_category = audio_category
	event.is_3d = is_3d
	
	_audio_events[event_name] = event
	event_registered.emit(event_name)
	
	return true

## Unregisters an audio event by name.
## @param event_name Event identifier.
## @return bool True if event existed and was removed.
func unregister_event(event_name: String) -> bool:
	if not _audio_events.has(event_name):
		push_error("Xedats: Event '%s' not found" % event_name)
		return false
	
	_audio_events.erase(event_name)
	event_unregistered.emit(event_name)
	
	return true

## Gets an event definition by name.
## @param event_name Event identifier.
## @return AudioEvent Matching event or null.
func get_event(event_name: String) -> AudioEvent:
	return _audio_events.get(event_name)

## Gets all registered event names.
## @return Array[String] Array of event identifiers.
func get_all_events() -> Array[String]:
	return _audio_events.keys()

## Triggers an event and returns the created player (2D or 3D).
## @param event_name Event identifier.
## @param position World position for playback.
## @param volume_override Optional volume override (<0 uses default).
## @param pitch_override Optional pitch override (<0 uses default).
## @return Node Created player (XedatsPlayer3D or XedatsPlayer2D) or null.
func trigger_event(event_name: String,
				  position: Vector3 = Vector3.ZERO,
				  volume_override: float = -1.0,
				  pitch_override: float = -1.0) -> Node:
	var event: AudioEvent = _audio_events.get(event_name)
	if not event:
		event_creation_failed.emit(event_name, "Event not registered")
		push_error("Xedats: Event '%s' not registered" % event_name)
		return null

	if event.max_playback_count > 0 and event.current_playback_count >= event.max_playback_count:
		event_creation_failed.emit(event_name, "Max playback count reached")
		return null

	if not event.audio_container:
		event_creation_failed.emit(event_name, "No audio container")
		return null

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if not xedats:
		push_error("Xedats: XedatsSingleton not available")
		return null

	var player: Node
	if event.is_3d or not ClassDB.class_exists(&"XedatsPlayer2D"):
		player = xedats.create_player_3d(position) as Node
	else:
		var pos_2d: Vector2 = Vector2(position.x, position.y)
		player = xedats.create_player_2d(pos_2d) as Node

	if not player:
		event_creation_failed.emit(event_name, "Failed to create player")
		return null

	player.audio_category = event.audio_category

	var final_volume: float = volume_override if volume_override >= 0 else event.default_volume
	final_volume *= event.audio_container.get_random_volume()
	player.volume_db = linear_to_db(clamp(final_volume, 0.0, 1.0))

	var final_pitch: float = pitch_override if pitch_override >= 0 else event.default_pitch
	final_pitch *= event.audio_container.get_random_pitch()
	player.pitch_scale = clamp(final_pitch, 0.5, 2.0)

	player.play_random_from_container(event.audio_container)

	event.current_playback_count += 1
	_record_playback(event_name)

	player.audio_finished_custom.connect(func(_p: Node):
		event.current_playback_count = max(0, event.current_playback_count - 1)
	, CONNECT_ONE_SHOT)

	event_triggered.emit(event_name, player)

	return player

## Triggers an event using a params dictionary interface.
## @param event_name Event identifier.
## @param params Dictionary with optional keys: position, volume, pitch.
## @return Node Created player (XedatsPlayer3D or XedatsPlayer2D) or null.
func trigger_event_with_params(event_name: String, params: Dictionary) -> Node:
	var position: Vector3 = params.get("position", Vector3.ZERO)
	var volume: float = params.get("volume", -1.0)
	var pitch: float = params.get("pitch", -1.0)
	
	return trigger_event(event_name, position, volume, pitch)

## Records an event playback entry in rolling history.
## @param event_name Event identifier that was played.
func _record_playback(event_name: String) -> void:
	_event_playback_history.append({
		"event": event_name,
		"timestamp": Time.get_ticks_msec()
	})
	
	if _event_playback_history.size() > MAX_HISTORY_SIZE:
		_event_playback_history.pop_front()

## Gets aggregated playback stats for one event.
## @param event_name Event identifier.
## @return Dictionary Statistics dictionary, or empty if missing.
func get_event_stats(event_name: String) -> Dictionary:
	var event: AudioEvent = _audio_events.get(event_name)
	if not event:
		return {}
	
	var total_playbacks: int = _event_playback_history.filter(
		func(entry): return entry["event"] == event_name
	).size()
	
	return {
		"event_name": event_name,
		"total_playbacks": total_playbacks,
		"current_active": event.current_playback_count,
		"max_allowable": event.max_playback_count,
		"default_volume": event.default_volume,
		"default_pitch": event.default_pitch
	}

## Gets aggregated playback stats for all events.
## @return Dictionary Map of event name to stat dictionary.
func get_all_stats() -> Dictionary:
	var stats: Dictionary = {}
	for event_name in _audio_events.keys():
		stats[event_name] = get_event_stats(event_name)
	return stats

## Sets max concurrent playback count for an event.
## @param event_name Event identifier.
## @param max_count Maximum active instances (-1 for unlimited).
func set_event_max_playback(event_name: String, max_count: int) -> void:
	var event: AudioEvent = _audio_events.get(event_name)
	if event:
		event.max_playback_count = max_count

## Adds or updates metadata on an event.
## @param event_name Event identifier.
## @param key Metadata key.
## @param value Metadata value.
func set_event_metadata(event_name: String, key: String, value: Variant) -> void:
	var event: AudioEvent = _audio_events.get(event_name)
	if event:
		event.metadata[key] = value

## Gets metadata value from an event.
## @param event_name Event identifier.
## @param key Metadata key.
## @return Variant Metadata value or null when missing.
func get_event_metadata(event_name: String, key: String) -> Variant:
	var event: AudioEvent = _audio_events.get(event_name)
	if event and event.metadata.has(key):
		return event.metadata[key]
	return null
