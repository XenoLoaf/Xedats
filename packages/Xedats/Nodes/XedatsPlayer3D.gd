class_name XedatsPlayer3D
extends AudioStreamPlayer3D

## XedatsPlayer3D is an enhanced 3D audio player for the Xedats audio system.
## 
## Features:
## - Advanced spatial audio processing (doppler, occlusion, distance filtering)
## - Audio container playback with automatic randomization
## - Volume and pitch fading with smooth transitions
## - Audio categorization for volume control groups
## - Automatic returning to object pool after playback
## - Velocity and occlusion tracking
##
## [b]COMMON USAGE PATTERNS:[/b]
##
## [b]1. Playing footstep sounds:[/b]
## [codeblock]
## var audio = XedatsSingleton.instance()
## var container = preload("res://audio/footsteps/grass.tres")  # AudioArrayContainer
## var player = audio.create_player_3d(global_position)
## player.audio_category = "SFX"
## player.play_random_from_container(container)
## [/codeblock]
##
## [b]2. Playing world object sounds (doors, chests, etc.):[/b]
## [codeblock]
## var audio = XedatsSingleton.instance()
## var player = audio.create_player_3d(door.global_position)
## player.audio_category = "SFX"
## player.stream = door_open_sound
## player.pitch_scale = randf_range(0.95, 1.05)
## player.play()
## [/codeblock]
##
## [b]3. Impact sounds with volume scaling:[/b]
## [codeblock]
## func play_landing(impact_force: float) -> void:
##     var player = audio.create_player_3d(global_position)
##     var volume = clamp(impact_force / 10.0, 0.3, 1.0)
##     player.set_volume_linear_normalized(volume)
##     player.stream = landing_sound
##     player.play()
## [/codeblock]
##
## [b]4. Fading audio in/out:[/b]
## [codeblock]
## var player = audio.create_player_3d(global_position)
## player.stream = my_stream
## player.play()
## player.fade_out(1.0)  # Fade out over 1 second
## 
## var other_player = audio.create_player_3d(other_pos)
## other_player.stream = other_stream
## player.fade_in(1.0, 0.8)  # Fade in to 80% volume over 1 second
## [/codeblock]
##
## See Xedats.md for comprehensive usage documentation and examples.

## @export var audio_category
## Audio category bus grouping for this player (for example: "SFX", "Music", "Ambient").
@export var audio_category: String = "SFX"

## @export var auto_return_to_pool
## Whether this player should automatically return to the Xedats pool after playback finishes.
@export var auto_return_to_pool: bool = true

## @export var priority
## Playback priority value used by higher-level systems when limiting simultaneous sounds.
@export var priority: int = 0

## @export var enable_spatial_audio
## Master toggle for all spatial processing features in this player.
@export var enable_spatial_audio: bool = true

## @export var enable_doppler
## Enables doppler pitch shifting based on relative velocity to the active listener.
@export var enable_doppler: bool = true

## @export var enable_occlusion
## Enables occlusion checks (raycast-based) between this source and the active listener.
@export var enable_occlusion: bool = true

## @export var enable_distance_filtering
## Enables distance-based filtering hook (implemented via audio bus effects).
@export var enable_distance_filtering: bool = true

## @export var occlusion_check_interval
## Interval in seconds between occlusion checks.
@export var occlusion_check_interval: float = 0.5

## @export var doppler_speed_multiplier
## Scalar applied to velocity when calculating doppler pitch shift.
@export var doppler_speed_multiplier: float = 1.0

## @export var max_distance_for_attenuation
## Reference max distance used by external attenuation/filter systems.
@export var max_distance_for_attenuation: float = 100.0

## @export var occlusion_intensity
## Reference intensity value for external occlusion filtering systems.
@export var occlusion_intensity: float = 0.5

## @var _is_from_pool
## Internal flag indicating whether this player originated from Xedats' pooled instances.
var _is_from_pool: bool = false

## @var _pool_id
## Internal identifier/index assigned when this player is checked out from pool tracking.
var _pool_id: int = -1

## @var _audio_container
## Last AudioArrayContainer used to play this player's content.
var _audio_container: AudioArrayContainer

## @var _previous_position
## Previous frame world position for velocity estimation.
var _previous_position: Vector3 = Vector3.ZERO

## @var _velocity
## Estimated source velocity used for doppler and external systems.
var _velocity: Vector3 = Vector3.ZERO

## @var _occlusion_check_timer
## Countdown timer used to schedule occlusion checks.
var _occlusion_check_timer: float = 0.0

## @var _is_occluded
## Current occlusion state between this source and active listener.
var _is_occluded: bool = false

## @signal audio_finished_custom(player)
## Emitted when playback finishes, providing this player instance.
signal audio_finished_custom(player: XedatsPlayer3D)

