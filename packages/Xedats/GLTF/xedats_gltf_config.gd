class_name XedatsGLTFConfig
extends RefCounted

## Single configuration point for file-system path resolution across the
## Xedats glTF extension module.
##
## [b]Porting to a new project:[/b] change [member XEDATS_ROOT] to the
## [code]res://[/code] path of the Xedats root folder in the target project.
## All other path constants and [method ResourceLoader.load] calls in this module
## are derived from that value at runtime, so no other edits are required.
##
## [b]Note on [code]preload()[/code]:[/b] GDScript requires compile-time string
## literals for [code]preload()[/code].  Those calls use Godot 4 UIDs
## ([code]uid://xxxx[/code]) which resolve across any project layout.  This
## variable is therefore only consumed by [method ResourceLoader.load] paths and
## [code].tres[/code] resource path fallbacks.

## Root folder of the Xedats module tree.  Must be set to match the [code]res://[/code]
## path used in the host project.  Trailing slash must be omitted.
static var XEDATS_ROOT: String = "res://ProjectHelix/Xedats"


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
