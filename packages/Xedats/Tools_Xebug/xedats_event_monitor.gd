class_name XedatsEventMonitor
extends XebugModule


var _history: Array[Dictionary] = []
var _max_history: int = 50


func _init() -> void:
	module_name = "XedatsEventMonitor"
	module_version = "1.0.0"
	module_author = "Xedats"
	module_description = "Monitor Xedats audio event triggers and registration at runtime."


func _register_commands() -> void:
	register_command("xedats.event", Callable(self, "_cmd_event_list"),
		"List all registered audio events with playback counts.",
		"xedats.event")

	register_command("xedats.event.history", Callable(self, "_cmd_event_history"),
		"Show recent audio event trigger history.",
		"xedats.event.history")

	register_command("xedats.event.inspect", Callable(self, "_cmd_event_inspect"),
		"Detailed inspection of a specific audio event.",
		"xedats.event.inspect <event_name>")


func _on_module_enabled() -> void:
	_connect_event_signals()


func _on_module_disabled() -> void:
	_disconnect_event_signals()


func _connect_event_signals() -> void:
	if not ClassDB.class_exists(&"XedatsSingleton"):
		return
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return
	var event_system: AudioEventSystem = xedats.get_event_system()
	if event_system == null:
		return
	if not event_system.event_triggered.is_connected(_on_event_triggered):
		event_system.event_triggered.connect(_on_event_triggered)


func _disconnect_event_signals() -> void:
	if not ClassDB.class_exists(&"XedatsSingleton"):
		return
	var xedats: XedatsSingleton = XedatsSingleton.peek_instance()
	if xedats == null:
		return
	var event_system: AudioEventSystem = xedats.get_event_system()
	if event_system == null:
		return
	if event_system.event_triggered.is_connected(_on_event_triggered):
		event_system.event_triggered.disconnect(_on_event_triggered)


func _on_event_triggered(event_name: String, _player: Node) -> void:
	var entry: Dictionary = {
		"event": event_name,
		"time": Time.get_ticks_msec(),
	}
	_history.append(entry)
	while _history.size() > _max_history:
		_history.pop_front()


func _cmd_event_list(_args: PackedStringArray) -> Dictionary:
	if not ClassDB.class_exists(&"XedatsSingleton"):
		return _error("xedats.event", "XedatsSingleton is not available.")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error("xedats.event", "XedatsSingleton instance is unavailable.")

	var event_system: AudioEventSystem = xedats.get_event_system()
	if event_system == null:
		return _error("xedats.event", "AudioEventSystem is unavailable.")

	var event_names: Array[String] = event_system.get_all_events()
	var all_stats: Dictionary = event_system.get_all_stats()

	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== Audio Events (%d) ===" % event_names.size())

	for event_name: String in event_names:
		var stats: Dictionary = all_stats.get(event_name, {})
		lines.append("  %-30s plays=%d peak=%d" % [
			event_name,
			int(stats.get("total_plays", 0)),
			int(stats.get("peak_concurrent", 0)),
		])

	return {
		"ok": true,
		"command": "xedats.event",
		"message": "\n".join(PackedStringArray(lines)),
		"events": event_names,
		"count": event_names.size(),
	}


func _cmd_event_history(_args: PackedStringArray) -> Dictionary:
	if _history.is_empty():
		return {"ok": true, "command": "xedats.event.history", "message": "No events triggered yet."}

	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== Recent Event Triggers (%d) ===" % _history.size())

	var now: int = Time.get_ticks_msec()
	for entry: Dictionary in _history:
		var elapsed_ms: int = now - int(entry.get("time", 0))
		var elapsed_str: String = _format_elapsed(elapsed_ms)
		lines.append("  %-30s %s ago" % [String(entry.get("event", "?")), elapsed_str])

	return {
		"ok": true,
		"command": "xedats.event.history",
		"message": "\n".join(PackedStringArray(lines)),
		"history": _history,
	}


func _cmd_event_inspect(args: PackedStringArray) -> Dictionary:
	if args.is_empty():
		return _error("xedats.event.inspect", "Usage: xedats.event.inspect <event_name>")

	if not ClassDB.class_exists(&"XedatsSingleton"):
		return _error("xedats.event.inspect", "XedatsSingleton is not available.")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error("xedats.event.inspect", "XedatsSingleton instance is unavailable.")

	var event_system: AudioEventSystem = xedats.get_event_system()
	if event_system == null:
		return _error("xedats.event.inspect", "AudioEventSystem is unavailable.")

	var event_name: String = String(args[0])
	var event_obj: AudioEventSystem.AudioEvent = event_system.get_event(event_name)
	if event_obj == null:
		return _error("xedats.event.inspect", "Event '%s' not registered." % event_name)

	var stats: Dictionary = event_system.get_event_stats(event_name)

	return {
		"ok": true,
		"command": "xedats.event.inspect",
		"message": "%s: 3D=%s plays=%d peak=%d category=%s" % [
			event_name,
			str(event_obj.is_3d),
			int(stats.get("total_plays", 0)),
			int(stats.get("peak_concurrent", 0)),
			String(event_obj.audio_category),
		],
		"event_name": event_name,
		"stats": stats,
	}


func _error(command: String, message: String) -> Dictionary:
	return {"ok": false, "command": command, "message": message}


func _format_elapsed(ms: int) -> String:
	if ms < 1000:
		return "%dms" % ms
	if ms < 60000:
		return "%.1fs" % (float(ms) / 1000.0)
	return "%.1fm" % (float(ms) / 60000.0)