## @signal occlusion_changed(is_occluded)
## Emitted whenever occlusion state changes.
signal occlusion_changed(is_occluded: bool)

## Initializes signal wiring and spatial state on node ready.
func _ready() -> void:
	# Connect to finished signal and emit custom signal
	finished.connect(_on_audio_finished)
	
	# Setup spatial audio if enabled
	if enable_spatial_audio:
		_setup_spatial_audio()
	
	_previous_position = global_position

## Updates per-frame spatial processing (doppler, occlusion, distance filtering).
## @param delta Time elapsed since previous frame in seconds.
func _process(delta: float) -> void:
	if not enable_spatial_audio:
		return
	
	# Update doppler effect
	if enable_doppler:
		_update_doppler(delta)
	
	# Update occlusion checking
	if enable_occlusion:
		_occlusion_check_timer -= delta
		if _occlusion_check_timer <= 0:
			_check_occlusion()
			_occlusion_check_timer = occlusion_check_interval
	
	# Update distance-based filtering
	if enable_distance_filtering:
		_update_distance_filtering()

## Handles built-in finished signal and emits Xedats-specific completion signal.
func _on_audio_finished() -> void:
	audio_finished_custom.emit(self )
	
	# Auto-return to pool if enabled
	if auto_return_to_pool and _is_from_pool:
		var xedats: XedatsSingleton = XedatsSingleton.instance()
		if xedats:
			xedats.return_player_to_pool(self )

## Plays audio from a specific index inside an AudioArrayContainer.
## @param container Source audio container.
## @param index Stream index inside container.
## @param override_stream If true, assigns selected stream to this player before play().
func play_from_container(container: AudioArrayContainer, index: int = 0, override_stream: bool = true) -> void:
	if not container or index < 0 or index >= container.StreamContainer.size():
		push_error("Invalid audio container or index")
		return
	
	_audio_container = container
	if override_stream:
		stream = container.StreamContainer[index]
	play()

## Plays a random stream from an AudioArrayContainer.
## @param container Source audio container.
## @param override_stream If true, assigns selected stream to this player before play().
func play_random_from_container(container: AudioArrayContainer, override_stream: bool = true) -> void:
	if not container or container.StreamContainer.is_empty():
		push_error("Invalid or empty audio container")
		return
	
	var random_index: int = randi() % container.StreamContainer.size()
	play_from_container(container, random_index, override_stream)

## Sets volume using normalized linear value in range [0.0, 1.0].
## @param volume Normalized linear volume value.
func set_volume_linear_normalized(volume: float) -> void:
	volume_db = linear_to_db(clamp(volume, 0.0, 1.0))

## Returns current volume in normalized linear space.
## @return float Current linear volume value.
func get_volume_linear_normalized() -> float:
	return db_to_linear(volume_db)


## Swaps this player's output bus directly, using [XedatsSingleton] route resolution
## when available and falling back safely to [code]Master[/code].
## Returns the resolved bus name actually assigned.
func swap_audio_bus(bus_name: String, fallback_bus: String = "Master") -> String:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats != null:
		return xedats.swap_player_bus(self , bus_name, fallback_bus)

	var resolved_bus_name: String = bus_name.strip_edges()
	if resolved_bus_name.is_empty() or AudioServer.get_bus_index(resolved_bus_name) < 0:
		resolved_bus_name = fallback_bus if AudioServer.get_bus_index(fallback_bus) >= 0 else "Master"
	bus = resolved_bus_name
	return resolved_bus_name


## Routes this player through a category bus or its paired effect bus.
## Returns the resolved bus name actually assigned.
func route_to_audio_category(category: String, use_effect_bus: bool = false, requested_bus: String = "") -> String:
	var normalized_category: String = category.strip_edges()
	if normalized_category.is_empty():
		normalized_category = audio_category
	if normalized_category.is_empty():
		normalized_category = "SFX"

	audio_category = normalized_category
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats != null:
		return xedats.route_player_to_category(self , normalized_category, use_effect_bus, requested_bus)

	var resolved_bus_name: String = requested_bus.strip_edges()
	if resolved_bus_name.is_empty() or AudioServer.get_bus_index(resolved_bus_name) < 0:
		var fallback_effect_bus: String = "%sEffects" % normalized_category
		if use_effect_bus and AudioServer.get_bus_index(fallback_effect_bus) >= 0:
			resolved_bus_name = fallback_effect_bus
		elif AudioServer.get_bus_index(normalized_category) >= 0:
			resolved_bus_name = normalized_category
		else:
			resolved_bus_name = "Master"
	bus = resolved_bus_name
	return resolved_bus_name

