class_name XedatsGLTFConfig
extends RefCounted

## Single configuration point for file-system path resolution across the
## Xedats glTF extension module.
##
## The [member XEDATS_ROOT] is auto-detected at runtime by searching for the
## Xedats plugin.cfg in the standard addon location. For projects that install
## Xedats in a non-standard location, set [member XEDATS_ROOT] manually before
## any other Xedats API calls.
##
## [b]Note on [code]preload()[/code]:[/b] GDScript requires compile-time string
## literals for [code]preload()[/code].  Those calls use Godot 4 UIDs
## ([code]uid://xxxx[/code]) which resolve across any project layout.  This
## variable is therefore only consumed by [method ResourceLoader.load] paths and
## [code].tres[/code] resource path fallbacks.

## Root folder of the Xedats module tree as a [code]res://[/code] path.
## Auto-detected on first access. Set manually to override detection.
## Trailing slash must be omitted.
static var XEDATS_ROOT: String:
	get:
		if _cached_root.is_empty():
			_cached_root = _detect_xedats_root()
		return _cached_root
	set(value):
		_cached_root = value

static var _cached_root: String = ""


static func _detect_xedats_root() -> String:
	if ResourceLoader.exists("res://addons/xedats/plugin.cfg"):
		return "res://addons/xedats"
	return "res://ProjectHelix/Xedats"


static func modules_root() -> String:
	return XEDATS_ROOT + "/Modules"


static func resources_root() -> String:
	return XEDATS_ROOT + "/Resources"


static func tests_root() -> String:
	return XEDATS_ROOT + "/Tests"


static func fixtures_root() -> String:
	return tests_root() + "/GLTF/Fixtures"


static func precomputed_propagation_root() -> String:
	return resources_root() + "/GLTF/PrecomputedPropagation"


static func project_root() -> String:
	return XEDATS_ROOT.get_base_dir()
