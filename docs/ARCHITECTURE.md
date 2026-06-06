# Xedats — Architecture Reference

Design overview and subsystem reference for agents and contributors.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Singleton Bootstrap](#2-singleton-bootstrap)
3. [Core Nodes](#3-core-nodes)
4. [Base Script Subsystems](#4-base-script-subsystems)
5. [Resource Definitions](#5-resource-definitions)
6. [GLTF Module](#6-gltf-module)
7. [XedatsConsoleModule](#7-xedatsconsolemodule)
8. [Key Design Constraints](#8-key-design-constraints)

---

## 1. System Overview

Xedats is a self-contained 3D audio runtime for Godot 4. It is accessed through a single lazy singleton entry point (`XedatsSingleton`) and requires no autoload configuration. The system is organized into three layers:

| Layer | Contents | Notes |
|-------|----------|-------|
| **Singleton / Nodes** | `XedatsSingleton`, `XedatsPlayer3D`, `XedatsListener3D` | Runtime entry points and managed scene nodes |
| **Base Script Subsystems** | `AudioEventSystem`, `AudioStateManager`, `AudioCrossfade` | Stateful services owned and exposed by the singleton |
| **Resources** | `AudioArrayContainer`, `EffectChain`, GLTF profiles | Data containers used by the subsystems |

Optional layers:

| Layer | Contents | Notes |
|-------|----------|-------|
| **GLTF Module** | `xedats_gltf_document_extension.gd` and supporting scripts | Editor-only import pipeline bridge; beta |
| **Console Module** | `xedats_console_module.gd` | Runtime command bridge; requires a compatible console host |

---

## 2. Singleton Bootstrap

`XedatsSingleton` uses a **lazy instantiation** pattern. There is no autoload entry in `project.godot`.

```
XedatsSingleton.instance()
    │
    ├─ If instance already exists → return it
    │
    └─ If not → create new XedatsSingleton node
                attach to active SceneTree root
                return it
```

**Implications:**
- The singleton is created on first access, not at project start.
- Consumers must null-check `XedatsSingleton.instance()` before use — the singleton may be absent in headless or stripped builds.
- Do not store the singleton reference across frames; the reference can change during hot-reload.
- `peek_instance()` returns the existing instance without creating one. Use this in teardown paths to avoid re-creating the singleton during `_exit_tree()`.

---

## 3. Core Nodes

### XedatsSingleton (`Nodes/XedatsSingleton.gd`)

The primary runtime API. Responsibilities:
- **Player pool** — creates, tracks, and releases `XedatsPlayer3D` instances. `create_player_3d()` allocates from pool; `release_player()` returns to pool.
- **Bus routing** — `resolve_bus_name()`, `route_player_to_category()`, `swap_player_bus()`, `apply_effect_chain_to_bus()`.
- **Subsystem access** — exposes `AudioEventSystem`, `AudioStateManager`, `AudioCrossfade` through typed properties.
- **Performance monitoring** — optional `perf_timer` tracks active player count and pool utilization; gated behind `enable_performance_monitoring`.
- **Debug logging** — all debug `print()` calls throughout the codebase are gated behind `enable_debug_logging`.

Public API surface is documented in `packages/Xedats/Xedats.md`.

### XedatsPlayer3D (`Nodes/XedatsPlayer3D.gd`)

A managed `AudioStreamPlayer3D` subclass. Responsibilities:
- Pooled lifecycle (`_claim()` / `_release()`).
- Named category assignment for bus routing.
- `fade_in()` / `fade_out()` crossfade helpers.
- `play_random_from_container()` for `AudioArrayContainer`-backed variation.
- Spatial properties (attenuation, doppler, max distance) configurable per instance.

### XedatsListener3D (`Nodes/XedatsListener3D.gd`)

A thin wrapper around Godot's audio listener system. Registered with `XedatsSingleton` so the singleton knows the current listener position for occlusion and distance queries.

---

## 4. Base Script Subsystems

All subsystems are instantiated and held by `XedatsSingleton`. They are not singletons themselves; access them through the singleton.

### AudioEventSystem (`Base Scripts/AudioEventSystem.gd`)

Named audio trigger dispatch. Responsibilities:
- Register named events (`register_event(event_name, stream_or_container)`).
- Trigger events (`trigger_event(event_name, at_position)`) — acquires a player from the pool, connects a one-shot completion signal, and plays.
- Uses `CONNECT_ONE_SHOT` on completion signals to avoid signal accumulation on pooled players.

### AudioStateManager (`Base Scripts/AudioStateManager.gd`)

Audio settings persistence. Responsibilities:
- Save volume category levels to disk (`save_audio_state()`).
- Load and apply saved state on startup (`load_audio_state()`).
- Delete saved state (`delete_saved_state()`).
- All `print()` calls in this subsystem must be gated behind `XedatsSingleton.enable_debug_logging`.

### AudioCrossfade (`Base Scripts/AudioCrossfade.gd`)

Crossfade orchestration between two audio sources. Responsibilities:
- `fade_out_player(player)` / `fade_in_player(player)` — drive volume over time.
- Operates on `XedatsPlayer3D` instances that are already added to the scene tree.

> **Known issue (BACKLOG #14):** `fade_out_player()` / `fade_in_player()` currently create orphaned dummy `XedatsPlayer3D` nodes without `add_child()`. Planned refactor to use `XedatsPlayer3D.fade_out()` / `fade_in()` directly.

---

## 5. Resource Definitions

### AudioArrayContainer (`Base Scripts/ResourceDef/AudioArrayContainer.gd`)

A `Resource` subclass holding an array of `AudioStream` assets for randomized variation. Used by `XedatsPlayer3D.play_random_from_container()` and `AudioEventSystem`.

> **Known issue (BACKLOG #15):** `_get_property_list()` emits a `push_warning()` on every editor inspection, causing noise in the output panel. The warning should be removed or guarded.

### EffectChain (`Base Scripts/ResourceDef/EffectChain.gd`)

A `Resource` subclass defining an ordered list of `AudioEffect` assets to apply to a bus. Used by `XedatsSingleton.apply_effect_chain_to_bus()`.

### GLTF Profile Resources (`Resources/GLTF/`)

Default `.tres` assets for GLTF module profiles:
- `xedats_distance_band_profile_default.tres`
- `xedats_omi_effect_mapping_profile_default.tres`
- `xedats_reflection_budget_profile_default.tres`

These are the fallback resources used when a GLTF scene does not provide its own profiles.

---

## 6. GLTF Module

**Status: Beta.** Located at `packages/Xedats/Modules/GLTF/`.

The GLTF module is a `GLTFDocumentExtension` that bridges glTF audio metadata into the Xedats runtime during Godot's asset import pipeline.

### Extension entry point

`xedats_gltf_document_extension.gd` — registered as a `GLTFDocumentExtension` via the editor plugin (`plugin.cfg` at `res://addons/xedats_gltf/`). It hooks into the standard GLTF import lifecycle methods.

### Supporting scripts

| Script | Role |
|--------|------|
| `xedats_gltf_config.gd` | Import-time configuration |
| `xedats_gltf_emitter_binding.gd` | Maps glTF emitter nodes to Xedats players |
| `xedats_distance_band_policy.gd` | Policy rules for distance-based audio band selection |
| `xedats_distance_band_profile.gd` | Per-scene distance band configuration resource |
| `xedats_dynamic_approximation_service.gd` | Runtime spatial audio approximation |
| `xedats_omi_effect_mapping_profile.gd` | `OMI_audio_material` → `EffectChain` mapping |
| `xedats_precomputed_propagation_profile.gd` | Precomputed zone/region propagation data resource |
| `xedats_precomputed_propagation_resolver.gd` | Resolves precomputed data at runtime |
| `xedats_reflection_budget_profile.gd` | Per-scene reflection compute budget |
| `xedats_reflection_salience.gd` | Salience scoring for reflection prioritization |

### Spec mapping

- `KHR_audio_emitter` → Xedats event/clip playback.
- `OMI_audio_material` → deterministic `EffectChain` generation and node metadata.

### Import fallback rule

If Xedats runtime services are unavailable during import, the module logs a warning and falls back to simple playback binding. It must **never** fail the import.

### Authoring reference

Full JSON structure, source URI conventions, acoustic surface tuning values, and headless test instructions are in:
`packages/Xedats/Modules/GLTF/Setup_GLTF_Audio_Surfaces.md`

---

## 7. XedatsConsoleModule

**Location:** `packages/XedatsConsoleModule/xedats_console_module.gd`

An optional, standalone runtime node that registers Xedats-specific commands into a compatible host command console (`Xebug` or any console implementing the same `register_command` / `unregister_command` contract).

**Lifecycle:**
- Instantiate after the host console is available.
- Commands are registered in `_ready()`.
- Commands are unregistered in `_exit_tree()`.

**Commands registered:**
- `xd.panel`, `xd.overlay`, `xd.trace`, `xd.status`, `xd.refresh`, `xd.feed`
- `audio list_buses`, `audio list_events`, `audio toggle_category`, `audio inspect_player`, `audio route_test`

**Constraint:** This module must not introduce any dependency on a specific console implementation. It must work with any console that satisfies the `register_command` / `unregister_command` contract.

---

## 8. Key Design Constraints

| Constraint | Rationale |
|-----------|-----------|
| **Zero external dependencies** | Both `Xedats` and `XedatsConsoleModule` must drop into any Godot project without requiring `AutoloadManager`, `Xebug`, or any other package. |
| **No autoload configuration required** | The lazy singleton pattern means users do not need to touch `project.godot` to use Xedats. |
| **Null-safe singleton access** | Consumers must always null-check `XedatsSingleton.instance()`. This allows Xedats to be absent in test or stripped builds without crashing consuming code. |
| **Pool ownership** | Players created via `create_player_3d()` are owned by the pool. Consumers must call `release_player()` when done; they must not call `queue_free()` directly on pooled players. |
| **Debug prints gated** | All `print()` diagnostics in runtime scripts must be gated behind `XedatsSingleton.enable_debug_logging`. Never add unconditional prints. |
| **GLTF module is editor-only** | The GLTF extension runs in the import pipeline only. It must not add runtime overhead or break scenes when the plugin is disabled. |
| **Tests folder is omit-safe** | No runtime script references paths inside `packages/Xedats/Tests/`. Users may safely delete the tests folder from shipped builds. |
