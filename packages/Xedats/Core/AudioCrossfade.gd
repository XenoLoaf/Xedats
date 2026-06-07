class_name AudioCrossfade
extends Node

## AudioCrossfade manages smooth transitions between different audio sources for Xedats.
##
## Features:
## - Smooth fade in/out transitions between audio players
## - Customizable fade curves for different feel/mood transitions
## - Support for single player fades and dual-player crossfades
## - Signals for fade lifecycle events (started, completed, cancelled)
##
## [b]COMMON USAGE PATTERNS:[/b]
##
## [b]1. Fade out current music and fade in new music:[/b]
## [codeblock]
## var audio = XedatsSingleton.instance()
## var crossfade = audio.get_crossfade_system()
## 
## var current_music = audio.create_player_3d()  # Current playing music
## var new_music = audio.create_player_3d()      # New music to play
## new_music.stream = next_track
## 
## crossfade.start_crossfade(current_music, new_music, 2.0)  # 2 second fade
## [/codeblock]
##
## [b]2. Fade out single player:[/b]
## [codeblock]
## var crossfade = audio.get_crossfade_system()
## var player = audio.create_player_3d()
## player.stream = music_stream
## player.play()
## 
## # Later, fade out
## crossfade.fade_out_player(player, 1.5)  # Fade out over 1.5 seconds
## [/codeblock]
##
## [b]3. Fade in single player:[/b]
## [codeblock]
## var crossfade = audio.get_crossfade_system()
## var player = audio.create_player_3d()
## player.stream = music_stream
## 
## # Fade in from silent to full volume over 2 seconds
## crossfade.fade_in_player(player, 2.0, 1.0)
## [/codeblock]
##
## [b]4. Connect to crossfade events:[/b]
## [codeblock]
## var crossfade = audio.get_crossfade_system()
## crossfade.crossfade_started.connect(func(info): print("Fading started"))
## crossfade.crossfade_completed.connect(func(info): print("Fade complete"))
## 
## crossfade.start_crossfade(from_player, to_player, 2.0)
## [/codeblock]
##
## See Xedats.md for comprehensive usage documentation and examples.

#region Static Helper

## Gets the current AudioCrossfade instance from XedatsSingleton.
## @return AudioCrossfade Current crossfade subsystem, or null.
static func instance() -> AudioCrossfade:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats:
		return xedats.get_crossfade_system()
	return null

#endregion

class CrossfadeInfo:
	## @var source_player
	## Player being faded out (XedatsPlayer3D or XedatsPlayer2D).
	var source_player: Node
	## @var target_player
	## Player being faded in (XedatsPlayer3D or XedatsPlayer2D).
	var target_player: Node
	## @var duration
	## Total fade duration in seconds.
	var duration: float
	## @var curve
	## Curve used to map progress to blend value.
	var curve: Curve
	## @var is_active
	## Whether this crossfade is still active.
	var is_active: bool = false
	## @var progress
	## Normalized progress [0.0, 1.0].
	var progress: float = 0.0
	## @var start_time
	## Start timestamp in milliseconds.
	var start_time: float = 0.0

## @var _active_crossfades
## Collection of currently active crossfade operations.
var _active_crossfades: Array[CrossfadeInfo] = []

## @signal crossfade_started(crossfade_info)
## Emitted when a new crossfade is created and starts running.
signal crossfade_started(crossfade_info: CrossfadeInfo)

## @signal crossfade_completed(crossfade_info)
## Emitted when a crossfade reaches full completion.
signal crossfade_completed(crossfade_info: CrossfadeInfo)

## @signal crossfade_cancelled(crossfade_info)
## Emitted when a crossfade is cancelled before completion.
signal crossfade_cancelled(crossfade_info: CrossfadeInfo)

## @var default_curve
## Default linear curve used when caller does not provide a custom curve.
var default_curve: Curve

## Initializes default fade curve and enables processing.
func _ready() -> void:
	# Create a linear fade curve as default
	default_curve = Curve.new()
	default_curve.add_point(Vector2(0, 0))
	default_curve.add_point(Vector2(1, 1))
	
	set_process(true)

## Updates active crossfades each frame and emits completion signals.
## @param delta Delta time in seconds.
func _process(delta: float) -> void:
	# Update all active crossfades
	var completed: Array[int] = []
	for i in range(_active_crossfades.size() - 1, -1, -1):
		var crossfade: CrossfadeInfo = _active_crossfades[i]
		if not _update_crossfade(crossfade, delta):
			completed.append(i)
	
	# Remove completed crossfades
	for i in completed:
		var crossfade: CrossfadeInfo = _active_crossfades[i]
		_active_crossfades.remove_at(i)
		crossfade_completed.emit(crossfade)

## Advances a single crossfade and applies source/target volumes.
## @param crossfade Crossfade state object.
## @param delta Delta time in seconds.
## @return bool True while still active; false when completed.
func _update_crossfade(crossfade: CrossfadeInfo, delta: float) -> bool:
	if not crossfade.is_active:
		return false
	
	crossfade.progress += delta / crossfade.duration
	
	if crossfade.progress >= 1.0:
		# Crossfade complete — stop source, normalize target
		if crossfade.source_player:
			crossfade.source_player.stop()
		if crossfade.target_player:
			crossfade.target_player.set_volume_linear_normalized(1.0)
		
		# Free orphaned silent players created by fade_out/fade_in
		# Silent players are never added to the scene tree, so
		# is_inside_tree() reliably distinguishes them from real pooled players.
		if crossfade.source_player and not crossfade.source_player.is_inside_tree():
			crossfade.source_player.queue_free()
		if crossfade.target_player and not crossfade.target_player.is_inside_tree():
			crossfade.target_player.queue_free()
		
		return false # Remove from active list
	
	# Apply fade curve
	var curve_value: float = crossfade.curve.sample(crossfade.progress)
	
	# Fade out source
	if crossfade.source_player:
		var start_vol: float = db_to_linear(crossfade.source_player.volume_db)
		var source_volume: float = start_vol * (1.0 - curve_value)
		crossfade.source_player.set_volume_linear_normalized(source_volume)
	
	# Fade in target
	if crossfade.target_player:
		var target_volume: float = curve_value
		crossfade.target_player.set_volume_linear_normalized(target_volume)
	
	return true # Keep in active list

