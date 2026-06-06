# Xedats — Backlog

_Last updated: 2026-05-22_

---

## Open Tasks

### Standalone Version (canonical — work here first)

| # | Priority | Task | Notes |
|---|----------|------|-------|
| 1 | High | **Folder restructure** — the project-level folder hierarchy is disorganized; rename and reorganize before further development | Sub-planning session required; do not rename files until `res://` paths inventoried |
| 3 | High | **Tests folder** — rename `Tests/` to a more specific name and confirm it is omit-safe (no runtime scripts hard-reference paths inside it) | Proposed names: `Tests_GLTF/`, `GLTF_Tests/` — decision needed |
| 4 | High | **Verify `Tests/` omit-safety** — grep all runtime `.gd` files for `res://...Tests/` path references | Must be zero hits before tests can be safely omitted |
| 5 | ~~Medium~~ | ~~**`xedats_gltf_document_extension.gd` editor guards** — verify all `@tool` code is guarded with `Engine.is_editor_hint()` where appropriate~~ | **Closed** — confirmed correct: `GLTFDocumentExtension` lifecycle methods are import-pipeline only; `XedatsSingleton.instance()` call is null-guarded; no additional guards needed |
| 8 | Low | **`AudioStateManager` — unguarded `print()` calls** — `save_audio_state()`, `load_audio_state()`, `delete_saved_state()` call `print()` unconditionally; should check `XedatsSingleton.enable_debug_logging` | |
| 9 | Low | **`AudioStateManager` — duplicate validation methods** — `_validate_state()` and `_validate_state_structure()` do the same work; merge into single parameterized method | |
| 10 | Low | **`XedatsSingleton` — performance timer efficiency** — `perf_timer` with `wait_time = 1.0/60.0` drifts; should use `_process()` with `enable_performance_monitoring` guard instead | |
| 11 | Low | **`XedatsSingleton` / `create_listener_3d()` — `randi()` name collisions** — `XedatsPlayer_%d` and `XedatsListener_%d` names can collide; replace `randi()` with an incrementing counter | |
| 12 | Low | **`XedatsPlayer3D.play_random_from_container()` — modulo bias** — `randi() % size` has non-uniform distribution; replace with `randi_range(0, size - 1)` | |
| 13 | Low | **`xedats_omi_effect_mapping_profile.gd` docs** — `Modules/GLTF/` research docs are raw notes; clean up or archive | |
| 14 | Low | **`AudioCrossfade.fade_out_player()` / `fade_in_player()` — orphaned silent players** — dummy `XedatsPlayer3D.new()` nodes are created without `add_child()`; they leak and `target.play()` won't work on a parentless node; consider refactoring to use `XedatsPlayer3D.fade_out()` / `fade_in()` directly since those already exist | |
| 15 | Low | **`AudioArrayContainer._get_property_list()` — spurious editor warning** — `push_warning()` fires every time the editor inspects the resource, not only on explicit validation; causes noise in the editor output panel; remove warning or guard it behind an `Engine.is_editor_hint()` + explicit validate call | |

---

## Planned Features

| # | Feature | Rationale |
|---|---------|-----------|
| 1 | **Godot 4.x glTF audio: `KHR_audio_emitter` full spec coverage** — some edge cases in `xedats_gltf_document_extension.gd` are noted as beta | Track against upstream spec changes |
| 2 | **Distance band profile editor UI** — expose `xedats_distance_band_profile.gd` fields in a custom inspector | Quality of life for audio designers |
| 3 | **Precomputed propagation baking tool** — editor utility for generating `zone_a.tres` / `region_a.tres` assets | Currently manual |

---

## Known Issues

| # | Severity | Issue | Status |
|---|----------|-------|--------|
| 1 | High | Folder structure is disorganized — `Decoupled/` naming is confusing and folder names are verbose | Phase 0 of audit |
| 2 | Medium | Dual bootstrap: `GameEnvironment.gd` and `AutoloadManagerScript` both instantiate debug singletons | Bundled version only; fix before next bundle release |
| 3 | Low | `Modules/GLTF/` contains raw research markdown (not user docs) | Archive or clean up |

