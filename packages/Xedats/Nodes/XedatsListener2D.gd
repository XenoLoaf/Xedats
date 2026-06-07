class_name XedatsListener2D
extends AudioListener2D

## XedatsListener2D is an enhanced audio listener for the Xedats audio system.
##
## The listener represents the player's perspective in 2D audio space. Only one
## listener can be active at a time. Audio is mixed relative to the active listener's
## position on the current viewport.
##
## Features:
## - Automatic registration with XedatsSingleton
## - Reverb zone support for 2D spatial effects (Area2D)
## - Custom attenuation profiles
## - Automatic cleanup when removed from scene
##
## See Xedats.md for comprehensive usage documentation and examples.

@export var listener_name: String = "MainListener2D"

@export var reverb_zone: Area2D

@export var custom_attenuation: float = 1.0

var _is_from_pool: bool = false

var _pool_id: int = -1

func _ready() -> void:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats:
		xedats._register_listener_2d(self)

func _exit_tree() -> void:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats:
		xedats._unregister_listener_2d(self)

func set_reverb_zone(zone: Area2D) -> void:
	reverb_zone = zone
	_update_reverb_settings()

func _update_reverb_settings() -> void:
	pass

func _set_pool_info(is_from_pool: bool, pool_id: int) -> void:
	_is_from_pool = is_from_pool
	_pool_id = pool_id

func _reset_for_pool() -> void:
	listener_name = "PooledListener"
	reverb_zone = null
	custom_attenuation = 1.0
