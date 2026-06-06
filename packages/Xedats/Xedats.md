# Xedats Audio System - Comprehensive Usage Guide

> **New to Xedats?** Start here: **[Getting_Started.md](Getting_Started.md)**
> Covers common object/interaction audio setup, exported variable patterns, and good practices.
>
> **Planning interactable audio expansion?** See **[Interactable_Audio_Requirements.md](Interactable_Audio_Requirements.md)**
> for the Project Helix interactable spectrum, extracted requirements, and the cue/profile implementation plan.

## Overview

**Xedats** is a comprehensive 3D audio system for Godot 4.6+. It provides:
- **Efficient audio playback** via object pooling
- **Spatial 3D audio** with doppler effects and occlusion
- **Audio event system** for named audio triggers
- **Volume categorization** (Master, SFX, Music, VoiceLines, Ambient)
- **Category/effect-lane bus routing** with hot-swap helpers
- **Audio persistence** (save/load settings)
- **Crossfading** between audio sources
- **Performance monitoring** and debugging

### Bus Routing Helpers

Xedats singleton exposes runtime-safe bus routing helpers for designer workflows and code-driven hot swaps:

- `resolve_bus_name(category, use_effect_bus=false, requested_bus="")`
- `route_player_to_category(player, category, use_effect_bus=false, requested_bus="")`
- `swap_player_bus(player, bus_name, fallback_bus="Master")`
- `get_audio_bus_names()`
- `create_audio_bus()`, `remove_audio_bus()`
- `apply_effect_chain_to_bus()`

For runtime route inspection in debug tools, use:

- `get_active_player_bus_routes()`

Typical workflow:

```gdscript
var audio: XedatsSingleton = XedatsSingleton.instance()
if audio:
    var player: XedatsPlayer3D = audio.create_player_3d(global_position)
    player.stream = my_stream

    # Route to SFX base lane.
    audio.route_player_to_category(player, "SFX", false)
    player.play()

    # Later, move the same player to the SFX effect lane.
    audio.route_player_to_category(player, "SFX", true)

    # Explicit swap with deterministic fallback.
    audio.swap_player_bus(player, "SFXEffects", "Master")
```

Use `resolve_bus_name(...)` when you need the final resolved bus string ahead of playback,
for example when assigning `player.bus` directly in custom workflows.

## Project-Agnostic Design

Xedats is designed as a **generic Godot addon** that works in any project. All examples use generic file paths like `res://audio/...` rather than project-specific directories. While the examples reference common game audio scenarios (character footsteps, door sounds, etc.), these patterns are universally applicable across different game types and genres.

## Dependencies

**This standalone Xedats package does not require AutoloadManager.**

Call `XedatsSingleton.instance()` when you want the runtime to initialize. The standalone singleton lazily creates itself and attaches to the active scene tree root.

## glTF Audio Import (Beta)

Xedats now includes a `GLTFDocumentExtension` bridge for glTF audio metadata:
- `KHR_audio_emitter` maps to Xedats event/clip playback where possible.
- `OMI_audio_material` maps to deterministic `EffectChain` generation and node metadata.

To enable importer registration in the editor:
1. Enable plugin: `res://addons/xedats_gltf/plugin.cfg`.
2. Keep Xedats runtime scripts available in project (default layout already satisfies this).

If Xedats runtime services are unavailable during import, the importer logs warnings and falls back to simple playback binding instead of failing import.

For full authoring guidance including JSON structure, source URI conventions, acoustic surface tuning values, and headless test instructions see:
**[Modules/GLTF/Setup_GLTF_Audio_Surfaces.md](Modules/GLTF/Setup_GLTF_Audio_Surfaces.md)**

Spatial audio R&D notes and paper-to-implementation guidance are tracked here:
**[Modules/GLTF/Spatial_Audio_Research_Reference.md](Modules/GLTF/Spatial_Audio_Research_Reference.md)**

Grouped implementation planning tracks are here:
**[Modules/GLTF/Implementation_Idea_Groups.md](Modules/GLTF/Implementation_Idea_Groups.md)**

