# Spatial Audio Research Reference

This page summarizes the bibliography files in the external research folder and translates each paper into actionable guidance for the Xedats + glTF audio pipeline.

Source bibliography folder: `j:\Godot_Projects\ProjectHelix\Godot Spatial Audio Resources\PDFs`

## Why this page exists

The current Xedats glTF integration already supports:
- `XEDATS_audio_emitter` routing through `AudioEventSystem` / `XedatsSingleton`
- `XEDATS_audio_material` mapping into deterministic `EffectChain` behavior
- State-aware category fallback and mute handling

These papers suggest next-stage improvements for perceptual quality, scalable runtime cost, and physically motivated tuning.

Second pass note: additional non-`.bib` PDFs in the same folder were reviewed by metadata and first-page extraction. This pass adds implementation direction from those sources, with priority given to papers directly relevant to interactive game audio propagation.

---

## 1) A Sparsity Measure for Echo Density Growth in General Environments (ICASSP 2019)

- **Authors:** Helena Peic Tukuljac, Ville Pulkki, Hannes Gamper, Keith Godin, Ivan Tashev, Nikunj Raghuvanshi
- **Type:** Conference paper
- **Core idea:** Model impulse-response echo density growth over time using a smooth sorted density measure and a power-law trend.
- **Project relevance:** Gives a quantitative descriptor for how “dense” reflections should feel indoors vs outdoors.

### Suggested Xedats use

- Add an optional metadata scalar per surface/zone for expected echo-density growth profile.
- Use it to drive subtle post-processing in OMI-derived reverb tuning:
  - lower growth profile → drier / less diffuse
  - higher growth profile → denser tail / higher wetness tendency
- Keep implementation data-driven so this is a parameter layer over existing `XEDATS_audio_material` mapping, not a rewrite.

**Link:** https://www.microsoft.com/en-us/research/publication/a-sparsity-measure-for-echo-density-growth-in-general-environments/

---

## 2) Acoustic Texture Rendering for Extended Sources in Complex Scenes (TOG/SIGGRAPH Asia 2019)

- **Authors:** Zechen Zhang, Nikunj Raghuvanshi, John Snyder, Steve Marschner
- **Type:** Journal paper (ACM TOG)
- **Core idea:** Represent ambient/extended stochastic sources with event-loudness density (ELD), then render spatially varying texture with granular synthesis.
- **Project relevance:** Directly applies to rain, crowds, machinery beds, wind foliage, water flow, and other non-point ambience.

### Suggested Xedats use

- Introduce a “texture emitter” concept on top of existing multi-source `AudioArrayContainer` routing.
- Encode source-region behavior as glTF extras (future extension keys) and map to:
  - event spawn rate
  - near/far loudness distribution
  - occlusion-sensitive variation amount
- Start simple: derive rate and gain spread from listener distance bands, then iterate toward ELD-like behavior.

**Link:** https://www.microsoft.com/en-us/research/publication/acoustic-texture-rendering-for-extended-sources-in-complex-scenes/

---

## 3) Fast Acoustic Scattering Using Convolutional Neural Networks (ICASSP 2020)

- **Authors:** Ziqi Fan, Vibhav Vineet, Hannes Gamper, Nikunj Raghuvanshi
- **Type:** Conference paper
- **Core idea:** Predict scattering loudness fields from geometry cross-sections with image-to-image CNNs, achieving <1 dB RMS error at >100x speedup vs full wave simulation.
- **Project relevance:** Strong candidate for offline bake assistance and fast runtime approximations in complex scenes.

### Suggested Xedats use

- Keep neural methods out of runtime first pass; use them as offline authoring aids:
  - precompute scattering-aware weighting maps
  - export result as lightweight lookup data (resource or glTF extras)
- At runtime, consume precomputed maps to modulate:
  - emitter gain bias by orientation/occlusion context
  - material-driven reflection intensity presets

**Link:** https://www.microsoft.com/en-us/research/publication/fast-acoustic-scattering-using-convolutional-neural-networks/

---

## 4) Towards Encoding Perceptually Salient Early Reflections for Parametric Spatial Audio Rendering (AES 2020)

- **Authors:** Fabian Brinkmann, Hannes Gamper, Nikunj Raghuvanshi, Ivan Tashev
- **Type:** Conference paper
- **Core idea:** Select only perceptually salient early reflections; a listening test found ~6 reflections can be perceptually close to a full reference for tested speech scenarios.
- **Project relevance:** Useful for reducing reflection complexity while preserving perceived quality.

### Suggested Xedats use

