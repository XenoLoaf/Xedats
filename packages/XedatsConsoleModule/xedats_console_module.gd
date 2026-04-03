## Xedats-specific command bridge for an XebugConsole host.
##
## This module owns the Xedats bridge commands and runtime audio inspection commands
## that used to live directly in the console core. It registers commands against the
## host console instance and unregisters them on teardown.
class_name XedatsConsoleModule
extends Node

const PROVIDER_XEDATS_DEBUG: String = "XedatsDebugTool"
const PROVIDER_XEDATS_AUDIO: String = "XedatsAudio"

const COMMAND_XD_PANEL: String = "xd.panel"
const COMMAND_XD_OVERLAY: String = "xd.overlay"
const COMMAND_XD_TRACE: String = "xd.trace"
const COMMAND_XD_STATUS: String = "xd.status"
const COMMAND_XD_REFRESH: String = "xd.refresh"
const COMMAND_XD_FEED: String = "xd.feed"
const COMMAND_AUDIO: String = "audio"

var _console: XebugConsole = null


func _ready() -> void:
	_console = XebugConsole.instance() as XebugConsole
	if _console == null:
		push_warning("XedatsConsoleModule: host command console is unavailable.")
		return
	_register_xedats_debug_bridge_commands()
	_register_xedats_audio_commands()


func _exit_tree() -> void:
	if _console == null:
		return
	for command_name: String in get_managed_commands():
		_console.unregister_command(command_name)


func get_managed_commands() -> Array[String]:
	return [
		COMMAND_XD_PANEL,
		COMMAND_XD_OVERLAY,
		COMMAND_XD_TRACE,
		COMMAND_XD_STATUS,
		COMMAND_XD_REFRESH,
		COMMAND_XD_FEED,
		COMMAND_AUDIO
	]


func _register_xedats_debug_bridge_commands() -> void:
	_console.register_command(COMMAND_XD_PANEL, Callable(self , "_cmd_xedats_panel"), "Xedats debug panel control (on/off/toggle).", "xd.panel <on|off|toggle>", PROVIDER_XEDATS_DEBUG)
	_console.register_command(COMMAND_XD_OVERLAY, Callable(self , "_cmd_xedats_overlay"), "Xedats debug world overlay control (on/off/toggle).", "xd.overlay <on|off|toggle>", PROVIDER_XEDATS_DEBUG)
	_console.register_command(COMMAND_XD_TRACE, Callable(self , "_cmd_xedats_trace"), "Xedats debug trace control (on/off/toggle).", "xd.trace <on|off|toggle>", PROVIDER_XEDATS_DEBUG)
	_console.register_command(COMMAND_XD_STATUS, Callable(self , "_cmd_xedats_status"), "Returns current XedatsDebugTool state.", "xd.status", PROVIDER_XEDATS_DEBUG)
	_console.register_command(COMMAND_XD_REFRESH, Callable(self , "_cmd_xedats_refresh"), "Refreshes XedatsDebugTool snapshot.", "xd.refresh", PROVIDER_XEDATS_DEBUG)
	_console.register_command(COMMAND_XD_FEED, Callable(self , "_cmd_xedats_feed"), "Forwards feed commands to XedatsDebugTool.", "xd.feed <subcommand...>", PROVIDER_XEDATS_DEBUG)


func _register_xedats_audio_commands() -> void:
	_console.register_command(
		COMMAND_AUDIO,
		Callable(self , "_cmd_audio"),
		"Xedats audio runtime tools (list_buses, list_events, toggle_category, inspect_player, route_test).",
		"audio <list_buses|list_events|toggle_category|inspect_player|route_test> [args]",
		PROVIDER_XEDATS_AUDIO
	)


func _cmd_xedats_panel(args: PackedStringArray) -> Dictionary:
	return _forward_to_xedats_debug("panel", args)


func _cmd_xedats_overlay(args: PackedStringArray) -> Dictionary:
	return _forward_to_xedats_debug("overlay", args)


func _cmd_xedats_trace(args: PackedStringArray) -> Dictionary:
	return _forward_to_xedats_debug("trace", args)


func _cmd_xedats_status(_args: PackedStringArray) -> Dictionary:
	return _forward_to_xedats_debug("status", PackedStringArray())


func _cmd_xedats_refresh(_args: PackedStringArray) -> Dictionary:
	return _forward_to_xedats_debug("refresh", PackedStringArray())


func _cmd_xedats_feed(args: PackedStringArray) -> Dictionary:
	return _forward_to_xedats_debug("feed", args)


