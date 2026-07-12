class_name MidiSequence
extends Resource

## Pure-GDScript Standard MIDI File (SMF) parser.
##
## Parses .mid files in Format 0 (single track) and Format 1 (multi-track).
## Stores tempo, time signature, and per-track note/controller events with
## delta-time and absolute-tick timing for use by [MidiSequencer].
##
## Usage:
## [codeblock]
## var sequence: MidiSequence = MidiSequence.new()
## if sequence.load_from_file("res://music/boss_theme.mid") == OK:
##     print("Parsed %d tracks, %d total events" % [
##         sequence.tracks.size(), sequence.get_total_event_count()])
## [/codeblock]

enum MidiEventType {
	NOTE_ON,            # Note pressed
	NOTE_OFF,           # Note released
	CONTROL_CHANGE,     # CC (controller change)
	PROGRAM_CHANGE,     # Instrument/patch change
	PITCH_BEND,         # Pitch wheel
	AFTERTOUCH,         # Polyphonic key pressure
	CHANNEL_PRESSURE,   # Channel pressure (mono aftertouch)
	TEMPO,              # Meta: microseconds per quarter note
	TIME_SIGNATURE,     # Meta: numerator, denominator, clocks per click, 32nd notes per quarter
	KEY_SIGNATURE,      # Meta: sharps/flats, major/minor
	TRACK_NAME,         # Meta: track name text
	TEXT,               # Meta: generic text
	END_OF_TRACK,       # Meta: marks end of track data
	META,               # Catch-all for other meta events
	SYSEX,              # System exclusive message
}


class MidiEvent:
	var delta_time: int = 0
	var absolute_time: int = 0
	var event_type: MidiEventType = MidiEventType.NOTE_ON
	var channel: int = 0
	var note: int = 0
	var velocity: int = 0
	var controller: int = 0
	var value: int = 0
	var program: int = 0
	var pitch_bend: int = 8192
	var tempo: int = 500000
	var numerator: int = 4
	var denominator: int = 4
	var meta_type: int = 0
	var meta_data: PackedByteArray = PackedByteArray()
	var meta_text: String = ""
	var sysex_data: PackedByteArray = PackedByteArray()


class MidiTrack:
	var events: Array = []  # Array[MidiEvent]
	var track_name: String = ""


## SMF format: 0 (single track) or 1 (multi-track, synchronous).
var format: int = 0

## Number of tracks declared in the file header.
var num_tracks: int = 0

## Ticks per quarter note, or -frames-per-second if the MSB is set.
var division: int = 480

## Parsed track data. Each track contains its own [MidiEvent] timeline.
var tracks: Array = []  # Array[MidiTrack]

## Total duration in ticks across all tracks.
var duration_ticks: int = 0


func load_from_file(path: String) -> int:
	if not FileAccess.file_exists(path):
		push_error("MidiSequence: File not found: %s" % path)
		return ERR_FILE_NOT_FOUND

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("MidiSequence: Failed to open file: %s" % path)
		return ERR_CANT_OPEN

	var err: int = _parse_file(file)
	file.close()
	return err


func load_from_buffer(data: PackedByteArray) -> int:
	var file: FileAccess = FileAccess.open("user://_midi_temp.mid", FileAccess.WRITE)
	if file == null:
		return ERR_CANT_CREATE
	file.store_buffer(data)
	file.close()

	file = FileAccess.open("user://_midi_temp.mid", FileAccess.READ)
	if file == null:
		return ERR_CANT_OPEN
	var err: int = _parse_file(file)
	file.close()
	return err


func get_total_event_count() -> int:
	var count: int = 0
	for track: MidiTrack in tracks:
		count += track.events.size()
	return count


func get_tempo_at_tick(tick: int) -> int:
	var tempo: int = 500000
	if tracks.is_empty():
		return tempo
	var first_track: MidiTrack = tracks[0] as MidiTrack
	for event_variant: Variant in first_track.events:
		var event: MidiEvent = event_variant as MidiEvent
		if event.absolute_time > tick:
			break
		if event.event_type == MidiEventType.TEMPO:
			tempo = event.tempo
	return tempo


