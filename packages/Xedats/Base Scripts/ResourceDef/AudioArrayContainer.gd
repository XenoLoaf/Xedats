class_name AudioArrayContainer
extends Resource

## AudioArrayContainer is a resource that holds multiple audio variations.
##
## Use this resource to organize related audio clips (e.g., different footstep sounds,
## door opening variations, impact sounds). The container handles random variation of
## volume and pitch to prevent repetitive-sounding audio.
##
## [b]COMMON USAGE PATTERNS:[/b]
##
## [b]1. Create an AudioArrayContainer resource:[/b]
## - In FileSystem (right-click) → New Resource → AudioArrayContainer
## - Set container_name to something descriptive
## - Drag audio streams into StreamContainer array
## - Set volume_variation and pitch_variation ranges
## - Save as .tres file
##
## [b]2. Use containers for player footsteps:[/b]
## [codeblock]
## # In a scene that plays footsteps:
## @export var grass_footsteps: AudioArrayContainer
## @export var concrete_footsteps: AudioArrayContainer
## 
## func play_footstep(surface: String) -> void:
##     var container = grass_footsteps if surface == "grass" else concrete_footsteps
##     var player = audio.create_player_3d(global_position)
##     player.play_random_from_container(container)
## [/codeblock]
##
## [b]3. Use containers for world object sounds:[/b]
## [codeblock]
## # Door opening sounds container
## # - Contains 3-4 door creak variations
## # - Volume variation: 0.8 to 1.2
## # - Pitch variation: 0.95 to 1.05
##
## var door_open_container = preload("res://audio/doors/open.tres")
## var player = audio.create_player_3d(door_pos)
## player.play_random_from_container(door_open_container)
## [/codeblock]
##
## [b]4. Configure playback modes:[/b]
## - SEQUENTIAL: Always plays first sound (rarely needed)
## - RANDOM: Fully random selection (most common)
## - RANDOM_NO_REPEAT: Avoids repeating last selection (great for audio clarity)
##
## [b]5. Access variation values in code:[/b]
## [codeblock]
## var container = preload("res://path/to/container.tres")
## var random_volume = container.get_random_volume()
## var random_pitch = container.get_random_pitch()
## print("Volume variation: %.2f" % random_volume)
## print("Pitch variation: %.2f" % random_pitch)
## [/codeblock]
##
## [b]BEST PRACTICES:[/b]
## - Create separate containers for different sound types (footsteps, doors, impacts)
## - Use RANDOM_NO_REPEAT for frequently played sounds to avoid repetition
## - Keep volume_variation between 0.7-1.3 for subtle randomization
## - Keep pitch_variation between 0.9-1.1 to avoid unnatural pitch shifts
## - Organize containers in folders matching their usage (Footsteps/, Interactables/, etc.)
##
## See Xedats.md for comprehensive usage documentation and examples.

## @export var container_name
## Human-readable container name for editor and debugging.
@export var container_name: String = "AudioContainer"

## @export var StreamContainer
## Array of AudioStream variations used for playback selection.
@export var StreamContainer: Array[AudioStream]

## @export var playback_mode
## Selection behavior used when choosing stream from StreamContainer.
@export var playback_mode: PlaybackMode = PlaybackMode.SEQUENTIAL

## @export var loop
## Optional loop flag for higher-level systems.
@export var loop: bool = false

## @export var volume_variation
## Min/max multipliers used when generating randomized volume.
@export var volume_variation: Vector2 = Vector2(0.8, 1.2)

## @export var pitch_variation
## Min/max multipliers used when generating randomized pitch.
@export var pitch_variation: Vector2 = Vector2(0.9, 1.1)

enum PlaybackMode {
	SEQUENTIAL, # Play in order
	RANDOM, # Play random
	RANDOM_NO_REPEAT # Play random without immediate repeats
}

## @var _last_random_index
## Last random index used by RANDOM_NO_REPEAT mode.
var _last_random_index: int = -1

## Selects an audio stream according to current playback mode.
## @return AudioStream Selected stream or null when container is empty.
func get_stream() -> AudioStream:
	if StreamContainer.is_empty():
		return null
	
	match playback_mode:
		PlaybackMode.SEQUENTIAL:
			return StreamContainer[0] # For now, just return first
		PlaybackMode.RANDOM:
			return StreamContainer[randi() % StreamContainer.size()]
		PlaybackMode.RANDOM_NO_REPEAT:
			return _get_random_no_repeat()
	
	return null

## Selects random stream while trying to avoid immediate repetition.
## @return AudioStream Selected stream or null when container is empty.
func _get_random_no_repeat() -> AudioStream:
	if StreamContainer.size() <= 1:
		return StreamContainer[0] if not StreamContainer.is_empty() else null
	
	var new_index: int
	var attempts = 0
	while attempts < 10: # Prevent infinite loop
		new_index = randi() % StreamContainer.size()
		if new_index != _last_random_index:
			_last_random_index = new_index
			return StreamContainer[new_index]
		attempts += 1
	
	# Fallback if we can't find a non-repeating index
	return StreamContainer[randi() % StreamContainer.size()]

## Generates randomized volume multiplier within configured range.
## @return float Random volume multiplier.
func get_random_volume() -> float:
	return randf_range(volume_variation.x, volume_variation.y)

## Generates randomized pitch multiplier within configured range.
## @return float Random pitch multiplier.
func get_random_pitch() -> float:
	return randf_range(pitch_variation.x, pitch_variation.y)

## Provides custom property list and emits warning when container has no streams.
## @return Array[Dictionary] Property list entries.
func _get_property_list() -> Array[Dictionary]:
	var properties = []
	
	# Add validation for stream container
	if StreamContainer.is_empty():
		push_warning("AudioArrayContainer '%s' has no audio streams" % container_name)
	
	return properties
