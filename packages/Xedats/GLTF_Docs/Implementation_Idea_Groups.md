# Xedats Spatial Audio Implementation Idea Groups

This page clusters research-driven ideas into implementation families so planning can be parallelized without losing fallback safety.

Before implementing Group F and Group A, use the staged debug build plan in:
**[../../XedatsDebugTool_Plan.md](../../XedatsDebugTool_Plan.md)**

## Example Project Pass (Godot Spatial Audio Resources)

This pass reviewed implementation patterns in:
- `SpatialAudio3D-main/addons/spatial_audio_3d/spatial_audio_3d.gd`
- `godot-spatial-audio-main/addons/gd_spatial_audio/*`

The goal is to extract practical sequencing guidance for Xedats + glTF integration without introducing hard dependencies or removing fallback behavior.

### Practical patterns worth adopting

1. **Bounded incremental physics/audio work**
  - Both examples avoid heavy all-at-once updates by spreading ray/scan work over frames and using update intervals.
  - Xedats implication: keep Group A/D runtime passes on strict per-frame budgets and deterministic tick scheduling.

2. **Per-emitter dedicated bus/effect chain ownership**
  - Example player nodes create dedicated buses and own effect state updates.
  - Xedats implication: keep importer/runtime binding at emitter granularity, with deterministic `EffectChain` generation from OMI metadata and isolated updates.

3. **Material-driven acoustics via explicit mapping resources**
  - `ExpandedPhysicsMaterial` + mapper dictionary demonstrates data-driven material semantics.
  - Xedats implication: continue using deterministic OMI-to-EffectChain mapping tables/resources (not ad hoc per-scene branching).

4. **Graceful degradation paths**
  - Examples default to simpler behavior when advanced context is unavailable.
  - Xedats implication: preserve current contract: warn and skip advanced Xedats-specific bindings if singleton/event/state services are absent.

5. **Staged complexity (simple first, advanced later)**
  - The examples layer raycast reverb/occlusion first, then richer modeling.
  - Xedats implication: align Group F/A/B before C/E to keep iteration fast and testable.

### Phase 12 — Importer-authored auto-bind portal path + Interactable signals
*Completed 2026-03-14*

`xedats_portal_source_path` extras key added to `_parse_xedats_emitter_extras` in the document extension; passed through the emitter payload to `XedatsGLTFAudioEmitterBinding`. In `_ready()`, if the key is present a `call_deferred(&"_auto_bind_portal_source")` is queued so the live scene tree is fully settled before path resolution. `_auto_bind_portal_source()` walks three resolution strategies (relative-to-parent, relative-to-self, absolute) and calls `bind_dynamic_portal_state_source()` automatically when a valid portal source is found. Meta `xedats_portal_auto_bind_resolved_path` is set on success. Common value `"."` binds the parent glTF door node itself.

### Updated “what/when” guidance

#### Now (active cycle)
- **Group F:** Formalize `xedats_*` extras validation and warning breadcrumbs.
- **Group A (MVP slice):** Add reflection budget caps and deterministic ordering hooks only (no major propagation rewrite).
- **Group B (import metadata only):** Pass through texture/variance extras and retain safe no-op behavior when absent.
- **Group C:** Baseline precomputed propagation lookup is implemented; focus now is debug visibility polish + authoring quality checks.
- **Group D:** Baseline dynamic approximation + portal hooks are implemented; focus now is runtime tuning + debug observability.

#### Next (after current glTF bridge stabilization)
- **Group A (phase 2):** Elevation-aware salience weighting once debug tooling verifies perceptual gains.
- **Group B (phase 2):** Distance-band modulation policies for texture emitters using existing `AudioArrayContainer` flow.
- **Group F (phase 2):** Expand schema coverage and typed diagnostics for new extras keys as Groups A/B mature.

#### Later (pipeline-heavy)
- **Group E:** Offline authoring assistants that output deterministic resources only.

### Guardrails from this pass

