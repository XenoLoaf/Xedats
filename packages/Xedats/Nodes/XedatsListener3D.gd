class_name XedatsListener3D
extends AudioListener3D

## XedatsListener3D is an enhanced audio listener for the Xedats audio system.
##
## The listener represents the player's perspective in 3D audio space. Only one listener
## can be active at a time. Audio is mixed relative to the active listener's position.
##
## Features:
## - Automatic registration with XedatsSingleton
## - Reverb zone support for spatial effects
## - Custom attenuation profiles
## - Automatic cleanup when removed from scene
##
## [b]COMMON USAGE PATTERNS:[/b]
##
## [b]1. Create listener on player character:[/b]
## [codeblock]
## extends CharacterBody3D
## 
## func _ready() -> void:
##     var audio = XedatsSingleton.instance()
##     if audio:
##         var listener = audio.create_listener_3d(global_position, self)
##         audio.set_current_listener(listener)
##
##     # Keep listener synced with player position
##     audio.get_current_listener().global_position = global_position
## [/codeblock]
##
## [b]2. Using reverb zones for spatial effects:[/b]
## [codeblock]
## var audio = XedatsSingleton.instance()
## var listener = audio.get_current_listener()
## var reverb_zone = get_reverb_zone_at_position(listener.global_position)
## if reverb_zone:
##     listener.set_reverb_zone(reverb_zone)
## [/codeblock]
##
## [b]3. Custom attenuation for audio proximity:[/b]
## [codeblock]
## var listener = audio.get_current_listener()
## listener.custom_attenuation = 1.5  # Increase attenuation (sounds quieter at distance)
## [/codeblock]
##
## See Xedats.md for comprehensive usage documentation and examples.

## @export var listener_name
## Friendly name used for debugging and listener identification.
@export var listener_name: String = "MainListener"

## @export var reverb_zone
## Optional Area3D used by external systems to determine local reverb behavior.
@export var reverb_zone: Area3D

## @export var custom_attenuation
## Custom attenuation multiplier available to external distance/volume systems.
@export var custom_attenuation: float = 1.0

## @var _is_from_pool
## Internal flag indicating whether this listener is pool-managed.
var _is_from_pool: bool = false

## @var _pool_id
## Internal pool tracking identifier for this listener.
var _pool_id: int = -1

## Registers this listener with XedatsSingleton when entering scene tree.
func _ready() -> void:
	# Register with XedatsSingleton if available
	var xedats = XedatsSingleton.instance()
	if xedats:
		xedats._register_listener(self )

## Unregisters this listener from XedatsSingleton when leaving scene tree.
func _exit_tree() -> void:
	# Unregister from XedatsSingleton
	var xedats = XedatsSingleton.instance()
	if xedats:
		xedats._unregister_listener(self )

## Assigns a reverb zone and updates reverb integration state.
## @param zone Reverb area assigned to this listener.
func set_reverb_zone(zone: Area3D) -> void:
	reverb_zone = zone
	_update_reverb_settings()

## Hook for applying reverb settings via bus effects or middleware.
func _update_reverb_settings() -> void:
	# This would integrate with audio bus effects for reverb
	# For now, just store the reference
	pass

## Internal pool metadata setter used by XedatsSingleton.
## @param is_from_pool Whether this listener is managed by pool lifecycle.
## @param pool_id Pool tracking identifier.
func _set_pool_info(is_from_pool: bool, pool_id: int) -> void:
	_is_from_pool = is_from_pool
	_pool_id = pool_id

## Resets listener state before returning to pool.
func _reset_for_pool() -> void:
	listener_name = "PooledListener"
	reverb_zone = null
	custom_attenuation = 1.0
