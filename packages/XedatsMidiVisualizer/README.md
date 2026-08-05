# Xedats MIDI Visualizer

Companion package providing a clickable 128-key piano keyboard widget with optional hardware MIDI input visualization and Xedats audio integration.

## Purpose

Visualize MIDI keyboard input in real time and optionally trigger Xedats audio events by clicking on-screen piano keys.

## Components

- **`MidiPianoKeyboard`** — `Control`-based 128-key horizontal piano widget. Draws white and black keys with pressed/unpressed states. Emits `key_pressed(note, velocity)` and `key_released(note)` signals on interaction.
- **`MidiPianoKeyboardWindow`** — `Window` wrapper hosting the keyboard with optional `XedatsMIDIInput` integration and optional click-to-audio dispatch through Xedats.

## Quick start

### Standalone keyboard widget (no Xedats audio)

```gdscript
var keyboard: MidiPianoKeyboard = MidiPianoKeyboard.new()
keyboard.interactive = true
add_child(keyboard)
```

### Keyboard with hardware MIDI input visualization

```gdscript
var window: MidiPianoKeyboardWindow = MidiPianoKeyboardWindow.new()
window.use_hardware_input = true
window.note_map = preload("res://my_note_map.tres")
add_child(window)
```

### Keyboard with external XedatsMIDIInput

```gdscript
var midi_input: XedatsMIDIInput = XedatsMIDIInput.new()
midi_input.note_map = preload("res://my_note_map.tres")
add_child(midi_input)

var keyboard: MidiPianoKeyboard = MidiPianoKeyboard.new()
midi_input.note_triggered.connect(keyboard.press_key)
midi_input.note_off.connect(keyboard.release_key)
add_child(keyboard)
```

## Requirements

- Xedats package (for audio integration and `XedatsMIDIInput`)
- Godot 4.7+
- MIDI hardware input requires `OS.has_feature("midi")` (platform-dependent)

## Notes

This is a companion package. Delete the `XedatsMidiVisualizer/` folder if unused — nothing else depends on it.
