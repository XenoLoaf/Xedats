# Setup glTF Audio Surfaces

_Xedats glTF Audio — Author Reference_  
_Last updated: Xedats 0.1.0 / Godot 4.6.1_

---

## Overview

The Xedats glTF module bridges two glTF audio extensions into the Xedats runtime:

| Extension | Purpose |
|---|---|
| `KHR_audio_emitter` | Attaches audio playback to a 3D scene node via clip URI, named event, or multi-clip container |
| `OMI_audio_material` | Describes acoustic surface properties (absorption, transmission, reflection) that map to a deterministic `EffectChain` on an Xedats audio bus |

Both extensions are handled by a single `GLTFDocumentExtension` registered by the `xedats_gltf` editor plugin. Import can be tested headlessly; see [Running Fixture Tests](#running-fixture-tests).

### Config Root

Project-specific Xedats pathing for the glTF module is centralized in `XedatsGLTFConfig`:

```gdscript
static var XEDATS_ROOT: String = "res://ProjectHelix/Xedats"
```

File: `res://ProjectHelix/Xedats/Modules/GLTF/xedats_gltf_config.gd`

This is the single path you change when the Xedats module lives somewhere else in a different project. Runtime/resource lookups in the importer and fixture runner are derived from this root through helpers such as:

- `modules_root()`
- `resources_root()`
- `tests_root()`
- `fixtures_root()`
- `project_root()`

What this does cover:

- Reflection and distance-band profile loading.
- Script fallback loading for GLTF helper resources.
- Fixture `.gltf` lookup in the headless test runner.
- Expected audio fixture clip paths used by the test harness.

What this does not cover:

- The path you pass on the command line to launch the runner scene itself.
- Godot-managed `.tscn`, `.tres`, and `.import` references already authored on disk.

In practice, porting the GLTF module now usually means updating `XEDATS_ROOT` once, then launching the correct runner scene path for that project layout.

---

## Plugin Activation

1. Open **Project → Project Settings → Plugins**.
2. Find **Xedats glTF** and toggle it **Enable**.
3. Confirm `project.godot` contains:
   ```ini
   [editor_plugins]
   enabled=PackedStringArray("res://addons/xedats_gltf/plugin.cfg")
   ```

The plugin registers `GLTFDocumentExtensionXedatsAudio` globally for the whole editor session. Disabling it unregisters the extension cleanly.

---

## KHR_audio_emitter

### What it does at runtime

When Godot imports a glTF that contains `KHR_audio_emitter` the importer creates an `XedatsGLTFAudioEmitterBinding` child node on every affected scene node. At scene instantiation (`_ready`) the binding fires the audio through whichever Xedats service is available:

1. **Named Xedats event** — if `event_name` resolves to a registered event in `AudioEventSystem`, uses `trigger_event()`. Category is applied to the pooled player.
2. **Multi-source container** — if 2+ source paths are present, builds an `AudioArrayContainer` in `RANDOM_NO_REPEAT` mode and routes through `XedatsSingleton.play_audio_container_at_position()`.
3. **Single-clip direct play** — calls `XedatsSingleton.play_audio_at_position()`.
4. **Fallback** — if `XedatsSingleton` is absent a plain `AudioStreamPlayer3D` is added and played immediately.

### JSON structure

```jsonc
// Document root
{
  "extensions": {
    "KHR_audio_emitter": {
      "sources": [
        {
          "uri": "../../../../Sound/Doors/open_gate_sfx.wav",
          "extras": {
            "xedats_path": "res://ProjectHelix/Sound/Doors/open_gate_sfx.wav"
          }
        }
      ],
      "emitters": [
        {
          "name": "gate_open_emitter",
          "sources": [0],
          "gain": 0.8,
          "loop": false,
          "extras": {
            "xedats_event":    "gate_open",        // preferred — looks up a named Xedats event
            "xedats_category": "SFX"               // optional — defaults to "SFX" if omitted
          }
        }
      ]
    }
  },
  "nodes": [
    {
      "name": "GateNode",
      "extensions": {
        "KHR_audio_emitter": { "emitter": 0 }
      }
    }
  ]
}
```

### Source path resolution

The importer resolves clip URIs in this order:

1. `extras.xedats_path` on the source — explicit `res://` override; skips all URI math.
2. `uri` field — treated as a path relative to the `.gltf` file's directory. Leading `../` segments are supported and collapsed with `.simplify_path()`. `ProjectSettings.localize_path()` converts the result to `res://`.

If you want authored fixtures or third-party glTF content to remain portable across projects, prefer relative `uri` values where practical and reserve `extras.xedats_path` for explicit project-local overrides.

**Depth example:**  
A fixture at `res://ProjectHelix/Xedats/Tests/GLTF/Fixtures/my.gltf` that references a clip at `res://ProjectHelix/Sound/clip.wav` needs four levels up:

```jsonc
"uri": "../../../../Sound/clip.wav"
```

### Event name resolution

The emitter's resolved event name is looked up in priority order:

| Field | Where |
|---|---|
| `extras.xedats_event` | `emitters[n].extras` |
| `extras.event` | `emitters[n].extras` (generic fallback) |
| `event` | Top-level emitter field |
| `name` | Top-level emitter field (used as event name by convention) |

If none match a registered event the binding records `xedats_runtime_event_fallback=<event_name>` and falls back to clip playback without treating that path as a hard failure.

### Audio categories

Built-in Xedats categories:

| Category | Typical use |
|---|---|
| `Master` | Global volume only; do not assign to individual clips |
| `SFX` | **Default when not specified** |
| `Music` | Background tracks |
| `VoiceLines` | Dialogue and narration |
| `Ambient` | Environmental loops |

Set the category on the emitter's `extras` block:

```jsonc
"extras": { "xedats_category": "Ambient" }
```

At playback time the binding checks `AudioStateManager` for the category mute state; a muted category silences the emitter entirely (no player is created).

### Category routing terminology (base lane vs effect lane)

To keep naming consistent with the runtime docs:

- **Category base lane** means routing by the category bus name itself (for example `SFX`, `Music`, `Ambient`).
- **Category effect lane** means the paired effect bus used by runtime helpers (for example `SFXEffects -> SFX`).

Current `KHR_audio_emitter` authoring maps by `xedats_category` (base-lane category intent). There is not yet a dedicated `KHR_audio_emitter` extras key for forcing effect-lane routing directly.

When a precomputed propagation profile includes `target_bus_name`, that explicit bus route takes precedence for that emitter at runtime.

### Runtime path metadata

Each imported `XedatsGLTFAudioEmitterBinding` records the runtime path it actually used in `xedats_runtime_path`. This makes fallback behavior easy to inspect in the editor, fixture tests, and future debug HUDs.

| `xedats_runtime_path` value | Meaning |
|---|---|
| `muted_skip` | Category was muted at init time; playback was skipped intentionally |
| `xedats_event` | Named event resolved through `AudioEventSystem.trigger_event()` |
| `xedats_container` | Multi-source emitter routed through `AudioArrayContainer` |
| `xedats_direct` | Single source path routed through `XedatsSingleton.play_audio_at_position()` |
| `fallback_local` | Local `AudioStreamPlayer3D` fallback was used |
| `fallback_no_streams` | Fallback path was selected but no streams were loadable |
| `no_streams` | No loadable streams were available for the emitter at all |

When an event-like name is authored but no registered event exists, the binding also stamps `xedats_runtime_event_fallback` with the unresolved event name. This replaced the older noisy warning path so intentional fallback fixtures stay observable without polluting normal runs.

### Gain and loop

| Field | Type | Default | Notes |
|---|---|---|---|
| `gain` | `float` 0–1 | `1.0` | Linear gain, clamped. Passed to player or `volume_variation` |
| `loop` | `bool` | `false` | Duplicates stream and sets loop flag/mode on WAV and OGG |

### Multi-source emitter

List multiple indices in the `sources` array to enable random-no-repeat playback:

```jsonc
"emitters": [
  {
    "sources": [0, 1, 2],
    "gain": 0.9,
    "extras": { "xedats_category": "SFX" }
  }
]
```

The binding builds an `AudioArrayContainer` with `RANDOM_NO_REPEAT` playback mode. Gain is applied as a constant `volume_variation` range (`[gain, gain]`).

### Reflection budget extras (Group A MVP)

`KHR_audio_emitter.extras` supports an optional reflection budget tier:

```jsonc
"extras": {
  "xedats_reflection_budget": "low" // low | medium | high
}
```

Current MVP behavior:
- Source candidates are salience-ranked deterministically.
- A max source cap is read from `res://ProjectHelix/Xedats/Resources/GLTF/xedats_reflection_budget_profile_default.tres`.
- `source_paths` are capped to that tier budget for emitter playback.
- Invalid tier values warn and fallback to `medium`.

Default budget profile values:
- `low = 2`
- `medium = 4`
- `high = 8`

---

### Texture density and variance extras (Group B)

Multi-source emitters can carry two optional extras that modulate the `AudioArrayContainer` volume spread at binding time:

```jsonc
"extras": {
  "xedats_texture_density": 0.5,   // float 0–1; scales center gain (0 = sparse/quiet, 1 = full gain)
  "xedats_texture_variance": 0.4   // float 0–1; spreads the volume range ±(value × 0.25) around center
}
```

#### Volume spread formula

```
center_gain  = gain * lerp(0.5, 1.0, texture_density)
half_spread  = texture_variance * 0.25
volume_variation.x = max(0.0, center_gain - half_spread)
volume_variation.y = min(1.0, center_gain + half_spread)
```

#### Examples

| gain | density | variance | vol_min | vol_max |
|------|---------|----------|---------|---------|
| 1.0  | 0.5     | 0.4      | 0.65    | 0.85    |
| 0.8  | 1.0     | 0.0      | 0.80    | 0.80    |  ← no spread (current default)
| 0.9  | 0.8     | 1.0      | 0.61    | 1.00    |

#### Fallback behavior
- When **both extras are absent**, `volume_variation = Vector2(gain, gain)` — exactly the previous fixed assignment; all existing emitters are unaffected.
- Individual absent keys use their neutral defaults: `density = 1.0`, `variance = 0.0`.
- Out-of-range values (< 0 or > 1) are clamped and a rate-limited warning is emitted.

---

### Distance-band policy extras (Group D)

Multi-source texture emitters can optionally have their volume range further sculpted by the listener's current distance at spawn time using `xedats_distance_policy`.

```jsonc
"extras": {
  "xedats_texture_density": 0.5,
  "xedats_texture_variance": 0.4,
  "xedats_distance_policy": "texture"  // "none" (default) | "texture"
}
```

#### How it works

When `xedats_distance_policy = "texture"`, the binding node samples the straight-line world-space distance from the emitter to the active listener at `_ready` time. The active distance band is determined by the **distance band profile** at `res://ProjectHelix/Xedats/Resources/GLTF/xedats_distance_band_profile_default.tres`.

The center gain computed from texture density/variance is then scaled by the band's `gain_scale`:

```
center_after_band = center_gain * gain_scale_at(distance)
volume_variation  = (center_after_band ± half_spread), clamped to [0, 1]
```

Default profile thresholds and scales:

| Band | Distance range | Gain scale | Rate scale |
|------|---------------|------------|------------|
| near | ≤ 8 m         | 1.00       | 1.00       |
| mid  | 8 – 24 m      | 0.80       | 0.70       |
| far  | > 24 m        | 0.50       | 0.35       |

The rate scale is stored as a payload metadata key (`xedats_distance_rate_scale`) for future Group B phase 2 spawn-cadence use but is not acted on by the binding itself.

#### Fallback behavior
- When `xedats_distance_policy` is absent or `"none"`, no distance sampling occurs — behavior is identical to Group B (texture density/variance only).
- When `xedats_distance_policy = "texture"` but **no listener is active** (e.g. headless, early init), the distance-band step is skipped and the base texture variation is used unchanged.
- Invalid policy values warn and fall back to `"none"`.

#### Inspecting applied values

After import, the binding node exposes two metadata keys for debugging:
- `xedats_texture_volume_variation` — the pre-distance base range.
- `xedats_distance_volume_variation` — the final range after distance-band scaling (only present when `policy = "texture"`).

#### Runtime portal-state hook (Phase 11)

Dynamic approximation records can also react to runtime door/window state via two optional extras:

```jsonc
"extras": {
  "xedats_distance_policy": "texture",
  "xedats_dynamic_portal_openness": 1.0,           // 0.0 closed .. 1.0 open
  "xedats_dynamic_portal_closed_gain_scale": 0.35  // gain scale when fully closed
}
```

These values seed the runtime record only. Live gameplay systems can then adjust the imported binding immediately through:

```gdscript
binding.set_dynamic_portal_openness(0.0)
binding.set_dynamic_portal_closed_gain_scale(0.25)
```

The dynamic service combines distance-band gain with the portal state gain:

```
portal_gain_scale = lerp(portal_closed_gain_scale, 1.0, portal_openness)
target_gain_scale = distance_band_gain_scale * portal_gain_scale
```

Fallback behavior:
- If the dynamic service is unavailable or the emitter is not registered for Group D, the binding methods return `false` and playback continues unchanged.
- If the extras are absent, runtime defaults are `portal_openness = 1.0` and `portal_closed_gain_scale = 0.35`.

#### Runtime portal-source adapter (Phase 12)

Imported bindings can now bind once to a live door/window node and let that node drive portal openness automatically:

```gdscript
binding.bind_dynamic_portal_state_source(door_interactable)
```

The adapter samples these common state surfaces in order:
- `get_portal_openness()` returning `0.0..1.0`
- `portal_openness` property
- `is_open` property

When available, these signals are hooked for immediate updates:
- `portal_openness_changed(openness)`
- `open_state_changed(is_open)`
- `opened()`
- `closed()`

If a source exposes only a property surface, the binding falls back to bounded polling (`0.1 s`) so existing `is_open`-style interactables can drive Group D attenuation without extra glue code.

---

### Precomputed propagation extras (Group C)

Emitters can opt into authored propagation hints using either a direct precomputed token or a probe-region fallback.

```jsonc
"extras": {
  "xedats_precomputed_id": "zone_a",   // preferred direct lookup token
  "xedats_probe_region": "region_a"    // optional fallback lookup key
}
```

The importer resolves profiles from:

```text
res://ProjectHelix/Xedats/Resources/GLTF/PrecomputedPropagation/<key>.tres
```

Lookup order:

1. `xedats_precomputed_id`
2. `xedats_probe_region` string
3. `xedats_probe_region.id` when the value is an object descriptor

#### Profile resource contract

The authored resource type is `XedatsPrecomputedPropagationProfile` and currently supports these init-time hints:

- `gain_multiplier`
- `override_enable_occlusion` + `enable_occlusion`
- `override_enable_distance_filtering` + `enable_distance_filtering`
- `occlusion_intensity`
- `target_bus_name` (optional explicit bus target)
- `lowpass_cutoff_hz` (optional)
- `highpass_cutoff_hz` (optional)
- `reverb_wet` + `reverb_room_size` (optional)

This MVP does **not** add per-frame propagation updates. It only applies deterministic spawn/init adjustments to the player and effective gain.

#### Runtime behavior

When a profile resolves successfully:

- `gain` is multiplied by `gain_multiplier` before event trigger, direct clip playback, texture-volume spread generation, or fallback playback.
- `XedatsPlayer3D.enable_occlusion` is overridden when authored.
- `XedatsPlayer3D.enable_distance_filtering` is overridden when authored.
- `XedatsPlayer3D.occlusion_intensity` is set from the profile.
- When filter/reverb hints are present, a deterministic precomputed bus is configured and the player is routed to that bus.

Precomputed bus naming:

- Uses `target_bus_name` when authored.
- Otherwise auto-generates `XedatsPrecomputed_<resolution_key>`.

Bus effects are configured once per bus in this order:

1. Low-pass (if authored)
2. High-pass (if authored)
3. Reverb (if authored)

#### Fallback behavior

- Missing or invalid profile assets only emit a warning; import continues normally.
- When no profile resolves, playback falls back to the current runtime path with authored `gain`, occlusion, and distance-filtering defaults unchanged.
- If `XedatsSingleton` is absent, the precomputed gain multiplier still affects the plain `AudioStreamPlayer3D` fallback volume.

#### Inspecting applied values

When a profile resolves, the binding node exposes debug metadata including:

- `xedats_precomputed_profile_path`
- `xedats_precomputed_resolution_key`
- `xedats_precomputed_resolution_source`
- `xedats_precomputed_gain_multiplier`
- `xedats_precomputed_base_gain`
- `xedats_precomputed_effective_gain`
- `xedats_precomputed_enable_occlusion` when overridden
- `xedats_precomputed_enable_distance_filtering` when overridden
- `xedats_precomputed_bus` when a precomputed bus route is applied
- `xedats_precomputed_lowpass_hz`, `xedats_precomputed_highpass_hz`, `xedats_precomputed_reverb_wet`, `xedats_precomputed_reverb_room_size` when authored

---

### Group C/D Debug Hooks

For debug-tool integration, the current Group C/D implementation intentionally exposes importer + binding metadata keys that can be consumed without runtime code instrumentation.

Recommended minimum keys to display in a debug HUD/inspector:

- Resolve stage:
  - `xedats_precomputed_id`
  - `xedats_probe_region`
  - `xedats_precomputed_resolution_source`
  - `xedats_precomputed_resolution_key`
  - `xedats_precomputed_profile_path`
- Group C apply stage:
  - `xedats_precomputed_base_gain`
  - `xedats_precomputed_gain_multiplier`
  - `xedats_precomputed_effective_gain`
  - `xedats_precomputed_bus`
- Group D apply stage:
  - `xedats_texture_volume_variation`
  - `xedats_distance_volume_variation` (policy=`texture` only)

This key set is sufficient to debug the full Group C/D init-time chain: authoring extras → profile resolution → effective gain/route → distance modulation.

### Runtime snapshot APIs

Two lightweight debug surfaces are now available for tooling:

```gdscript
var binding_snapshot: Dictionary = binding.get_debug_snapshot()
var service_snapshot: Array[Dictionary] = service.get_all_record_debug_states()
```

`binding.get_debug_snapshot()` includes:
- resolved payload copy
- `xedats_runtime_path`
- `xedats_runtime_event_fallback`
- fallback-player presence/play-state/bus
- portal adapter metadata
- precomputed-resolution metadata
- texture and distance volume-variation metadata
- live `dynamic_record` state when the dynamic approximation service is present

`service.get_all_record_debug_states()` returns one dictionary per registered emitter with:
- emitter name/path/class
- the standard `get_record_debug_state()` fields
- `binding_debug` when the emitter also exposes `get_debug_snapshot()`

These APIs are intended as the lowest-friction substrate for future HUD, inspection, or console tooling without requiring invasive runtime instrumentation.

---

## OMI_audio_material

### What it does at runtime

Nodes or materials that carry `OMI_audio_material` receive:

- `omi_audio_material` metadata — the raw parsed values (absorption, transmission, reflection, optional category/bus).
- `xedats_omi_effect_chain` metadata — a ready-to-use `EffectChain` resource.
- `xedats_omi_bus` metadata — the Xedats bus name the chain was applied to (present only when `XedatsSingleton` is available).

If `XedatsSingleton` is absent the chain is stored in metadata only (no bus is created) and a warning is logged.

### JSON structure

```jsonc
// On a node directly
{
  "name": "WallPanel",
  "extensions": {
    "OMI_audio_material": {
      "absorption":   0.25,   // 0 = fully reflective, 1 = fully absorptive
      "transmission": 0.50,   // 0 = opaque to sound, 1 = fully transparent
      "reflection":   0.75,   // 0 = no reverb contribution, 1 = strong echo
      "extras": {
        "xedats_bus":      "WallSurface",   // bus name; auto-generated if omitted
        "xedats_category": "SFX"            // for future category-bus routing
      }
    }
  }
}
```

### EffectChain mapping

The three acoustic parameters map deterministically to a three-effect chain:

#### Low-pass filter (absorption)
```
cutoff_hz = lerp(20_000 Hz, 1_200 Hz, absorption)
```
- `absorption = 0.0` → 20 000 Hz (no filtering, full brightness)
- `absorption = 1.0` → 1 200 Hz (heavy absorber, significantly dulled)
- Controls how much high-frequency energy a surface soaks up.

#### High-pass filter (transmission)
```
cutoff_hz = lerp(40 Hz, 900 Hz, 1 − transmission)
```
- `transmission = 1.0` → 40 Hz (transparent surface, deep bass passes freely)
- `transmission = 0.0` → 900 Hz (opaque surface, thins out low-end bleed-through)
- Controls how much low-frequency energy bleeds through the material.

#### Reverb (reflection)
```
wet       = reflection
room_size = 0.2 + reflection × 0.7
```
- `reflection = 0.0` → dry, small room (wet=0, room=0.2)
- `reflection = 1.0` → full wet, large room (wet=1, room=0.9)
- Controls the perceived acoustic space that sound bouncing off this surface creates.

#### Representative values

| Surface type | absorption | transmission | reflection | Low-pass Hz | High-pass Hz | Reverb wet |
|---|---|---|---|---|---|---|
| Open air | 0.0 | 1.0 | 0.0 | 20 000 | 40 | 0.0 |
| Carpet | 0.8 | 0.2 | 0.1 | 5 360 | 620 | 0.1 |
| Concrete wall | 0.1 | 0.05 | 0.7 | 18 120 | 857 | 0.7 |
| Glass | 0.05 | 0.9 | 0.4 | 19 410 | 76 | 0.4 |
| Stone vault | 0.2 | 0.1 | 0.9 | 15 280 | 773 | 0.9 |

### Bus naming

If `extras.xedats_bus` is present the chain is applied to a bus with that exact name. Otherwise the importer auto-generates a name:

```
XedatsOMI_<NodeName>
```

### OMI precedence

When both node-level and material-level `OMI_audio_material` are authored for the same node, the importer uses:

1. Node-level `OMI_audio_material` (highest precedence)
2. Material-level `OMI_audio_material` resolved through `mesh.primitives[].material`

This precedence applies to parsed metadata values, mapped `EffectChain`, and selected bus name.

The bus is created (or confirmed) with `Master` as its parent. Re-importing with the same bus name is safe — `create_audio_bus()` is idempotent.

---

## Fallback Behaviour

When the Xedats runtime is fully absent (e.g. stripped from a server build or loading a test scene without autoloads):

| Situation | What happens |
|---|---|
| `XedatsSingleton` missing on emitter | `AudioStreamPlayer3D` fallback, random clip if multi-source |
| `AudioEventSystem` missing | Skipped; falls through to direct clip playback |
| `XedatsSingleton` missing on material | `EffectChain` stored as metadata; no bus created, warning logged |
| No loadable streams | Warning logged, emitter is silent |

Import always succeeds (returns `OK`). Missing-service and missing-stream paths still warn, but intentional event-to-clip fallback is tracked through metadata instead of a warning.

---

## Running Fixture Tests

The fixture runner validates the full import pipeline headlessly and is the recommended smoke-test after any change to the importer.

The runner script derives its fixture and test-audio paths from `XedatsGLTFConfig` rather than hardcoded `res://ProjectHelix/Xedats/...` constants. That means the fixture harness follows the configured Xedats root automatically once `XEDATS_ROOT` is updated.

Runtime file: `res://ProjectHelix/Xedats/Tests/GLTF/xedats_gltf_fixture_runner.gd`

The runner performs these steps:

1. Registers `GLTFDocumentExtensionXedatsAudio` at runtime.
2. Registers temporary fixture events in `AudioEventSystem`.
3. Imports each fixture via `GLTFDocument.append_from_file()` and `generate_scene()`.
4. Validates payload metadata, playback routing, and material/effect mapping.
5. Unregisters temporary events and frees generated scenes during teardown.

**In-editor:** Open `res://ProjectHelix/Xedats/Tests/GLTF/xedats_gltf_fixture_runner.tscn` and run the scene.

**Headless (CI):**
```powershell
& "j:\Godot_Install\Godot_v4.6.1-stable_mono_win64\Godot_v4.6.1-stable_mono_win64_console.exe" `
    --headless --path "j:\Godot_Projects\ProjectHelix\MainProject" `
    "res://ProjectHelix/Xedats/Tests/GLTF/xedats_gltf_fixture_runner.tscn"
```

Exit code `0` = all assertions passed.  
Exit code `1` = at least one assertion failed (details in stdout).

Expected warnings during a passing run:

- Most intentional negative-fixture warnings are now suppressed for high-signal CI output.
- Remaining warnings should indicate an actual unexpected regression or an unhandled new negative-path case.

Those warnings are part of the test coverage and do not indicate a failed run by themselves.

Current fixtures:

| Fixture | What it validates |
|---|---|
| `khr_audio_emitter_relative_uri.gltf` | Relative `../` URI normalises to a valid `res://` path |
| `khr_audio_emitter_default_category.gltf` | Category fallback resolves to `SFX` when category metadata is omitted |
| `khr_audio_emitter_event_name.gltf` | `extras.xedats_event` resolves to `AudioEventSystem` playback |
| `khr_audio_emitter_name_fallback.gltf` | Emitter `name` is used as event name when no explicit event metadata is present |
| `khr_audio_emitter_xedats_extras_valid.gltf` | Valid Xedats extras survive normalization unchanged |
| `khr_audio_emitter_xedats_extras_invalid.gltf` | Invalid Xedats extras warn and fall back/clamp safely |
| `khr_audio_emitter_reflection_budget_cap.gltf` | Reflection salience ranking and max-source cap selection |
| `khr_audio_emitter_texture_modulation.gltf` | Texture density/variance mapping into `AudioArrayContainer.volume_variation` |
| `khr_audio_emitter_distance_policy.gltf` | Distance-band policy parsing and safe no-listener modulation behavior |
| `khr_audio_emitter_portal_source_path_dot.gltf` | Auto-bind resolves `xedats_portal_source_path` to parent node (`.`) and applies portal adapter metadata |
| `khr_audio_emitter_portal_source_path_bad.gltf` | Invalid portal path skips auto-bind safely without import failure |
| `khr_audio_emitter_precomputed_missing.gltf` | Missing precomputed asset warns and falls back without hard import failure |
| `khr_audio_emitter_precomputed_probe_region.gltf` | Probe-region fallback resolves a precomputed profile when no direct id is authored |
| `omi_audio_material_node_extension.gltf` | Full OMI parse, `EffectChain` shape, numeric effect values, custom bus creation |
| `omi_audio_material_extremes.gltf` | OMI mapping at 0.0/1.0 edge ranges for deterministic effect outputs |
| `omi_audio_material_material_index.gltf` | Material-index OMI resolution path when node-level OMI is absent |
| `omi_audio_material_precedence.gltf` | Node-level OMI values/bus override material-level OMI on same node |
| `omi_audio_material_default_bus.gltf` | Deterministic fallback bus naming (`XedatsOMI_<NodeName>`) when `xedats_bus` is omitted |

Additional runtime assertions in the fixture runner:

- Category mute gate at emitter `_ready` (`muted_skip` runtime path when category is muted).
- Isolated `XedatsSingleton`-unavailable fallback path (`fallback_local`) in test mode.

---

## Extending This Document

As the module grows, add new sections here for:

- `KHR_audio_emitter` v2 positional cone data (inner/outer angle, range cutoff)
- `OMI_audio_material` multi-channel per-frequency-band absorption arrays
- Reverb zone volumes linked to OMI material bus sends
- Import-time asset validation and error reporting improvements
- Integration with Godot's physics-based audio occlusion

Keep the [Representative values](#representative-values) table updated as new surface presets are confirmed with playtest data.
