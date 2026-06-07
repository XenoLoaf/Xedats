class_name XedatsPlayer2D
extends AudioStreamPlayer2D

## XedatsPlayer2D is an enhanced 2D audio player for the Xedats audio system.
##
## Features:
## - Audio container playback with automatic randomization
## - Volume and pitch fading with smooth transitions
## - Audio categorization for volume control groups
## - Automatic returning to object pool after playback
## - 2D spatial audio via built-in AudioStreamPlayer2D properties
##
## See Xedats.md for comprehensive usage documentation and examples.

@export var audio_category: String = "SFX"

@export var auto_return_to_pool: bool = true

@export var priority: int = 0

var _is_from_pool: bool = false

var _pool_id: int = -1

var _audio_container: AudioArrayContainer

var _is_occluded: bool = false

signal audio_finished_custom(player: XedatsPlayer2D)

signal occlusion_changed(is_occluded: bool)

func _ready() -> void:
	finished.connect(_on_audio_finished)

func _on_audio_finished() -> void:
	audio_finished_custom.emit(self)

	if auto_return_to_pool and _is_from_pool:
		var xedats: XedatsSingleton = XedatsSingleton.instance()
		if xedats:
			xedats.return_player_2d_to_pool(self)

func play_from_container(container: AudioArrayContainer, index: int = 0, override_stream: bool = true) -> void:
	if not container or index < 0 or index >= container.StreamContainer.size():
		push_error("Invalid audio container or index")
		return

	_audio_container = container
	if override_stream:
		stream = container.StreamContainer[index]
	play()

func play_random_from_container(container: AudioArrayContainer, override_stream: bool = true) -> void:
	if not container or container.StreamContainer.is_empty():
		push_error("Invalid or empty audio container")
		return

	var random_index: int = randi_range(0, container.StreamContainer.size() - 1)
	play_from_container(container, random_index, override_stream)

func set_volume_linear_normalized(volume: float) -> void:
	volume_db = linear_to_db(clamp(volume, 0.0, 1.0))

func get_volume_linear_normalized() -> float:
	return db_to_linear(volume_db)

func swap_audio_bus(bus_name: String, fallback_bus: String = "Master") -> String:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats != null:
		return xedats.swap_player_bus(self, bus_name, fallback_bus)

	var resolved_bus_name: String = bus_name.strip_edges()
	if resolved_bus_name.is_empty() or AudioServer.get_bus_index(resolved_bus_name) < 0:
		resolved_bus_name = fallback_bus if AudioServer.get_bus_index(fallback_bus) >= 0 else "Master"
	bus = resolved_bus_name
	return resolved_bus_name

func route_to_audio_category(category: String, use_effect_bus: bool = false, requested_bus: String = "") -> String:
	var normalized_category: String = category.strip_edges()
	if normalized_category.is_empty():
		normalized_category = audio_category
	if normalized_category.is_empty():
		normalized_category = "SFX"

	audio_category = normalized_category
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats != null:
		return xedats.route_player_to_category(self, normalized_category, use_effect_bus, requested_bus)

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

func fade_out(duration: float = 1.0) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(set_volume_linear_normalized, get_volume_linear_normalized(), 0.0, duration)
	tween.tween_callback(stop)

func fade_in(duration: float = 1.0, target_volume: float = 1.0) -> void:
	volume_db = linear_to_db(0.0)
	play()
	var tween: Tween = create_tween()
	tween.tween_method(set_volume_linear_normalized, 0.0, target_volume, duration)

func _set_pool_info(is_from_pool: bool, pool_id: int) -> void:
	_is_from_pool = is_from_pool
	_pool_id = pool_id

func _reset_for_pool() -> void:
	stop()
	volume_db = 0.0
	pitch_scale = 1.0
	_audio_container = null
	_is_occluded = false

func is_occluded() -> bool:
	return _is_occluded

func set_occluded(occluded: bool) -> void:
	var was_occluded: bool = _is_occluded
	_is_occluded = occluded
	if was_occluded != _is_occluded:
		occlusion_changed.emit(_is_occluded)
