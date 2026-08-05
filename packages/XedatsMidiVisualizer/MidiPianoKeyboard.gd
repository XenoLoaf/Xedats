@tool
class_name MidiPianoKeyboard
extends Control

## Horizontal piano keyboard widget — clickable, velocity-sensitive, zoomable.
##
## White and black keys are drawn as separate overlay layers:
## white keys tile the full height, black keys sit on top at 60% height,
## positioned in the correct piano grouping (groups of 2 and 3 separated
## by the E/F and B/C gaps).
##
## Supports range selection with octave presets and scroll navigation.
## Connects to [XedatsMIDIInput] signals to light up keys on hardware
## MIDI input and emits signals when keys are clicked with the mouse.

# ── MIDI ranges ───────────────────────────────────
const NOTE_0: int = 0
const NOTE_127: int = 127
const PIANO_88_LOW: int = 21
const PIANO_88_HIGH: int = 108

# ── White/black key indices within a 12-semitone octave starting at C ─
const WHITE_IN_OCTAVE: Array[int] = [0, 2, 4, 5, 7, 9, 11]
const BLACK_IN_OCTAVE: Array[int] = [1, 3, 6, 8, 10]

# ── Note names ────────────────────────────────────
const NOTE_NAMES: Array[String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# ── Geometry ──────────────────────────────────────
const MIN_KEY_HEIGHT: float = 80.0
const WHITE_KEY_MIN_WIDTH: float = 20.0
const BLACK_KEY_HEIGHT_FRAC: float = 0.6
const BLACK_KEY_WIDTH_FRAC: float = 0.55
const CONTROLS_HEIGHT: int = 28
const LABEL_FONT_SIZE: int = 10
const NAV_FONT_SIZE: int = 12
const OCTAVE_SEP_WIDTH: float = 1.5

# ── Colors ────────────────────────────────────────
const COLOR_BG: Color = Color(0.10, 0.09, 0.08)
const COLOR_WHITE_UP: Color = Color(0.96, 0.95, 0.93)
const COLOR_WHITE_DOWN: Color = Color(0.30, 0.50, 0.82)
const COLOR_WHITE_BORDER: Color = Color(0.55, 0.53, 0.50)
const COLOR_BLACK_UP: Color = Color(0.08, 0.07, 0.06)
const COLOR_BLACK_DOWN: Color = Color(0.20, 0.38, 0.72)
const COLOR_BLACK_BORDER: Color = Color(0.04, 0.03, 0.02)
const COLOR_BLACK_TOP: Color = Color(0.16, 0.15, 0.14)
const COLOR_LABEL: Color = Color(0.55, 0.53, 0.50)
const COLOR_OCTAVE_LABEL: Color = Color(0.72, 0.72, 0.67)
const COLOR_OCTAVE_DIVIDER: Color = Color(0.35, 0.33, 0.30)
const COLOR_HOVER: Color = Color(1.0, 1.0, 1.0, 0.10)
const COLOR_CONTROLS_BG: Color = Color(0.16, 0.15, 0.14)
const COLOR_NAV_TEXT: Color = Color(0.8, 0.8, 0.75)
const COLOR_NAV_DISABLED: Color = Color(0.4, 0.4, 0.35)

# ── Range presets ─────────────────────────────────
enum RangePreset {
	FULL_128,
	PIANO_88,
	OCTAVES_6,
	OCTAVES_3,
	OCTAVES_1,
}

const PRESET_LABELS: Dictionary = {
	RangePreset.FULL_128: "Full (128 keys)",
	RangePreset.PIANO_88: "Piano (88 keys)",
	RangePreset.OCTAVES_6: "C0-C6 (6 octaves)",
	RangePreset.OCTAVES_3: "C2-C5 (3 octaves)",
	RangePreset.OCTAVES_1: "C3-C4 (1 octave)",
}

# ── Signals ───────────────────────────────────────

signal key_pressed(note: int, velocity: int)
signal key_released(note: int)

# ── Exports ───────────────────────────────────────

@export var range_preset: RangePreset = RangePreset.PIANO_88
@export var custom_low_note: int = PIANO_88_LOW
@export var custom_high_note: int = PIANO_88_HIGH
@export var mouse_enabled: bool = true
@export var interactive: bool = true

## Black key width as a fraction of white key width. Adjust to tune the overlay fit.
@export_range(0.2, 1.0, 0.01) var black_key_width_frac: float = 0.50:
	set(v):
		black_key_width_frac = v
		_invalidate()

## Black key height as a fraction of white key height (key area).
@export_range(0.2, 1.0, 0.01) var black_key_height_frac: float = 0.60:
	set(v):
		black_key_height_frac = v
		_invalidate()

## Horizontal offset for all black keys, as a fraction of white key width.
## 0.0 = centered on gap midpoint. Negative = shift left, positive = shift right.
@export_range(-0.5, 0.5, 0.001) var black_key_offset_x: float = 0.0:
	set(v):
		black_key_offset_x = v
		queue_redraw()

## Vertical offset for all black keys, as a fraction of key area height.
@export_range(-0.2, 0.2, 0.001) var black_key_offset_y: float = 0.0:
	set(v):
		black_key_offset_y = v
		queue_redraw()

# ── State ─────────────────────────────────────────

var _visible_low: int = PIANO_88_LOW
var _visible_high: int = PIANO_88_HIGH
var _pressed_keys: Dictionary = {}
var _hovered_note: int = -1
var _mouse_down_note: int = -1
var _white_key_width: float = 0.0
var _black_key_width: float = 0.0
var _black_key_height: float = 0.0
var _key_area_height: float = 0.0
var _visible_whites: int = 0
var _white_start_idx: int = 0

var _zoom_button: Button = null
var _nav_prev: Button = null
var _nav_next: Button = null
var _nav_prev_octave: Button = null
var _nav_next_octave: Button = null
var _range_label: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _invalidate() -> void:
	_recompute_layout()


func _ready() -> void:
	_apply_preset(range_preset)


func _draw() -> void:
	if size.x <= 0.0 or _key_area_height <= 0.0:
		return
	_draw_background()
	_draw_octave_dividers()
	_draw_white_keys_layer()
	_draw_black_keys_layer()
	_draw_labels()
	if _hovered_note >= _visible_low and _hovered_note <= _visible_high:
		_draw_hover()


func _get_minimum_size() -> Vector2:
	return Vector2(200.0, MIN_KEY_HEIGHT + CONTROLS_HEIGHT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_recompute_layout()


# ── Public API ────────────────────────────────────

func press_key(note: int, velocity: int = 100) -> void:
	if note < 0 or note > NOTE_127:
		return
	_pressed_keys[note] = velocity
	queue_redraw()
	key_pressed.emit(note, velocity)


func release_key(note: int) -> void:
	if not _pressed_keys.has(note):
		return
	_pressed_keys.erase(note)
	queue_redraw()
	key_released.emit(note)


func release_all() -> void:
	var notes: Array[int] = _pressed_keys.keys().duplicate()
	for note: int in notes:
		release_key(note)


func is_pressed(note: int) -> bool:
	return _pressed_keys.has(note)


func get_pressed_notes() -> Array[int]:
	return Array(_pressed_keys.keys(), TYPE_INT, &"", null)


func set_visible_range(low: int, high: int) -> void:
	_visible_low = clampi(low, NOTE_0, NOTE_127)
	_visible_high = clampi(high, maxi(low + 12, NOTE_0 + 12), NOTE_127)
	_recompute_layout()
	_update_controls()


func shift_range(by_octaves: int) -> void:
	var shift: int = by_octaves * 12
	set_visible_range(_visible_low + shift, _visible_high + shift)


# ── Mouse input ───────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if not mouse_enabled:
		return

	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		_hovered_note = _xy_to_note(motion.position)
		if _mouse_down_note >= 0 and interactive and _hovered_note >= 0 and _hovered_note != _mouse_down_note:
			release_key(_mouse_down_note)
			var vel: int = _y_to_velocity(motion.position.y)
			press_key(_hovered_note, vel)
			_mouse_down_note = _hovered_note
		queue_redraw()
		return

	var button_event: InputEventMouseButton = event as InputEventMouseButton
	if button_event != null:
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			if button_event.pressed:
				var note: int = _xy_to_note(button_event.position)
				if note >= 0 and interactive:
					var vel: int = _y_to_velocity(button_event.position.y)
					press_key(note, vel)
					_mouse_down_note = note
			else:
				if _mouse_down_note >= 0:
					release_key(_mouse_down_note)
					_mouse_down_note = -1
		queue_redraw()
		return


func _mouse_exited() -> void:
	_hovered_note = -1
	if _mouse_down_note >= 0:
		release_key(_mouse_down_note)
		_mouse_down_note = -1
	queue_redraw()


# ── Layout ────────────────────────────────────────

func _apply_preset(preset: RangePreset) -> void:
	range_preset = preset
	match preset:
		RangePreset.FULL_128:
			set_visible_range(NOTE_0, NOTE_127)
		RangePreset.PIANO_88:
			set_visible_range(PIANO_88_LOW, PIANO_88_HIGH)
		RangePreset.OCTAVES_6:
			set_visible_range(12, 83)
		RangePreset.OCTAVES_3:
			set_visible_range(36, 71)
		RangePreset.OCTAVES_1:
			set_visible_range(48, 59)


func _count_white_keys(low: int, high: int) -> int:
	var count: int = 0
	for n: int in range(low, high + 1):
		if n % 12 in WHITE_IN_OCTAVE:
			count += 1
	return count


func _count_white_keys_before(note: int) -> int:
	var count: int = 0
	for n: int in range(_visible_low, note):
		if n % 12 in WHITE_IN_OCTAVE:
			count += 1
	return count


func _recompute_layout() -> void:
	if size.x <= 0.0:
		return

	_key_area_height = size.y - CONTROLS_HEIGHT
	_visible_whites = _count_white_keys(_visible_low, _visible_high)
	_white_key_width = size.x / float(maxi(_visible_whites, 1))
	_black_key_width = _white_key_width * black_key_width_frac
	_black_key_height = _key_area_height * black_key_height_frac

	_build_controls()
	queue_redraw()


# ── Drawing: background + octave dividers ─────────

func _draw_background() -> void:
	draw_rect(Rect2(0.0, 0.0, size.x, _key_area_height), COLOR_BG)
	draw_rect(Rect2(0.0, _key_area_height, size.x, CONTROLS_HEIGHT), COLOR_CONTROLS_BG)


func _draw_octave_dividers() -> void:
	for note: int in range(_visible_low, _visible_high + 1):
		if note % 12 != 0:
			continue
		var x: float = float(_count_white_keys_before(note)) * _white_key_width
		if x <= 0.0:
			continue
		# Subtle tick marks — not full-height dividers, so all white keys look uniform
		draw_line(Vector2(x, 0.0), Vector2(x, 5.0), COLOR_OCTAVE_DIVIDER, 1.0)
		draw_line(Vector2(x, _key_area_height), Vector2(x, _key_area_height - 5.0), COLOR_OCTAVE_DIVIDER, 1.0)


# ── Drawing: white key layer ──────────────────────
#
# White keys tile contiguously at integer positions 0, 1, 2, ... (N-1)
# where N = number of white keys in the visible range.
# Each white key = one integer unit of _white_key_width.

func _draw_white_keys_layer() -> void:
	for note: int in range(_visible_low, _visible_high + 1):
		if not (note % 12 in WHITE_IN_OCTAVE):
			continue
		var x: float = float(_count_white_keys_before(note)) * _white_key_width
		var w: float = _white_key_width
		var rect: Rect2 = Rect2(x, 0.0, w, _key_area_height)
		var is_down: bool = _pressed_keys.has(note)
		var color: Color = COLOR_WHITE_DOWN if is_down else COLOR_WHITE_UP
		draw_rect(rect, color)
		draw_rect(rect, COLOR_WHITE_BORDER, false, 0.5)

		# Subtle bottom shadow for depth
		if not is_down:
			draw_rect(Rect2(x + 1.0, _key_area_height - 3.0, w - 2.0, 3.0),
				Color(0.0, 0.0, 0.0, 0.06))


# ── Drawing: black key layer (overlay) ────────────
#
# Black keys sit ON TOP of white keys at the same Y origin, but shorter.
# Position system: white keys at integer indices (0, 1, 2, ...),
# black keys centered at half-integer positions (0.5, 1.5, 3.5, 4.5, 5.5, ...).
# Gaps at E/F (no black key after white index 2) and B/C create the
# visible grouping of 2 and 3 black keys.

func _draw_black_keys_layer() -> void:
	for note: int in range(_visible_low, _visible_high + 1):
		if not (note % 12 in BLACK_IN_OCTAVE):
			continue

		var whites_before: int = _count_white_keys_before(note)
		var center_x: float = (float(whites_before) - 0.5) * _white_key_width
		var key_x: float = center_x - _black_key_width * 0.5 + black_key_offset_x * _white_key_width
		var key_y: float = black_key_offset_y * _key_area_height
		var key_right: float = key_x + _black_key_width

		var is_down: bool = _pressed_keys.has(note)

		# Drop shadow (underlay — drawn first so white keys show through below)
		var shadow: float = 2.0
		draw_rect(Rect2(key_x + shadow, key_y, _black_key_width, _black_key_height + shadow),
			Color(0.0, 0.0, 0.0, 0.3))

		# Key body
		var body_color: Color = COLOR_BLACK_DOWN if is_down else COLOR_BLACK_UP
		draw_rect(Rect2(key_x, key_y, _black_key_width, _black_key_height), body_color)

		# Top face highlight (3D bevel)
		var top_color: Color = Color(0.25, 0.24, 0.22) if not is_down else Color(0.35, 0.50, 0.78)
		draw_rect(Rect2(key_x + 2.0, key_y + 1.0, maxf(_black_key_width - 4.0, 1.0), 3.0), top_color)

		# Left edge highlight
		draw_line(Vector2(key_x + 1.0, key_y + 2.0), Vector2(key_x + 1.0, key_y + _black_key_height - 2.0),
			Color(0.20, 0.19, 0.17) if not is_down else Color(0.30, 0.48, 0.72), 1.0)

		# Bottom edge where black meets white
		var bottom_y: float = key_y + _black_key_height
		if not is_down:
			draw_line(Vector2(key_x, bottom_y), Vector2(key_right, bottom_y),
				COLOR_BLACK_BORDER, 1.5)
		else:
			draw_rect(Rect2(key_x, bottom_y, _black_key_width, 2.0),
				Color(0.30, 0.48, 0.72, 0.5))


# ── Drawing: labels ───────────────────────────────

func _draw_labels() -> void:
	if _white_key_width < 22.0:
		return
	var font: Font = get_theme_default_font()

	# C-note octave labels
	for note: int in range(_visible_low, _visible_high + 1):
		if note % 12 != 0:
			continue
		var x: float = float(_count_white_keys_before(note)) * _white_key_width
		var octave: int = note / 12 - 1
		var label: String = "C%d" % octave
		draw_string(font, Vector2(x + 3.0, _key_area_height - 4.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_FONT_SIZE, COLOR_OCTAVE_LABEL)

	# Middle C marker
	var c4: int = 60
	if c4 >= _visible_low and c4 <= _visible_high:
		var cx: float = float(_count_white_keys_before(c4)) * _white_key_width
		draw_string(font, Vector2(cx + 4.0, 11.0), "Middle C",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, COLOR_LABEL)


# ── Drawing: hover highlight ──────────────────────

func _draw_hover() -> void:
	var is_white: bool = _hovered_note % 12 in WHITE_IN_OCTAVE
	var x: float
	var w: float
	var h: float

	if is_white:
		x = float(_count_white_keys_before(_hovered_note)) * _white_key_width
		w = _white_key_width
		h = _key_area_height
	else:
		var center_x: float = (float(_count_white_keys_before(_hovered_note)) - 0.5) * _white_key_width
		x = center_x - _black_key_width * 0.5 + black_key_offset_x * _white_key_width
		w = _black_key_width
		h = _black_key_height

	draw_rect(Rect2(x, black_key_offset_y * _key_area_height if not is_white else 0.0, w, h), COLOR_HOVER)


# ── Hit testing ───────────────────────────────────

func _xy_to_note(pos: Vector2) -> int:
	if pos.y < 0.0 or pos.y > _key_area_height:
		return -1

	# Black keys first (top layer, upper area)
	var bk_y: float = black_key_offset_y * _key_area_height
	if pos.y >= bk_y and pos.y <= bk_y + _black_key_height:
		for note: int in range(_visible_low, _visible_high + 1):
			if not (note % 12 in BLACK_IN_OCTAVE):
				continue
			var center_x: float = (float(_count_white_keys_before(note)) - 0.5) * _white_key_width
			var key_x: float = center_x - _black_key_width * 0.5 + black_key_offset_x * _white_key_width
			var key_y: float = black_key_offset_y * _key_area_height
			if pos.x >= key_x and pos.x <= key_x + _black_key_width and pos.y >= key_y and pos.y <= key_y + _black_key_height:
				return note

	# White keys
	var white_idx: int = int(pos.x / _white_key_width)
	if white_idx < 0 or white_idx >= _visible_whites:
		return -1

	var count: int = 0
	for note: int in range(_visible_low, _visible_high + 1):
		if note % 12 in WHITE_IN_OCTAVE:
			if count == white_idx:
				return note
			count += 1

	return -1


func _y_to_velocity(y: float) -> int:
	var frac: float = clamp(1.0 - y / maxf(_key_area_height, 1.0), 0.0, 1.0)
	return int(round(frac * 127.0))


# ── Controls bar ──────────────────────────────────

func _build_controls() -> void:
	_destroy_controls()

	var bar_y: float = _key_area_height

	_zoom_button = Button.new()
	_zoom_button.text = PRESET_LABELS.get(range_preset, "Custom")
	_zoom_button.flat = true
	_zoom_button.position = Vector2(4.0, bar_y + 3.0)
	_zoom_button.size = Vector2(130.0, CONTROLS_HEIGHT - 6.0)
	_zoom_button.pressed.connect(_cycle_preset)
	_zoom_button.add_theme_color_override("font_color", COLOR_NAV_TEXT)
	_zoom_button.add_theme_font_size_override("font_size", 10)
	add_child(_zoom_button)

	var nav_x: float = _zoom_button.position.x + _zoom_button.size.x + 10.0
	var btn_w: int = 28

	_nav_prev_octave = _make_nav_button("<|", Vector2(nav_x, bar_y + 3.0), Vector2(btn_w, CONTROLS_HEIGHT - 6.0))
	_nav_prev_octave.pressed.connect(func(): shift_range(-1))
	nav_x += btn_w + 3.0

	_nav_prev = _make_nav_button("<", Vector2(nav_x, bar_y + 3.0), Vector2(btn_w, CONTROLS_HEIGHT - 6.0))
	_nav_prev.pressed.connect(func(): shift_range(-((_visible_high - _visible_low) / 12)))
	nav_x += btn_w + 6.0

	_range_label = Label.new()
	_range_label.text = _make_range_text()
	_range_label.position = Vector2(nav_x, bar_y + 4.0)
	_range_label.size = Vector2(160.0, CONTROLS_HEIGHT - 8.0)
	_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_range_label.add_theme_color_override("font_color", COLOR_NAV_TEXT)
	_range_label.add_theme_font_size_override("font_size", 11)
	add_child(_range_label)
	nav_x += 166.0

	_nav_next = _make_nav_button(">", Vector2(nav_x, bar_y + 3.0), Vector2(btn_w, CONTROLS_HEIGHT - 6.0))
	_nav_next.pressed.connect(func(): shift_range((_visible_high - _visible_low) / 12))
	nav_x += btn_w + 3.0

	_nav_next_octave = _make_nav_button("|>", Vector2(nav_x, bar_y + 3.0), Vector2(btn_w, CONTROLS_HEIGHT - 6.0))
	_nav_next_octave.pressed.connect(func(): shift_range(1))

	_update_nav_state()


func _destroy_controls() -> void:
	for btn: Button in [_zoom_button, _nav_prev, _nav_next, _nav_prev_octave, _nav_next_octave]:
		if btn != null:
			btn.queue_free()
	if _range_label != null:
		_range_label.queue_free()
	_zoom_button = null
	_nav_prev = null
	_nav_next = null
	_nav_prev_octave = null
	_nav_next_octave = null
	_range_label = null


func _update_controls() -> void:
	if _zoom_button != null:
		_zoom_button.text = PRESET_LABELS.get(range_preset, "Custom")
	if _range_label != null:
		_range_label.text = _make_range_text()
	_update_nav_state()


func _update_nav_state() -> void:
	var can_prev: bool = _visible_low > NOTE_0
	var can_next: bool = _visible_high < NOTE_127
	for btn: Dictionary in [
		{"btn": _nav_prev, "enabled": can_prev},
		{"btn": _nav_next, "enabled": can_next},
		{"btn": _nav_prev_octave, "enabled": can_prev},
		{"btn": _nav_next_octave, "enabled": can_next},
	]:
		var b: Button = btn.btn as Button
		if b == null:
			continue
		b.disabled = not btn.enabled
		b.add_theme_color_override("font_color", COLOR_NAV_TEXT if btn.enabled else COLOR_NAV_DISABLED)


func _make_nav_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.flat = true
	btn.position = pos
	btn.size = sz
	btn.add_theme_color_override("font_color", COLOR_NAV_TEXT)
	btn.add_theme_font_size_override("font_size", NAV_FONT_SIZE)
	add_child(btn)
	return btn


func _make_range_text() -> String:
	return "%s – %s" % [_note_name(_visible_low), _note_name(_visible_high)]


func _note_name(note: int) -> String:
	var octave: int = note / 12 - 1
	return "%s%d" % [NOTE_NAMES[note % 12], octave]


# ── Navigation ────────────────────────────────────

func _cycle_preset() -> void:
	var presets: Array = RangePreset.values()
	var idx: int = presets.find(range_preset)
	idx = (idx + 1) % presets.size()
	_apply_preset(presets[idx])
