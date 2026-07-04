class_name MidiLayerDefinition
extends Resource

## Defines a single layer in [MidiProgressiveLayering]'s vertical orchestration.
##
## Each layer has a MIDI sequence, an intensity threshold at which it
## becomes audible, and a fade duration for smooth transitions.

## The MIDI sequence for this layer.
@export var sequence: MidiSequence

## [MidiNoteMap] for this layer's note-to-event mapping.
@export var note_map: MidiNoteMap

## Intensity threshold [0.0–1.0] at which this layer becomes audible.
@export var threshold: float = 0.5

## Volume scale when this layer is fully active.
@export var volume_scale: float = 1.0

## Bus or category override for this layer. Empty = use layering controller's default.
@export var bus_override: String = ""

## Transition duration in seconds when fading in or out.
@export var fade_duration: float = 1.0
