@tool
extends VBoxContainer

const PROFILE_EXT: String = ".tres"

var _profile_dir: String = ""
var _profiles: Dictionary = {}
var _selected_path: String = ""
var _dirty: bool = false

# --- UI references ---
var _dir_label: Label
var _dir_edit: LineEdit
var _file_list: ItemList
var _detail_container: VBoxContainer
var _no_selection_label: Label
var _save_button: Button

# Form fields
var _propagation_id_edit: LineEdit
var _probe_region_id_edit: LineEdit
var _gain_mult_slider: HSlider
var _gain_mult_label: Label
var _override_occ_cb: CheckBox
var _enable_occ_cb: CheckBox
var _occ_intensity_slider: HSlider
var _occ_intensity_label: Label
var _override_df_cb: CheckBox
var _enable_df_cb: CheckBox
var _lowpass_spin: SpinBox
var _highpass_spin: SpinBox
var _reverb_wet_slider: HSlider
var _reverb_wet_label: Label
var _reverb_room_slider: HSlider
var _reverb_room_label: Label
var _target_bus_edit: LineEdit


func _ready() -> void:
	if not ClassDB.class_exists(&"XedatsGLTFConfig"):
		_config_not_found_ui()
		return

	_profile_dir = XedatsGLTFConfig.precomputed_propagation_root()
	_build_ui()
	_refresh_list()


func _config_not_found_ui() -> void:
	var label: Label = Label.new()
	label.text = "XedatsGLTFConfig not found.\nEnsure Xedats scripts are in the project."
	add_child(label)


func _build_ui() -> void:
	add_theme_constant_override("separation", 4)

	# ── Header ──────────────────────────────────────────────────────
	var header := Label.new()
	header.text = "Propagation Profile Baker"
	header.add_theme_font_size_override("font_size", 14)
	add_child(header)

	# ── Directory bar ────────────────────────────────────────────────
	var dir_hbox := HBoxContainer.new()
	add_child(dir_hbox)

	_dir_label = Label.new()
	_dir_label.text = "Dir:"
	_dir_label.custom_minimum_size.x = 28
	dir_hbox.add_child(_dir_label)

	_dir_edit = LineEdit.new()
	_dir_edit.text = _profile_dir
	_dir_edit.tooltip_text = "Profile save directory"
	_dir_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir_hbox.add_child(_dir_edit)

	var browse_btn := Button.new()
	browse_btn.text = "..."
	browse_btn.tooltip_text = "Browse profile directory"
	browse_btn.pressed.connect(_on_browse)
	dir_hbox.add_child(browse_btn)

	var refresh_btn := Button.new()
	refresh_btn.text = "Refresh"
	refresh_btn.pressed.connect(_refresh_list)
	dir_hbox.add_child(refresh_btn)

	# ── Body: split profile list + detail ────────────────────────────
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	# Left: profile list
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size.x = 140
	split.add_child(left_vbox)

	var list_header := Label.new()
	list_header.text = "Profiles"
	left_vbox.add_child(list_header)

	_file_list = ItemList.new()
	_file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_file_list.item_selected.connect(_on_file_selected)
	_file_list.nothing_selected.connect(_on_nothing_selected)
	left_vbox.add_child(_file_list)

	var list_btn_hbox := HBoxContainer.new()
	left_vbox.add_child(list_btn_hbox)

	var new_btn := Button.new()
	new_btn.text = "Create New"
	new_btn.pressed.connect(_on_create_new)
	list_btn_hbox.add_child(new_btn)

	var delete_btn := Button.new()
	delete_btn.text = "Delete"
	delete_btn.pressed.connect(_on_delete)
	list_btn_hbox.add_child(delete_btn)

	# Right: detail form (scrollable)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)

	_detail_container = VBoxContainer.new()
	_detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_detail_container)

	_no_selection_label = Label.new()
	_no_selection_label.text = "Select a profile to edit"
	_no_selection_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	_detail_container.add_child(_no_selection_label)

	# Detail form (hidden until a profile is selected)
	_build_detail_form()
	_set_detail_visible(false)