## Fades current playback to silence and stops when tween completes.
## @param duration Fade duration in seconds.
func fade_out(duration: float = 1.0) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(set_volume_linear_normalized, get_volume_linear_normalized(), 0.0, duration)
	tween.tween_callback(stop)

## Starts playback from silence and fades to target volume.
## @param duration Fade duration in seconds.
## @param target_volume Target normalized linear volume in range [0.0, 1.0].
func fade_in(duration: float = 1.0, target_volume: float = 1.0) -> void:
	volume_db = linear_to_db(0.0) # Start silent
	play()
	var tween: Tween = create_tween()
	tween.tween_method(set_volume_linear_normalized, 0.0, target_volume, duration)

## Internal pool metadata setter used by XedatsSingleton.
## @param is_from_pool Whether this player is currently managed by pool lifecycle.
## @param pool_id Pool tracking identifier.
func _set_pool_info(is_from_pool: bool, pool_id: int) -> void:
	_is_from_pool = is_from_pool
	_pool_id = pool_id

## Resets this player state before returning it to pool.
func _reset_for_pool() -> void:
	stop()
	volume_db = 0.0
	pitch_scale = 1.0
	_audio_container = null
	_velocity = Vector3.ZERO
	_is_occluded = false

# ============ SPATIAL AUDIO METHODS ============

## Initializes spatial-audio-related runtime state and integration hooks.
func _setup_spatial_audio() -> void:
	# Spatial audio setup
	# Note: Effects (lowpass filtering for occlusion, etc.) should be applied
	# via the audio bus system, not directly on the player.
	# See XedatsSingleton.add_bus_effect() for details.
	pass

## Updates doppler pitch based on relative source/listener motion.
## @param delta Time elapsed since previous frame in seconds.
func _update_doppler(delta: float) -> void:
	# Calculate velocity from position change
	var current_position: Vector3 = global_position
	_velocity = (current_position - _previous_position) / delta
	_previous_position = current_position
	
	# Apply doppler shift to pitch
	var speed: float = _velocity.length() * doppler_speed_multiplier
	if speed > 0.01: # Only apply if moving
		# Estimate observer position (camera or player listener)
		var xedats: XedatsSingleton = XedatsSingleton.instance()
		var listener: XedatsListener3D = xedats.get_current_listener() if xedats else null
		if listener:
			var to_listener: Vector3 = (listener.global_position - current_position).normalized()
			var velocity_towards_listener: float = _velocity.dot(to_listener)
			
			# Simple doppler formula: pitch_multiplier = 1 + (velocity / sound_speed)
			# Using 343 m/s as speed of sound, scaled for game speed
			var sound_speed: float = 343.0 / 10.0 # Scaled for typical game units
			var doppler_multiplier: float = 1.0 + (velocity_towards_listener / sound_speed)
			doppler_multiplier = clamp(doppler_multiplier, 0.5, 2.0)
			
			pitch_scale = doppler_multiplier

## Performs line-of-sight occlusion test against physics world.
func _check_occlusion() -> void:
	# Raycast from player to audio source to check for walls/obstacles
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	var listener: XedatsListener3D = xedats.get_current_listener() if xedats else null
	if not listener:
		_is_occluded = false
		return
	
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		listener.global_position,
		global_position
	)
	query.exclude = [ self ]
	
	var result: Dictionary = space_state.intersect_ray(query)
	
	var was_occluded: bool = _is_occluded
	_is_occluded = not result.is_empty() # If ray hit something, we're occluded
	
	# Emit signal only if occlusion state changed
	if was_occluded != _is_occluded:
		occlusion_changed.emit(_is_occluded)
		_update_occlusion_filtering()

## Hook for applying occlusion filtering via bus effects.
func _update_occlusion_filtering() -> void:
	# Audio effects should be applied via the audio bus system
	# See XedatsSingleton.add_bus_effect() for effect chain management
	pass

## Hook for applying distance filtering via bus effects.
func _update_distance_filtering() -> void:
	# Audio effects should be applied via the audio bus system
	# See XedatsSingleton.add_bus_effect() for effect chain management
	pass

## Returns current estimated velocity.
## @return Vector3 Current velocity estimate.
func get_velocity() -> Vector3:
	return _velocity

## Sets velocity manually for externally-driven motion systems.
## @param velocity Velocity to assign.
func set_velocity(velocity: Vector3) -> void:
	_velocity = velocity

## Returns current occlusion state.
## @return bool True if source is currently occluded.
func is_occluded() -> bool:
	return _is_occluded

## Sets occlusion state manually and emits change signal when needed.
## @param occluded New occlusion state.
func set_occluded(occluded: bool) -> void:
	var was_occluded: bool = _is_occluded
	_is_occluded = occluded
	if was_occluded != _is_occluded:
		occlusion_changed.emit(_is_occluded)
		_update_occlusion_filtering()