- Keep all advanced logic optional at import/runtime.
- Do not fail glTF import when Xedats services are missing.
- Keep `SFX` as default category when metadata is absent.
- Respect `AudioStateManager` mute state during spawn/init binding.
- Prefer typed, data-driven helpers/resources over extension-specific hard-coded branches.

## Group A — Perceptual Reflection Selection

**Goal:** Keep reflections perceptually convincing while reducing runtime complexity.

### Included ideas
- Salience-ranked early reflection selection.
- Reflection count budgets by quality tier (`low`, `medium`, `high`).
- Elevation-aware reflection weighting.

### Candidate data inputs
- Listener-source geometry.
- Optional authored salience hints in glTF extras.
- Category context (`VoiceLines` vs `Ambient`).

### MVP deliverables
1. Reflection budget config resource.
2. Salience sorting utility with deterministic ordering.
3. Runtime cap enforcement with fallback to current behavior.

### Risks
- Over-aggressive culling can reduce spaciousness.
- Speech and ambience may require different heuristics.

---

## Group B — Texture / Extended Source Rendering

**Goal:** Improve ambience realism for non-point emitters (rain, stream, crowd, machinery beds).

### Included ideas
- “Texture emitter” profile on top of existing `AudioArrayContainer` flow.
- Distance-band event-rate and loudness-distribution control.
- Occlusion-sensitive variation depth.

### Candidate glTF extras (draft)
- `xedats_texture_profile`
- `xedats_texture_density`
- `xedats_texture_variance`

### MVP deliverables
1. Importer pass-through of texture extras to emitter payload metadata.
2. Binding-time modulation of spawn cadence / gain spread.
3. Safe ignore path when extras are absent.

### Risks
- Too much randomization can mask gameplay-critical cues.
- Needs category-aware tuning defaults.

---

## Group C — Precomputed Propagation Assets

**Goal:** Trade offline bake time for runtime stability and quality.

### Included ideas
- Precomputed propagation lookup assets.
- Probe-region mapping from glTF nodes.
- Hybrid runtime: precomputed when present, current logic when missing.

### Candidate glTF extras (draft)
- `xedats_precomputed_id`
- `xedats_probe_region`

### MVP deliverables
1. Resource schema for precomputed propagation hints.
2. Import resolver mapping extras → resource references.
3. Runtime blend policy with deterministic fallback.

### Risks
- Authoring pipeline complexity.
- Asset versioning / cache invalidation overhead.

#### Status note (2026-03-14)

Group C MVP (import-time precomputed propagation lookup) is implemented. Deliverables:
- `XedatsPrecomputedPropagationProfile` resource — deterministic init-time gain and player-override hints.
- `XedatsPrecomputedPropagationResolver` static utility — resolves lookup key from `xedats_precomputed_id` or `xedats_probe_region`.
- `xedats_gltf_document_extension.gd` — resolves authored extras into flattened payload hints and preserves warning-only fallback when assets are missing.
- `xedats_gltf_emitter_binding.gd` — applies effective gain and player occlusion/distance-filtering overrides at `_ready`; routes through deterministic precomputed buses when optional low/high-pass or reverb hints are authored; exposes debug metadata for fixture inspection.
- Sample assets under `GLTF/Profiles/PrecomputedPropagation/` and fixture coverage for valid profile, missing asset, and probe-region fallback cases.

---

## Group D — Dynamic Approximation Layer (2.5D)

**Goal:** Capture major dynamic occlusion/opening changes at low CPU cost.

### Included ideas
- Horizontal-plane propagation approximation for moving occluders.
- Real-time updates to gain + filter controls.
- Optional integration with door/window state systems.

### MVP deliverables
1. Lightweight propagation estimator service.
2. Per-emitter update hook with bounded tick rate.
3. Quality toggle in project settings.

### Risks
- Vertical gameplay layouts can exceed 2.5D assumptions.
- Update cadence must avoid audio pumping.

#### Status note (2026-03-14)

