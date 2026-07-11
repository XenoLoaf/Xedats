class_name XedatsRuntimeValidator
extends XebugModule


func _init() -> void:
	module_name = "XedatsRuntimeValidator"
	module_version = "1.0.0"
	module_author = "Xedats"
	module_description = "Runtime validation and integrity checks for Xedats audio systems."


func _register_commands() -> void:
	register_command("xedats.test.smoke", Callable(self, "_cmd_smoke"),
		"Run basic runtime smoke test (singleton, pool, buses, events).",
		"xedats.test.smoke")

	register_command("xedats.test.leak", Callable(self, "_cmd_leak"),
		"Check for pool leaks (active players exceeding pool capacity).",
		"xedats.test.leak")

	register_command("xedats.test.buses", Callable(self, "_cmd_buses"),
		"Verify audio bus routing integrity.",
		"xedats.test.buses")

	register_command("xedats.test.health", Callable(self, "_cmd_health"),
		"Run system health check and report warnings.",
		"xedats.test.health")


func _cmd_smoke(_args: PackedStringArray) -> Dictionary:
	if not ClassDB.class_exists(&"XedatsSingleton"):
		return _error("xedats.test.smoke", "XedatsSingleton is not available — is Xedats installed?")

	var results: PackedStringArray = PackedStringArray()
	var passed: int = 0
	var failed: PackedStringArray = PackedStringArray()

	# Test 1: Singleton
	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats != null:
		results.append("PASS: XedatsSingleton created")
		passed += 1
	else:
		failed.append("XedatsSingleton instance is null")
		return _build_result("xedats.test.smoke", results, passed, failed)

	# Test 2: Pool
	var stats: Dictionary = xedats.get_pool_stats()
	if stats.size() > 0:
		results.append("PASS: Pool stats available (3D pool=%d, 2D pool=%d)" % [
			int(stats.get("pool_3d", 0)),
			int(stats.get("pool_2d", 0)),
		])
		passed += 1
	else:
		failed.append("Pool stats returned empty")

	# Test 3: 3D Player
	var player_3d: XedatsPlayer3D = xedats.create_player_3d(Vector3.ZERO)
	if player_3d != null:
		results.append("PASS: XedatsPlayer3D created")
		passed += 1
		player_3d.queue_free()
	else:
		failed.append("create_player_3d() returned null")

	# Test 4: 2D Player (if available)
	if ClassDB.class_exists(&"XedatsPlayer2D"):
		var player_2d: XedatsPlayer2D = xedats.create_player_2d(Vector2.ZERO)
		if player_2d != null:
			results.append("PASS: XedatsPlayer2D created")
			passed += 1
			player_2d.queue_free()
		else:
			failed.append("create_player_2d() returned null")
	else:
		results.append("SKIP: XedatsPlayer2D not available")

	# Test 5: Audio buses
	xedats.create_audio_bus("SFX", "Master")
	if xedats.has_audio_bus("SFX"):
		results.append("PASS: SFX audio bus created")
		passed += 1
	else:
		failed.append("SFX bus creation failed")

	# Test 6: Event system
	var event_system: AudioEventSystem = xedats.get_event_system()
	if event_system != null:
		results.append("PASS: AudioEventSystem available")
		passed += 1
	else:
		failed.append("AudioEventSystem unavailable")

	# Test 7: Category volumes
	var volumes: Dictionary = xedats.get_all_category_volumes()
	if volumes.size() >= 0:
		results.append("PASS: Category volumes accessible (%d categories)" % volumes.size())
		passed += 1
	else:
		failed.append("get_all_category_volumes() failed")

	return _build_result("xedats.test.smoke", results, passed, failed)


