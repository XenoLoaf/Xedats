class_name MidiFileResource
extends Resource

## Wraps a .mid file path for drag-and-drop inspector assignment.
##
## Allows designers to assign a MIDI file in the Godot inspector and
## access the parsed [MidiSequence] data at runtime without manual
## [method load_from_file] calls in code.
##
## Usage:
## [codeblock]
## @export var music: MidiFileResource
## # In code:
## var sequence: MidiSequence = music.get_sequence()
## if sequence != null:
##     sequencer.sequence = sequence
## [/codeblock]

## Path to the .mid file, relative to the project (e.g. "res://music/theme.mid").
@export var file_path: String = ""

## If true, the MIDI file is parsed automatically when [method get_sequence] is called.
@export var auto_parse: bool = true

## The parsed [MidiSequence] data, populated on demand.
var data: MidiSequence = null


func load_from_file(path: String = "") -> int:
	if path.is_empty():
		path = file_path
	if path.is_empty():
		push_error("MidiFileResource: No file path provided.")
		return ERR_INVALID_PARAMETER

	var sequence: MidiSequence = MidiSequence.new()
	var result: int = sequence.load_from_file(path)
	if result != OK:
		data = null
		push_error("MidiFileResource: Failed to load '%s'." % path)
		return result

	data = sequence
	file_path = path
	return result


func get_sequence() -> MidiSequence:
	if data == null and auto_parse and not file_path.is_empty():
		load_from_file()
	return data
