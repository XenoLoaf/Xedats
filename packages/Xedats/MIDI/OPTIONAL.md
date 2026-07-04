# MIDI Module — Optional

This subfolder contains the MIDI foundation layer. It is **fully optional** — you can delete this entire directory and the core Xedats audio system will continue to function normally.

## What it provides

- `MidiSequence` — pure-GDScript `.mid` binary parser producing a `MidiSequence` resource (tempo, time signature, track/instrument data, note-on/note-off events with timing)
- `MidiSequencer` — node consuming `MidiSequence` and dispatching notes through `AudioEventSystem`
- `MidiNoteMap` — dictionary resource mapping MIDI note numbers to event names or containers
- `XedatsMIDIInput` — hardware MIDI input bridge capturing `InputEventMIDI`

## Dependencies (required to exist)

- `Core/` — `AudioEventSystem`, `AudioArrayContainer`
- `Nodes/` — `XedatsSingleton`

## Dependencies (none to be deleted with this)

No other Xedats directory depends on MIDI classes. Deleting this folder never breaks anything else.

## Safety

Use `XedatsModuleLoader.is_midi_available()` before accessing any MIDI class at runtime.
