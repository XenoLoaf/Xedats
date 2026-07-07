# Third-Party Notices

Xedats is a standalone, zero-dependency Godot 4 plugin. All source code is original GDScript written for Xedats.

---

## Godot Engine

- **Owner:** Juan Linietsky, Ariel Manzur, and contributors.
- **License:** [MIT License](https://github.com/godotengine/godot/blob/master/LICENSE.txt)
- Xedats runs as a plugin for Godot 4.7. It communicates with Godot's glTF import pipeline through the public `GLTFDocumentExtension` API. No Godot Engine source code, binaries, or assets are included in this package.

## glTF 2.0 Format

- **Owner:** The Khronos Group Inc.
- **Specification license:** [Creative Commons Attribution 4.0 International (CC-BY-4.0)](https://github.com/KhronosGroup/glTF/blob/main/LICENSE.adoc)
- Xedats reads and writes glTF 2.0 files through Godot's built-in document parser. No glTF specification text, schemas, or reference code from the Khronos or OMI repositories is included in this package.

## Extension Naming

Xedats uses the `XEDATS_` vendor prefix for its glTF audio extensions (`XEDATS_audio_emitter`, `XEDATS_audio_material`). The extension JSON schemas and runtime behavior are original to Xedats. The naming convention follows the standard glTF extension prefix pattern (`XEDATS_` as a vendor prefix for Xedats), consistent with how other engines and tools name their custom glTF extensions.

## Research References

The `GLTF_Docs/Spatial_Audio_Research_Reference.md` file cites external research papers and open-source Godot spatial audio addons that were studied during Xedats development. Those projects are referenced as architectural inspiration only. No code, data, or assets from those projects are included in Xedats.

---

*Last updated: 2026-07-06*

