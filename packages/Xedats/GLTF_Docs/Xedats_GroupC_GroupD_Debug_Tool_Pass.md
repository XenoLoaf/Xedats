# Xedats Group C + Group D Debug Tool Pass

Focused notes for the first dedicated debug-tool coverage pass for:
- Group C (precomputed propagation lookup + init-time routing)
- Group D (distance-band policy modulation)

---

## 1) Debug goals for this pass

1. Make precomputed profile resolution observable without stepping through importer code.
2. Make `_ready`-time distance policy outcomes observable in one snapshot.
3. Make bus/effect routing from precomputed hints observable per emitter.
4. Keep fallback paths visible (missing profile, no listener, event fallback).

---

## 2) Recommended debug tools

### A. Emitter Resolve Inspector
**Shows**
- emitter index/name
- resolved extras keys
- `xedats_precomputed_resolution_source`
- `xedats_precomputed_resolution_key`
- `xedats_precomputed_profile_path`

**Primary use**
- Validate importer parse/resolve behavior from fixture data.

### B. Precomputed Application Inspector
**Shows**
- `xedats_precomputed_base_gain`
- `xedats_precomputed_gain_multiplier`
- `xedats_precomputed_effective_gain`
- occlusion and distance-filtering overrides
- precomputed low/high-pass + reverb hints

**Primary use**
- Verify Group C profile output affects runtime init values as intended.

### C. Distance Policy Snapshot
**Shows**
- policy value (`none` / `texture`)
- base texture variation
- distance-modulated variation
- listener-available status

**Primary use**
- Verify Group D logic and no-listener no-op behavior quickly.

### D. Precomputed Bus/Effect Route Explorer
**Shows**
- emitter binding → bus name
- bus existence in `get_bus_info()`
- effect count
- route source (explicit `target_bus_name` vs generated name)

**Primary use**
- Validate deterministic bus setup and effect-chain hookup.

### E. Warning Correlation Feed
**Shows**
- warning key
- emitter context
- fallback note
- fixture context when available

**Primary use**
- Catch authoring errors and unexpected fallback paths fast.

---

## 3) Toolchain updates (documentation + implementation hooks)

1. **Command functions implemented in debug plugin**
   - `dump_precomputed_resolve()`
   - `dump_distance_policy()`
   - `dump_bus_routes()`
   - `clear_warning_feed()` *(currently a stub until warning accumulator phase lands)*

   Command-dispatch aliases (via `execute_command(...)`):
   - `precomputed`
   - `distance`
   - `bus`
   - `warnings clear`

Current implemented hook surface:
- `XedatsGLTFAudioEmitterBinding.get_debug_snapshot()` exposes payload, runtime-path, portal, texture, and precomputed metadata in one dictionary.
- `XedatsDynamicApproximationService.get_record_debug_state(emitter)` exposes per-emitter live dynamic state.
- `XedatsDynamicApproximationService.get_all_record_debug_states()` exposes aggregate registered-emitter snapshots for HUD/feed tooling.

2. **Snapshot models to add**
   - `PrecomputedResolutionSnapshot`
   - `DistancePolicySnapshot`
   - `PrecomputedBusRouteSnapshot`

3. **Preset profiles**
   - `fixture_pass`: high warning visibility, low-overhead overlays
   - `runtime_space`: world overlays enabled, reduced warning verbosity

4. **Fixture linkage**
   - ensure runner annotations include fixture name/source so debug feed can group events.

---

## 4) Group C/D quick validation playbook

1. Run GLTF fixture scene headless.
2. Confirm all assertions pass.
3. Inspect warning feed for expected-only warnings:
   - invalid extras fixtures
   - missing precomputed profile fixture
   - event fallback fixtures
4. Confirm each precomputed fixture exposes expected:
   - resolution source/key
   - effective gain
   - precomputed bus route/effect count
5. Confirm distance policy fixture exposes expected:
   - `texture` path metadata
   - `none` path omits distance metadata

---

## 5) Suggested next debug build increment

Implement minimal debug-plugin read models first (no heavy world gizmo work):
- service status
- emitter resolve snapshots
- precomputed route snapshots
- distance snapshots
- warning feed

Then layer in 3D overlays once data quality is stable.