## Starts a crossfade between source and target players (2D and 3D compatible).
## @param source Player to fade out.
## @param target Player to fade in.
## @param duration Fade duration in seconds.
## @param curve Optional custom blending curve.
## @return CrossfadeInfo Created crossfade object, or null on failure.
func start_crossfade(source: Node, target: Node,
					 duration: float = 1.0, curve: Curve = null) -> CrossfadeInfo:
	if not source or not target:
		push_error("Xedats: Cannot crossfade with null players")
		return null

	if not source.has_method("set_volume_linear_normalized") or not target.has_method("set_volume_linear_normalized"):
		push_error("Xedats: Crossfade players must support set_volume_linear_normalized()")
		return null
	
	if duration <= 0:
		push_error("Xedats: Crossfade duration must be positive")
		return null
	
	# Start target playing at zero volume
	target.set_volume_linear_normalized(0.0)
	if not target.playing:
		target.play()
	
	# Create crossfade info
	var crossfade: CrossfadeInfo = CrossfadeInfo.new()
	crossfade.source_player = source
	crossfade.target_player = target
	crossfade.duration = duration
	crossfade.curve = curve if curve else default_curve
	crossfade.is_active = true
	crossfade.start_time = Time.get_ticks_msec()
	
	_active_crossfades.append(crossfade)
	crossfade_started.emit(crossfade)
	
	return crossfade

## Fades out one player by crossfading into a silent temporary player (2D and 3D compatible).
## @param player Player to fade out.
## @param duration Fade duration in seconds.
## @param curve Optional custom blending curve.
## @return CrossfadeInfo Created crossfade object, or null on failure.
func fade_out_player(player: Node, duration: float = 1.0, curve: Curve = null) -> CrossfadeInfo:
	if not player:
		push_error("Xedats: Cannot fade out null player")
		return null

	if not player.has_method("set_volume_linear_normalized"):
		push_error("Xedats: Fade-out player must support set_volume_linear_normalized()")
		return null
	
	# Create a dummy silent player
	var silent_player: Node = XedatsPlayer3D.new()
	silent_player.volume_db = linear_to_db(0.0)
	
	# Start the crossfade
	var crossfade: CrossfadeInfo = start_crossfade(player, silent_player, duration, curve)
	
	return crossfade

## Fades in one player by crossfading from a silent temporary player (2D and 3D compatible).
## @param player Player to fade in.
## @param duration Fade duration in seconds.
## @param target_volume Target linear volume at end of fade.
## @param curve Optional custom blending curve.
## @return CrossfadeInfo Created crossfade object, or null on failure.
func fade_in_player(player: Node, duration: float = 1.0,
					target_volume: float = 1.0, curve: Curve = null) -> CrossfadeInfo:
	if not player:
		push_error("Xedats: Cannot fade in null player")
		return null

	if not player.has_method("set_volume_linear_normalized"):
		push_error("Xedats: Fade-in player must support set_volume_linear_normalized()")
		return null
	
	# Create a dummy silent player as source
	var silent_player: Node = XedatsPlayer3D.new()
	silent_player.volume_db = linear_to_db(0.0)
	
	# Start with player at target volume
	player.set_volume_linear_normalized(target_volume)
	if not player.playing:
		player.play()
	
	# Fade in
	var crossfade: CrossfadeInfo = start_crossfade(silent_player, player, duration, curve)
	
	return crossfade

## Cancels one active crossfade if present.
## @param crossfade Crossfade to cancel.
## @return bool True if cancelled.
func cancel_crossfade(crossfade: CrossfadeInfo) -> bool:
	var index: int = _active_crossfades.find(crossfade)
	if index >= 0:
		crossfade.is_active = false
		_active_crossfades.remove_at(index)
		crossfade_cancelled.emit(crossfade)
		return true
	return false

## Cancels and clears all active crossfades.
func cancel_all_crossfades() -> void:
	for crossfade in _active_crossfades:
		crossfade.is_active = false
	_active_crossfades.clear()

## Gets number of currently active crossfades.
## @return int Active crossfade count.
func get_active_crossfade_count() -> int:
	return _active_crossfades.size()

## Creates a curve suitable for eased fade behavior.
## @param _ease_type Requested ease type placeholder.
## @return Curve Generated curve instance.
static func create_ease_curve(_ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> Curve:
	var curve: Curve = Curve.new()
	
	# For now, create a linear curve. Full ease support would require custom implementation
	# of easing functions (e.g., ease_in_out_quad, ease_out_cubic, etc.)
	for i in range(0, 11):
		var t: float = float(i) / 10.0
		curve.add_point(Vector2(t, t)) # Linear interpolation
	
	return curve

## Creates a curve from explicit control points.
## @param points Control points in normalized time/value space.
## @return Curve Generated curve instance.
static func create_custom_curve(points: Array[Vector2]) -> Curve:
	var curve: Curve = Curve.new()
	for point in points:
		curve.add_point(point)
	return curve