func _build_detail_form() -> void:
	# ── Identity ────────────────────────────────────────────────────
	var id_header := Label.new()
	id_header.text = "Identity"
	id_header.add_theme_font_size_override("font_size", 12)
	id_header.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_detail_container.add_child(id_header)
	_detail_container.add_child(_hr())

	_propagation_id_edit = LineEdit.new()
	_propagation_id_edit.placeholder_text = "propagation_id (used as filename)"
	_propagation_id_edit.tooltip_text = "Lookup key referenced by glTF extras (xedats_precomputed_id)"
	_propagation_id_edit.text_changed.connect(_mark_dirty)
	_detail_container.add_child(_labeled("Propagation ID", _propagation_id_edit))

	_probe_region_id_edit = LineEdit.new()
	_probe_region_id_edit.placeholder_text = "probe_region_id (optional fallback)"
	_probe_region_id_edit.tooltip_text = "Fallback lookup key when precomputed_id is absent"
	_probe_region_id_edit.text_changed.connect(_mark_dirty)
	_detail_container.add_child(_labeled("Probe Region ID", _probe_region_id_edit))

	# ── Gain ─────────────────────────────────────────────────────────
	_detail_container.add_child(_section_gap())
	var gain_header := Label.new()
	gain_header.text = "Gain"
	gain_header.add_theme_font_size_override("font_size", 12)
	gain_header.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_detail_container.add_child(gain_header)
	_detail_container.add_child(_hr())

	var gain_hbox := HBoxContainer.new()
	_gain_mult_label = Label.new()
	_gain_mult_label.text = "1.00"
	_gain_mult_label.custom_minimum_size.x = 36
	_gain_mult_slider = HSlider.new()
	_gain_mult_slider.min_value = 0.0
	_gain_mult_slider.max_value = 2.0
	_gain_mult_slider.step = 0.01
	_gain_mult_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gain_mult_slider.value_changed.connect(_on_gain_changed)
	gain_hbox.add_child(_labeled("Gain Multiplier", _gain_mult_slider))
	gain_hbox.add_child(_gain_mult_label)
	_detail_container.add_child(gain_hbox)

	# ── Occlusion ────────────────────────────────────────────────────
	_detail_container.add_child(_section_gap())
	var occ_header := Label.new()
	occ_header.text = "Occlusion"
	occ_header.add_theme_font_size_override("font_size", 12)
	occ_header.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_detail_container.add_child(occ_header)
	_detail_container.add_child(_hr())

	_override_occ_cb = CheckBox.new()
	_override_occ_cb.text = "Override Enable Occlusion"
	_override_occ_cb.toggled.connect(_on_override_occ_toggled)
	_detail_container.add_child(_override_occ_cb)

	_enable_occ_cb = CheckBox.new()
	_enable_occ_cb.text = "Enable Occlusion"
	_enable_occ_cb.disabled = true
	_detail_container.add_child(_enable_occ_cb)

	var occ_int_hbox := HBoxContainer.new()
	_occ_intensity_label = Label.new()
	_occ_intensity_label.text = "0.50"
	_occ_intensity_label.custom_minimum_size.x = 36
	_occ_intensity_slider = HSlider.new()
	_occ_intensity_slider.min_value = 0.0
	_occ_intensity_slider.max_value = 1.0
	_occ_intensity_slider.step = 0.01
	_occ_intensity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_occ_intensity_slider.value_changed.connect(_on_occ_int_changed)
	occ_int_hbox.add_child(_labeled("Occlusion Intensity", _occ_intensity_slider))
	occ_int_hbox.add_child(_occ_intensity_label)
	_detail_container.add_child(occ_int_hbox)

	# ── Distance Filtering ───────────────────────────────────────────
	_detail_container.add_child(_section_gap())
	var df_header := Label.new()
	df_header.text = "Distance Filtering"
	df_header.add_theme_font_size_override("font_size", 12)
	df_header.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_detail_container.add_child(df_header)
	_detail_container.add_child(_hr())

	_override_df_cb = CheckBox.new()
	_override_df_cb.text = "Override Enable Distance Filtering"
	_override_df_cb.toggled.connect(_on_override_df_toggled)
	_detail_container.add_child(_override_df_cb)

	_enable_df_cb = CheckBox.new()
	_enable_df_cb.text = "Enable Distance Filtering"
	_enable_df_cb.disabled = true
	_detail_container.add_child(_enable_df_cb)

	# ── Audio Filters ────────────────────────────────────────────────
	_detail_container.add_child(_section_gap())
	var filter_header := Label.new()
	filter_header.text = "Audio Filters"
	filter_header.add_theme_font_size_override("font_size", 12)
	filter_header.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_detail_container.add_child(filter_header)
	_detail_container.add_child(_hr())

	_lowpass_spin = SpinBox.new()
	_lowpass_spin.min_value = -1.0
	_lowpass_spin.max_value = 20000.0
	_lowpass_spin.step = 10.0
	_lowpass_spin.tooltip_text = "Low-pass cutoff in Hz (-1 = disabled)"
	_lowpass_spin.value_changed.connect(_mark_dirty)
	_detail_container.add_child(_labeled("Lowpass Hz", _lowpass_spin))

	_highpass_spin = SpinBox.new()
	_highpass_spin.min_value = -1.0
	_highpass_spin.max_value = 20000.0
	_highpass_spin.step = 10.0
	_highpass_spin.tooltip_text = "High-pass cutoff in Hz (-1 = disabled)"
	_highpass_spin.value_changed.connect(_mark_dirty)
	_detail_container.add_child(_labeled("Highpass Hz", _highpass_spin))

	# ── Reverb ───────────────────────────────────────────────────────
	_detail_container.add_child(_section_gap())
	var reverb_header := Label.new()
	reverb_header.text = "Reverb"
	reverb_header.add_theme_font_size_override("font_size", 12)
	reverb_header.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_detail_container.add_child(reverb_header)
	_detail_container.add_child(_hr())

	var rw_hbox := HBoxContainer.new()
	_reverb_wet_label = Label.new()
	_reverb_wet_label.text = "-1.0"
	_reverb_wet_label.custom_minimum_size.x = 36
	_reverb_wet_slider = HSlider.new()
	_reverb_wet_slider.min_value = -1.0
	_reverb_wet_slider.max_value = 1.0
	_reverb_wet_slider.step = 0.01
	_reverb_wet_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reverb_wet_slider.value_changed.connect(_on_rw_changed)
	rw_hbox.add_child(_labeled("Reverb Wet", _reverb_wet_slider))
	rw_hbox.add_child(_reverb_wet_label)
	_detail_container.add_child(rw_hbox)

	var rr_hbox := HBoxContainer.new()
	_reverb_room_label = Label.new()
	_reverb_room_label.text = "-1.0"
	_reverb_room_label.custom_minimum_size.x = 36
	_reverb_room_slider = HSlider.new()
	_reverb_room_slider.min_value = -1.0
	_reverb_room_slider.max_value = 1.0
	_reverb_room_slider.step = 0.01
	_reverb_room_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reverb_room_slider.value_changed.connect(_on_rr_changed)
	rr_hbox.add_child(_labeled("Reverb Room", _reverb_room_slider))
	rr_hbox.add_child(_reverb_room_label)
	_detail_container.add_child(rr_hbox)

	# ── Bus ──────────────────────────────────────────────────────────
	_detail_container.add_child(_section_gap())
	var bus_header := Label.new()
	bus_header.text = "Routing"
	bus_header.add_theme_font_size_override("font_size", 12)
	bus_header.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_detail_container.add_child(bus_header)
	_detail_container.add_child(_hr())

	_target_bus_edit = LineEdit.new()
	_target_bus_edit.placeholder_text = "target_bus_name (empty = auto-derived)"
	_target_bus_edit.text_changed.connect(_mark_dirty)
	_detail_container.add_child(_labeled("Target Bus", _target_bus_edit))

	# ── Save button ──────────────────────────────────────────────────
	_detail_container.add_child(_section_gap())

	_save_button = Button.new()
	_save_button.text = "Save Profile"
	_save_button.pressed.connect(_on_save)
	_detail_container.add_child(_save_button)


