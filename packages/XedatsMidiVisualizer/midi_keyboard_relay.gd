extends Control

## Relay scene — owns XedatsMIDIInput and MidiPianoKeyboardWindow.
## Keeps them decoupled: window = visual/sound, MIDI input = data source.

const KeyboardWindow := preload("res://addons/xedats_midi_visualizer/MidiPianoKeyboardWindow.gd")

var _midi_input: XedatsMIDIInput = null
var _status_label: Label = null


func _ready() -> void:
	_midi_input = XedatsMIDIInput.new()
	_midi_input.name = "MidiInput"
	_midi_input.verbose_log = true
	add_child(_midi_input)

	var window: MidiPianoKeyboardWindow = KeyboardWindow.new()
	window.name = "KeyboardWindow"
	add_child(window)

	_midi_input.note_triggered.connect(_on_midi_note_triggered.bind(window))
	_midi_input.note_off.connect(_on_midi_note_off.bind(window))

	# Status bar at the bottom
	_status_label = Label.new()
	_status_label.text = "MIDI: initializing..."
	_status_label.position = Vector2(4, 0)
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
	add_child(_status_label)

	set_process_input(true)

	# Show devices after driver opens
	var timer: SceneTreeTimer = get_tree().create_timer(0.5)
	timer.timeout.connect(_refresh_status)

	print("=" .repeat(50))
	print("MIDI Relay ready.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _status_label != null:
		_status_label.position.y = size.y - 22


func _refresh_status() -> void:
	if _midi_input == null or _status_label == null:
		return
	var devices: Array = _midi_input.get_connected_devices()
	if devices.is_empty():
		_status_label.text = "MIDI: no devices"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2))
	else:
		_status_label.text = "MIDI: %d device(s)" % devices.size()
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))


func _input(event: InputEvent) -> void:
	var midi: InputEventMIDI = event as InputEventMIDI
	if midi != null and midi.message == MIDI_MESSAGE_NOTE_ON and midi.velocity > 0:
		_status_label.text = "MIDI: note %d vel %d" % [midi.pitch, midi.velocity]
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))


func _on_midi_note_triggered(note: int, velocity: int, channel: int, _event_name: String, window: MidiPianoKeyboardWindow) -> void:
	print("[MidiRelay] note_triggered: note=%d vel=%d" % [note, velocity])
	if window.keyboard != null:
		window.keyboard.press_key(note, velocity)
	else:
		print("[MidiRelay] ERROR: window.keyboard is null!")


func _on_midi_note_off(note: int, _channel: int, window: MidiPianoKeyboardWindow) -> void:
	print("[MidiRelay] note_off: note=%d" % note)
	if window.keyboard != null:
		window.keyboard.release_key(note)