---

## Version / Sync Status

| Item | State |
|------|-------|
| Canonical source | `j:\Godot_Projects\Xedats\Packages\Xedats\` |
| Last synced to this repo | 2026-05-20 (Phase 8 — Phases 4–7 sync) |
| Parity check | Manual — compare files against canonical source before each release |
| AutoloadManager-coupled version | `j:\Godot_Projects\Xedats\DevProject\Xedats\` |

> **Workflow:** Make all changes in the standalone canonical source first. Port to the AutoloadManager-coupled version only after standalone changes are validated. Then sync this repository.

---

## Scope Boundary

The **XenoLoaf Tool Suite** (a pre-wired bundle of Xedats + Xebug + AutoloadManager + GameEnvironment) is a future separate workspace and repository. It is explicitly **out of scope** for this standalone repository.

---

## Completed

| # | Task | Completed |
|---|------|-----------|
| 1 | Standalone bootstrap rewrite — `XedatsSingleton.gd` no longer inherits `AutoloadDocking` | 2026-04-03 |
| 2 | Subsystem access normalized — `AudioEventSystem`, `AudioStateManager`, `AudioCrossfade` resolve through `XedatsSingleton` | 2026-04-03 |
| 3 | `XedatsConsoleModule` extracted as separate optional package | 2026-04-03 |
| 4 | GLTF fixture test suite created (`Tests/GLTF/` with 20+ fixtures) | 2026-04-03 |
| 5 | `package-matrix.md` written and accurate | 2026-04-03 |
| 6 | Phase 4 code review — Bug fix: `_check_occlusion()` — `result != null` always true; fixed to `not result.is_empty()` | 2026-05-21 |
| 7 | Phase 4 code review — Bug fix: `AudioEventSystem.trigger_event()` — signal accumulation on pooled players; fixed with `CONNECT_ONE_SHOT` | 2026-05-21 |
| 8 | Phase 4 code review — Type annotation pass: `XedatsSingleton.gd`, `XedatsPlayer3D.gd`, `XedatsListener3D.gd`, `AudioEventSystem.gd`, `AudioStateManager.gd` | 2026-05-21 |
| 9 | Phase 4 code review — Dead variable removed: `_start_volume` in `XedatsPlayer3D.fade_in()` was computed but never used | 2026-05-21 |
| 10 | Phase 4 code review — `AudioEventSystem.trigger_event()` — duplicate `XedatsSingleton.instance()` calls hoisted to single call before player creation branch | 2026-05-21 |
| 11 | Phase 5 code review — Bug fix: `AudioCrossfade` — `set_volume_linear` / `get_volume_linear` calls replaced with `set_volume_linear_normalized` / `get_volume_linear_normalized`; completion block no-op fixed to `set_volume_linear_normalized(1.0)` | 2026-05-21 |
| 12 | Phase 5 code review — Type annotation pass: `AudioCrossfade.gd`, `AudioArrayContainer.gd`, `EffectChain.gd`, `XedatsConsoleModule` (already clean) | 2026-05-21 |
| 13 | Phase 6 docs audit — Bug fix: `Getting_Started.md` §6c — `audio.trigger_audio_event_with_params()` doesn’t exist on `XedatsSingleton`; corrected to `audio.get_event_system().trigger_event_with_params()` | 2026-05-21 |
| 14 | Phase 6 docs audit — Type annotation pass: all code examples in `Getting_Started.md` and `Xedats.md` updated to explicit type style | 2026-05-21 |
| 15 | Phase 7 GLTF review — `@tool` guard audit complete: no changes needed (import-pipeline methods are editor-only by design) | 2026-05-22 |
| 16 | Phase 7 GLTF review — Type annotation pass: 9 for-loop variable declarations in `xedats_gltf_document_extension.gd` | 2026-05-22 |
