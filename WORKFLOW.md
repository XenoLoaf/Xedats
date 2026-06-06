# Xedats — Workflow Practices

Operational guidelines for working on this project. Agents and contributors should read this alongside `AGENTS.md`.

---

## Table of Contents

1. [Canonical Source vs. This Repo](#1-canonical-source-vs-this-repo)
2. [Compile Check](#2-compile-check)
3. [Question-First Approach](#3-question-first-approach)
4. [Navigating the Godot Workspace](#4-navigating-the-godot-workspace)
5. [Working with the GLTF Module](#5-working-with-the-gltf-module)
6. [Updating BACKLOG.md](#6-updating-backlogmd)
7. [Testing](#7-testing)
8. [Sync Checklist](#8-sync-checklist)

---

## 1. Canonical Source vs. This Repo

| Location | Role |
|----------|------|
| `j:\Godot_Projects\Xedats\Packages\Xedats\` | **Canonical source** — all code changes go here first |
| `j:\[2] Game Development\GitHub Projects Tools\xedats_master\` | **GitHub mirror** — sync after canonical validation |

The `Version / Sync Status` table at the bottom of `BACKLOG.md` tracks the current sync state. Check it at the start of every session.

**When to ask which target applies:**
- The user says "fix this" or "update X" without specifying a path.
- The task involves a `.gd` file that also exists in the canonical source.
- The change is large enough that manual syncing may introduce drift between the two locations.
- The user references audio behavior in their project — that project likely uses the canonical source, not this repo.

---

## 2. Compile Check

Run before and after every code change. The check confirms there are no GDScript parse or compile errors in the project.

```powershell
& 'J:\Godot_Install\Godot_v4.7-beta2_mono_win64\Godot_v4.7-beta2_mono_win64_console.exe' --path 'j:\Godot_Projects\Xedats' --headless --quit-after 5 2>&1 | Select-String "SCRIPT ERROR|Parse Error|Compile Error"
```

**Project path options (in order of preference):**

| Option | Path | When to use |
|--------|------|-------------|
| Canonical project | `j:\Godot_Projects\Xedats\` | Working in canonical source |
| Scratch test project | *(set up locally)* | Working in this GitHub repo |
| Manual review | *(no project available)* | Last resort — review types and casts by hand |

**Interpreting results:**
- No output → clean, no errors.
- Exit code 1 with only RID/resource-leak warnings → normal for beta builds, not a script error.
- Any line matching `SCRIPT ERROR`, `Parse Error`, or `Compile Error` → must be fixed before proceeding.

**GUI boot check** (after editor plugin or `@tool` script changes):

```powershell
& 'J:\Godot_Install\Godot_v4.7-beta2_mono_win64\Godot_v4.7-beta2_mono_win64_console.exe' 'j:\Godot_Projects\Xedats\project.godot' 2>&1 | Select-String "SCRIPT ERROR|Parse Error|Compile Error"
```

The headless parse misses some runtime errors (undeclared identifiers in `@tool` scripts, missing methods on editor classes). Use the GUI boot check when editing `xedats_gltf_document_extension.gd` or any other `@tool`-annotated file.

---

## 3. Question-First Approach

Before implementing anything non-trivial, ask targeted questions. Precision is cheaper than fixing a wrong implementation.

**Always ask when:**
- The task description is ambiguous about which subsystem or file is the target.
- You are unsure whether a behavior is a bug or an intentional design choice.
- A change would affect the public API on `XedatsSingleton`.
- The request could mean a one-line patch or a broader refactor.
- It is unclear whether changes should go to the canonical source or this GitHub repo.
- The change involves bus routing, category names, or effect chain behavior that consumers may depend on.
- The GLTF module is involved and spec-compliance implications are unclear.

**Format:**

> **Clarification needed:**
> 1. [Question A]
> 2. [Question B]
> *(If no answer: I'll assume X and proceed.)*

5–7 questions is acceptable when a task is genuinely complex. Do not pad with obvious questions; every question should require an answer to unblock the work.

---

## 4. Navigating the Godot Workspace

The workspace includes local copies of Godot docs, engine source, and C++ bindings. Use these before searching online.

### Class reference (RST docs)

```
j:\Godot_Install\Docs&CPP\Godot v4.7\godot-docs-master\classes\
```

Files are named `class_<classname>.rst` (all lowercase, no spaces). Useful lookups for Xedats:

| File | Class |
|------|-------|
| `class_node.rst` | Node — lifecycle, tree methods |
| `class_audiostreamplayer3d.rst` | AudioStreamPlayer3D — spatial audio properties |
| `class_audioserver.rst` | AudioServer — bus management, effect slots |
| `class_area3d.rst` | Area3D — body/area overlap for occlusion |
| `class_physicsraythroughparameters3d.rst` | Ray query construction |
| `class_gltfdocumentextension.rst` | GLTF import pipeline hook |
| `class_gltfstate.rst` | GLTF import state object |
| `class_resource.rst` | Resource — save/load, property list |
| `class_timer.rst` | Timer — performance monitor node |
| `class_scenetree.rst` | SceneTree — root, get_main_loop |
| `class_callable.rst` | Callable — is_valid, call |

### Engine source (implementation details)

```
j:\Godot_Install\Docs&CPP\Godot v4.7\godot-master\
```

Useful subtrees:
- `scene/audio/` — AudioServer, bus implementation
- `modules/gltf/` — GLTFDocumentExtension lifecycle
- `scene/main/scene_tree.cpp` — SceneTree implementation

### C++ / GDExtension headers

```
j:\Godot_Install\Docs&CPP\Godot v4.7\godot-cpp-master\include\
```

Use when working with GDExtension class bindings or verifying extension API surface.

---

## 5. Working with the GLTF Module

The GLTF module (`packages/Xedats/Modules/GLTF/`) is a `GLTFDocumentExtension` bridge and is marked **beta**. Before any GLTF task:

1. **Read the setup guide.** Open `Modules/GLTF/Setup_GLTF_Audio_Surfaces.md` for JSON structure, source URI conventions, and import pipeline details.
2. **Check the research reference.** `Modules/GLTF/Spatial_Audio_Research_Reference.md` tracks paper-to-implementation mapping. Check it before making decisions about spatial audio behavior.
3. **Check the implementation plan.** `Modules/GLTF/Implementation_Idea_Groups.md` tracks grouped feature tracks. Confirm any new work aligns with the planned direction.
4. **Verify editor guards.** All code inside `GLTFDocumentExtension` lifecycle methods (`_import_preflight`, `_import_node`, etc.) runs during the import pipeline only. Do not add `Engine.is_editor_hint()` guards to these — they are already import-pipeline-scoped. Only guard code that is shared between import and runtime.
5. **Confirm fallback behavior.** If Xedats runtime services are unavailable during import, the module must log a warning and fall back gracefully — never fail the import.

---

## 6. Updating BACKLOG.md

When completing a backlog task:

1. Move the row from **Open Tasks** (or Planned Features) to the **Completed** table.
2. Add the completion date.
3. Note any follow-on tasks that emerged in a new Open Tasks row.
4. If new issues were discovered during the work, add them to **Known Issues**.
5. Update the `Last synced` date in **Version / Sync Status** if files were synced from the canonical source.

---

## 7. Testing

The test suite lives under `packages/Xedats/Tests/GLTF/` and contains headless fixture tests for the GLTF import pipeline. It is safe to omit from shipped builds — no runtime script references paths inside `Tests/`.

| What to verify | How |
|----------------|-----|
| No parse/compile errors | Run the headless compile check |
| GLTF fixture import | Run headless with the test scene; check for `SCRIPT ERROR` lines |
| Pool behavior (create/release/reuse) | Manual test in a live project |
| Bus routing and hot-swap | Manual test: `route_player_to_category`, `swap_player_bus` |
| Audio event dispatch | Manual test: `AudioEventSystem.trigger_event()` with a registered event |
| State save/load | Manual test: save, reload project, confirm settings restored |
| XedatsConsoleModule commands | Manual test: register module, run `xd.status`, `audio list_buses` in Xebug console |

When a headless test runner is added for runtime behavior, update this section with the runner command and suite location.

---

## 8. Sync Checklist

Use this before closing a work session to confirm the repo state is consistent.

- [ ] Compile check passed (canonical project or scratch project).
- [ ] If code was changed in this repo: confirmed this is the intended target (not the canonical source).
- [ ] If code was changed in the canonical source: synced the updated `.gd` files to this repo.
- [ ] `BACKLOG.md` open tasks reflect current state (nothing completed without moving the row).
- [ ] `Version / Sync Status` table in `BACKLOG.md` is accurate.
- [ ] No references to `Xebug`, `AutoloadManager`, or external packages were introduced in `.gd` files.