- Add a configurable “early reflection budget” profile per acoustic context (speech-focused vs ambience-focused).
- For future reflection spawning systems:
  - prioritize strongest/salient paths first
  - cap active reflection taps around a small target budget
- Expose quality tiers in project settings (low/medium/high) as count budgets.

**Link:** https://www.microsoft.com/en-us/research/publication/towards-encoding-perceptually-salient-early-reflections-for-parametric-spatial-audio-rendering/

---

## 5) Spatio-Temporal Windowing for Encoding Perceptually Salient Early Reflections in Parametric Spatial Audio Rendering (JAES 2023)

- **Authors:** Tobias Jüterbock, Fabian Brinkmann, Hannes Gamper, Nikunj Raghuvanshi, Stefan Weinzierl
- **Type:** Journal article
- **Core idea:** Improve salient reflection detection with perceptually motivated spatio-temporal windowing + masking-threshold salience estimation, including vertical dependency.
- **Project relevance:** Important for modern 3D scenes where elevation cues matter (stairs, atriums, mezzanines, vertical gameplay).

### Suggested Xedats use

- In future reflection systems, include elevation-aware salience weighting.
- Treat vertical separation as a first-class cue when deciding which reflections to preserve.
- Maintain compatibility with current simple fallback paths: advanced reflection logic should degrade gracefully to existing emitter + reverb behavior.

**Link:** https://www.microsoft.com/en-us/research/publication/spatio-temporal-windowing-for-encoding-perceptually-salient-early-reflections-in-parametric-spatial-audio-rendering/

---

## 6) Precomputed Wave Simulation for Real-Time Sound Propagation of Dynamic Sources in Complex Scenes (TOG 2010)

- **Authors:** Nikunj Raghuvanshi, John Snyder, Ravish Mehra, Ming Lin, Naga Govindaraju
- **Type:** Journal paper (ACM TOG)
- **Core idea:** Precompute expensive wave simulation results and use compact runtime data for real-time source updates in complex environments.
- **Project relevance:** Strong fit for Xedats authoring workflows where quality is prioritized but runtime must stay predictable.

### Suggested Xedats use

- Add an optional precomputed propagation asset format (resource file) consumed by emitter bindings.
- Support a hybrid runtime path:
  - precomputed propagation map when available
  - current deterministic fallback path when absent
- Introduce bake metadata keys in glTF extras for future lookup:
  - `xedats_precomputed_id`
  - `xedats_probe_region`

**Reference PDF:** `PrecomputedWaveSimSoundPropagation.pdf`

---

## 7) Interactive Sound Propagation for Dynamic Scenes Using 2D Wave Simulation (SCA 2020 / Planeverb)

- **Authors:** Matthew Rosen, Keith W. Godin, Nikunj Raghuvanshi
- **Type:** Conference paper
- **Core idea:** Use fast 2D wave simulation to approximate dynamic propagation interactively.
- **Project relevance:** Good middle ground between coarse heuristic occlusion and full 3D wave simulation, especially for gameplay-centric responsiveness.

### Suggested Xedats use

- Add a low-cost dynamic propagation approximation layer for moving occluders/doors.
- Restrict scope initially to horizontal-plane gameplay assumptions (2.5D approximation).
- Feed results into existing emitter gain/filter controls, avoiding API churn.

**Reference PDF:** `Planeverb_CameraReady_wFonts.pdf`

---

## 8) Adaptive Far-Field Spatial-Temporal Sound Prediction Using Attentive 1D U-Net (JSV 2025)

- **Authors:** Chao Liang et al.
- **Type:** Journal paper
- **Core idea:** Learn spatial-temporal far-field sound behavior with an attentive 1D U-Net model.
- **Project relevance:** Candidate for offline tooling that predicts far-field response envelopes without full simulation per iteration.

### Suggested Xedats use

- Keep ML inference in offline tooling, not in first runtime integration.
- Use predicted envelopes to auto-suggest emitter defaults:
  - gain rolloff profile
  - category-specific low-pass curves
  - ambience density presets
- Save generated presets as plain resources for deterministic runtime playback.

**Reference PDF:** `Adaptive-far-field-spatial-temporal-sound-prediction-_2025_Journal-of-Sound-.pdf`

---

## 9) Ray-Tracing Implementation Papers (2006, OptiX-based)

- **Sources:**
  - `AN IMPLEMENTATION OF RAY TRACING ALGORITHM.pdf`
  - `The Design and Implementation of a Ray-tracing Algorithm.pdf`
- **Core idea:** Parallel and GPU-driven ray-tracing acceleration techniques.
- **Project relevance:** Useful implementation background for potential geometric acoustic ray modules, but not directly plug-in ready for current Xedats GLTF scope.