Group D MVP (import-time distance-band hooks) is implemented. Deliverables:
- `XedatsDistanceBandProfile` resource — per-band gain/rate scales with near/mid/far thresholds.
- `XedatsDistanceBandPolicy` static utility — `distance_to_listener`, `modulate_volume_variation`, `load_default_profile`.
- `xedats_distance_band_profile_default.tres` — default profile (near ≤ 8 m, mid ≤ 24 m; gain scales 1.0 / 0.8 / 0.5).
- `xedats_gltf_document_extension.gd` — `xedats_distance_policy` key parsed/validated (`"none"` | `"texture"`).
- `xedats_gltf_emitter_binding.gd` — at `_ready`, if policy = `"texture"`, applies band gain scale to the texture volume variation center; no listener = safe no-op.
- Fixture `khr_audio_emitter_distance_policy.gltf` + `_validate_distance_policy_fixture()` in runner — all assertions pass headless.

Group D dynamic approximation service skeleton (2026-03-14). Deliverables:
- `XedatsDynamicApproximationService` Node service — bounded-tick (10 Hz default), round-robin work budget (`MAX_EMITTERS_PER_TICK = 8`), anti-pumping guards (`DISTANCE_CHANGE_THRESHOLD`, `GAIN_CHANGE_THRESHOLD`).
- Static `instance()` / `get_or_create(anchor_node)` lazy-creation pattern with `WeakRef` so the service lifecycle follows the scene tree cleanly.
- `register_emitter` / `unregister_emitter` typed API with duplicate-registration rejection and stale-record pruning.
- `update_emitter_player` typed hook updates the tracked live looping player reference without re-registering the emitter.
- `set_enabled` toggle; `get_record_count()` for diagnostic queries.
- Player `volume_db` writes active for looping emitters with a valid player ref; gain now scales from effective gain (`gain * xedats_precomputed_gain_multiplier`) before dynamic band modulation.
- Binding `_register_with_dynamic_service(player)` is wired from real playback branches (event/container/direct) so the service receives a live player reference when available; texture-policy and xedats-presence guards remain intact.
- Binding `_exit_tree()` hooks into unregistration path.
- `_validate_dynamic_approximation_service()` in fixture runner covers: creation, registration, duplicate rejection, player-ref updates, unregistration, and enable/disable toggle — passes headless without listener.

Group D Phase 3 throttling hardening (2026-03-14). Deliverables:
- Listener-motion throttling in `XedatsDynamicApproximationService` (`LISTENER_MOTION_THRESHOLD = 0.15 m`) to skip expensive update passes while listener motion is effectively stationary.
- Idle refresh guard (`LISTENER_IDLE_REFRESH_INTERVAL = 0.8 s`) so stationary-listener scenarios still receive bounded periodic refreshes.
- Per-emitter cooldown windows (`xedats_dynamic_update_cooldown`, clamped to `0.05..2.0 s`, default `0.2 s`) to damp micro-update churn and reduce pumping risk.
- Runtime tuning/debug readout methods (`get_runtime_tuning`, `get_record_debug_state`) to expose cadence/threshold state to debug tooling and fixtures without private-field coupling.
- Fixture `_validate_dynamic_approximation_service()` now asserts tuning keys, cooldown clamping, and player-attachment debug state transitions.

Group D Phase 4 smoothing ramps (2026-03-14). Deliverables:
- Attack/release time-constant smoothing in `XedatsDynamicApproximationService` for dynamic gain transitions (`DEFAULT_ATTACK_SECONDS = 0.12`, `DEFAULT_RELEASE_SECONDS = 0.28`).
- Optional per-emitter smoothing keys: `xedats_dynamic_attack_seconds` and `xedats_dynamic_release_seconds`, clamped to `0.01..2.0 s`.
- Smoothed state tracking per emitter (`smoothed_gain_scale`, `target_gain_scale`, `last_update_time`) and epsilon snap (`SMOOTHING_EPSILON`) to prevent jitter near target.
- Dynamic `volume_db` writes now use smoothed gain scale instead of immediate target band scale to reduce audible stepping during listener motion and band transitions.
- Fixture `_validate_dynamic_approximation_service()` now asserts smoothing tuning exposure and clamp behavior for attack/release payload values.

