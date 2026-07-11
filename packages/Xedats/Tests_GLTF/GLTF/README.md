# Xedats glTF Fixture Tests

Open and run `res://MyProject/Xedats/Tests/GLTF/xedats_gltf_fixture_runner.tscn` to validate the current Xedats glTF importer path.

The runner's internal fixture/audio lookups are derived from `XedatsGLTFConfig.XEDATS_ROOT`, so moving the Xedats module to a different `res://` location normally only requires updating `res://MyProject/Xedats/Modules/GLTF/xedats_gltf_config.gd`.

Runner lifecycle:
- Registers `GLTFDocumentExtensionXedatsAudio` at runtime.
- Registers temporary fixture events in `AudioEventSystem`.
- Imports each fixture through `GLTFDocument`.
- Validates payload metadata and runtime mapping behavior.
- Unregisters temporary fixture events and frees generated scenes on teardown.

Covered fixtures:
- `khr_audio_emitter_relative_uri.gltf`: validates relative source URI normalization into a `res://` path.
- `khr_audio_emitter_event_name.gltf`: validates `extras.xedats_event` resolution into `AudioEventSystem` playback.
- `khr_audio_emitter_name_fallback.gltf`: validates emitter `name` fallback when explicit event metadata is not present.
- `khr_audio_emitter_xedats_extras_valid.gltf`: validates accepted Xedats extras remain intact after parsing.
- `khr_audio_emitter_xedats_extras_invalid.gltf`: validates invalid extras warn and fall back safely.
- `khr_audio_emitter_reflection_budget_cap.gltf`: validates reflection source ranking and budget capping.
- `khr_audio_emitter_texture_modulation.gltf`: validates texture density/variance modulation.
- `khr_audio_emitter_distance_policy.gltf`: validates distance-policy parsing and no-listener safe behavior.
- `khr_audio_emitter_portal_source_path_dot.gltf`: validates `extras.xedats_portal_source_path="."` auto-binds to the emitter's parent portal source.
- `khr_audio_emitter_portal_source_path_bad.gltf`: validates unresolved `xedats_portal_source_path` follows warning path and leaves adapter unbound.
- `khr_audio_emitter_precomputed_missing.gltf`: validates missing precomputed assets warn and preserve runtime fallback.
- `khr_audio_emitter_precomputed_probe_region.gltf`: validates probe-region fallback resolves a precomputed profile.
- `omi_audio_material_node_extension.gltf`: validates `XEDATS_audio_material` payload parsing, `EffectChain` mapping, and custom bus creation.

The runner registers the `GLTFDocumentExtension` at runtime, registers fixture audio events, imports each fixture via `GLTFDocument`, and prints a pass/fail summary to the Output panel.

Expected warnings during a passing run:
- Validation warnings from intentionally-invalid extras fixtures.
- Missing-profile or unresolved portal-source warnings for fixtures that intentionally exercise degraded runtime paths.

Runtime metadata verified by the runner includes:
- `xedats_runtime_path` on emitter bindings across the fixture suite.
- `xedats_runtime_event_fallback` when an authored event-like name deterministically falls back to clip playback.
- portal auto-bind metadata such as `xedats_portal_auto_bind_resolved_path` and `xedats_dynamic_portal_adapter_bound`.

Useful runtime debug APIs for tooling:
- `XedatsGLTFAudioEmitterBinding.get_debug_snapshot()`
- `XedatsDynamicApproximationService.get_record_debug_state(emitter)`
- `XedatsDynamicApproximationService.get_all_record_debug_states()`

Phase 12 validation checklist:
- Dot path fixture (`khr_audio_emitter_portal_source_path_dot.gltf`) preserves payload key and sets `xedats_portal_auto_bind_resolved_path`.
- Dot path fixture binds adapter (`xedats_dynamic_portal_adapter_bound = true`) and updates portal openness from `0.0 -> 1.0` after open-state signal.
- Bad path fixture (`khr_audio_emitter_portal_source_path_bad.gltf`) preserves payload key but leaves adapter unbound and does not set resolved-path metadata.
- Bad path fixture emits unresolved-path warning and retains authored `xedats_dynamic_portal_openness` as runtime fallback.