func _labeled(text: String, control: Control) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	vbox.add_child(label)
	vbox.add_child(control)
	return vbox


func _hr() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.35, 0.4))
	return sep


func _section_gap() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	return gap


# ── List management ──────────────────────────────────────────────

func _refresh_list() -> void:
	_profile_dir = _dir_edit.text.strip_edges()
	if _profile_dir.is_empty():
		return

	_profiles.clear()
	_file_list.clear()

	var dir: DirAccess = DirAccess.open(_profile_dir)
	if dir == null:
		push_warning("Xedats baking tool: cannot open directory '%s'" % _profile_dir)
		return

	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while not fname.is_empty():
		if fname.ends_with(PROFILE_EXT) and not dir.current_is_dir():
			var full_path: String = _profile_dir.path_join(fname)
			_profiles[full_path] = null
			_file_list.add_item(fname.trim_suffix(PROFILE_EXT))
		fname = dir.get_next()
	dir.list_dir_end()

	_set_detail_visible(false)


func _on_file_selected(index: int) -> void:
	if index < 0 or index >= _file_list.item_count:
		return

	var item_text: String = _file_list.get_item_text(index)
	var full_path: String = _profile_dir.path_join(item_text + PROFILE_EXT)

	# Load profile
	var profile: Resource = ResourceLoader.load(full_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if profile == null or not profile is XedatsPrecomputedPropagationProfile:
		push_warning("Xedats baking tool: failed to load profile at '%s'" % full_path)
		return

	_profiles[full_path] = profile
	_selected_path = full_path
	_dirty = false
	_populate_form(profile as XedatsPrecomputedPropagationProfile)
	_set_detail_visible(true)


func _on_nothing_selected() -> void:
	_selected_path = ""
	_dirty = false
	_set_detail_visible(false)


# ── Form population ─────────────────────────────────────────────

func _populate_form(profile: XedatsPrecomputedPropagationProfile) -> void:
	_propagation_id_edit.text = profile.propagation_id
	_probe_region_id_edit.text = profile.probe_region_id
	_gain_mult_slider.value = profile.gain_multiplier
	_gain_mult_label.text = "%0.2f" % profile.gain_multiplier

	_override_occ_cb.button_pressed = profile.override_enable_occlusion
	_enable_occ_cb.disabled = not profile.override_enable_occlusion
	_enable_occ_cb.button_pressed = profile.enable_occlusion
	_occ_intensity_slider.value = profile.occlusion_intensity
	_occ_intensity_label.text = "%0.2f" % profile.occlusion_intensity

	_override_df_cb.button_pressed = profile.override_enable_distance_filtering
	_enable_df_cb.disabled = not profile.override_enable_distance_filtering
	_enable_df_cb.button_pressed = profile.enable_distance_filtering

	_lowpass_spin.value = profile.lowpass_cutoff_hz
	_highpass_spin.value = profile.highpass_cutoff_hz
	_reverb_wet_slider.value = profile.reverb_wet
	_reverb_wet_label.text = "%0.2f" % profile.reverb_wet
	_reverb_room_slider.value = profile.reverb_room_size
	_reverb_room_label.text = "%0.2f" % profile.reverb_room_size
	_target_bus_edit.text = profile.target_bus_name


func _set_detail_visible(visible: bool) -> void:
	_no_selection_label.visible = not visible
	for child: Node in _detail_container.get_children():
		if child != _no_selection_label:
			child.visible = visible


# ── Form interactions ──────────────────────────────────────────

func _on_gain_changed(value: float) -> void:
	_gain_mult_label.text = "%0.2f" % value
	_mark_dirty()


func _on_occ_int_changed(value: float) -> void:
	_occ_intensity_label.text = "%0.2f" % value
	_mark_dirty()


func _on_override_occ_toggled(enabled: bool) -> void:
	_enable_occ_cb.disabled = not enabled
	_mark_dirty()


func _on_override_df_toggled(enabled: bool) -> void:
	_enable_df_cb.disabled = not enabled
	_mark_dirty()


func _on_rw_changed(value: float) -> void:
	_reverb_wet_label.text = "%0.2f" % value
	_mark_dirty()


func _on_rr_changed(value: float) -> void:
	_reverb_room_label.text = "%0.2f" % value
	_mark_dirty()


func _mark_dirty() -> void:
	_dirty = true


# ── Actions ─────────────────────────────────────────────────────

func _on_create_new() -> void:
	var profile: XedatsPrecomputedPropagationProfile = XedatsPrecomputedPropagationProfile.new()
	profile.propagation_id = ""
	profile.probe_region_id = ""
	profile.gain_multiplier = 1.0
	profile.override_enable_occlusion = false
	profile.enable_occlusion = true
	profile.override_enable_distance_filtering = false
	profile.enable_distance_filtering = true
	profile.occlusion_intensity = 0.5
	profile.lowpass_cutoff_hz = -1.0
	profile.highpass_cutoff_hz = -1.0
	profile.reverb_wet = -1.0
	profile.reverb_room_size = -1.0
	profile.target_bus_name = ""

	_selected_path = ""
	_dirty = true
	_populate_form(profile)
	_set_detail_visible(true)
	_propagation_id_edit.grab_focus()


func _on_delete() -> void:
	if _selected_path.is_empty():
		return

	var selection: PackedInt32Array = _file_list.get_selected_items()
	if selection.size() == 0:
		return

	var name: String = _selected_path.get_file().trim_suffix(PROFILE_EXT)
	push_warning("Xedats baking tool: deleting '%s'" % name)

	var file: DirAccess = DirAccess.open(_profile_dir)
	if file == null:
		push_error("Xedats baking tool: cannot open directory '%s'" % _profile_dir)
		return

	var err: int = file.remove(_selected_path.get_file())
	if err != OK:
		push_error("Xedats baking tool: failed to delete '%s' (error %d)" % [_selected_path, err])
		return

	_refresh_list()
	_set_detail_visible(false)


func _on_save() -> void:
	var propagation_id: String = _propagation_id_edit.text.strip_edges()
	if propagation_id.is_empty():
		push_warning("Xedats baking tool: propagation_id is required before saving")
		_propagation_id_edit.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		return

	_propagation_id_edit.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))

	var profile: XedatsPrecomputedPropagationProfile = XedatsPrecomputedPropagationProfile.new()
	_read_form_into(profile)

	# Determine save path
	var filename: String = propagation_id + PROFILE_EXT
	var save_path: String = _profile_dir.path_join(filename)

	var result: int = ResourceSaver.save(profile, save_path)
	if result != OK:
		push_error("Xedats baking tool: failed to save profile at '%s' (error %d)" % [save_path, result])
		return

	_dirty = false
	_selected_path = save_path
	_refresh_list()

	for i: int in _file_list.item_count:
		if _file_list.get_item_text(i) == propagation_id:
			_file_list.select(i)
			_on_file_selected(i)
			break


