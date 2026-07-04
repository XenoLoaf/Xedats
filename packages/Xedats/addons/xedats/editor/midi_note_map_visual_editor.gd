@tool
class_name MidiNoteMapEditor
extends Window

## Piano-roll editor for [MidiNoteMap] resources.
##
## Non-modal, resizable window with 128-key piano roll, inline editing,
## range paint, and event name autocomplete.

# ── Geometry ──────────────────────────────────────
const KEY_HEIGHT: int                = 20
const LABEL_WIDTH: int               = 54
const CANVAS_PAD_TOP: int            = 4
const CANVAS_PAD_BOTTOM: int         = 4
const CANVAS_PAD_RIGHT: int          = 12
const TOP_NOTE: int                  = 127
const BOTTOM_NOTE: int               = 0
const CANVAS_WIDTH_MIN: int          = 200
const STATUSBAR_HEIGHT: int          = 28

# ── Font sizes ────────────────────────────────────
const FONT_NOTE_LABEL: int           = 10
const FONT_EVENT_NAME: int           = 9
const FONT_STATUS: int               = 10

# ── Key fills ─────────────────────────────────────
const COLOR_UNMAPPED_WHITE: Color    = Color("4e5466")
const COLOR_UNMAPPED_BLACK: Color    = Color("333744")
const COLOR_MAPPED_WHITE: Color      = Color("3d6348")
const COLOR_MAPPED_BLACK: Color      = Color("2e4a35")
const COLOR_HOVER_OVERLAY: Color     = Color("ffffff10")

# ── Borders & separators ──────────────────────────
const COLOR_KEY_BORDER: Color        = Color("3b3f4c")
const COLOR_BLACK_BORDER: Color      = Color("2c303a")
const COLOR_SELECTED_BORDER: Color   = Color("6a9fd8")
const COLOR_OCTAVE_SEP: Color        = Color("5d6270")

# ── Text ──────────────────────────────────────────
const COLOR_LABEL_TEXT: Color        = Color("8a8f9a")
const COLOR_LABEL_OCTAVE: Color      = Color("b0b5bf")
const COLOR_LABEL_HOVER: Color       = Color("e0e4ec")
const COLOR_EVENT_TEXT: Color        = Color("b8d4b8")
const COLOR_HINT_NORMAL: Color       = Color("5d6270")
const COLOR_HINT_HOVER: Color        = Color("7d828f")

# ── Inline edit ───────────────────────────────────
const COLOR_EDIT_BG: Color           = Color("3b4252")
const COLOR_EDIT_BORDER: Color       = Color("5d8ed9")

# ── Chrome ────────────────────────────────────────
const COLOR_STATUSBAR_BG: Color      = Color("252830")

# ── Drag overlays ─────────────────────────────────
const COLOR_DRAG_UNMAPPED: Color     = Color("7bc67e30")
const COLOR_DRAG_OVERWRITE: Color    = Color("d9b14e30")


var note_map: MidiNoteMap = null
var _hovered_note: int = -1
var _selected_notes: Array = []
var _drag_origin: int = -1
var _drag_end: int = -1
var _dragging: bool = false
var _undo_snapshot: Dictionary = {}
var _show_banner: bool = true
var _compact: bool = false

var _status_label: Label = null
var _piano_area: Control = null
var _inline_edit: LineEdit = null
var _inline_note: int = -1

