class_name XedatsModuleLoader
extends RefCounted

## Central registry for optional Xedats subsystems.
## Use this to check whether a module is available before accessing it.
## This prevents hard compile-time dependencies on deletable subdirectories.
##
## Usage:
## [codeblock]
## if XedatsModuleLoader.is_gltf_available():
##     var binding = XedatsGLTFAudioEmitterBinding.new()
## if XedatsModuleLoader.is_2d_available():
##     var player = xedats.create_player_2d(pos)
## [/codeblock]
##
## @module_gltf
## @module_2d
## @module_midi


static var _gltf_available: int = -1
static var _2d_available: int = -1
static var _midi_available: int = -1


static func is_gltf_available() -> bool:
	if _gltf_available == -1:
		_gltf_available = 1 if ClassDB.class_exists(&"GLTFDocumentExtensionXedatsAudio") else 0
	return _gltf_available == 1


static func is_2d_available() -> bool:
	if _2d_available == -1:
		_2d_available = 1 if ClassDB.class_exists(&"XedatsPlayer2D") else 0
	return _2d_available == 1


static func is_midi_available() -> bool:
	if _midi_available == -1:
		_midi_available = 1 if ClassDB.class_exists(&"MidiSequence") else 0
	return _midi_available == 1