func _read_form_into(profile: XedatsPrecomputedPropagationProfile) -> void:
	profile.propagation_id = _propagation_id_edit.text.strip_edges()
	profile.probe_region_id = _probe_region_id_edit.text.strip_edges()
	profile.gain_multiplier = _gain_mult_slider.value
	profile.override_enable_occlusion = _override_occ_cb.button_pressed
	profile.enable_occlusion = _enable_occ_cb.button_pressed
	profile.override_enable_distance_filtering = _override_df_cb.button_pressed
	profile.enable_distance_filtering = _enable_df_cb.button_pressed
	profile.occlusion_intensity = _occ_intensity_slider.value
	profile.lowpass_cutoff_hz = _lowpass_spin.value
	profile.highpass_cutoff_hz = _highpass_spin.value
	profile.reverb_wet = _reverb_wet_slider.value
	profile.reverb_room_size = _reverb_room_slider.value
	profile.target_bus_name = _target_bus_edit.text.strip_edges()


func _on_browse() -> void:
	var fd: EditorFileDialog = EditorFileDialog.new()
	fd.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	fd.current_dir = _profile_dir
	fd.dir_selected.connect(_on_browse_selected)
	fd.access = EditorFileDialog.ACCESS_FILESYSTEM
	add_child(fd)
	fd.popup_centered_ratio(0.4)


func _on_browse_selected(dir: String) -> void:
	_dir_edit.text = dir
	_profile_dir = dir
	_refresh_list()
