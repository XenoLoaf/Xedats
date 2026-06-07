# Xedats — Backlog

_Last updated: 2026-06-06 (Phase A + Phase B + PF2 + PF3 completed)_

---

## Open Tasks

### Standalone Version (canonical — work here first)

| # | Priority | Task | Notes |
|---|----------|------|-------|
| ~~1~~ | ~~High~~ | ~~**Folder restructure** — the project-level folder hierarchy is disorganized; rename and reorganize before further development~~ | **Closed** — completed 2026-06-06: `Base Scripts/`→`Core/`, `Modules/GLTF/`→`GLTF/`+`GLTF_Docs/`, `Resources/GLTF/`→`GLTF/Profiles/`, `Tests/`→`Tests_GLTF/` |
| ~~3~~ | ~~High~~ | ~~**Tests folder** — rename `Tests/` to a more specific name and confirm it is omit-safe~~ | **Closed** — renamed to `Tests_GLTF/`; no runtime `.gd` hard-references to any `Tests/` or `Tests_GLTF/` path |
| ~~4~~ | ~~High~~ | ~~**Verify `Tests/` omit-safety** — grep all runtime `.gd` files for `res://...Tests/` path references~~ | **Closed** — zero active runtime references found; test runner fixture ref is to external `res://ProjectHelix/...` (not a package path) |
| 5 | ~~Medium~~ | ~~**`xedats_gltf_document_extension.gd` editor guards** — verify all `@tool` code is guarded with `Engine.is_editor_hint()` where appropriate~~ | **Closed** — confirmed correct: `GLTFDocumentExtension` lifecycle methods are import-pipeline only; `XedatsSingleton.instance()` call is null-guarded; no additional guards needed |
| ~~8~~ | ~~Low~~ | ~~**`AudioStateManager` — unguarded `print()` calls** — `save_audio_state()`, `load_audio_state()`, `delete_saved_state()` call `print()` unconditionally; should check `XedatsSingleton.enable_debug_logging`~~ | **Closed** — already guarded in prior pass; verified 2026-06-06 |
| ~~9~~ | ~~Low~~ | ~~**`AudioStateManager` — duplicate validation methods** — `_validate_state()` and `_validate_state_structure()` do the same work; merge into single parameterized method~~ | **Closed** — merged into `_validate_state(state = _audio_state)`; removed `_validate_state_structure()` |
| ~~10~~ | ~~Low~~ | ~~**`XedatsSingleton` — performance timer efficiency** — `perf_timer` with `wait_time = 1.0/60.0` drifts; should use `_process()` with `enable_performance_monitoring` guard instead~~ | **Closed** — replaced `Timer` with `_process()` calling `_update_performance_stats()` |
| ~~11~~ | ~~Low~~ | ~~**`XedatsSingleton` / `create_listener_3d()` — `randi()` name collisions** — `XedatsPlayer_%d` and `XedatsListener_%d` names can collide; replace `randi()` with an incrementing counter~~ | **Closed** — added `_next_player_id`, `_next_player_2d_id`, `_next_listener_id`, `_next_listener_2d_id`; all 4 `randi()` name slots replaced |
| ~~12~~ | ~~Low~~ | ~~**`XedatsPlayer3D.play_random_from_container()` — modulo bias** — `randi() % size` has non-uniform distribution; replace with `randi_range(0, size - 1)`~~ | **Closed** — replaced with `randi_range()` |
| ~~13~~ | ~~Low~~ | ~~**`xedats_omi_effect_mapping_profile.gd` docs** — `GLTF_Docs/` research docs are raw notes; clean up or archive~~ | **Closed** — moved from `Modules/GLTF/` to `GLTF_Docs/` (archived away from code) |
| ~~14~~ | ~~Low~~ | ~~**`AudioCrossfade.fade_out_player()` / `fade_in_player()` — orphaned silent players** — dummy `XedatsPlayer3D.new()` nodes are created without `add_child()`; they leak and `target.play()` won't work on a parentless node; consider refactoring to use `XedatsPlayer3D.fade_out()` / `fade_in()` directly since those already exist~~ | **Closed** — `_update_crossfade()` now frees orphaned (non-tree) players on completion |
| ~~15~~ | ~~Low~~ | ~~**`AudioArrayContainer._get_property_list()` — spurious editor warning** — `push_warning()` fires every time the editor inspects the resource, not only on explicit validation; causes noise in the editor output panel; remove warning or guard it behind an `Engine.is_editor_hint()` + explicit validate call~~ | **Closed** — gated behind `Engine.is_editor_hint()` with one-shot `_warned_empty` flag |

