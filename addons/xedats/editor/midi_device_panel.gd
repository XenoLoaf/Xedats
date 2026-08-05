@tool
extends Control

## Editor dock panel for MIDI device detection, refresh, and live monitoring.
##
## Opens the system MIDI driver automatically on first use and displays
## connected device names. Supports hot-plug refresh and live MIDI
## message monitoring (note-on, note-off, CC).

# ── UI State ──────────────────────────────────────
var _devices_label: Label = null
var _status_label: Label = null
var _monitor_label: Label = null
var _refresh_button: Button = null
var _toggle_monitor_button: Button = null
var _monitoring: bool = false
var _midi_open: bool = false
var _last_note: String = ""
var _last_cc: String = ""


func _init() -> void:
	name = "MIDI Manager"


func _ready() -> void:
	_build_ui()
	_open_midi_driver()


func _exit_tree() -> void:
	if _midi_open:
		OS.close_midi_inputs()


# ── Input (MIDI messages) ─────────────────────────

func _input(event: InputEvent) -> void:
	if not _monitoring:
		return

	var midi: InputEventMIDI = event as InputEventMIDI
	if midi == null:
		return

	get_viewport().set_input_as_handled()

	match midi.message:
		MIDI_MESSAGE_NOTE_ON:
			if midi.velocity > 0:
				var octave: int = midi.pitch / 12 - 1
				var names: Array[String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
				_last_note = "Note ON:  %s%d  ch=%d  vel=%d" % [names[midi.pitch % 12], octave, midi.channel, midi.velocity]
			else:
				_last_note = "Note OFF: %d  ch=%d" % [midi.pitch, midi.channel]
		MIDI_MESSAGE_NOTE_OFF:
			_last_note = "Note OFF: %d  ch=%d" % [midi.pitch, midi.channel]
		MIDI_MESSAGE_CONTROL_CHANGE:
			_last_cc = "CC:  %d = %d  ch=%d" % [midi.controller_number, midi.controller_value, midi.channel]

	_refresh_monitor_label()


# ── MIDI Driver ───────────────────────────────────

func _open_midi_driver() -> void:
	if not _is_midi_supported():
		_status_label.text = "Status: MIDI not supported on this platform"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.3))
		return

	OS.open_midi_inputs()
	_midi_open = true
	_refresh_device_list()


func _is_midi_supported() -> bool:
	return OS.has_feature("midi")


func _refresh_device_list() -> void:
	if not _midi_open:
		return

	var devices: PackedStringArray = OS.get_connected_midi_inputs()
	if devices.is_empty():
		_status_label.text = "Status: No MIDI devices detected"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		_devices_label.text = "No devices found.\nPlug in your MIDI keyboard and press Refresh."
	else:
		_status_label.text = "Status: %d device(s) found" % devices.size()
		_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		var lines: Array[String] = []
		for i: int in range(devices.size()):
			lines.append("%d. %s" % [i + 1, devices[i]])
		_devices_label.text = "\n".join(PackedStringArray(lines))


func refresh_devices() -> void:
	if _midi_open:
		OS.close_midi_inputs()
	OS.open_midi_inputs()
	_midi_open = true
	_refresh_device_list()
	_update_monitor_status()


# ── Monitoring ────────────────────────────────────

func _toggle_monitoring(on: bool) -> void:
	_monitoring = on
	set_process_input(on)
	_update_monitor_status()


func _update_monitor_status() -> void:
	if _toggle_monitor_button == null:
		return
	_toggle_monitor_button.text = "Monitoring: ON" if _monitoring else "Monitoring: OFF"


func _refresh_monitor_label() -> void:
	if _monitor_label == null:
		return
	var text: String = ""
	if not _last_note.is_empty():
		text += _last_note
	if not _last_cc.is_empty():
		text += "\n" + _last_cc
	_monitor_label.text = text if not text.is_empty() else "No MIDI activity yet."


# ── UI Construction ───────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(220, 300)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# ── Status ─────────────────────────────
	_status_label = Label.new()
	_status_label.text = "Initializing..."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_status_label)
	vbox.add_child(_make_separator())

	# ── Devices ────────────────────────────
	var devices_header: Label = Label.new()
	devices_header.text = "Devices:"
	devices_header.add_theme_font_size_override("font_size", 12)
	devices_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(devices_header)

	_devices_label = Label.new()
	_devices_label.text = "Scanning..."
	_devices_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_devices_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_devices_label)

	# ── Device selection note ──────────────
	var note: Label = Label.new()
	note.text = "Godot cannot separate MIDI devices.\nSet each keyboard to a different\nMIDI channel, then use channel_filter\nin XedatsMIDIInput to select one."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
	vbox.add_child(note)

	vbox.add_child(_make_separator())

	# ── Buttons ────────────────────────────
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_refresh_button = Button.new()
	_refresh_button.text = "Refresh"
	_refresh_button.pressed.connect(refresh_devices)
	btn_row.add_child(_refresh_button)

	_toggle_monitor_button = Button.new()
	_toggle_monitor_button.pressed.connect(func(): _toggle_monitoring(not _monitoring))
	_toggle_monitor_button.toggle_mode = true
	btn_row.add_child(_toggle_monitor_button)
	_update_monitor_status()

	vbox.add_child(btn_row)
	vbox.add_child(_make_separator())

	# ── Monitor output ────────────────────
	var mon_header: Label = Label.new()
	mon_header.text = "MIDI Monitor:"
	mon_header.add_theme_font_size_override("font_size", 12)
	mon_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(mon_header)

	_monitor_label = Label.new()
	_monitor_label.text = "No MIDI activity yet."
	_monitor_label.add_theme_font_size_override("font_size", 11)
	_monitor_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	vbox.add_child(_monitor_label)


func _make_separator() -> HSeparator:
	var sep: HSeparator = HSeparator.new()
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sep