# Note name table
const _note_names: Array[String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


func _init() -> void:
	title = "Piano Roll — MidiNoteMap"
	wrap_controls = true
	close_requested.connect(queue_free)
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_SCREEN_WITH_MOUSE_FOCUS


func _ready() -> void:
	size = Vector2(460, 620)
	min_size = Vector2(360, 380)
	_build_ui()


func _build_ui() -> void:
	# Status bar (drawn manually in canvas)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", FONT_STATUS)

	# Piano surface
	_piano_area = Control.new()
	_piano_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_piano_area.gui_input.connect(_on_piano_input)
	_piano_area.mouse_entered.connect(func(): _piano_area.grab_focus())
	_piano_area.draw.connect(_on_piano_draw)

	# Scroll container
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.add_child(_piano_area)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Layout
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_child(_status_label)
	vbox.add_child(scroll)
	add_child(vbox)

	_apply_layout()
	_refresh_status()


func _apply_layout() -> void:
	if _piano_area == null:
		return
	if _compact:
		_piano_area.custom_minimum_size = Vector2(CANVAS_WIDTH_MIN, KEY_HEIGHT * 13 + 8)
	else:
		_piano_area.custom_minimum_size = Vector2(CANVAS_WIDTH_MIN, KEY_HEIGHT * 128 + 8)
	_piano_area.queue_redraw()


func _on_piano_draw() -> void:
	if note_map == null or _piano_area == null:
		return

	var font: Font = get_theme_default_font()
	var key_width: int = maxi(CANVAS_WIDTH_MIN, int(_piano_area.size.x) - LABEL_WIDTH - CANVAS_PAD_RIGHT)

	# First-visit banner
	if _show_banner and note_map.note_events.is_empty() and note_map.note_containers.is_empty():
		_piano_area.draw_rect(Rect2(LABEL_WIDTH, 8, key_width, 32), Color("2a3a5a"))
		_piano_area.draw_string(font, Vector2(LABEL_WIDTH + 8, 28), "Click keys to assign audio events. Right-click to clear.", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_NOTE_LABEL, Color("8ab4e0"))
		_piano_area.draw_string(font, Vector2(LABEL_WIDTH + 8, 44), "Shift+click for range, Ctrl+click to toggle, drag to paint.", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_NOTE_LABEL, Color("6a90b0"))

	# Selection range (drag highlight)
	if _dragging and _drag_origin >= 0 and _drag_end >= 0:
		var r_start: int = mini(_drag_origin, _drag_end)
		var r_end: int = maxi(_drag_origin, _drag_end)
		for n: int in range(r_start, r_end + 1):
			var y: float = float(TOP_NOTE - n) * KEY_HEIGHT + CANVAS_PAD_TOP
			var mapped: bool = note_map.note_events.has(n) or note_map.note_containers.has(n)
			var color: Color = COLOR_DRAG_OVERWRITE if mapped else COLOR_DRAG_UNMAPPED
			_piano_area.draw_rect(Rect2(LABEL_WIDTH, y, key_width, KEY_HEIGHT), color)

	for note: int in range(BOTTOM_NOTE, TOP_NOTE + 1):
		var y: float = float(TOP_NOTE - note) * KEY_HEIGHT + CANVAS_PAD_TOP
		var name_idx: int = note % 12
		var is_black: bool = name_idx in [1, 3, 6, 8, 10]
		var mapped: bool = note_map.note_events.has(note) or note_map.note_containers.has(note)
		var selected: bool = note in _selected_notes

		# Key fill
		var color: Color
		if selected:
			color = COLOR_SELECTED_BORDER
		elif mapped:
			color = COLOR_MAPPED_BLACK if is_black else COLOR_MAPPED_WHITE
		else:
			color = COLOR_UNMAPPED_BLACK if is_black else COLOR_UNMAPPED_WHITE

		var key_rect: Rect2 = Rect2(LABEL_WIDTH, y, key_width, KEY_HEIGHT)
		_piano_area.draw_rect(key_rect, color)

		# Selected border
		if selected:
			_piano_area.draw_rect(key_rect, COLOR_SELECTED_BORDER, false, 1.0)
		else:
			_piano_area.draw_rect(key_rect, COLOR_BLACK_BORDER if is_black else COLOR_KEY_BORDER, false, 1.0)

		# Hover highlight
		if note == _hovered_note:
			_piano_area.draw_rect(key_rect, COLOR_HOVER_OVERLAY)

		# Octave separator
		if name_idx == 0 and note > 0:
			_piano_area.draw_line(Vector2(LABEL_WIDTH, y), Vector2(LABEL_WIDTH + key_width, y), COLOR_OCTAVE_SEP, 1.0)

		# Note label
		var octave: int = note / 12 - 1
		var label: String = "%s%d" % [_note_names[name_idx], octave]
		var label_color: Color = COLOR_LABEL_HOVER if note == _hovered_note else (COLOR_LABEL_OCTAVE if name_idx == 0 else COLOR_LABEL_TEXT)
		_piano_area.draw_string(font, Vector2(4, y + KEY_HEIGHT - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_NOTE_LABEL, label_color)

		# Mapped content
		if mapped and not selected:
			var text: String = ""
			if note_map.note_events.has(note):
				text = String(note_map.note_events[note])
			elif note_map.note_containers.has(note):
				var c: AudioArrayContainer = note_map.note_containers[note] as AudioArrayContainer
				if c != null:
					text = "[%s]" % c.container_name
			var max_chars: int = maxi(2, (key_width - 12) / 7)
			if text.length() > max_chars:
				text = text.left(max_chars - 1) + "…"
			if not text.is_empty():
				_piano_area.draw_string(font, Vector2(LABEL_WIDTH + 6, y + KEY_HEIGHT - 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_EVENT_NAME, COLOR_EVENT_TEXT)
		elif not mapped:
			var hint_color: Color = COLOR_HINT_HOVER if note == _hovered_note else COLOR_HINT_NORMAL
			_piano_area.draw_string(font, Vector2(LABEL_WIDTH + 6, y + KEY_HEIGHT - 4), "···", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_EVENT_NAME, hint_color)

	# Status bar fill
	_piano_area.draw_rect(Rect2(0, KEY_HEIGHT * 128 + 8, _piano_area.size.x, STATUSBAR_HEIGHT), COLOR_STATUSBAR_BG)
	var status_text: String = _build_status_text()
	_piano_area.draw_string(font, Vector2(6, KEY_HEIGHT * 128 + 24), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_STATUS, COLOR_LABEL_TEXT)


func _build_status_text() -> String:
	var mapped: int = note_map.note_events.size() + note_map.note_containers.size() if note_map else 0
	var text: String = "%d notes mapped" % mapped
	if _hovered_note >= 0:
		var octave: int = _hovered_note / 12 - 1
		text += "  |  %s%d" % [_note_names[_hovered_note % 12], octave]
		if note_map.note_events.has(_hovered_note):
			text += " → %s" % note_map.note_events[_hovered_note]
	return text


func _on_piano_input(event: InputEvent) -> void:
	if note_map == null:
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event != null:
		var note: int = _y_to_note(mouse_event.position.y)
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				_cancel_inline_edit()
				if mouse_event.shift_pressed and _selected_notes.size() > 0:
					_select_range(_selected_notes.back(), note)
				elif mouse_event.ctrl_pressed:
					_toggle_selection(note)
				else:
					_select_single(note)
				_drag_origin = note
				_drag_end = note
				_show_banner = false
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_inline_edit()
				if mouse_event.shift_pressed or _selected_notes.size() > 1:
					_clear_range()
				else:
					_clear_note(note)
		else:
			# Released
			if mouse_event.button_index == MOUSE_BUTTON_LEFT and _dragging:
				_commit_range_paint()
			_dragging = false
			_drag_origin = -1
			_drag_end = -1
		_piano_area.queue_redraw()
		return

	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_hovered_note = _y_to_note(motion.position.y)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _drag_origin >= 0:
			_drag_end = _y_to_note(motion.position.y)
			_dragging = true
		_piano_area.queue_redraw()
		return


func _cancel_inline_edit() -> void:
	if _inline_edit != null:
		_inline_edit.queue_free()
		_inline_edit = null
		_inline_note = -1
		_piano_area.queue_redraw()


func _select_single(note: int) -> void:
	_undo_snapshot = note_map.note_events.duplicate()
	_selected_notes.clear()
	_selected_notes.append(note)
	_spawn_inline_edit(note)


func _select_range(from: int, to: int) -> void:
	_undo_snapshot = note_map.note_events.duplicate()
	var start: int = mini(from, to)
	var end: int = maxi(from, to)
	_selected_notes.clear()
	for n: int in range(start, end + 1):
		_selected_notes.append(n)


func _toggle_selection(note: int) -> void:
	if note in _selected_notes:
		_selected_notes.erase(note)
	else:
		_selected_notes.append(note)


func _clear_note(note: int) -> void:
	_undo_snapshot = note_map.note_events.duplicate()
	note_map.note_events.erase(note)
	note_map.note_containers.erase(note)
	_selected_notes.erase(note)
	notify_property_list_changed()
	_refresh_status()


func _clear_range() -> void:
	_undo_snapshot = note_map.note_events.duplicate()
	for note: int in _selected_notes:
		note_map.note_events.erase(note)
		note_map.note_containers.erase(note)
	_selected_notes.clear()
	notify_property_list_changed()
	_refresh_status()


func _commit_range_paint() -> void:
	if _drag_origin < 0 or _drag_end < 0:
		return
	if abs(_drag_origin - _drag_end) < 2:
		return

	_undo_snapshot = note_map.note_events.duplicate()
	var start: int = mini(_drag_origin, _drag_end)
	var end: int = maxi(_drag_origin, _drag_end)

	# Use the drag-origin key's event name as the paint ink
	var ink: String = ""
	if note_map.note_events.has(_drag_origin):
		ink = String(note_map.note_events[_drag_origin])

	for n: int in range(start, end + 1):
		if ink.is_empty():
			note_map.note_events.erase(n)
		else:
			note_map.note_events[n] = ink

	notify_property_list_changed()
	_refresh_status()


func _spawn_inline_edit(note: int) -> void:
	_cancel_inline_edit()

	var y: float = float(TOP_NOTE - note) * KEY_HEIGHT + CANVAS_PAD_TOP
	var key_width: int = maxi(CANVAS_WIDTH_MIN, int(_piano_area.size.x) - LABEL_WIDTH - CANVAS_PAD_RIGHT)

	_inline_note = note
	_inline_edit = LineEdit.new()
	_inline_edit.position = Vector2(LABEL_WIDTH, y)
	_inline_edit.size = Vector2(key_width, KEY_HEIGHT)
	_inline_edit.add_theme_stylebox_override("normal", _make_edit_style())
	_inline_edit.add_theme_stylebox_override("focus", _make_edit_style())
	_inline_edit.add_theme_font_size_override("font_size", FONT_EVENT_NAME)
	_inline_edit.add_theme_color_override("font_color", Color("e0e4ec"))
	_inline_edit.add_theme_color_override("font_placeholder_color", Color("6a7078"))
	_inline_edit.add_theme_color_override("caret_color", COLOR_EDIT_BORDER)
	_inline_edit.placeholder_text = "event_name"
	_inline_edit.expand_to_text_length = true

	if note_map.note_events.has(note):
		_inline_edit.text = String(note_map.note_events[note])
		_inline_edit.caret_column = _inline_edit.text.length()

	_inline_edit.text_submitted.connect(_on_inline_confirm)
	_inline_edit.focus_exited.connect(_cancel_inline_edit)
	_piano_area.add_child(_inline_edit)
	_inline_edit.grab_focus()


func _make_edit_style() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = COLOR_EDIT_BG
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = COLOR_EDIT_BORDER
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_right = 2
	s.corner_radius_bottom_left = 2
	return s


func _on_inline_confirm(value: String) -> void:
	var trimmed: String = value.strip_edges()
	if trimmed.is_empty():
		note_map.note_events.erase(_inline_note)
	else:
		note_map.note_events[_inline_note] = trimmed
	notify_property_list_changed()
	_refresh_status()
	_cancel_inline_edit()


func _refresh_status() -> void:
	if _status_label != null:
		_status_label.text = _build_status_text()


func _y_to_note(y: float) -> int:
	var note: int = TOP_NOTE - int((y - CANVAS_PAD_TOP) / KEY_HEIGHT)
	return clampi(note, BOTTOM_NOTE, TOP_NOTE)
