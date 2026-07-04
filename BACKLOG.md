# Xedats — Backlog

_Last updated: 2026-06-30 (Phase D MIDI complete; Arena Rounds 6-8 complete; piano roll build queued)_

---

## Open Questions — Resolved

_All Q1–Q6 answered 2026-06-30. See `pipeline-kit/project-docs/core/phase-c-q-and-a-log.md` for full decisions._

| # | Topic | Resolution |
|---|-------|------------|
| Q1 | 2D auto-occlusion | **A** — Mirror 3D raycast pattern (`_check_occlusion_2d()`) |
| Q2 | 2D distance bands | **B** — Extend existing profile with `is_2d` flag |
| Q3 | Reverb zones | **A** — Wire both 3D and 2D to `AudioEffectReverb` on Master bus |
| Q4 | MIDI priority | **B** — 2D polish first, MIDI after |
| Q5 | MIDI design path | **B** — MIDI Event Sequencer (Option A requires GDExtension — deferred) |
| Q6 | Ease curves | **A** — Implement quad, cubic, expo, sine easing |

---

## Phase C — 2D Polish + MIDI Foundation

### Track 1: 2D Enhancements — COMPLETE

| # | Priority | Task | Status |
|---|----------|------|--------|
| 22 | Medium | **2D auto-occlusion** — `_check_occlusion_2d()` with `PhysicsRayQueryParameters2D`, `enable_occlusion`/`occlusion_check_interval` exports, `_process()` timer. | ✅ 2026-06-30 |
| 23 | Low | **Reverb zone wiring** — `_update_reverb_settings()` in both listeners applies `AudioEffectReverb` via `add_bus_effect()`. Zone metadata: `reverb_room_size`, `reverb_damping`, `reverb_wet`. | ✅ 2026-06-30 |
| 24 | Low | **2D distance band profiles** — `@export var is_2d: bool` flag added to `XedatsDistanceBandProfile`. | ✅ 2026-06-30 |

### Track 2: MIDI Foundation — COMPLETE

| # | Priority | Task | Depends | Status |
|---|----------|------|---------|--------|
| 25 | Planned | **MidiSequence** — pure-GDScript `.mid` binary parser (SMF format 0/1). Tempo, time sig, tracks, note-on/off with timing. → `MidiSequence` resource. | — | ✅ 2026-06-30 |
| 26 | Planned | **MidiSequencer** — consumes `MidiSequence`, dispatches notes through `AudioEventSystem`. Tempo override, looping, note→container mapping, pitch shifting. | #25 | ✅ 2026-06-30 |
| 27 | Planned | **MidiNoteMap** — resource mapping MIDI note numbers → event names or `AudioArrayContainer`. Instrument-per-track + default catch-all. | #26 | ✅ 2026-06-30 |
| 28 | Planned | **XedatsMIDIInput** — hardware MIDI input bridge capturing `InputEventMIDI`. CC→volume, note→event triggers. Platform-gated. | — | ✅ 2026-06-30 |

### Track 3: General Polish — COMPLETE

| # | Priority | Task | Status |
|---|----------|------|--------|
| 29 | Low | **`create_ease_curve()` real easing** — quad, cubic, expo, sine via `Tween.TransitionType`. | ✅ 2026-06-30 |
| 30 | Low | **`get_stream()` RANDOM modulo bias** — `randi() % size` → `randi_range(0, size - 1)`. | ✅ 2026-06-30 |
| 31 | Low | **`_get_random_no_repeat()` modulo bias** — same fix at lines 123, 132. | ✅ 2026-06-30 |

---

## Phase D — Scoped Feature Proposals

_Generated 2026-06-30 via three-agent feature scoping pipeline (MIDI, 2D, 3D). Features are proposed — not yet prioritized or sequenced._

### Track 4: MIDI Features — COMPLETE (Phase D Round 1+2)

| # | Feature | Scope | Status |
|---|---------|-------|--------|
| 32 | **MidiParameterAutomationLane** | Medium | ✅ 2026-06-30 |
| 33 | **MidiProgressiveLayering** | Medium | ✅ 2026-06-30 |
| 34 | **MidiStinger** | Small | ✅ 2026-06-30 |
| 35 | **MidiSoundDesignTimeline** | Medium | ✅ 2026-06-30 |
| 36 | **MidiLivePerformanceController** | Small | ✅ 2026-06-30 |
| 37 | **MidiRhythmGate** | Small | ✅ 2026-06-30 |

### Track 5: 2D Features (6 proposals)