Group D Phase 5 interpolation mode selection (2026-03-14). Deliverables:
- Deterministic per-emitter smoothing mode key: `xedats_dynamic_smoothing_mode`.
- Supported interpolation modes in `XedatsDynamicApproximationService`:
	- `linear` (default)
	- `exp` (exponential approach, time-constant based)
- Invalid/unknown mode values fall back deterministically to `linear`.
- Runtime/debug surfaces now expose mode data via `get_runtime_tuning()` (`default_smoothing_mode`, `valid_smoothing_modes`) and `get_record_debug_state()` (`smoothing_mode`).
- Fixture `_validate_dynamic_approximation_service()` now asserts authored `exp` mode, valid-mode registry, and invalid-mode fallback behavior.

Group D Phase 6 quality preset controls (2026-03-14). Deliverables:
- Project setting integration in `XedatsDynamicApproximationService` via `xedats/gltf/dynamic_approximation_quality`.
- Runtime quality API:
	- `set_quality_preset("low"|"medium"|"high")`
	- `get_quality_preset()`
- Quality preset drives runtime cadence/budgets/defaults:
	- tick interval
	- per-tick emitter budget
	- listener-motion threshold + idle refresh interval
	- default emitter cooldown + default attack/release times
- Deterministic invalid-preset handling: unknown preset returns false and preserves current active preset.
- Fixture `_validate_dynamic_approximation_service()` now asserts low/high transitions and invalid-preset no-op behavior.

Group D Phase 7 state-aware runtime suppression (2026-03-14). Deliverables:
- Dynamic service runtime checks now respect current category mute state on each update pass (not just spawn/init time).
- Per-emitter category parsing in the dynamic record (`category`, fallback `SFX`) enables consistent mute lookups.
- Runtime mute checks follow existing Xedats contract:
	- `AudioStateManager.is_category_muted(category)`
	- or category volume effectively zero (`<= 0.0001`)
- `get_record_debug_state()` now exposes `category`, `runtime_category_muted`, and `muted_skip_count` for diagnostics.
- Fixture `_validate_dynamic_approximation_service()` now validates mute-state transitions (unmuted, explicit mute, zero-volume mute) with state restoration.

Group D Phase 8 master-aware suppression (2026-03-14). Deliverables:
- Dynamic service runtime suppression now includes master mute state, not just per-category state.
- Master checks follow existing Xedats contract:
	- `AudioStateManager.is_master_muted()`
	- or `XedatsSingleton.get_category_volume("Master") <= 0.0001`
- New public helpers in `XedatsDynamicApproximationService`:
	- `is_master_runtime_muted()`
	- `is_runtime_audio_suppressed(category)`
- `get_record_debug_state()` now exposes `runtime_master_muted` and combined `runtime_audio_suppressed`.
- Fixture `_validate_dynamic_approximation_service()` now validates explicit master mute and zero master-volume suppression with full state restoration.

Group D Phase 9 immediate refresh hooks (2026-03-14). Deliverables:
- Public `request_immediate_refresh()` API in `XedatsDynamicApproximationService` clears listener-idle gates and per-record cooldown gates so runtime state changes apply immediately.
- Service now hooks `AudioStateManager.state_loaded` and `state_reset` when available and converts them into immediate refresh requests.
- Runtime tuning/debug surface now exposes:
	- `state_signal_hooks_enabled`
	- `state_signal_connected`
	- `refresh_request_count`
- Fixture `_validate_dynamic_approximation_service()` now asserts direct refresh requests and `state_reset` signal-driven refresh increments.

Group D Phase 10 listener transition refresh hooks (2026-03-14). Deliverables:
- Dynamic service now detects active-listener transitions (initial acquisition, listener swap, listener loss) and requests immediate refreshes.
- Listener refresh diagnostics added to runtime tuning:
	- `listener_transition_hooks_enabled`
	- `listener_refresh_count`
	- `last_refresh_reason`
