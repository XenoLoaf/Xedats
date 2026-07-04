class_name MidiStingerDefinition
extends Resource

## Defines a stinger — a short musical phrase that interrupts background music.
##
## Used by [MidiStinger] to queue and play stingers at bar boundaries.

## The MIDI sequence for this stinger.
@export var sequence: MidiSequence

## Priority level. Higher priority stingers interrupt lower-priority ones.
@export var priority: int = 0

## How much to reduce background music volume during the stinger (0.0 = no duck, 1.0 = full mute).
@export var duck_amount: float = 0.5

## Crossfade duration in seconds when the stinger enters and exits.
@export var fade_duration: float = 0.25

## Whether to wait for the next bar boundary before playing.
@export var wait_for_bar: bool = true
