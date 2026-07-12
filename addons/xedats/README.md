# Xedats — XenoLoaf's Dynamic Audio Tool System

Zero-dependency 3D/2D audio system plugin for Godot 4.7+.

## What this package contains

- `Core/` — audio subsystems (crossfade, events, state, containers)
- `Nodes/` — runtime nodes (singleton, players, listeners)
- `MIDI/` — MIDI parser, sequencer, effects (optional)
- `GLTF/` — glTF import bridge + profiles (optional)
- `GLTF_Docs/` — authoring guides and research references
- `Shared/` — shared module loader
- `editor/` — inspector plugins for distance bands, propagation, and MIDI note maps
- `Tests_GLTF/` — headless fixture tests for the GLTF import pipeline (optional)
- `Getting_Started.md` — practical setup guide
- `Xedats.md` — comprehensive API reference

## Installation

### From the Godot Asset Library

Search for **Xedats** in the in-engine Asset Library and install.

### Manual installation

Copy `addons/xedats/` into your project. Access the singleton from any script:

```gdscript
var audio: XedatsSingleton = XedatsSingleton.instance()
```

The singleton creates itself lazily and attaches to the scene tree — no autoload or project settings required.

## Usage

| Resource | Contents |
|----------|----------|
| **[Getting_Started.md](Getting_Started.md)** | Practical setup with common audio patterns |
| **[Xedats.md](Xedats.md)** | Full API reference |

## Plugin

Enable **Xedats Distance Band Editor** in `Project Settings → Plugins` to use the inspector previews and Propagation Baker dock.

## Optional Components

| Component | Path | Removal |
|-----------|------|---------|
| MIDI module | `addons/xedats/MIDI/` | Delete the folder |
| GLTF module | `addons/xedats/GLTF/` | Delete the folder |
| GLTF tests | `addons/xedats/Tests_GLTF/` | Delete the folder |

## License

MIT — see [LICENSE](LICENSE). Xedats glTF audio extensions use the `XEDATS_` vendor prefix and are original implementations.
