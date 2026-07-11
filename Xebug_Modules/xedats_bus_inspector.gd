class_name XedatsBusInspector
extends XebugModule


func _init() -> void:
	module_name = "XedatsBusInspector"
	module_version = "1.0.0"
	module_author = "Xedats"
	module_description = "Inspect and control Xedats audio bus routing at runtime."


func _register_commands() -> void:
	register_command("xedats.bus", Callable(self, "_cmd_bus_list"),
		"List all audio buses with effect counts and send targets.",
		"xedats.bus")

	register_command("xedats.bus.inspect", Callable(self, "_cmd_bus_inspect"),
		"Detailed inspection of a specific audio bus.",
		"xedats.bus.inspect <bus_name>")

	register_command("xedats.bus.volume", Callable(self, "_cmd_bus_volume"),
		"Get or set the volume for a category bus.",
		"xedats.bus.volume <category> [value]")

	register_command("xedats.bus.routes", Callable(self, "_cmd_bus_routes"),
		"Show all active player-to-bus route assignments.",
		"xedats.bus.routes")


func _cmd_bus_list(_args: PackedStringArray) -> Dictionary:
	if not ClassDB.class_exists(&"XedatsSingleton"):
		return _error("xedats.bus", "XedatsSingleton is not available.")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error("xedats.bus", "XedatsSingleton instance is unavailable.")

	var bus_info: Dictionary = xedats.get_bus_info()
	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== Audio Buses (%d) ===" % bus_info.size())

	for bus_name_variant: Variant in bus_info.keys():
		var bus_name: String = String(bus_name_variant)
		var entry_variant: Variant = bus_info.get(bus_name, {})
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant as Dictionary
		lines.append("  %-20s effects=%d send=%s" % [
			bus_name,
			int(entry.get("effects", 0)),
			String(entry.get("send", "?"))
		])

	return {
		"ok": true,
		"command": "xedats.bus",
		"message": "\n".join(PackedStringArray(lines)),
		"buses": bus_info,
	}


func _cmd_bus_inspect(args: PackedStringArray) -> Dictionary:
	if args.is_empty():
		return _error("xedats.bus.inspect", "Usage: xedats.bus.inspect <bus_name>")

	if not ClassDB.class_exists(&"XedatsSingleton"):
		return _error("xedats.bus.inspect", "XedatsSingleton is not available.")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error("xedats.bus.inspect", "XedatsSingleton instance is unavailable.")

	var bus_name: String = String(args[0])
	if not xedats.has_audio_bus(bus_name):
		return _error("xedats.bus.inspect", "Bus '%s' not found." % bus_name)

	var bus_info: Dictionary = xedats.get_bus_info()
	var entry_variant: Variant = bus_info.get(bus_name, {})
	if not (entry_variant is Dictionary):
		return _error("xedats.bus.inspect", "No metadata for bus '%s'." % bus_name)

	var entry: Dictionary = entry_variant as Dictionary
	var index: int = int(entry.get("index", -1))
	var send: String = String(entry.get("send", "?"))
	var effects: int = int(entry.get("effects", 0))
	var volume_db: float = float(entry.get("volume_db", 0.0))

	return {
		"ok": true,
		"command": "xedats.bus.inspect",
		"message": "%s: index=%d send=%s effects=%d volume=%.1fdB" % [bus_name, index, send, effects, volume_db],
		"bus_name": bus_name,
		"bus": entry,
	}


func _cmd_bus_volume(args: PackedStringArray) -> Dictionary:
	if args.is_empty():
		return _error("xedats.bus.volume", "Usage: xedats.bus.volume <category> [value]")

	if not ClassDB.class_exists(&"XedatsSingleton"):
		return _error("xedats.bus.volume", "XedatsSingleton is not available.")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error("xedats.bus.volume", "XedatsSingleton instance is unavailable.")

	var category: String = String(args[0])

	if args.size() >= 2:
		var value: float = float(args[1])
		value = clamp(value, 0.0, 1.0)
		xedats.set_category_volume(category, value)
		return {
			"ok": true,
			"command": "xedats.bus.volume",
			"message": "Category '%s' volume set to %.2f" % [category, value],
		}

	var current: float = xedats.get_category_volume(category)
	return {
		"ok": true,
		"command": "xedats.bus.volume",
		"message": "Category '%s' volume = %.2f" % [category, current],
		"category": category,
		"volume": current,
	}


func _cmd_bus_routes(_args: PackedStringArray) -> Dictionary:
	if not ClassDB.class_exists(&"XedatsSingleton"):
		return _error("xedats.bus.routes", "XedatsSingleton is not available.")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error("xedats.bus.routes", "XedatsSingleton instance is unavailable.")

	var routes_3d: Array[Dictionary] = xedats.get_active_player_bus_routes()
	var routes_2d: Array[Dictionary] = xedats.get_active_player_bus_routes_2d()

	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== 3D Routes (%d) ===" % routes_3d.size())
	for r: Dictionary in routes_3d:
		lines.append("  %s → %s [%s]" % [
			String(r.get("node", "?")),
			String(r.get("bus", "?")),
			String(r.get("category", "?"))
		])

	lines.append("=== 2D Routes (%d) ===" % routes_2d.size())
	for r: Dictionary in routes_2d:
		lines.append("  %s → %s [%s]" % [
			String(r.get("node", "?")),
			String(r.get("bus", "?")),
			String(r.get("category", "?"))
		])

	return {
		"ok": true,
		"command": "xedats.bus.routes",
		"message": "\n".join(PackedStringArray(lines)),
		"routes_3d": routes_3d,
		"routes_2d": routes_2d,
	}


func _error(command: String, message: String) -> Dictionary:
	return {"ok": false, "command": command, "message": message}
