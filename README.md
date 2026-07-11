# Xedats — XenoLoaf's Dynamic Audio Tool System

[![Godot](https://img.shields.io/badge/Godot-4.7-478cbf?logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)

**Xedats** (**Xe**noLoaf's **D**ynamic **A**udio **T**ool **S**ystem) is a standalone, zero-dependency 3D/2D audio system plugin for Godot 4.7+. It provides object pooling, spatial audio, named event dispatch, bus routing, audio persistence, crossfading, MIDI playback, and a glTF audio import bridge — no autoloads, no external packages required.

---

## Features

- **Object pooling** — pre-allocated 3D and 2D audio player pools with configurable size limits
- **Spatial 3D audio** — doppler effects, per-player occlusion with raycast filtering, distance band profiles
- **2D audio** — UI and non-positional playback with the same pool/bus/event system as 3D
- **Audio event system** — register named events (`player_footstep_grass`, `door_open`, etc.) and trigger them from anywhere
- **Bus routing** — category-based routing (SFX, Music, VoiceLines, Ambient, Master) with runtime hot-swap helpers
- **Crossfading** — duck-typed crossfade between any node with `set_volume_linear_normalized()`, with quad/cubic/expo/sine easing
- **MIDI playback** — parse `.mid` files (SMF 0/1), map notes to audio events, hardware MIDI input bridge, stinger/layering/gate effects
- **glTF audio import (beta)** — `GLTFDocumentExtension` bridge for `XEDATS_audio_emitter` and `XEDATS_audio_material` metadata
- **Audio persistence** — save/load category volumes, mute states, and master volume to disk
- **Performance monitoring** — pool stats, active player counts, peak tracking, capacity usage percentage
- **Zero dependencies** — no AutoloadManager, no Xebug, no external packages. `XedatsSingleton.instance()` bootstraps everything on first access.

---

## Installation

1. Copy `packages/Xedats/` into your project's `addons/xedats/` directory.
2. Access the singleton from any script:

```gdscript
var audio: XedatsSingleton = XedatsSingleton.instance()
```

The singleton creates itself lazily and attaches to the scene tree root — no autoload or project settings required.

---

## Quick Start

```gdscript
# Play a 3D sound at position
var player: XedatsPlayer3D = audio.create_player_3d(global_position)
player.stream = preload("res://audio/explosion.ogg")
player.audio_category = "SFX"
player.play()

# Play a 2D UI sound
var ui_player: XedatsPlayer2D = audio.create_player_2d(Vector2.ZERO)
ui_player.stream = preload("res://audio/click.ogg")
ui_player.play()

# Use the event system
audio.get_event_system().register_event("player_jump", jump_stream, 0.8, 1.0, "SFX")
audio.trigger_audio_event("player_jump", global_position)
```

Full API reference: **[packages/Xedats/Xedats.md](packages/Xedats/Xedats.md)**  
Getting started guide: **[packages/Xedats/Getting_Started.md](packages/Xedats/Getting_Started.md)**

---

## Optional Components

Xedats ships as a single package, but several components are optional and can be added or removed without affecting the core runtime.

| Component | Location | Purpose | Removable? |
|-----------|----------|---------|------------|
| **Editor plugin** | `packages/Xedats/addons/xedats/` | Inspector preview for distance band profiles, propagation profile baker dock | Yes — editor-only, not needed at runtime |
| **Console module** | `packages/XedatsConsoleModule/` | Command bridge (`audio list_buses`, `audio inspect_player`, etc.) for [Xebug](https://github.com/XenoLoaf/Xebug) or compatible console hosts | Yes — separate optional package |
| **GLTF module** | `packages/Xedats/GLTF/` | `GLTFDocumentExtension` bridge for importing audio metadata from glTF files | Yes — safe to delete if you don't use glTF audio import |
| **GLTF Tests** | `packages/Xedats/Tests_GLTF/` | Headless fixture tests for the glTF import pipeline (25+ fixtures) | Yes — only needed if validating the GLTF importer |
| **GLTF Docs** | `packages/Xedats/GLTF_Docs/` | Authoring guides and research references for the glTF audio module | Yes — documentation only |
| **MIDI module** | `packages/Xedats/MIDI/` | MIDI parser, sequencer, note map, hardware input, stinger/layering/gate effects | Yes — delete the `MIDI/` folder if unused |
| **Xebug companion modules** | `xebug-modules` branch | Pool monitor, bus inspector, event monitor, runtime validator for [Xebug](https://github.com/XenoLoaf/Xebug) | Yes — separate branch, not on `main` |

### Enabling the Editor Plugin

1. Ensure `packages/Xedats/addons/xedats/plugin.cfg` exists in your project.
2. Go to **Project Settings → Plugins** and enable **Xedats Distance Band Editor**.
3. The Propagation Baker dock appears in the right panel (drag to reposition).

### Enabling the Console Module

1. Copy `packages/XedatsConsoleModule/` into your project.
2. After your host console (e.g., Xebug) is available, call:
```gdscript
var bridge: XedatsConsoleModule = XedatsConsoleModule.new()
add_child(bridge)
```
The module auto-registers `audio`, `xd.panel`, `xd.overlay`, `xd.trace`, `xd.status`, `xd.refresh`, and `xd.feed` commands.

Xebug companion modules (pool monitor, bus inspector, event monitor, runtime validator) are available on the **[`xebug-modules`](../../tree/xebug-modules)** branch.

### Enabling glTF Audio Import

1. Ensure `packages/Xedats/GLTF/` and `packages/Xedats/GLTF/Profiles/` are present.
2. Enable plugin: `res://addons/xedats_gltf/plugin.cfg` in **Project Settings → Plugins**.
3. See **[GLTF_Docs/Setup_GLTF_Audio_Surfaces.md](packages/Xedats/GLTF_Docs/Setup_GLTF_Audio_Surfaces.md)** for full authoring guidance.
4. The `Tests_GLTF/` folder contains fixture-based import validation tests — safe to omit in shipped builds.

---

## Project Bundle

~~A pre-bundled setup with the wider XenoLoaf Tool Suite (Xedats + Xebug + AutoloadManager + GameEnvironment) pre-wired together is planned.~~ *Work in progress — not yet available.*

---

## Repository Layout

```
Xedats-Standalone/
├── packages/
│   ├── Xedats/                  ← standalone runtime package
│   │   ├── Core/                ← audio subsystems (crossfade, events, state, containers)
│   │   ├── Nodes/               ← runtime nodes (singleton, players, listeners)
│   │   ├── MIDI/                ← MIDI parser, sequencer, effects (optional)
│   │   ├── GLTF/                ← glTF import bridge + profiles (optional)
│   │   ├── addons/xedats/       ← editor plugin (optional)
│   │   ├── Xedats.md            ← comprehensive API reference
│   │   └── Getting_Started.md   ← practical usage guide
│   └── XedatsConsoleModule/     ← optional console command bridge
├── test-environment/            ← headless compile-check project
├── LICENSE
└── README.md
```

---

## Documentation

| Document | Contents |
|----------|----------|
| **[Xedats.md](packages/Xedats/Xedats.md)** | Full API reference: buses, events, crossfading, MIDI, glTF, best practices |
| **[Getting_Started.md](packages/Xedats/Getting_Started.md)** | Practical setup guide with common object/interaction audio patterns |
| **[GLTF_Docs/](packages/Xedats/GLTF_Docs/)** | glTF audio authoring, spatial audio research, implementation plan |
| **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** | System design and subsystem boundaries |
| **[THIRDPARTY_NOTICES.md](THIRDPARTY_NOTICES.md)** | Third-party dependency declarations |

---

## License

MIT — see [LICENSE](./LICENSE).

Xedats glTF audio extensions use the `XEDATS_` vendor prefix and are original implementations. They are not implementations of any Khronos or OMI specification. See [THIRDPARTY_NOTICES.md](THIRDPARTY_NOTICES.md) for details.