| # | Feature | Scope | Description |
|---|---------|-------|-------------|
| 38 | **Viewport-Relative Audio Panning** | Medium | Screen-edge-aware panning — sounds near viewport edge pan to that speaker with configurable falloff curves. |
| 39 | **Parallax Audio Depth Layers** | Medium | Foreground/midground/far audio layers with per-layer `EffectChain` + gain offset. `XedatsPlayer2D.depth_layer` auto-routes. |
| 40 | **Audio Fog-of-War / Visibility Filter** | Medium | Per-frame low-pass + volume reduction on 2D players in non-visible regions. Grid/Area2D/tile-based visibility. |
| 41 | **UI Audio Zoning** | Small | Rectangular screen regions trigger hover/click audio via `AudioEventSystem`. Declarative — no per-button code. |
| 42 | **Tilemap Audio Emission Patterns** | Large | Paint audio data layers on `TileMap`. Auto-spawn pooled 2D players, surface footstep metadata, viewport-culled recycling. |
| 43 | **Audio Stinger / Priority Ducking** | Medium | Priority-based ducking with spatial-region awareness — only players within screen-radius get ducked. Queue with interruption. |

### Track 6: 3D Features (5 proposals)

| # | Feature | Scope | Description |
|---|---------|-------|-------------|
| 44 | **Per-Player Dynamic Effect Bus** | Med-Large | Implements `_update_occlusion_filtering()` + `_update_distance_filtering()` stubs. Per-player bus with lowpass modulated by occlusion raycast. | ✅ 2026-06-30 |
| 45 | **Audio Rooms & Portals** | Large | `AudioRoom3D` areas with `EffectChain` acoustic profiles connected by `AudioPortal3D`. Uses existing `DynamicApproximationService` portal hooks. |
| 46 | **Acoustic Material Response** | Med-Large | Occlusion raycast reads hit-surface acoustic properties. Wood=mild lowpass, concrete=heavy lowpass. Uses `OMIEffectMappingProfile` at runtime. |
| 47 | **Audio LOD System** | Medium | 4-tier distance-based fidelity: near=full, mid=reduced, far=shared bus, beyond=culled to proxy. Uses `DistanceBandProfile` + pool. |
| 48 | **Environmental Audio Zones** | Medium | `AudioEnvironmentZone3D` volumes with `EffectChain` profiles. Priority blending, boundary interpolation. Pre-built: Underwater, Cave, Open Field. |

---

## Known Issues

| # | Severity | Issue | Status |
|---|----------|-------|--------|
| 2 | Medium | Dual bootstrap: `GameEnvironment.gd` and `AutoloadManagerScript` both instantiate debug singletons | Bundled version only |
| 4 | Low | Three stub methods in `XedatsPlayer3D` | ✅ RESOLVED — #44 implemented per-player effect bus |
| 5 | Medium | **2D hard-coupled to singleton** | ✅ RESOLVED — 2D decoupled: arrays→untyped, constructors→ClassDB.instantiate(), methods gated with class_exists. Deletion test passes. |
| 6 | Low | AGENTS.md engine path references `v4.7-beta2` — should be `v4.7-stable` | ✅ RESOLVED — updated to v4.7-stable test-project path |
| 7 | Medium | GLTF path functions (`modules_root`, `resources_root`, `tests_root`) assume canonical layout — paths may not resolve correctly in addon layout | Tracked for path resolution cleanup |
| 8 | Low | Test-project `plugin.gd` must be manually resynced after source edits (copied, not junctioned) | T1 Phase 2 detects staleness |
| 9 | Medium | **Piano roll needs rewrite** — current `MidiNoteMapDialog` is clunky, no scroll, AcceptDialog-based. Arena Round 7-8 produced complete specs. | ✅ RESOLVED — #49 complete: Window+ScrollContainer, inline edit, range paint, visual spec |
| 10 | Low | **Arena rounds need cleanup** — Rounds 6-7 have ABSORBED files ready for deletion. M16 manifest written. | ✅ RESOLVED — 7 ABSORBED files deleted, retained files verified |
| 11 | Medium | **MidiParameterAutomationLane re-processes CC events when synced to paused sequencer** | ✅ RESOLVED — `_last_processed_tick` guard prevents re-processing |
| 12 | Low | **MidiStinger `fade_duration` field defined but unused** | ✅ RESOLVED — `_process()` lerps category volume over fade_duration |

---

## New Tasks

