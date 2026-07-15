class_name MidiInstrumentResource
extends Resource

## Defines a multi-sampled instrument with velocity layers and key zones.
##
## Each [InstrumentZone] maps a key range and velocity range to an
## [AudioArrayContainer]. When assigned to a [MidiSequencer] channel,
## the sequencer resolves notes through this resource instead of the
## flat [MidiNoteMap].
##
## Zones are evaluated in order — the first zone whose key range and
## velocity range match the incoming note wins. Arrange zones from most
## specific to most general for correct priority.

class InstrumentZone:
	var note_min: int = 0
	var note_max: int = 127
	var vel_min: int = 0
	var vel_max: int = 127
	var root_note: int = 60
	var container: AudioArrayContainer = null
	var volume_scale: float = 1.0


## Ordered list of zones. First match wins.
@export var zones: Array[InstrumentZone] = []

## Fallback container used when no zone matches.
@export var default_container: AudioArrayContainer = null

## Fallback root note used when no zone matches.
@export var default_root_note: int = 60


func add_zone(
	container: AudioArrayContainer,
	note_min: int = 0,
	note_max: int = 127,
	vel_min: int = 0,
	vel_max: int = 127,
	root_note: int = 60,
	volume_scale: float = 1.0
) -> InstrumentZone:
	var zone: InstrumentZone = InstrumentZone.new()
	zone.container = container
	zone.note_min = note_min
	zone.note_max = note_max
	zone.vel_min = vel_min
	zone.vel_max = vel_max
	zone.root_note = root_note
	zone.volume_scale = volume_scale
	zones.append(zone)
	return zone


## Resolves a MIDI note and velocity to a container, pitch offset, and volume scale.
## Returns { "container": AudioArrayContainer|null, "pitch_offset": float, "volume_scale": float }.
func resolve(note: int, velocity: int) -> Dictionary:
	for zone_variant: Variant in zones:
		var zone: InstrumentZone = zone_variant as InstrumentZone
		if note < zone.note_min or note > zone.note_max:
			continue
		if velocity < zone.vel_min or velocity > zone.vel_max:
			continue

		var pitch_offset: float = float(note - zone.root_note)
		return {
			"container": zone.container,
			"pitch_offset": pitch_offset,
			"volume_scale": zone.volume_scale,
		}

	var default_pitch_offset: float = float(note - default_root_note)
	return {
		"container": default_container,
		"pitch_offset": default_pitch_offset,
		"volume_scale": 1.0,
	}
