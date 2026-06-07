@tool
extends Control

const PAD: float = 8.0
const ROW_H: float = 18.0
const BAR_H: float = 14.0

var profile: XedatsDistanceBandProfile = null

var _test_distance: float = 12.0
var _dragging_slider: bool = false
var _slider_rect: Rect2 = Rect2()


func _ready() -> void:
	custom_minimum_size = Vector2(0, _compute_height())
	if profile != null and not profile.changed.is_connected(_on_profile_changed):
		profile.changed.connect(_on_profile_changed)


func _compute_height() -> float:
	return PAD * 5 + ROW_H * 7 + 44.0


func _on_profile_changed() -> void:
	queue_redraw()


func _draw() -> void:
	if profile == null:
		return

	var w: float = size.x - PAD * 2
	var y: float = PAD

	# ── Draw background ──────────────────────────────────────────────
	draw_rect(Rect2(PAD, y, w, _compute_height() - PAD * 2), Color(0.12, 0.12, 0.15, 0.6), true)
	y += 6.0

	# ── Header ──────────────────────────────────────────────────────
	draw_string(get_theme_default_font(), Vector2(PAD + 4, y + 14), "Distance Band Profile",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.85, 0.9))
	y += ROW_H

	# ── Band ruler ───────────────────────────────────────────────────
	var near_max: float = profile.near_max_distance
	var mid_max: float = profile.mid_max_distance
	var ruler_w: float = w - 8
	var ruler_y: float = y
	var ruler_h: float = 24.0

	# Normalize bands: scale so far band cap = mid_max * 2 or 48 min
	var far_cap: float = max(mid_max * 2.0, 48.0)
	var near_frac: float = near_max / far_cap
	var mid_frac: float = (mid_max - near_max) / far_cap
	var far_frac: float = 1.0 - near_frac - mid_frac

	var x0: float = PAD + 4
	var nr_x: float = x0
	var nr_w: float = ruler_w * near_frac
	var mr_x: float = nr_x + nr_w
	var mr_w: float = ruler_w * mid_frac
	var fr_x: float = mr_x + mr_w
	var fr_w: float = ruler_w - (nr_w + mr_w)

	draw_rect(Rect2(nr_x, ruler_y, nr_w, ruler_h), Color(0.25, 0.7, 0.35, 0.8), true)
	draw_rect(Rect2(mr_x, ruler_y, mr_w, ruler_h), Color(0.75, 0.65, 0.2, 0.8), true)
	draw_rect(Rect2(fr_x, ruler_y, fr_w, ruler_h), Color(0.7, 0.3, 0.25, 0.8), true)

	# Band labels
	var font: Font = get_theme_default_font()
	var font_size: int = 10
	var fg: Color = Color(0.95, 0.95, 0.98)

	draw_string(font, Vector2(nr_x + 4, ruler_y + 16), "Near", HORIZONTAL_ALIGNMENT_LEFT, nr_w - 8, font_size, fg)
	draw_string(font, Vector2(mr_x + 4, ruler_y + 16), "Mid",  HORIZONTAL_ALIGNMENT_LEFT, mr_w - 8, font_size, fg)
	draw_string(font, Vector2(fr_x + 4, ruler_y + 16), "Far",  HORIZONTAL_ALIGNMENT_LEFT, fr_w - 8, font_size, fg)

	# Scale labels below ruler
	var label_y: float = ruler_y + ruler_h + 2
	var dim: Color = Color(0.6, 0.6, 0.65)
	draw_string(font, Vector2(nr_x, label_y), "0m", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, dim)
	var mid_label: String = "%dm" % near_max
	draw_string(font, Vector2(mr_x, label_y), mid_label, HORIZONTAL_ALIGNMENT_CENTER, mr_w, font_size, dim)
	var far_label: String = "%dm+" % mid_max
	draw_string(font, Vector2(fr_x, label_y), far_label, HORIZONTAL_ALIGNMENT_LEFT, fr_w, font_size, dim)

	y = label_y + 16.0

	# ── Separator ────────────────────────────────────────────────────
	var sep_y: float = y
	var dim_line: Color = Color(0.35, 0.35, 0.4, 0.5)
	draw_rect(Rect2(PAD + 4, sep_y, w - 8, 1), dim_line, true)
	y += 6.0

	# ── Gain scales ──────────────────────────────────────────────────
	y = _draw_bar_row(y, "Gain", [
		["Near", profile.near_gain_scale, Color(0.25, 0.7, 0.35)],
		["Mid",  profile.mid_gain_scale,  Color(0.75, 0.65, 0.2)],
		["Far",  profile.far_gain_scale,  Color(0.7, 0.3, 0.25)],
	], font, font_size, w, fg, dim, PAD)
	y += 2.0

	# ── Rate scales ─────────────────────────────────────────────────
	y = _draw_bar_row(y, "Rate", [
		["Near", profile.near_rate_scale, Color(0.25, 0.7, 0.35)],
		["Mid",  profile.mid_rate_scale,  Color(0.75, 0.65, 0.2)],
		["Far",  profile.far_rate_scale,  Color(0.7, 0.3, 0.25)],
	], font, font_size, w, fg, dim, PAD)

	# ── Separator ────────────────────────────────────────────────────
	draw_rect(Rect2(PAD + 4, y, w - 8, 1), dim_line, true)
	y += 6.0

	# ── Test distance slider ─────────────────────────────────────────
	var slider_label: String = "Test distance:"
	draw_string(font, Vector2(PAD + 4, y + 12), slider_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)
	var dist_str: String = "%0.1f m" % _test_distance
	var label_w: float = font.get_string_size(dist_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(w + PAD - label_w - 4, y + 12), dist_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)

	y += 18.0

	var track_w: float = w - 8
	var track_h: float = 6.0
	var track_x: float = PAD + 4
	var track_y: float = y
	_slider_rect = Rect2(track_x, track_y - 4, track_w, track_h + 8)

	# Track background
	draw_rect(Rect2(track_x, track_y, track_w, track_h), Color(0.25, 0.25, 0.28), true)

	# Track fill up to current position
	var fill_frac: float = clamp(_test_distance / far_cap, 0.0, 1.0)
	var fill_w: float = track_w * fill_frac
	draw_rect(Rect2(track_x, track_y, fill_w, track_h), Color(0.4, 0.6, 0.9), true)

	# Thumb
	var thumb_x: float = track_x + fill_w
	draw_rect(Rect2(thumb_x - 4, track_y - 3, 8, track_h + 6), Color(0.85, 0.85, 0.9), true)

	y += track_h + 6.0

	# Active band label
	var band: String = profile.band_label_at(_test_distance)
	var gain: float = profile.gain_scale_at(_test_distance)
	var active_color: Color
	match band:
		"near": active_color = Color(0.25, 0.7, 0.35)
		"mid":  active_color = Color(0.75, 0.65, 0.2)
		_:      active_color = Color(0.7, 0.3, 0.25)
	var active_str: String = "Active band: %s (gain x%0.2f)" % [band.capitalize(), gain]
	draw_string(font, Vector2(PAD + 4, y + 12), active_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, active_color)


