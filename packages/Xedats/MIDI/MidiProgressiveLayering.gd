class_name MidiProgressiveLayering
extends Node

## Manages vertical orchestration — multiple [MidiSequencer] instances
## playing synchronized layers controlled by a single intensity value.
##
## As [member intensity] changes, layers crossfade in and out at their
## configured thresholds. All layers share the same [member bpm] and clock.
##
## Usage:
## [codeblock]
## var layering: MidiProgressiveLayering = MidiProgressiveLayering.new()
## layering.layers = [bass_layer, perc_layer, harmony_layer, melody_layer]
## add_child(layering)
## layering.play()
## layering.set_intensity(0.3)  # bass + percussion only
## layering.set_intensity(0.7)  # adds harmony
## [/codeblock]

## Array of [MidiLayerDefinition] resources defining each layer.
@export var layers: Array[MidiLayerDefinition] = []

## Current intensity [0.0–1.0]. Drives which layers are active.
@export var intensity: float = 0.0

## Tempo override in BPM for all layers. 0 = use sequence's embedded tempo.
@export var bpm: float = 0.0

## Audio category for all layers (if layer doesn't override).
@export var audio_category: String = "Music"

## Whether all layers are playing.
var is_playing: bool = false

var _sequencers: Array = []  # Array[MidiSequencer]
var _current_volumes: Array[float] = []
var _ready_count: int = 0
var _all_ready: bool = false


func _ready() -> void:
	_create_sequencers()
	set_process(true)


func _process(delta: float) -> void:
	if not is_playing or not _all_ready:
		return

	for i: int in range(layers.size()):
		if i >= _sequencers.size():
			break

		var layer: MidiLayerDefinition = layers[i] as MidiLayerDefinition
		var target: float = layer.volume_scale if intensity >= layer.threshold else 0.0
		var speed: float = 1.0 / max(layer.fade_duration, 0.01)
		_current_volumes[i] = move_toward(_current_volumes[i], target, delta * speed)

		var seq: MidiSequencer = _sequencers[i] as MidiSequencer
		seq.volume_scale = _current_volumes[i] * layer.volume_scale


func play() -> void:
	if not _all_ready:
		_all_ready = true

	for seq_variant: Variant in _sequencers:
		var seq: MidiSequencer = seq_variant as MidiSequencer
		if seq != null:
			seq.play()

	is_playing = true


func stop() -> void:
	for seq_variant: Variant in _sequencers:
		var seq: MidiSequencer = seq_variant as MidiSequencer
		if seq != null:
			seq.stop()

	is_playing = false


func set_intensity(value: float) -> void:
	intensity = clamp(value, 0.0, 1.0)


func _create_sequencers() -> void:
	for layer_variant: Variant in layers:
		var layer: MidiLayerDefinition = layer_variant as MidiLayerDefinition
		if layer == null or layer.sequence == null:
			continue

		var seq: MidiSequencer = MidiSequencer.new()
		seq.sequence = layer.sequence
		seq.note_map = layer.note_map
		seq.audio_category = layer.bus_override if not layer.bus_override.is_empty() else audio_category
		seq.volume_scale = 0.0
		seq.tempo_override = bpm
		seq.loop = true
		seq.name = "LayerSequencer_%d" % _sequencers.size()

		seq.ready.connect(_on_sequencer_ready.bind(_sequencers.size()))

		add_child(seq)
		_sequencers.append(seq)
		_current_volumes.append(0.0)

	_ready_count = 0
	_all_ready = _sequencers.is_empty()


func _on_sequencer_ready(_idx: int) -> void:
	_ready_count += 1
	if _ready_count >= _sequencers.size():
		_all_ready = true
