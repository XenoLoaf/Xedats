# GLTF Module — Optional

This subfolder contains the glTF audio import extension. It is **fully optional** — you can delete this entire directory and the core Xedats audio system will continue to function normally.

## What it provides

- `GLTFDocumentExtensionXedatsAudio` — glTF import pipeline hook for XEDATS_audio_emitter and XEDATS_audio_material extensions
- `XedatsGLTFAudioEmitterBinding` — runtime binding node for imported audio emitters
- `XedatsDynamicApproximationService` — runtime spatial approximation management
- Profile resources for distance bands, reflection budgets, OMI effect mapping, precomputed propagation
- Path configuration via `XedatsGLTFConfig` (auto-detects `res://addons/xedats/` when installed as addon)

## Dependencies (required to exist)

- `Core/` — `EffectChain`, `AudioArrayContainer`, `AudioEventSystem`, `AudioStateManager`
- `Nodes/` — `XedatsSingleton`, `XedatsPlayer3D`, `XedatsListener3D`

## What else to delete with this

If you delete `GLTF/`, also delete:
- `Tests_GLTF/` — GLTF test fixtures (hard dependency on GLTF classes)
- `addons/xedats/editor/propagation_baking_panel.gd` — depends on `XedatsGLTFConfig`, `XedatsPrecomputedPropagationProfile`
- `addons/xedats/editor/distance_band_profile_inspector_plugin.gd` — depends on `XedatsDistanceBandProfile`
- `addons/xedats/editor/distance_band_profile_preview.gd` — depends on `XedatsDistanceBandProfile`

The `addons/xedats/plugin.gd` editor plugin safely skips these if the files are missing (uses `ResourceLoader.exists()` guards).

## Safety

Use `XedatsModuleLoader.is_gltf_available()` before accessing any GLTF class at runtime.