- Listener-triggered refresh reasons are normalized (`listener_changed`, `listener_lost`).
- Fixture `_validate_dynamic_approximation_service()` now creates/switches listeners through `XedatsSingleton` and asserts listener-refresh counters/reasons.

Group D Phase 11 portal state hooks (2026-03-14). Deliverables:
- Dynamic service now tracks per-emitter portal openness (`0.0..1.0`) and multiplies it into the distance-band target gain, enabling low-cost door/window opening responses without a custom propagation rewrite.
- New runtime APIs in `XedatsDynamicApproximationService`:
	- `set_emitter_portal_openness(emitter_node, openness)`
	- `set_emitter_portal_closed_gain_scale(emitter_node, gain_scale)`
- `XedatsGLTFAudioEmitterBinding` now exposes convenience wrappers so gameplay systems can drive imported emitters directly without taking a dependency on the service singleton.
- Optional extras parsed/validated by the importer:
	- `xedats_dynamic_portal_openness`
	- `xedats_dynamic_portal_closed_gain_scale`
- Runtime/debug surfaces now expose portal-state tuning and per-record state for tooling/fixtures.
- Fixture `_validate_dynamic_approximation_service()` and the extras fixtures now validate clamp behavior, runtime updates, and combined target-gain behavior.

Group D Phase 12 portal source adapter (2026-03-14). Deliverables:
- `XedatsGLTFAudioEmitterBinding` now supports one-time binding to a live portal/door/window node via `bind_dynamic_portal_state_source(source_node, open_property, openness_property)`.
- The adapter reacts immediately to common scene signals (`portal_openness_changed`, `open_state_changed`, `opened`, `closed`) and falls back to bounded property polling when only a property surface exists.
- Existing `is_open`-style interactables can now drive Group D portal attenuation without repeated manual binding updates.
- Fixture `_validate_dynamic_approximation_service()` now validates both signal-driven and property-polling adapter paths.
- Dedicated importer-path fixtures now validate `xedats_portal_source_path` auto-bind behavior:
	- `khr_audio_emitter_portal_source_path_dot.gltf` validates `xedats_portal_source_path = "."` resolves to the emitter parent and auto-binds successfully.
	- `khr_audio_emitter_portal_source_path_bad.gltf` validates unresolved paths follow the warning/fallback path and leave the adapter unbound.
- Fixture runner now includes `_validate_portal_source_path_auto_bind_fixtures()` to assert payload preservation, binding metadata (`xedats_portal_auto_bind_resolved_path`), adapter bound/unbound state, and runtime portal-openness behavior after signal updates.

Phase 12 validation checklist:
- Dot path fixture (`khr_audio_emitter_portal_source_path_dot.gltf`) preserves payload key and sets `xedats_portal_auto_bind_resolved_path`.
- Dot path fixture binds adapter (`xedats_dynamic_portal_adapter_bound = true`) and updates portal openness from `0.0 -> 1.0` after open-state signal.
- Bad path fixture (`khr_audio_emitter_portal_source_path_bad.gltf`) preserves payload key but leaves adapter unbound and does not set resolved-path metadata.
- Bad path fixture emits unresolved-path warning and retains authored `xedats_dynamic_portal_openness` as runtime fallback.

---

## Group E — Offline ML Authoring Assistants

**Goal:** Use ML to speed authoring, never as a mandatory runtime dependency.

### Included ideas
- Far-field envelope prediction assistant.
- Scattering-aware preset suggestion tools.
- Auto-recommendations for OMI mapping presets.

### MVP deliverables
1. Editor-side batch utility that outputs plain resource presets.
2. Confidence score + manual override workflow.
3. Export into deterministic runtime config files.

### Risks
- Dataset mismatch can produce unstable recommendations.
- Tooling trust requires clear explainability and override controls.

---