| # | Priority | Task | Source |
|---|----------|------|--------|
| 49 | High | **Piano Roll Rewrite (Phase 1)** — Window+scroll+draw engine+inline edit+paint system+status bar. ~350 lines, 2 files. | ✅ 2026-06-30 |
| 50 | Medium | **Arena Cleanup (M16)** — Delete 7 ABSORBED files from Rounds 6-7. RETAIN Round 8 until #49 complete. | ✅ 2026-06-30 |
| 51 | High | **MIDI automated test suite** — 16 test cases covering MidiSequence parsing, tempo/timing, note events, MidiNoteMap resolution, MidiAutomationBinding, MidiStingerDefinition, MidiParameterAutomationLane lifecycle, MidiSequencer lifecycle, pool stats. | ✅ 2026-06-30 — 16 cases in `test_midi_pipeline.gd`. Headless-only limitation: scene-based MIDI tests timeout due to class resolution cascade. Verified editor-safe via compile check. |
| 52 | Medium | **Phase 2-3 Deferred Proposals** — 6 items from Arena R6-7 with gating criteria: zone canvas, velocity/pitch lanes, template system, dimension lens, spreadsheet view, instant audition. Blocked until piano roll (#49) ships + community demand. | Arena R6-7 |

---

## Infrastructure & Pipeline Tasks (Completed)

| # | Task | Completed |
|---|------|-----------|
| 24 | **Round 2 implementation** — 2D auto-occlusion, reverb zones, distance band `is_2d`, ease curves, modulo bias fixes. 6 files changed, 0 compile errors. | 2026-06-30 |
| 25 | **Modularity improvements** — `plugin.gd` conditional loading, `SilentPlayer` duck-type, `AudioEventSystem` 2D guard, `XedatsModuleLoader`, optional subdirectory docs, `XedatsGLTFConfig` auto-detect, UID→path preloads. | 2026-06-30 |
| 26 | **Test environment** — `test-project/` created with `project.godot`, directory junctions, shim directories, smoke tests. `Shared/` directory added. `MIDI/` and `Tools_Xebug/` scaffolded. | 2026-06-30 |
| 27 | **Pipeline protocols** — P1-P8 (project dev) + T1-T5 (test environment) defined in `protocols/xedats-pipelines.md`. P1 prior to/after every change. T1 at session start. | 2026-06-30 |
| 28 | **XEDATS_INTEGRATION.md** — Agent prompt for installing Xebug into Xedats test projects. 6-phase pipeline: discovery, Xebug install, bridge module, plugin enable, compile check, smoke test. | 2026-06-30 |
| 29 | **Tools_Xebug/** — Four Xebug companion modules: `XedatsPoolMonitor`, `XedatsBusInspector`, `XedatsEventMonitor`, `XedatsRuntimeValidator`. Auto-discoverable, deletion-safe. | 2026-06-30 |
| 30 | **Q&A log** — All Q1-Q6 design questions answered with pros/cons research and scope resolution. `phase-c-q-and-a-log.md`. | 2026-06-30 |
| 31 | **MIDI Foundation (#25-28)** — MidiSequence (SMF parser), MidiSequencer (playback node), MidiNoteMap (mapping resource), XedatsMIDIInput (hardware bridge). 4 files, ~800 lines. | 2026-06-30 |
| 32 | **MIDI Phase D (#32-37)** — MidiSoundDesignTimeline, MidiStinger+MidiStingerDefinition, MidiRhythmGate, MidiParameterAutomationLane+MidiAutomationBinding, MidiProgressiveLayering+MidiLayerDefinition, MidiLivePerformanceController. 9 files, ~1300 lines. | 2026-06-30 |
| 33 | **Arena Session 1 — Bug fixes** — 2D MIDI path, super._dispatch_note() chain, pool sizes as @export, stinger priority guard, layering deadlock fix. 5 fixes across 5 files. | 2026-06-30 |
| 34 | **Arena Session 2-3 — 2D path + MidiNoteMap editor** — 2D offset support in timeline/XedatsMIDIInput, piano-roll editor with inspector plugin. | 2026-06-30 |
| 35 | **3D Per-Player Dynamic Effect Bus (#44)** — Implemented _setup_spatial_audio(), _update_occlusion_filtering(), _update_distance_filtering() with per-player AudioEffectLowPassFilter. | 2026-06-30 |
| 36 | **2D Singleton Decoupling (#5)** — 66 2D type references converted: typed arrays→untyped, constructors→ClassDB.instantiate(), methods gated with class_exists. Deletion test passes. | 2026-06-30 |
| 37 | **Arena Rounds 6-8** — 3 DIVERGE+CONVERGE rounds: MIDI pipeline synthesis (21 agent files), piano roll redesign (12 agent files), interactive build session (9 agent files). | 2026-06-30 |
| 38 | **Quick fixes (#6, #11, #12)** — AGENTS.md engine path (beta2→stable), CC re-processing guard, stinger fade_duration lerp. | 2026-06-30 |
| 39 | **Piano Roll Rewrite (#49)** — MidiNoteMapEditor (Window+ScrollContainer, inline LineEdit, range paint, 128-key draw with spec colors, status bar, hint dots, banner). ~350 lines. | 2026-06-30 |

---

## Version / Sync Status

| Item | State |
|------|-------|
| Primary source | This repo — `xedats_master`, linked to `XenoLoaf/Xedats-Standalone` on GitHub |
| Canonical source (legacy) | `j:\Godot_Projects\Xedats\Packages\Xedats\` — **being phased out / relocated** |
| Last updated | 2026-06-30 — Phase D MIDI complete; 3D per-player bus done; 2D decoupled; Arena R6-8 complete; piano roll build queued |

---

## Scope Boundary

The **XenoLoaf Tool Suite** (a pre-wired bundle of Xedats + Xebug + AutoloadManager + GameEnvironment) is a future separate workspace and repository. It is explicitly **out of scope** for this standalone repository.

MIDI hardware synthesis (GDExtension-backed real-time synth, soundfont rendering — Options A and C from audit) is **out of scope** and would require a separate investigation with explicit approval.

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
| 11 | Phase 5 code review — Bug fix: `AudioCrossfade` — `set_volume_linear`/`get_volume_linear` calls replaced with `set_volume_linear_normalized`/`get_volume_linear_normalized`; completion block no-op fixed to `set_volume_linear_normalized(1.0)` | 2026-05-21 |
| 12 | Phase 5 code review — Type annotation pass: `AudioCrossfade.gd`, `AudioArrayContainer.gd`, `EffectChain.gd`, `XedatsConsoleModule` (already clean) | 2026-05-21 |
| 13 | Phase 6 docs audit — Bug fix: `Getting_Started.md` §6c — `audio.trigger_audio_event_with_params()` doesn't exist on `XedatsSingleton`; corrected to `audio.get_event_system().trigger_event_with_params()` | 2026-05-21 |
| 14 | Phase 6 docs audit — Type annotation pass: all code examples in `Getting_Started.md` and `Xedats.md` updated to explicit type style | 2026-05-21 |
| 15 | Phase 7 GLTF review — `@tool` guard audit complete: no changes needed (import-pipeline methods are editor-only by design) | 2026-05-22 |
| 16 | Phase 7 GLTF review — Type annotation pass: 9 for-loop variable declarations in `xedats_gltf_document_extension.gd` | 2026-05-22 |
| 17 | **2D audio implementation (Phases 1–8):** XedatsPlayer2D.gd, XedatsListener2D.gd, singleton 2D pool, duck-typed crossfade, event `is_3d` flag, console module 2D inspection, docs | 2026-06-06 |
| 18 | **Phase A — Folder restructure:** `Base Scripts/`→`Core/`, `Modules/GLTF/`→`GLTF/`+`GLTF_Docs/`, `Resources/GLTF/`→`GLTF/Profiles/`, `Tests/`→`Tests_GLTF/`. Stale `.uid` files removed. | 2026-06-06 |
| 19 | **Phase B — Bug fixes & polish (7 items):** AudioStateManager prints verified-guarded; validation methods merged; perf timer→_process; randi()→counters (4 slots); modulo bias→randi_range(); crossfade orphan cleanup; AudioArrayContainer editor warning gated. | 2026-06-06 |
| 20 | **PF2 — Distance band profile editor UI:** `addons/xedats/` plugin with `EditorInspectorPlugin` + visual preview (`_draw()`-based band ruler, gain/rate bars, test-distance slider). | 2026-06-06 |
| 21 | **PF3 — Precomputed propagation baking tool:** editor dock panel with profile list, full detail form (14 fields), create/save/delete actions, browseable directory path. | 2026-06-06 |
| 22 | **System audit + API log:** full codebase audit of all 30 files / ~9,300 lines across 6 layers. Complete public API log. 2D parity gap analysis. MIDI feasibility research (5 design options). Output: `docs/AUDIT_2026-06-27.md`. | 2026-06-27 |
| 23 | **BACKLOG.md Phase C planning:** restructured with open questions section (Q1–Q6), three implementation tracks (2D, MIDI, polish), candidate task list (#22–#31). | 2026-06-27 |