func _draw_bar_row(y: float, label: String, bands: Array, font: Font, font_size: int, w: float, fg: Color, dim: Color, pad: float) -> float:
	var x: float = pad + 4
	draw_string(font, Vector2(x, y + 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, dim)
	x += 40.0

	var bar_max_w: float = w - 48.0
	for band_data: Array in bands:
		var name: String = band_data[0]
		var value: float = band_data[1]
		var color: Color = band_data[2]

		var bar_w: float = bar_max_w * clamp(value, 0.0, 1.0) * 0.5
		var bar_h: float = BAR_H

		draw_rect(Rect2(x, y + 2, bar_w, bar_h), color, true)

		var text: String = "%s %0.2f" % [name, value]
		var tx: float = x + bar_w + 6.0
		draw_string(font, Vector2(tx, y + 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)

		x += bar_max_w * 0.5 + 8.0

	return y + ROW_H


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _slider_rect.has_point(mb.position):
				_dragging_slider = true
				_set_test_from_mouse(mb.position.x)
				accept_event()
			elif not mb.pressed:
				_dragging_slider = false

	if event is InputEventMouseMotion and _dragging_slider:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_set_test_from_mouse(mm.position.x)
		accept_event()


func _set_test_from_mouse(mx: float) -> void:
	if profile == null:
		return
	var far_cap: float = max(profile.mid_max_distance * 2.0, 48.0)
	var t: float = (mx - _slider_rect.position.x) / _slider_rect.size.x
	_test_distance = clamp(t * far_cap, 0.0, far_cap)
	queue_redraw()
