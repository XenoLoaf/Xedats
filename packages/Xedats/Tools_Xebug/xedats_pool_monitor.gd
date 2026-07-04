class_name XedatsPoolMonitor
extends XebugModule


func _init() -> void:
	module_name = "XedatsPoolMonitor"
	module_version = "1.0.0"
	module_author = "Xedats"
	module_description = "Real-time Xedats audio pool statistics and monitoring."


func _register_commands() -> void:
	register_command("xedats.pool", Callable(self, "_cmd_pool_stats"),
		"Show 3D/2D pool utilization (available, active, peak).",
		"xedats.pool")

	register_command("xedats.pool.snapshot", Callable(self, "_cmd_pool_snapshot"),
		"Detailed snapshot of all pooled player instances.",
		"xedats.pool.snapshot")

	register_command("xedats.pool.watch", Callable(self, "_cmd_pool_watch"),
		"Toggle continuous pool monitoring with threshold alerts.",
		"xedats.pool.watch <on|off>")


func _cmd_pool_stats(_args: PackedStringArray) -> Dictionary:
	if not ClassDB.class_exists(&"XedatsSingleton"):
		return _error("xedats.pool", "XedatsSingleton is not available — is Xedats installed?")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error("xedats.pool", "XedatsSingleton instance is unavailable.")

	var stats: Dictionary = xedats.get_pool_stats()
	return {
		"ok": true,
		"command": "xedats.pool",
		"message": "3D: %d active / %d pool / %d peak | 2D: %d active / %d pool / %d peak" % [
			int(stats.get("active_3d", 0)),
			int(stats.get("pool_3d", 0)),
			int(stats.get("peak_3d", 0)),
			int(stats.get("active_2d", 0)),
			int(stats.get("pool_2d", 0)),
			int(stats.get("peak_2d", 0)),
		],
		"stats": stats,
	}


func _cmd_pool_snapshot(_args: PackedStringArray) -> Dictionary:
	if not ClassDB.class_exists(&"XedatsSingleton"):
		return _error("xedats.pool.snapshot", "XedatsSingleton is not available.")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error("xedats.pool.snapshot", "XedatsSingleton instance is unavailable.")

	var routes_3d: Array[Dictionary] = xedats.get_active_player_bus_routes()
	var routes_2d: Array[Dictionary] = xedats.get_active_player_bus_routes_2d()

	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== 3D Players (%d active) ===" % routes_3d.size())
	for i: int in range(routes_3d.size()):
		var r: Dictionary = routes_3d[i]
		lines.append("  [%d] cat=%s bus=%s pool=%s" % [
			i,
			String(r.get("category", "?")),
			String(r.get("bus", "?")),
			String(r.get("from_pool", "?"))
		])

	lines.append("=== 2D Players (%d active) ===" % routes_2d.size())
	for i: int in range(routes_2d.size()):
		var r: Dictionary = routes_2d[i]
		lines.append("  [%d] cat=%s bus=%s pool=%s" % [
			i,
			String(r.get("category", "?")),
			String(r.get("bus", "?")),
			String(r.get("from_pool", "?"))
		])

	return {
		"ok": true,
		"command": "xedats.pool.snapshot",
		"message": "\n".join(PackedStringArray(lines)),
		"routes_3d": routes_3d,
		"routes_2d": routes_2d,
	}


func _cmd_pool_watch(args: PackedStringArray) -> Dictionary:
	if args.is_empty():
		return _error("xedats.pool.watch", "Usage: xedats.pool.watch <on|off>")

	var action: String = String(args[0]).to_lower()
	match action:
		"on":
			return _error("xedats.pool.watch", "Continuous monitoring not yet implemented. Use 'xedats.pool' for a snapshot.")
		"off":
			return {"ok": true, "command": "xedats.pool.watch", "message": "Watch disabled."}
		_:
			return _error("xedats.pool.watch", "Unknown action '%s'. Use 'on' or 'off'." % action)


func _error(command: String, message: String) -> Dictionary:
	return {"ok": false, "command": command, "message": message}