func _cmd_audio(args: PackedStringArray) -> Dictionary:
	if args.is_empty():
		return _error_result("audio", "Usage: audio <list_buses|list_events|toggle_category|inspect_player|route_test> [args]")

	var subcommand: String = String(args[0]).to_lower()
	var sub_args: PackedStringArray = PackedStringArray()
	if args.size() > 1:
		for index: int in range(1, args.size()):
			sub_args.append(args[index])

	match subcommand:
		"list_buses":
			return _cmd_audio_list_buses(sub_args)
		"list_events":
			return _cmd_audio_list_events(sub_args)
		"toggle_category":
			return _cmd_audio_toggle_category(sub_args)
		"inspect_player":
			return _cmd_audio_inspect_player(sub_args)
		"route_test":
			return _cmd_audio_route_test(sub_args)
		_:
			return _error_result("audio", "Unknown subcommand '%s'. Usage: audio <list_buses|list_events|toggle_category|inspect_player|route_test> [args]" % subcommand)


func _cmd_audio_list_buses(_args: PackedStringArray) -> Dictionary:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error_result("audio", "XedatsSingleton is unavailable.")

	var bus_info: Dictionary = xedats.get_bus_info()
	var bus_names: Array[String] = []
	for bus_name_variant: Variant in bus_info.keys():
		bus_names.append(String(bus_name_variant))
	bus_names.sort()

	var routes: Array[Dictionary] = xedats.get_active_player_bus_routes()
	var lines: PackedStringArray = PackedStringArray()
	for bus_name: String in bus_names:
		var entry_variant: Variant = bus_info.get(bus_name, {})
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		lines.append("%s | effects=%d | send=%s" % [
			bus_name,
			int(entry.get("effects", 0)),
			String(entry.get("send", ""))
		])

	return {
		"ok": true,
		"command": "audio",
		"message": "Audio buses: %d | Active players: %d" % [bus_names.size(), routes.size()],
		"subcommand": "list_buses",
		"buses": bus_info,
		"active_routes": routes,
		"lines": lines
	}


func _cmd_audio_list_events(_args: PackedStringArray) -> Dictionary:
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error_result("audio", "XedatsSingleton is unavailable.")

	var event_system: AudioEventSystem = xedats.get_event_system()
	if event_system == null:
		return _error_result("audio", "AudioEventSystem is unavailable.")

	var event_names: Array[String] = event_system.get_all_events()
	event_names.sort()
	var stats: Dictionary = event_system.get_all_stats()

	return {
		"ok": true,
		"command": "audio",
		"message": "Registered events: %d" % event_names.size(),
		"subcommand": "list_events",
		"events": event_names,
		"stats": stats
	}


func _cmd_audio_toggle_category(args: PackedStringArray) -> Dictionary:
	if args.is_empty():
		return _error_result("audio", "Usage: audio toggle_category <category>")

	var category: String = String(args[0]).strip_edges()
	if category.is_empty():
		return _error_result("audio", "Usage: audio toggle_category <category>")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error_result("audio", "XedatsSingleton is unavailable.")

	var state_manager: AudioStateManager = xedats.get_state_manager()
	if state_manager == null:
		return _error_result("audio", "AudioStateManager is unavailable.")

	var is_muted: bool = state_manager.is_category_muted(category)
	if is_muted:
		state_manager.unmute_category(category)
	else:
		state_manager.mute_category(category)

	var muted_now: bool = state_manager.is_category_muted(category)
	return {
		"ok": true,
		"command": "audio",
		"message": "Category '%s' is now %s." % [category, "muted" if muted_now else "unmuted"],
		"subcommand": "toggle_category",
		"category": category,
		"muted": muted_now,
		"volume": xedats.get_category_volume(category)
	}


func _cmd_audio_inspect_player(args: PackedStringArray) -> Dictionary:
	if args.is_empty():
		return _error_result("audio", "Usage: audio inspect_player <player_id>")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error_result("audio", "XedatsSingleton is unavailable.")

	var routes: Array[Dictionary] = xedats.get_active_player_bus_routes()
	var resolved: Dictionary = _resolve_player_from_identifier(String(args[0]), routes)
	if not bool(resolved.get("ok", false)):
		return _error_result("audio", String(resolved.get("message", "Player not found.")))

	var player: XedatsPlayer3D = resolved.get("player") as XedatsPlayer3D
	if player == null:
		return _error_result("audio", "Resolved player is invalid.")

	var route: Dictionary = resolved.get("route", {})
	return {
		"ok": true,
		"command": "audio",
		"message": "Player '%s' inspected." % String(route.get("player_name", player.name)),
		"subcommand": "inspect_player",
		"player": {
			"name": String(player.name),
			"path": String(player.get_path()) if player.is_inside_tree() else "",
			"category": String(player.audio_category),
			"bus": String(player.bus),
			"playing": player.playing,
			"pitch_scale": player.pitch_scale,
			"volume_db": player.volume_db,
			"position": player.global_position,
			"stream": String(player.stream.resource_path) if player.stream != null else ""
		},
		"route": route,
		"index": int(resolved.get("index", -1))
	}