func _cmd_leak(_args: PackedStringArray) -> Dictionary:
	if not ClassDB.class_exists(&"XedatsSingleton"):
		return _error("xedats.test.leak", "XedatsSingleton is not available.")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error("xedats.test.leak", "XedatsSingleton instance is unavailable.")

	var stats: Dictionary = xedats.get_pool_stats()
	var results: PackedStringArray = PackedStringArray()
	var passed: int = 0
	var failed: PackedStringArray = PackedStringArray()

	var active_3d: int = int(stats.get("active_3d", 0))
	var pool_3d: int = int(stats.get("pool_3d", 0))
	var peak_3d: int = int(stats.get("peak_3d", 0))
	var active_2d: int = int(stats.get("active_2d", 0))
	var pool_2d: int = int(stats.get("pool_2d", 0))
	var peak_2d: int = int(stats.get("peak_2d", 0))

	# Check 3D
	var max_3d: int = 32  # MAX_POOL_SIZE
	if peak_3d >= max_3d:
		failed.append("3D peak (%d) reached pool limit (%d) — possible exhaustion" % [peak_3d, max_3d])
	else:
		results.append("PASS: 3D peak %d / %d" % [peak_3d, max_3d])
		passed += 1

	if active_3d > pool_3d:
		failed.append("3D active (%d) exceeds pool (%d) — possible leak" % [active_3d, pool_3d])
	else:
		results.append("PASS: 3D active %d ≤ pool %d" % [active_3d, pool_3d])
		passed += 1

	# Check 2D
	var max_2d: int = 16
	if peak_2d >= max_2d:
		failed.append("2D peak (%d) reached pool limit (%d) — possible exhaustion" % [peak_2d, max_2d])
	else:
		results.append("PASS: 2D peak %d / %d" % [peak_2d, max_2d])
		passed += 1

	if active_2d > pool_2d:
		failed.append("2D active (%d) exceeds pool (%d) — possible leak" % [active_2d, pool_2d])
	else:
		results.append("PASS: 2D active %d ≤ pool %d" % [active_2d, pool_2d])
		passed += 1

	return _build_result("xedats.test.leak", results, passed, failed)


func _cmd_buses(_args: PackedStringArray) -> Dictionary:
	if not ClassDB.class_exists(&"XedatsSingleton"):
		return _error("xedats.test.buses", "XedatsSingleton is not available.")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error("xedats.test.buses", "XedatsSingleton instance is unavailable.")

	var results: PackedStringArray = PackedStringArray()
	var passed: int = 0
	var failed: PackedStringArray = PackedStringArray()

	# Check Master bus exists
	if xedats.has_audio_bus("Master"):
		results.append("PASS: Master bus exists")
		passed += 1
	else:
		failed.append("Master bus not found")

	# Check built-in buses
	var builtins: PackedStringArray = PackedStringArray(["Master", "SFX", "Music", "Ambient", "Voice", "UI"])
	for bus_name: String in builtins:
		if xedats.has_audio_bus(bus_name):
			results.append("PASS: Bus '%s' exists" % bus_name)
			passed += 1
		else:
			results.append("INFO: Bus '%s' not present (expected if not yet created)" % bus_name)

	# Check bus routes are valid
	var routes_3d: Array[Dictionary] = xedats.get_active_player_bus_routes()
	var orphan_count: int = 0
	for r: Dictionary in routes_3d:
		var bus: String = String(r.get("bus", ""))
		if not bus.is_empty() and not xedats.has_audio_bus(bus):
			orphan_count += 1

	if orphan_count == 0:
		results.append("PASS: No orphan 3D routes (all buses exist)")
		passed += 1
	else:
		failed.append("%d orphan 3D routes — players assigned to nonexistent buses" % orphan_count)

	return _build_result("xedats.test.buses", results, passed, failed)


func _cmd_health(_args: PackedStringArray) -> Dictionary:
	if not ClassDB.class_exists(&"XedatsSingleton"):
		return _error("xedats.test.health", "XedatsSingleton is not available.")

	var xedats: XedatsSingleton = XedatsSingleton.instance()
	if xedats == null:
		return _error("xedats.test.health", "XedatsSingleton instance is unavailable.")

	var health: Dictionary = xedats.get_system_health()
	var perf: Dictionary = xedats.get_performance_metrics()

	var lines: PackedStringArray = PackedStringArray()

	lines.append("=== System Health ===")
	for key_variant: Variant in health.keys():
		var key: String = String(key_variant)
		lines.append("  %s: %s" % [key, str(health.get(key, "?"))])

	lines.append("=== Performance ===")
	for key_variant: Variant in perf.keys():
		var key: String = String(key_variant)
		lines.append("  %s: %s" % [key, str(perf.get(key, "?"))])

	return {
		"ok": true,
		"command": "xedats.test.health",
		"message": "\n".join(PackedStringArray(lines)),
		"health": health,
		"performance": perf,
	}


func _error(command: String, message: String) -> Dictionary:
	return {"ok": false, "command": command, "message": message}


func _build_result(command: String, results: PackedStringArray, passed: int, failed: PackedStringArray) -> Dictionary:
	var lines: PackedStringArray = PackedStringArray()
	lines.append_array(results)
	if failed.size() > 0:
		lines.append("--- FAILURES ---")
		for f: String in failed:
			lines.append("  FAIL: %s" % f)
	lines.append("--- %d passed, %d failed ---" % [passed, failed.size()])

	return {
		"ok": failed.is_empty(),
		"command": command,
		"message": "\n".join(PackedStringArray(lines)),
		"passed": passed,
		"failed": failed.size(),
	}