func ticks_to_seconds(ticks: int, override_bpm: float = -1.0) -> float:
	var tempo: int = get_tempo_at_tick(ticks)
	var usec_per_beat: float = float(tempo)
	if override_bpm > 0.0:
		usec_per_beat = 60000000.0 / override_bpm
	var usec_per_tick: float = usec_per_beat / float(division)
	return float(ticks) * usec_per_tick / 1000000.0


func seconds_to_ticks(seconds: float, override_bpm: float = -1.0) -> int:
	var tempo: int = 500000
	if tracks.size() > 0:
		var first_track: MidiTrack = tracks[0] as MidiTrack
		if first_track.events.size() > 0:
			for event_variant: Variant in first_track.events:
				var event: MidiEvent = event_variant as MidiEvent
				if event.event_type == MidiEventType.TEMPO:
					tempo = event.tempo
					break
	var usec_per_beat: float = float(tempo)
	if override_bpm > 0.0:
		usec_per_beat = 60000000.0 / override_bpm
	var usec_per_tick: float = usec_per_beat / float(division)
	return int(seconds * 1000000.0 / usec_per_tick)


func _parse_file(file: FileAccess) -> int:
	tracks.clear()
	format = 0
	num_tracks = 0
	division = 480
	duration_ticks = 0

	# Read header chunk ID
	var chunk_id: String = _read_chunk_id(file)
	if chunk_id != "MThd":
		push_error("MidiSequence: Invalid MIDI file header: '%s'" % chunk_id)
		return ERR_FILE_CORRUPT

	var header_length: int = file.get_32()  # big-endian, should be 6
	if header_length < 6:
		push_error("MidiSequence: Invalid header length: %d" % header_length)
		return ERR_FILE_CORRUPT

	format = file.get_16()
	num_tracks = file.get_16()
	division = file.get_16()

	# Skip extra header bytes if present
	for _i: int in range(6, header_length):
		file.get_8()

	# Parse each track
	for _track_index: int in range(num_tracks):
		var track: MidiTrack = _parse_track(file)
		if track == null:
			return ERR_FILE_CORRUPT
		tracks.append(track)

	# Calculate duration
	for track: MidiTrack in tracks:
		if track.events.size() > 0:
			var last_event: MidiEvent = track.events[track.events.size() - 1] as MidiEvent
			if last_event.absolute_time > duration_ticks:
				duration_ticks = last_event.absolute_time

	return OK