Latest example-project planning pass (Godot Spatial Audio Resources) is included in:
**[Modules/GLTF/Implementation_Idea_Groups.md#example-project-pass-godot-spatial-audio-resources](Modules/GLTF/Implementation_Idea_Groups.md#example-project-pass-godot-spatial-audio-resources)**

## Runtime Tooling

This package exposes runtime state and helper APIs that can be consumed by optional tooling layers.

Those tooling layers are intentionally outside the scope of this standalone runtime package.

## Quick Start

### 1. Access the Singleton

```gdscript
var audio: XedatsSingleton = XedatsSingleton.instance()
if audio:
    # Use the audio system
    pass
```

### 2. Play a Simple Sound

```gdscript
var stream: AudioStream = preload("res://path/to/sound.ogg")
var audio: XedatsSingleton = XedatsSingleton.instance()
if audio:
    var player: XedatsPlayer3D = audio.create_player_3d(global_position)
    player.stream = stream
    player.play()
```

---

## Common Usage Patterns

### Player Character Audio

Player character sounds are typically **positional 3D audio** with dynamic variations based on movement type.

#### Footsteps

Footsteps should vary based on surface type and movement speed:

```gdscript
extends CharacterBody3D

@export var terrain_type: String = "grass"  # "grass", "concrete", "metal", "wood"
var audio_system: XedatsSingleton

# Audio containers for different surfaces
var footstep_sounds = {
    "grass": preload("res://audio/footsteps/grass.tres"),
    "concrete": preload("res://audio/footsteps/concrete.tres"),
    "metal": preload("res://audio/footsteps/metal.tres"),
    "wood": preload("res://audio/footsteps/wood.tres")
}

func _ready() -> void:
    audio_system = XedatsSingleton.instance()

# Called periodically as the player walks
func play_footstep() -> void:
    if not audio_system:
        return
    
    var container: AudioArrayContainer = footstep_sounds.get(terrain_type) as AudioArrayContainer
    if not container:
        return
    
    var player: XedatsPlayer3D = audio_system.create_player_3d(global_position)
    player.audio_category = "SFX"
    player.play_random_from_container(container)
    
    # Vary pitch based on terrain type
    match terrain_type:
        "grass":
            player.pitch_scale = randf_range(0.9, 1.1)
        "concrete":
            player.pitch_scale = randf_range(0.95, 1.05)
        "metal":
            player.pitch_scale = randf_range(1.0, 1.2)
        "wood":
            player.pitch_scale = randf_range(0.85, 1.15)

# Handle jumping
func play_jump_sound() -> void:
    if not audio_system:
        return
    
    var jump_sound = preload("res://audio/movement/jump.ogg")
    var player: XedatsPlayer3D = audio_system.create_player_3d(global_position)
    player.audio_category = "SFX"
    player.stream = jump_sound
    player.pitch_scale = randf_range(0.95, 1.05)
    player.play()

# Handle landing
func play_landing_sound(impact_force: float = 1.0) -> void:
    if not audio_system:
        return
    
    var landing_sound = preload("res://audio/movement/land.ogg")
    var player: XedatsPlayer3D = audio_system.create_player_3d(global_position)
    player.audio_category = "SFX"
    player.stream = landing_sound
    
    # Scale volume by impact force
    var volume = clamp(impact_force / 10.0, 0.3, 1.0)
    player.set_volume_linear_normalized(volume)
    
    # Scale pitch by impact force
    player.pitch_scale = 1.0 - (impact_force / 20.0)
    player.play()
```

#### Movement Variants

Different movement types should have distinct audio signatures:

```gdscript
# In your player controller
func handle_movement() -> void:
    if is_sprinting:
        play_sprint_footsteps()
    elif is_walking:
        play_walk_footsteps()
    elif is_sneaking:
        play_sneak_footsteps()

func play_sprint_footsteps() -> void:
    if not audio_system:
        return
    
    var container: AudioArrayContainer = footstep_sounds.get(terrain_type) as AudioArrayContainer
    var player: XedatsPlayer3D = audio_system.create_player_3d(global_position)
    player.pitch_scale = 1.2  # Higher pitch for faster movement
    player.set_volume_linear_normalized(0.8)  # Louder steps
    player.play_random_from_container(container)

func play_walk_footsteps() -> void:
    if not audio_system:
        return
    
    var container: AudioArrayContainer = footstep_sounds.get(terrain_type) as AudioArrayContainer
    var player: XedatsPlayer3D = audio_system.create_player_3d(global_position)
    player.pitch_scale = 1.0  # Normal pitch
    player.set_volume_linear_normalized(0.6)  # Normal volume
    player.play_random_from_container(container)

func play_sneak_footsteps() -> void:
    if not audio_system:
        return
    
    var container: AudioArrayContainer = footstep_sounds.get(terrain_type) as AudioArrayContainer
    var player: XedatsPlayer3D = audio_system.create_player_3d(global_position)
    player.pitch_scale = 0.9  # Slightly lower pitch
    player.set_volume_linear_normalized(0.3)  # Very quiet
    player.play_random_from_container(container)
```

#### Breathing and Effort Sounds

Add realism with contextual breathing and effort audio:

```gdscript
# Breathing system based on exertion
var is_exhausted: bool = false
var breathing_timer: float = 0.0

func _process(delta: float) -> void:
    if is_sprinting:
        breathing_timer -= delta
        if breathing_timer <= 0.0:
            play_breathing_sound()
            breathing_timer = randf_range(0.5, 1.0)

func play_breathing_sound() -> void:
    if not audio_system:
        return
    
    var breathing_sound: AudioStream = preload("res://audio/movement/breathing.ogg")
    var player: XedatsPlayer3D = audio_system.create_player_3d(global_position)
    player.audio_category = "SFX"
    player.stream = breathing_sound
    
    # More exhausted = more frequent and intense
    if is_exhausted:
        player.pitch_scale = randf_range(1.1, 1.3)
        player.set_volume_linear_normalized(0.7)
    else:
        player.pitch_scale = randf_range(0.9, 1.0)
        player.set_volume_linear_normalized(0.3)
    
    player.play()
```

---

### World Objects and Interactables

World objects like doors, chests, and interactive elements should emit audio at their location.

#### Door Opening/Closing

```gdscript
extends StaticBody3D
class_name Door

@export var open_sound_container: AudioArrayContainer
@export var close_sound_container: AudioArrayContainer
@export var is_locked: bool = false

var audio_system: XedatsSingleton
var is_open: bool = false

func _ready() -> void:
    audio_system = XedatsSingleton.instance()

func open_door() -> void:
    if is_open or is_locked:
        return
    
    is_open = true
    play_door_sound(open_sound_container, "high")
    
    # Animate door opening
    var tween: Tween = create_tween()
    tween.tween_property(self, "rotation.y", PI / 2, 0.5)

func close_door() -> void:
    if not is_open:
        return
    
    is_open = false
    play_door_sound(close_sound_container, "low")
    
    # Animate door closing
    var tween: Tween = create_tween()
    tween.tween_property(self, "rotation.y", 0.0, 0.5)

func play_door_sound(container: AudioArrayContainer, pitch_variant: String) -> void:
    if not audio_system or not container:
        return
    
    var player: XedatsPlayer3D = audio_system.create_player_3d(global_position)
    player.audio_category = "SFX"
    player.play_random_from_container(container)
    
    match pitch_variant:
        "high":
            player.pitch_scale = randf_range(1.05, 1.15)
        "low":
            player.pitch_scale = randf_range(0.9, 1.0)

func try_open_locked() -> void:
    if not is_locked:
        return
    
    # Play locked door sound
    var locked_sound: AudioStream = preload("res://audio/interactables/door_locked.ogg")
    var player: XedatsPlayer3D = audio_system.create_player_3d(global_position)
    player.audio_category = "SFX"
    player.stream = locked_sound
    player.play()
```

#### Chest/Container Opening

```gdscript
extends StaticBody3D
class_name Chest

@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var empty_sound: AudioStream

var audio_system: XedatsSingleton
var is_open: bool = false
var has_items: bool = true

func _ready() -> void:
    audio_system = XedatsSingleton.instance()

func toggle_open() -> void:
    if is_open:
        close()
    else:
        open()

func open() -> void:
    if is_open:
        return
    
    is_open = true
    
    # Play opening sound
    var player: XedatsPlayer3D = audio_system.create_player_3d(global_position)
    player.audio_category = "SFX"
    player.stream = open_sound
    player.pitch_scale = randf_range(0.95, 1.05)
    player.play()
    
    # Play secondary sound if chest is empty
    if not has_items:
        await get_tree().create_timer(0.3).timeout
        var empty_player: XedatsPlayer3D = audio_system.create_player_3d(global_position)
        empty_player.audio_category = "SFX"
        empty_player.stream = empty_sound
        empty_player.play()
    
    # Animate opening
    var tween: Tween = create_tween()
    tween.tween_property(self, "rotation.x", -PI / 4, 0.4)

func close() -> void:
    if not is_open:
        return
    
    is_open = false
    
    # Play closing sound
    var player: XedatsPlayer3D = audio_system.create_player_3d(global_position)
    player.audio_category = "SFX"
    player.stream = close_sound
    player.pitch_scale = randf_range(0.95, 1.05)
    player.play()
    
    # Animate closing
    var tween: Tween = create_tween()
    tween.tween_property(self, "rotation.x", 0.0, 0.4)
```

#### Ambient Interactables

For passive world objects (fountains, machinery, etc.):

```gdscript
extends Node3D
class_name AmbientSound

@export var ambient_loop: AudioStream
@export var category: String = "Ambient"
@export var base_volume: float = 0.5

var audio_system: XedatsSingleton
var ambient_player: XedatsPlayer3D

func _ready() -> void:
    audio_system = XedatsSingleton.instance()
    if audio_system and ambient_loop:
        setup_ambient_loop()

func setup_ambient_loop() -> void:
    ambient_player = audio_system.create_player_3d(global_position)
    ambient_player.audio_category = category
    ambient_player.stream = ambient_loop
    ambient_player.bus = category
    ambient_player.set_volume_linear_normalized(base_volume)
    ambient_player.play()

func _process(_delta: float) -> void:
    if ambient_player:
        ambient_player.global_position = global_position

func stop_ambient() -> void:
    if ambient_player:
        ambient_player.fade_out(1.0)
```

---

## Audio Events System

For more complex audio scenarios, use the **Audio Event System** for centralized audio management:

### Register Events

```gdscript
# In your game manager or level setup
func setup_audio_events() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if not audio:
        return
    
    var event_system: AudioEventSystem = audio.get_event_system()
    
    # Register player events
    event_system.register_event(
        "player_footstep_grass",
        preload("res://audio/footsteps/grass.tres"),
        0.6,  # default volume
        1.0,  # default pitch
        "SFX"
    )
    
    event_system.register_event(
        "player_jump",
        preload("res://audio/movement/jump.tres"),
        0.8,
        1.0,
        "SFX"
    )
    
    event_system.register_event(
        "door_open",
        preload("res://audio/interactables/door_open.tres"),
        0.7,
        1.0,
        "SFX"
    )
    
    event_system.register_event(
        "music_ambient",
        preload("res://audio/music/ambient.tres"),
        0.8,
        1.0,
        "Music"
    )
```

### Trigger Events

```gdscript
func play_footstep_via_event() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        audio.trigger_audio_event("player_footstep_grass", global_position)

func play_jump_via_event() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        audio.trigger_audio_event("player_jump", global_position)

# With parameter overrides
func play_quiet_door_open() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        var event_system: AudioEventSystem = audio.get_event_system()
        var params: Dictionary = {
            "position": global_position,
            "volume": 0.4,  # Override default volume
            "pitch": 0.95   # Override default pitch
        }
        event_system.trigger_event_with_params("door_open", params)
```

---

## Audio Buses and Volume Control

Organize audio into categories for independent volume control:

```gdscript
# Setup custom audio buses (typically in your AudioManager)
func setup_audio_buses() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if not audio:
        return
    
    # Create category buses (parent is "Master" bus)
    audio.create_audio_bus("SFX", "Master")
    audio.create_audio_bus("Music", "Master")
    audio.create_audio_bus("VoiceLines", "Master")
    audio.create_audio_bus("Ambient", "Master")
    
    # Add effects to buses as needed (e.g., reverb, EQ)
    # audio.add_bus_effect("SFX", audio_effect_instance)

# Control volume by category
func set_sfx_volume(volume: float) -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        audio.set_category_volume("SFX", clamp(volume, 0.0, 1.0))

func set_music_volume(volume: float) -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        audio.set_category_volume("Music", clamp(volume, 0.0, 1.0))

func mute_sfx() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        audio.set_category_volume("SFX", 0.0)

func unmute_sfx() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        audio.set_category_volume("SFX", 1.0)

func get_master_volume() -> float:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        return audio.get_category_volume("Master")
    return 1.0
```

---

## Audio Containers

**AudioArrayContainer** resources let you organize multiple audio variations:

```gdscript
# In an AudioArrayContainer resource (.tres):
# - StreamContainer: Array of AudioStream resources
# - volume_variation: Vector2(min, max) random volume multiplier range
# - pitch_variation: Vector2(min, max) random pitch multiplier range

# Usage in code:
var footstep_container: AudioArrayContainer = preload("res://audio/footsteps/grass.tres")
var player: XedatsPlayer3D = audio_system.create_player_3d(position)
player.play_random_from_container(footstep_container)

# Access random variations
var random_volume: float = footstep_container.get_random_volume()  # Based on volume_variation range
var random_pitch: float = footstep_container.get_random_pitch()    # Based on pitch_variation range
```

---

## Crossfading Audio

Smoothly transition between sounds:

```gdscript
# Fade between two players
func crossfade_music(from_player: XedatsPlayer3D, to_player: XedatsPlayer3D) -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        var crossfade: AudioCrossfade = audio.get_crossfade_system()
        crossfade.start_crossfade(from_player, to_player, 2.0)  # 2 second fade

# Fade out a single player
func fade_out_music(player: XedatsPlayer3D) -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        var crossfade: AudioCrossfade = audio.get_crossfade_system()
        crossfade.fade_out_player(player, 2.0)

# Fade in a single player
func fade_in_music(player: XedatsPlayer3D, target_volume: float = 1.0) -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        var crossfade: AudioCrossfade = audio.get_crossfade_system()
        crossfade.fade_in_player(player, 2.0, target_volume)
```

---

## Audio State Persistence

Automatically save and load audio settings:

```gdscript
# Save audio state to disk
func save_audio_settings() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        var state_manager: AudioStateManager = audio.get_state_manager()
        state_manager.save_audio_state()
        print("Audio settings saved")

# Load audio state from disk
func load_audio_settings() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        var state_manager: AudioStateManager = audio.get_state_manager()
        state_manager.load_audio_state()
        print("Audio settings loaded")

# Get current state
func get_audio_state() -> Dictionary:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        var state_manager: AudioStateManager = audio.get_state_manager()
        return state_manager.get_state()
    return {}

# Reset to defaults
func reset_audio_settings() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        var state_manager: AudioStateManager = audio.get_state_manager()
        state_manager.reset_audio_state()
        print("Audio settings reset to defaults")
```

---

## Performance Monitoring

Track audio system performance:

```gdscript
# Get performance metrics
func check_audio_performance() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        var metrics: Dictionary = audio.get_performance_metrics()
        print("Active players: %d" % metrics["active_players"])
        print("Peak players: %d" % metrics["peak_active_players"])
        print("Pooled players: %d" % metrics["pooled_players"])

# Print full performance report
func print_audio_report() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        audio.print_performance_report()

# Get pool statistics
func check_pool_stats() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        var stats: Dictionary = audio.get_pool_stats()
        print("Pooled players: %d" % stats["pooled"])
        print("Active players: %d" % stats["active"])
        print("Total tracked players: %d" % stats["total"])

# Get system health
func check_system_health() -> void:
    var audio: XedatsSingleton = XedatsSingleton.instance()
    if audio:
        var health: Dictionary = audio.get_system_health()
        print("Capacity usage: %.1f%%" % health["capacity_usage_percent"])
        print("System status: %s" % health["status"])
```

---

## Best Practices

### 1. **Spatial Audio**
- Always use positional audio for world objects
- Position sounds exactly where they originate (door hinge, footstep location)
- Use appropriate audio categories for volume control

### 2. **Performance**
- Use audio pooling for frequently played sounds (footsteps, UI sounds)
- Limit simultaneous sounds (max_simultaneous_sounds = 64)
- Monitor pool usage via `get_pool_stats()`

### 3. **Audio Variation**
- Use AudioArrayContainers with randomized pitch/volume
- Avoid repetitive, identical sounds back-to-back
- Vary pitch and volume based on context (jump height, door speed, etc.)

### 4. **Volume Control**
- Always assign sounds to appropriate audio categories
- Respect user volume settings via save/load system
- Use normalized volume (0.0-1.0) via `set_volume_linear_normalized()`

### 5. **Listener Management**
- Create a listener on the player character
- Keep listener position synchronized with camera/player
- Use `set_current_listener()` to manage audio perspective

### 6. **Event System**
- Register events during level/scene setup
- Use events for triggering complex audio chains
- Leave event system for non-positional audio (UI, music, etc.)

### 7. **Cleanup**
- Rely on auto-return to pool (set `auto_return_to_pool = true`)
- For manual cleanup, call `return_player_to_pool()`
- Check pool statistics regularly during development

---

## Example: Complete Player Audio Implementation

```gdscript
extends CharacterBody3D
class_name PlayerCharacter

@export var footstep_containers: Dictionary[String, AudioArrayContainer] = {}
@export var terrain_type: String = "grass"
@export var footstep_interval: float = 0.4

var audio_system: XedatsSingleton
var last_footstep_time: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var is_walking: bool = false
var is_sprinting: bool = false

func _ready() -> void:
    audio_system = XedatsSingleton.instance()

func _process(delta: float) -> void:
    handle_movement(delta)
    update_position()

func handle_movement(delta: float) -> void:
    var input_dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    is_sprinting = Input.is_action_pressed("ui_accept")
    is_walking = input_dir.length() > 0.0
    
    # Update velocity based on input
    if is_walking:
        var speed: float = 15.0 if is_sprinting else 7.0
        velocity = Vector3(input_dir.x, velocity.y, input_dir.y) * speed
        
        # Play footsteps
        if Time.get_ticks_msec() - last_footstep_time > footstep_interval * 1000:
            play_footstep()
            last_footstep_time = Time.get_ticks_msec()

func play_footstep() -> void:
    if not audio_system:
        return
    
    var container: AudioArrayContainer = footstep_containers.get(terrain_type) as AudioArrayContainer
    if not container:
        return
    
    var player: XedatsPlayer3D = audio_system.create_player_3d(global_position)
    player.audio_category = "SFX"
    player.play_random_from_container(container)
    
    if is_sprinting:
        player.pitch_scale = randf_range(1.1, 1.3)
        player.set_volume_linear_normalized(0.7)
    else:
        player.pitch_scale = randf_range(0.95, 1.05)
        player.set_volume_linear_normalized(0.5)

func update_position() -> void:
    velocity.y = 0  # Simple platformer physics
    global_position += velocity * get_physics_process_delta_time()
```

---

## Debugging

Enable debug logging in XedatsSingleton:

```gdscript
# In inspector or via code:
audio_system.enable_debug_logging = true
audio_system.enable_performance_monitoring = true
```

Check the output console for detailed system information about audio playback and pooling.