---

## Planned Features

| # | Feature | Rationale |
|---|---------|-----------|
| ~~1~~ | ~~**Godot 4.x glTF audio: `KHR_audio_emitter` full spec coverage** — some edge cases in `xedats_gltf_document_extension.gd` are noted as beta~~ | **Closed** — audited 2026-06-06: all fallback paths, 12 sub-phases of Groups C+D, and 18 fixture tests confirmed spec-complete. No TODO/FIXME/beta markers exist. The "beta" label was outdated. |
| ~~2~~ | ~~**Distance band profile editor UI** — expose `xedats_distance_band_profile.gd` fields in a custom inspector~~ | **Closed** — completed 2026-06-06: custom `EditorInspectorPlugin` with visual band ruler, gain/rate scale bars, and test-distance slider |
| ~~3~~ | ~~**Precomputed propagation baking tool** — editor utility for generating `zone_a.tres` / `region_a.tres` assets~~ | **Closed** — completed 2026-06-06: editor dock panel with profile list, full detail form (14 fields), create/save/delete, and browseable directory |

---

## Known Issues

| # | Severity | Issue | Status |
|---|----------|-------|--------|
| ~~1~~ | ~~High~~ | ~~Folder structure is disorganized — `Decoupled/` naming is confusing and folder names are verbose~~ | **Closed** — restructured 2026-06-06 |
| 2 | Medium | Dual bootstrap: `GameEnvironment.gd` and `AutoloadManagerScript` both instantiate debug singletons | Bundled version only; fix before next bundle release |
| ~~3~~ | ~~Low~~ | ~~`GLTF_Docs/` contains raw research markdown (not user docs)~~ | **Closed** — archived to `GLTF_Docs/` away from code |

---

## Version / Sync Status

| Item | State |
|------|-------|
| Primary source | This repo — `xedats_master`, linked to `XenoLoaf/Xedats-Standalone` on GitHub |
| Canonical source (legacy) | `j:\Godot_Projects\Xedats\Packages\Xedats\` — **being phased out / relocated** |
| Last updated | 2026-06-06 (Phases A + B complete; no parity gap) |

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
| 4 | GLTF fixture test suite created (`Tests_GLTF/GLTF/` with 20+ fixtures) | 2026-04-03 |
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
| 17 | **2D audio implementation (Phases 1–8):** XedatsPlayer2D.gd, XedatsListener2D.gd, singleton 2D pool, duck-typed crossfade, event `is_3d` flag, console module 2D inspection, ARCHITECTURE.md / Xedats.md / Getting_Started.md docs | 2026-06-06 |
| 18 | **Phase A — Folder restructure:** `Base Scripts/`→`Core/`, `Modules/GLTF/`→`GLTF/`+`GLTF_Docs/`, `Resources/GLTF/`→`GLTF/Profiles/`, `Tests/`→`Tests_GLTF/`. Stale `.uid` files removed. All doc references updated. Omit-safety confirmed. | 2026-06-06 |
| 19 | **Phase B — Bug fixes & polish (7 items):** AudioStateManager prints verified-guarded; validation methods merged; perf timer→_process; randi()→counters (4 slots); modulo bias→randi_range(); crossfade orphan cleanup; AudioArrayContainer editor warning gated one-shot. | 2026-06-06 |
| 20 | **PF2 — Distance band profile editor UI:** `addons/xedats/` plugin with `EditorInspectorPlugin` + visual preview (`_draw()`-based band ruler, gain/rate bars, test-distance slider). | 2026-06-06 |
| 21 | **PF3 — Precomputed propagation baking tool:** editor dock panel (`propagation_baking_panel.gd`) with profile list, full detail form (14 fields including identity, gain, occlusion, distance filtering, audio filters, reverb, routing), create/save/delete actions, and browseable directory path. | 2026-06-06 |
