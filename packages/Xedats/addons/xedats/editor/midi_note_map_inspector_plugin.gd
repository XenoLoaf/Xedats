@tool
extends EditorInspectorPlugin


func _can_handle(object: Object) -> bool:
	return object is MidiNoteMap


func _parse_end(object: Object) -> void:
	var note_map: MidiNoteMap = object as MidiNoteMap
	if note_map == null:
		return

	var sep: HSeparator = HSeparator.new()
	add_custom_control(sep)

	var label: Label = Label.new()
	label.text = "Piano Roll"
	add_custom_control(label)

	var button: Button = Button.new()
	button.text = "Open Piano Roll Editor"
	button.size_flags_horizontal = Control.SIZE_FILL
	button.pressed.connect(func():
		var editor: MidiNoteMapEditor = MidiNoteMapEditor.new()
		editor.note_map = note_map
		editor.unresizable = false
		EditorInterface.get_base_control().add_child(editor)
		editor.popup_centered(Vector2(460, 620))
	)
	add_custom_control(button)

	var sep2: HSeparator = HSeparator.new()
	add_custom_control(sep2)