## Group F — Import Schema and Validation

**Goal:** Keep advanced metadata scalable, typed, and safe.

### Included ideas
- Versioned `xedats_*` extras schema drafts.
- Import-time validation warnings for unknown/invalid values.
- Automatic clamping/normalization with warning breadcrumbs.

### MVP deliverables
1. Extras key registry in importer docs.
2. Validator helper methods in `GLTFDocumentExtensionXedatsAudio`.
3. Test fixtures for valid/invalid advanced metadata.

### Risks
- Overly strict validation can annoy content workflows.
- Schema drift across tools needs version tagging.

### Execution Checklist (Group F)

Use this sequence to implement validation with minimal churn and deterministic fallback.

1. **Create/confirm extras key registry**
	 - Registry owner: `GLTFDocumentExtensionXedatsAudio` (single source of truth).
	 - Include key metadata: expected type, allowed range/set, default behavior, warning text.

2. **Implement validator helpers (typed, pure functions)**
	 - `validate_string_enum(...)`
	 - `validate_float_range(...)`
	 - `validate_nonempty_string(...)`
	 - `validate_optional_object(...)`
	 - `validate_optional_array(...)`

3. **Apply validators in parse/resolve stages only**
	 - Parse: normalize/clamp and collect warning breadcrumbs.
	 - Resolve/apply: consume normalized values only.
	 - Never hard-fail import for invalid/unknown `xedats_*` values.

4. **Add fixture coverage before expanding key set**
	 - One valid fixture + one invalid fixture per key.
	 - Assert warning emitted for invalid, and deterministic fallback value used.

5. **Add docs sync gate**
	 - Any new `xedats_*` key requires same-PR update to setup/planning docs.

#### Status note (2026-03-13)

- Typed validator helpers are implemented in `GLTFDocumentExtensionXedatsAudio` for the current roadmap key set.
- Parse-time normalization is active; runtime mapping consumes normalized payload values only.
- Valid/invalid fixture coverage is in place for the current `xedats_*` key set.
- Repeated identical invalid-extra warnings are rate-limited per import pass (same key + context logs once).

#### Per-key validation cases (current roadmap set)

- `xedats_reflection_budget`
	- Type: string enum (`low`, `medium`, `high`) or integer budget (if numeric mode is enabled later).
	- Invalid handling: warn + fallback to project default tier.
	- Fixture pair: valid tier (`medium`) and invalid tier (`ultra`).

- `xedats_texture_profile`
	- Type: non-empty string enum/preset id.
	- Invalid handling: warn + ignore profile override.
	- Fixture pair: known profile id and unknown profile id.

- `xedats_texture_density`
	- Type: float range `[0.0, 1.0]`.
	- Invalid handling: clamp to range + warn when clamped.
	- Fixture pair: `0.35` and out-of-range `1.8`.

- `xedats_texture_variance`
	- Type: float range `[0.0, 1.0]`.
	- Invalid handling: clamp to range + warn when clamped.
	- Fixture pair: `0.5` and negative `-0.25`.

- `xedats_precomputed_id`
	- Type: non-empty string token.
	- Invalid handling: warn + disable precomputed lookup path.
	- Fixture pair: valid token and empty string.

- `xedats_probe_region`
	- Type: non-empty string or object descriptor (future expansion).
	- Invalid handling: warn + fallback to runtime/default region behavior.
	- Fixture pair: valid region id and wrong-type numeric value.

#### Warning policy checklist

- Warning includes emitter/material/node context when available.
- Warning includes offending key and received value type.
- Warning includes fallback path used (e.g., “default category SFX”, “ignore texture override”).
- Repeated identical warnings are rate-limited per import pass.

---

## Suggested Sequencing

1. Group F (schema/validation)
2. Group A (perceptual reflection budget)
3. Group B (texture emitters)
4. Group D (dynamic approximation)
5. Group C (precomputed propagation)
6. Group E (offline ML assists)

This order keeps improvements incremental and preserves current fallback behavior at every stage.
