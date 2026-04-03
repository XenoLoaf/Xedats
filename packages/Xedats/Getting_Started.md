# Xedats — Getting Started Guide

A practical reference for adding audio to game objects and player interactions using the Xedats audio system.
This document covers the most common setups you will encounter. It will grow alongside Xedats development.

---

## Table of Contents

1. [Accessing the System](#1-accessing-the-system)
2. [Audio Categories](#2-audio-categories)
3. [Playing a Sound at a Position](#3-playing-a-sound-at-a-position)
4. [Attaching Audio to a Game Object](#4-attaching-audio-to-a-game-object)
5. [Player Interaction Sounds (Interactables)](#5-player-interaction-sounds-interactables)
6. [Using the Audio Event System](#6-using-the-audio-event-system)
7. [Sound Variation with AudioArrayContainer](#7-sound-variation-with-audioarraycontainer)
8. [Persisting Volume Settings](#8-persisting-volume-settings)
9. [Common Variable Patterns](#9-common-variable-patterns)
10. [Good Practices](#10-good-practices)
11. [Signals and glTF Portal Auto-Bind](#11-signals-and-gltf-portal-auto-bind)
12. [Bus Routing and Hot-Swap](#12-bus-routing-and-hot-swap)

---

## 1. Accessing the System

Xedats is accessed through its singleton. Always null-check before using it so your object
degrades gracefully if the system is absent (e.g., in unit tests or stripped builds).

```gdscript
var audio := XedatsSingleton.instance()
if audio:
    # safe to use
```

You will write this pattern many times. Cache it as a local variable inside a function rather
than storing it across frames — the singleton reference can change during hot-reload.

---

## 2. Audio Categories

Xedats organizes playback into named volume categories. Use the correct category so that
player volume settings are respected automatically.

| Category     | Typical use                                    |
|--------------|------------------------------------------------|
| `"SFX"`      | World sounds, objects, impacts, UI feedback    |
| `"Music"`    | Background music, stingers, loops              |
| `"Ambient"`  | Environmental loops, wind, crowd, room tone    |
| `"VoiceLines"` | Character dialogue, narration                |

**When in doubt, use `"SFX"`.** It is the default category across Xedats internals.

---

## 3. Playing a Sound at a Position

The simplest one-shot play. Supply the stream, the world position, an optional volume
scalar (0.0–1.0 normalized linear), and a category.

```gdscript
func _play_footstep(pos: Vector3) -> void:
    var audio := XedatsSingleton.instance()
    if not audio:
        return
    audio.play_audio_at_position(footstep_stream, pos, 0.7, "SFX")
```

`play_audio_at_position` pulls a player from the internal pool, configures it, plays it,
then returns it automatically — no manual cleanup required.

---

## 4. Attaching Audio to a Game Object

For world objects that produce sound repeatedly (doors, machines, pickups), keep
a reference to the stream(s) at the class level and call into Xedats from the relevant function.

```gdscript
extends Node3D

# --- Audio ---
@export var sfx_open:  AudioStream  ## Sound played when this object opens.
@export var sfx_close: AudioStream  ## Sound played when this object closes.
@export var sfx_volume: float = 0.8 ## Master volume scalar for all sounds on this object.

var _is_open: bool = false


func open() -> void:
    if _is_open:
        return
    _is_open = true
    _play_sfx(sfx_open)
    # ... tween / animation logic


func close() -> void:
    if not _is_open:
        return
    _is_open = false
    _play_sfx(sfx_close)
    # ... tween / animation logic


func _play_sfx(stream: AudioStream) -> void:
    if stream == null:
        return
    var audio := XedatsSingleton.instance()
    if not audio:
        return
    var player := audio.create_player_3d(global_position)
    player.audio_category = "SFX"
    player.stream = stream
    player.volume_db = linear_to_db(sfx_volume)
    player.play()
```

**Why a helper function?**
Consolidating playback into `_play_sfx` means you only write the null-check and category
assignment once. Adding pitch variation, occlusion flags, or a cooldown later only touches
one place.

---

## 5. Player Interaction Sounds (Interactables)

When an object responds to player input (e.g., `DoorInteractable`), play sounds at the
moment the interaction state changes — not on every frame.

```gdscript
extends Interactable

@export_group("Audio")
@export var sfx_open:  AudioStream  ## Played when the door opens.
@export var sfx_close: AudioStream  ## Played when the door closes.
@export var sfx_locked: AudioStream ## Played when the player tries a locked door.
@export var sfx_pitch_variance: float = 0.06  ## ± random pitch range for natural variation.

var _is_open: bool = false
var _is_locked: bool = false


func interact(interactor: PlayerController) -> void:
    super(interactor)
    if _is_locked:
        _play_sfx(sfx_locked, 0.6)
        return
    if _is_open:
        _is_open = false
        _play_sfx(sfx_close)
        # ... close tween
    else:
        _is_open = true
        _play_sfx(sfx_open)
        # ... open tween


func _play_sfx(stream: AudioStream, volume: float = 0.8) -> void:
    if stream == null:
        return
    var audio := XedatsSingleton.instance()
    if not audio:
        return
    var player := audio.create_player_3d(global_position)
    player.audio_category = "SFX"
    player.stream = stream
    player.volume_db = linear_to_db(volume)
    player.pitch_scale = 1.0 + randf_range(-sfx_pitch_variance, sfx_pitch_variance)
    player.play()
```

Small random pitch variance (±0.05–0.10) is almost always worth adding to world-object
sounds. It prevents the "same clip every time" effect that breaks immersion quickly.

---

## 6. Using the Audio Event System

The `AudioEventSystem` lets you register a sound once by name and trigger it from
anywhere without carrying stream references around.

### 6a. Registering events (do this once, e.g. in a scene _ready or game manager)

```gdscript
func _register_audio_events() -> void:
    var aes := AudioEventSystem.instance()
    if not aes:
        return

    aes.register_event("door_open",  preload("res://Sound/door_open.ogg"),  0.8, 1.0, "SFX")
    aes.register_event("door_close", preload("res://Sound/door_close.ogg"), 0.8, 1.0, "SFX")
    aes.register_event("ui_click",   preload("res://Sound/ui_click.ogg"),   0.5, 1.0, "SFX")
```

### 6b. Triggering events

```gdscript
func interact(interactor: PlayerController) -> void:
    super(interactor)
    var audio := XedatsSingleton.instance()
    if audio:
        audio.trigger_audio_event("door_open", global_position)
```

### 6c. Triggering with parameter overrides

```gdscript
var params := {
    "position": global_position,
    "volume":   0.3,    # quieter than the default
    "pitch":    0.85,   # lower pitch
}
audio.trigger_audio_event_with_params("door_open", params)
```

### 6d. Limiting simultaneous playbacks

```gdscript
# Never play more than 3 footstep sounds at the same time
aes.set_event_max_playback("player_footstep", 3)
```

---

## 7. Sound Variation with AudioArrayContainer

`AudioArrayContainer` is a Resource that holds multiple `AudioStream` entries.
When played through `play_random_from_container`, Xedats picks one at random —
ideal for footsteps, impacts, voice barks, or any sound that should not repeat identically.

```gdscript
# At class level — preload the container resource, not individual clips
@export var footstep_surfaces: Array[AudioArrayContainer]  ## One container per surface type.

func _play_footstep(surface_index: int) -> void:
    if surface_index >= footstep_surfaces.size():
        return
    var audio := XedatsSingleton.instance()
    if not audio:
        return
    var player := audio.create_player_3d(global_position)
    player.audio_category = "SFX"
    player.play_random_from_container(footstep_surfaces[surface_index])
```

---

## 8. Persisting Volume Settings

When providing a settings menu, use `AudioStateManager` to save and load the player's
volume preferences so they survive between sessions.

```gdscript
# In a settings menu script

func _on_sfx_slider_changed(value: float) -> void:
    var audio := XedatsSingleton.instance()
    if audio:
        audio.set_category_volume("SFX", value)

func _on_apply_button_pressed() -> void:
    var state := AudioStateManager.instance()
    if state:
        state.save_audio_state()  # Writes to user://AudioConfig/audio_state.json

func _ready() -> void:
    var state := AudioStateManager.instance()
    if state:
        state.load_audio_state()  # Restore saved preferences on startup
```

To reset to factory defaults:
```gdscript
var state := AudioStateManager.instance()
if state:
    state.reset_audio_state()
```

---

## 9. Common Variable Patterns

These exports and variables appear repeatedly in well-structured audio-enabled objects.
Copy this block as a starting point and remove what you do not need.

```gdscript
# ── Audio ──────────────────────────────────────────────────────────────────
@export_group("Audio")

## Primary action sound (open, activate, fire, etc.).
@export var sfx_primary:   AudioStream

## Secondary or reverse-action sound (close, deactivate, etc.).
@export var sfx_secondary: AudioStream

## Sound played when the interaction is blocked or invalid.
@export var sfx_blocked:   AudioStream

## Volume for all sounds on this object (0.0 – 1.0 linear).
@export_range(0.0, 1.0) var sfx_volume: float = 0.8

## Random ± pitch variance applied per play to avoid repetition.
@export_range(0.0, 0.2)  var sfx_pitch_variance: float = 0.05

## Minimum time in seconds before the same sound can play again.
@export var sfx_cooldown: float = 0.05

# Runtime
var _sfx_cooldown_timer: float = 0.0  # Counts down each _process frame.
```

**Using the cooldown in `_process`:**

```gdscript
func _process(delta: float) -> void:
    if _sfx_cooldown_timer > 0.0:
        _sfx_cooldown_timer -= delta


func _play_sfx(stream: AudioStream, volume_override: float = -1.0) -> void:
    if stream == null or _sfx_cooldown_timer > 0.0:
        return
    _sfx_cooldown_timer = sfx_cooldown

    var vol := volume_override if volume_override >= 0.0 else sfx_volume
    var audio := XedatsSingleton.instance()
    if not audio:
        return
    var player := audio.create_player_3d(global_position)
    player.audio_category = "SFX"
    player.stream = stream
    player.volume_db = linear_to_db(vol)
    player.pitch_scale = 1.0 + randf_range(-sfx_pitch_variance, sfx_pitch_variance)
    player.play()
```

---

## 10. Good Practices

### Always null-check the singleton
`XedatsSingleton.instance()` can return `null` (test scenes, stripped builds, early startup).
Never assume it is present.

### Use `@export` for all audio streams
Hard-coded `preload()` paths inside logic functions couple your script to a specific file.
Exporting streams lets designers swap clips in the Inspector without touching code.

### Group audio exports under `@export_group("Audio")`
Keeps the Inspector tidy and makes audio properties easy to find alongside other object config.

### Prefer `create_player_3d` over holding a persistent player reference
Pool-managed players are released automatically after playback. Holding a long-lived
reference can prevent pool recycling. For looping ambient sounds that you need to stop
manually, holding the reference is correct — just release it in `_exit_tree`.

### Set category before calling `play()`
`audio_category` must be assigned before `play()` is called. The bus routing is resolved
at play time.

```gdscript
# Correct
player.audio_category = "SFX"
player.stream = my_stream
player.play()

# Wrong — category set after play() has no effect on this playback
player.stream = my_stream
player.play()
player.audio_category = "SFX"
```

### Use pitch variance on all world-object sounds
A small asymmetric range (e.g. `randf_range(-0.06, 0.04)`) gives sounds a slightly
organic feel without being perceptibly "wrong".

### Keep interaction sounds short (< 1.5 s for SFX)
Short clips are less likely to overlap awkwardly when the player triggers the same
interactable quickly. For longer sounds (e.g., a gate grinding open), use a distinct
open/close pair and let the in-flight sound finish.

### Register audio events once; trigger them everywhere
Events registered in `AudioEventSystem` decouple the sound choice from the code that
triggers it. Prefer event triggers in shared interaction code so individual object scripts
stay thin.

### For looping ambient audio on an object, stop it explicitly
```gdscript
var _ambient_player: XedatsPlayer3D = null

func _start_ambient() -> void:
    var audio := XedatsSingleton.instance()
    if not audio:
        return
    _ambient_player = audio.create_player_3d(global_position)
    _ambient_player.audio_category = "Ambient"
    _ambient_player.stream = ambient_loop
    _ambient_player.auto_return_to_pool = false  # We manage this manually
    _ambient_player.play()

func _stop_ambient() -> void:
    if is_instance_valid(_ambient_player):
        _ambient_player.stop()
        _ambient_player.auto_return_to_pool = true
        _ambient_player = null

func _exit_tree() -> void:
    _stop_ambient()
```

## 11. Signals and glTF Portal Auto-Bind

### 11a. Why signals matter for audio

Xedats GLTF emitter bindings use a bounded poll (every 0.1 s) as a fallback to stay
in sync with a portal source (e.g., a door). If that source also emits signals, the
binding connects to them immediately — bypassing the poll entirely for state changes.

Project Helix interactables expose the following signals for this purpose:

| Signal | When emitted | Connected handler behaviour |
|---|---|---|
| `opened` | Door transitions to open | Sets portal openness to 1.0 immediately |
| `closed` | Door transitions to closed | Sets portal openness to 0.0 immediately |
| `open_state_changed(is_door_open)` | Either direction | Maps `true`→1.0, `false`→0.0 immediately |

**You do not need to call anything extra.** When `bind_dynamic_portal_state_source(door_node)`
is called (manually or via auto-bind), the binding discovers and connects these signals
automatically. The poll is kept as a safety net for property-only sources that have no signals.

### 11b. Triggering the bind from script

For doors that live in hand-crafted scenes, connect the binding yourself after both nodes
are ready:

```gdscript
# e.g. in a level script's _ready()
var door: DoorInteractable = $Door
var emitter_binding: XedatsGLTFAudioEmitterBinding = $AudioEmitter/XedatsGLTFAudioEmitterBinding

if is_instance_valid(door) and is_instance_valid(emitter_binding):
        emitter_binding.bind_dynamic_portal_state_source(door)
```

### 11c. Importer-authored auto-bind (glTF extras)

For scenes that come in via glTF import, you can declare the portal source directly in
the emitter's `extras` block — no script needed at all:

```json
"extras": {
    "xedats_distance_policy": "texture",
    "xedats_portal_source_path": "."
}
```

`"."` is relative to the **parent** of the emitter binding node (i.e., the glTF node the
emitter is attached to). This means the emitter's own parent — typically the door mesh
node — is treated as the portal source.

Other valid path forms:

| Path value | Resolves to |
|---|---|
| `"."` | The glTF door node itself (most common) |
| `"../HingePivot"` | A sibling node named HingePivot |
| `"DoorFrame/Panel"` | A child under the door node |
| `"/root/Level/WallDoor"` | Absolute path from scene root |

Resolution is deferred one frame to ensure the full scene tree is available before the
path is walked. A warning is printed if the path cannot be resolved or the target node
does not expose a readable portal state.

---

## 12. Bus Routing and Hot-Swap

Xedats supports category-driven bus routing and runtime bus swaps so designers can keep
simple category workflows while still moving individual sounds between base and effect lanes.

### 12a. Route by category (base or effect lane)

```gdscript
func _play_door(stream: AudioStream) -> void:
    var audio := XedatsSingleton.instance()
    if not audio or stream == null:
        return

    var player := audio.create_player_3d(global_position)
    player.stream = stream

    # Base lane: SFX
    audio.route_player_to_category(player, "SFX", false)
    player.play()
```

Use `use_effect_bus = true` when you want the category's effect lane (for example
`SFXEffects -> SFX`) instead of the base lane.

### 12b. Hot-swap an active player to a different bus

```gdscript
func _promote_to_effect_lane(player: XedatsPlayer3D) -> void:
    var audio := XedatsSingleton.instance()
    if not audio or not is_instance_valid(player):
        return

    # Route to the category effect lane.
    audio.route_player_to_category(player, player.audio_category, true)


func _route_to_custom_bus(player: XedatsPlayer3D) -> void:
    var audio := XedatsSingleton.instance()
    if not audio or not is_instance_valid(player):
        return

    # If the bus does not exist, swap_player_bus falls back to Master.
    audio.swap_player_bus(player, "BossMusicDuck", "Master")
```

### 12c. Resolve bus names safely before assigning

```gdscript
var resolved_bus: String = audio.resolve_bus_name("Ambient", true)
player.bus = resolved_bus
```

This keeps routing deterministic across projects where buses may be added, renamed,
or removed during development.

---

*This document will be updated as Xedats features expand. Check `Xedats.md` for the
full system reference and `Modules/GLTF/Setup_GLTF_Audio_Surfaces.md` for glTF-specific
audio authoring.*
