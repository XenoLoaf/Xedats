class_name XedatsListener2D
extends AudioListener2D

## XedatsListener2D is a 2D audio listener for the Xedats audio system.
##
## Features:
## - 2D audio perspective management
## - Reverb zone integration
## - Pool lifecycle support
##
## See Xedats.md for comprehensive usage documentation and examples.

@export var listener_name: String = "MainListener2D"

@export var reverb_zone: Area2D

@export var custom_attenuation: float = 1.0

var _is_from_pool: bool = false

var _pool_id: int = -1

var _reverb_effect_index: int = -1

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
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if not xedats:
		return
	
	if _reverb_effect_index >= 0:
		xedats.remove_bus_effect("Master", _reverb_effect_index)
		_reverb_effect_index = -1
	
	if reverb_zone:
		var reverb: AudioEffectReverb = AudioEffectReverb.new()
		reverb.room_size = reverb_zone.get_meta(&"reverb_room_size", 0.5)
		reverb.damping = reverb_zone.get_meta(&"reverb_damping", 0.5)
		reverb.wet = reverb_zone.get_meta(&"reverb_wet", 1.0)
		_reverb_effect_index = xedats.add_bus_effect("Master", reverb)

func _set_pool_info(is_from_pool: bool, pool_id: int) -> void:
	_is_from_pool = is_from_pool
	_pool_id = pool_id

func _reset_for_pool() -> void:
	listener_name = "PooledListener"
	reverb_zone = null
	custom_attenuation = 1.0
	_reverb_effect_index = -1