### Suggested Xedats use

- Use as engineering references if a custom propagation baker is built later.
- Keep current roadmap focused on perceptual + metadata-driven gains before infrastructure-heavy tracing systems.

---

## 10) Lower-Priority / Domain-Distant PDFs in this folder

These were detected in the folder but are currently lower relevance to game spatial-audio rendering in Xedats:

- `Editorial-Board_2025_Journal-of-Sound-and-Vibration.pdf` (journal board listing)
- `High-precision-model-and-open-source-software-for-acoustic-bac_2025_Journal-.pdf` (fisheries backscattering domain)
- `Micro-perforated-rainbow-trapping-silencers-with-broadban_2025_Journal-of-So.pdf` (silencer hardware focus)
- `Modelling-and-identification-of-hysteresis-of-Vacuum_2025_Journal-of-Sound-a.pdf` (mechanical damper hysteresis)

These can remain in a background bibliography bucket unless a specific feature request maps to them.

---

## Implementation Priorities (Xedats + glTF)

### P1: Near-term, low-risk
- Add documented authoring presets in `Setup_GLTF_Audio_Surfaces.md` for indoor/outdoor reflection character.
- Add optional per-emitter extras for texture variance and spawn density (ignored safely if absent).
- Add quality-tier setting hooks for future reflection budget caps (no behavior change until enabled).
- Add optional glTF extras schema draft for future propagation metadata (`xedats_precomputed_id`, `xedats_texture_profile`, `xedats_reflection_budget`).

### P2: Mid-term
- Prototype reflection-budgeted playback helper (salience ordered, capped count).
- Prototype elevation-aware weighting of reflection contributions.
- Prototype dynamic 2.5D propagation approximation inspired by Planeverb concepts.
- Add importer-time validation warnings for unsupported/unknown advanced extras.

### P3: Longer-term
- Explore offline scattering bake helpers that emit lightweight runtime control maps.
- Keep runtime deterministic and fallback-safe when no advanced data exists.
- Explore precomputed wave-propagation asset baking and lookup integration.
- Evaluate ray/path acceleration options only after perceptual metadata layers prove value.

### P4: Experimental
- Build an offline assistant that recommends emitter/material presets from geometry + category context.
- Evaluate ML-assisted far-field envelope prediction as an authoring accelerator (never hard runtime dependency).

---

## Citation Seeds (from provided .bib files)

```bibtex
@inproceedings{tukuljac2019a,
  title = {A Sparsity Measure for Echo Density Growth in General Environments},
  year = {2019}
}

@article{zhang2019acoustic,
  title = {Acoustic Texture Rendering for Extended Sources in Complex Scenes},
  year = {2019}
}

@inproceedings{fan2020fast,
  title = {Fast acoustic scattering using convolutional neural networks},
  year = {2020}
}

@inproceedings{brinkmann2020towards,
  title = {Towards encoding perceptually salient early reflections for parametric spatial audio rendering},
  year = {2020}
}

@article{jterbock2023spatio-temporal,
  title = {Spatio-Temporal Windowing for Encoding Perceptually Salient Early Reflections in Parametric Spatial Audio Rendering},
  year = {2023}
}
```

---

## Notes

- This page is a design reference, not a claim that these algorithms are implemented today.
- Keep integration incremental and typed, preserving current Xedats fallback behavior when advanced services/data are unavailable.
- For grouped planning by implementation family, see `Implementation_Idea_Groups.md`.

---

## Example Addon Implementation Pass (Godot projects)

The following practical review complements the paper-driven roadmap with real Godot addon patterns:

- `Godot Spatial Audio Resources/SpatialAudio3D-main/addons/spatial_audio_3d/spatial_audio_3d.gd`
- `Godot Spatial Audio Resources/godot-spatial-audio-main/addons/gd_spatial_audio/*`

### What this adds to implementation timing

- **Immediate focus (P1/P2 bridge):** enforce bounded incremental update loops for any new reflection/occlusion passes; avoid full-frame propagation sweeps.
- **Importer contract hardening (P1):** continue deterministic material mapping tables for OMI, similar to explicit expanded-material mapping resources.
- **Runtime architecture (P2):** keep per-emitter effect ownership and update isolation, while preserving fallback simple playback.
- **Pipeline-heavy features (P3+):** defer octree/precompute-heavy experiments until schema validation + salience budgeting prove value in profiling.

### Operational guardrails validated by examples

- Stage complexity in layers: metadata + deterministic mapping first, richer propagation later.
- Keep advanced systems optional; do not block import/playback when optional services are unavailable.
- Prefer configurable resources/mappers over scene-specific special-case logic.