func _cmd_audio_route_test(args: PackedStringArray) -> Dictionary:
	if args.size() < 2:
		return _error_result("audio", "Usage: audio route_test <player_id> <bus>")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error_result("audio", "XedatsSingleton is unavailable.")

	var routes: Array[Dictionary] = xedats.get_active_player_bus_routes()
	var resolved: Dictionary = _resolve_player_from_identifier(String(args[0]), routes)
	if not bool(resolved.get("ok", false)):
		return _error_result("audio", String(resolved.get("message", "Player not found.")))

	var player: XedatsPlayer3D = resolved.get("player") as XedatsPlayer3D
	if player == null:
		return _error_result("audio", "Resolved player is invalid.")

	var requested_bus: String = String(args[1]).strip_edges()
	if requested_bus.is_empty():
		return _error_result("audio", "Usage: audio route_test <player_id> <bus>")

	var resolved_bus: String = xedats.swap_player_bus(player, requested_bus)
	return {
		"ok": true,
		"command": "audio",
		"message": "Routed player '%s' to bus '%s'." % [String(player.name), resolved_bus],
		"subcommand": "route_test",
		"player": String(player.name),
		"requested_bus": requested_bus,
		"resolved_bus": resolved_bus
	}


func _resolve_player_from_identifier(identifier: String, routes: Array[Dictionary]) -> Dictionary:
	var trimmed: String = identifier.strip_edges()
	if trimmed.is_empty():
		return {
			"ok": false,
			"message": "Player identifier cannot be empty."
		}

	if trimmed.is_valid_int():
		var index: int = int(trimmed)
		if index < 0 or index >= routes.size():
			return {
				"ok": false,
				"message": "Player index %d is out of range (0-%d)." % [index, maxi(routes.size() - 1, 0)]
			}
		var indexed_route_variant: Variant = routes[index]
		if indexed_route_variant is Dictionary:
			var indexed_route: Dictionary = indexed_route_variant
			var indexed_player: XedatsPlayer3D = _resolve_player_from_route(indexed_route)
			if indexed_player != null:
				return {
					"ok": true,
					"player": indexed_player,
					"route": indexed_route,
					"index": index
				}

	for route_index: int in range(routes.size()):
		var route_variant: Variant = routes[route_index]
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = route_variant
		if String(route.get("player_path", "")) == trimmed:
			var path_player: XedatsPlayer3D = _resolve_player_from_route(route)
			if path_player != null:
				return {
					"ok": true,
					"player": path_player,
					"route": route,
					"index": route_index
				}

	for route_index: int in range(routes.size()):
		var route_variant: Variant = routes[route_index]
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = route_variant
		if String(route.get("player_name", "")) == trimmed:
			var named_player: XedatsPlayer3D = _resolve_player_from_route(route)
			if named_player != null:
				return {
					"ok": true,
					"player": named_player,
					"route": route,
					"index": route_index
				}

	return {
		"ok": false,
		"message": "Player '%s' was not found. Use 'audio list_buses' to inspect active player identifiers." % trimmed
	}


func _resolve_player_from_route(route: Dictionary) -> XedatsPlayer3D:
	var player_path: String = String(route.get("player_path", ""))
	if player_path.is_empty():
		return null
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null or scene_tree.root == null:
		return null
	var node: Node = scene_tree.root.get_node_or_null(NodePath(player_path))
	if node is XedatsPlayer3D and is_instance_valid(node):
		return node as XedatsPlayer3D
	return null


func _forward_to_xedats_debug(command_name: String, args: PackedStringArray) -> Dictionary:
	var xedats_debug_script: Script = load("res://addons/xedats_debug/xedats_debug_tool.gd")
	if xedats_debug_script == null:
		return _error_result(command_name, "XedatsDebugTool script is unavailable.")
	if not xedats_debug_script.has_method("instance"):
		return _error_result(command_name, "XedatsDebugTool script does not expose instance().")

	var xedats_debug_tool: Variant = xedats_debug_script.call("instance")
	if xedats_debug_tool == null:
		return _error_result(command_name, "XedatsDebugTool is unavailable.")
	if not xedats_debug_tool.has_method("execute_command"):
		return _error_result(command_name, "XedatsDebugTool does not expose execute_command().")

	var parts: Array[String] = [command_name]
	for arg in args:
		parts.append(String(arg))
	var forwarded: String = " ".join(parts)

	var result: Variant = xedats_debug_tool.call("execute_command", forwarded)
	if _console != null:
		return _console._normalize_command_result("xd.%s" % command_name, result)
	return _normalize_command_result("xd.%s" % command_name, result)


func _normalize_command_result(command_name: String, result: Variant) -> Dictionary:
	if result is Dictionary:
		var data: Dictionary = result
		if not data.has("command"):
			data["command"] = command_name
		if not data.has("ok"):
			data["ok"] = true
		if not data.has("message"):
			data["message"] = "OK"
		return data
	return {
		"ok": true,
		"command": command_name,
		"message": "OK",
		"result": result
	}


func _error_result(command_name: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"command": command_name,
		"message": message
	}
