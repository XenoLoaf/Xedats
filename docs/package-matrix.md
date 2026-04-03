# Package Matrix

This repository is the standalone home for `Xedats`.

If you want a pre-bundled setup with the wider tool stack already wired together, see `https://github.com/XenoLoaf/Xedats_ProjectBundle`.

## Packages in this repository

| Package | What it provides | When to use it | Notes |
| --- | --- | --- | --- |
| `Xedats` | Standalone Xedats runtime package | Start here | The core package and the default setup. |
| `XedatsConsoleModule` | Xedats-owned command registration layer | Optional | Add this only if you already have a compatible console host and want Xedats-specific commands exposed there. |

## Optional companion packages

These packages live outside this repository and can be added when you want to extend your setup.

| Package | Why you might add it | Required by `Xedats`? | Source |
| --- | --- | --- | --- |
| `AutoloadManager` | Generic autoload singleton registry and docking base | No | `https://github.com/XenoLoaf/AutoloadManager` |
| `Xebug` | Generic runtime command console and UI | No | `https://github.com/XenoLoaf/Xebug` |

## Common ways to use it

Use `Xedats` by itself when you want the simplest and most self-contained setup.

Add `XedatsConsoleModule` when you have a console runtime and want Xedats-specific command registration.

Bring in external `Xebug` if you want a ready-made console UI, and add external `AutoloadManager` if that project structure fits the way you want to organize your project.

If you want everything pre-wired, use the project bundle.