func _parse_track(file: FileAccess) -> MidiTrack:
	var chunk_id: String = _read_chunk_id(file)
	if chunk_id != "MTrk":
		push_error("MidiSequence: Expected MTrk chunk, got '%s'" % chunk_id)
		return null

	var track_length: int = file.get_32()
	var track_data: PackedByteArray = file.get_buffer(track_length)
	if track_data.size() < track_length:
		push_error("MidiSequence: Track data truncated")
		return null

	var track: MidiTrack = MidiTrack.new()
	var pos: int = 0
	var absolute_time: int = 0
	var running_status: int = 0

	while pos < track_data.size():
		var event: MidiEvent = MidiEvent.new()
		var delta_result: Array = _read_vlq(track_data, pos)
		event.delta_time = int(delta_result[0])
		pos = int(delta_result[1])
		absolute_time += event.delta_time
		event.absolute_time = absolute_time

		var status_byte: int = track_data[pos]
		pos += 1

		if status_byte < 0x80:
			# Running status — use previous status byte, rewind pos
			if running_status == 0:
				push_error("MidiSequence: Running status with no previous status at pos %d" % pos)
				return null
			status_byte = running_status
			pos -= 1
		elif status_byte < 0xF0:
			running_status = status_byte
		else:
			running_status = 0

		if status_byte == 0xFF:
			var meta_type: int = track_data[pos]
			pos += 1
			var length_result: Array = _read_vlq(track_data, pos)
			var meta_length: int = int(length_result[0])
			pos = int(length_result[1])

			match meta_type:
				0x00:
					# Sequence number (ignored in SMF)
					pos += meta_length
					continue
				0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07:
					# Text events
					event.event_type = MidiEventType.TEXT
					event.meta_type = meta_type
					event.meta_text = track_data.slice(pos, pos + meta_length).get_string_from_utf8()
				# Fall through to pos advance
				0x20:
					# Channel prefix
					pos += meta_length
					continue
				0x2F:
					event.event_type = MidiEventType.END_OF_TRACK
				0x51:
					if meta_length >= 3:
						event.event_type = MidiEventType.TEMPO
						event.tempo = (track_data[pos] << 16) | (track_data[pos + 1] << 8) | track_data[pos + 2]
				0x58:
					if meta_length >= 4:
						event.event_type = MidiEventType.TIME_SIGNATURE
						event.numerator = track_data[pos]
						event.denominator = 1 << track_data[pos + 1]
				0x59:
					if meta_length >= 2:
						event.event_type = MidiEventType.KEY_SIGNATURE
				0x03:
					event.event_type = MidiEventType.TRACK_NAME
					event.meta_text = track_data.slice(pos, pos + meta_length).get_string_from_utf8()
					track.track_name = event.meta_text
				_:
					event.event_type = MidiEventType.META
					event.meta_type = meta_type
					event.meta_data = track_data.slice(pos, pos + meta_length)

			pos += meta_length
			track.events.append(event)

		elif status_byte == 0xF0 or status_byte == 0xF7:
			var length_result: Array = _read_vlq(track_data, pos)
			var sysex_length: int = int(length_result[0])
			pos = int(length_result[1])
			event.event_type = MidiEventType.SYSEX
			event.sysex_data = track_data.slice(pos, pos + sysex_length)
			pos += sysex_length
			track.events.append(event)

		else:
			event.channel = status_byte & 0x0F
			var message_type: int = status_byte & 0xF0

			match message_type:
				0x80:
					event.event_type = MidiEventType.NOTE_OFF
					event.note = track_data[pos]
					event.velocity = track_data[pos + 1]
					pos += 2
				0x90:
					var velocity: int = track_data[pos + 1]
					if velocity == 0:
						event.event_type = MidiEventType.NOTE_OFF
					else:
						event.event_type = MidiEventType.NOTE_ON
					event.note = track_data[pos]
					event.velocity = velocity
					pos += 2
				0xA0:
					event.event_type = MidiEventType.AFTERTOUCH
					event.note = track_data[pos]
					event.value = track_data[pos + 1]
					pos += 2
				0xB0:
					event.event_type = MidiEventType.CONTROL_CHANGE
					event.controller = track_data[pos]
					event.value = track_data[pos + 1]
					pos += 2
				0xC0:
					event.event_type = MidiEventType.PROGRAM_CHANGE
					event.program = track_data[pos]
					pos += 1
				0xD0:
					event.event_type = MidiEventType.CHANNEL_PRESSURE
					event.value = track_data[pos]
					pos += 1
				0xE0:
					event.event_type = MidiEventType.PITCH_BEND
					event.pitch_bend = track_data[pos] | (track_data[pos + 1] << 7)
					pos += 2
				_:
					pos += 1  # Skip unknown status

			track.events.append(event)

	return track


func _read_chunk_id(file: FileAccess) -> String:
	var bytes: PackedByteArray = file.get_buffer(4)
	return bytes.get_string_from_ascii()


func _read_vlq(data: PackedByteArray, start: int) -> Array:
	var value: int = 0
	var pos: int = start
	var byte_val: int
	while pos < data.size():
		byte_val = data[pos]
		pos += 1
		value = (value << 7) | (byte_val & 0x7F)
		if (byte_val & 0x80) == 0:
			break
	return [value, pos]
