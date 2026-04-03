# Xedats

Standalone Xedats runtime package.

## What this package contains

- core Xedats runtime scripts
- resources, modules, and tests copied from the bundled source
- Xedats documentation in `Xedats.md`

## Current runtime model

This standalone package manages its singleton lifecycle internally.

To use it in another project:

1. Copy this Xedats package into the project.
2. Ensure the scripts are available on the normal `res://` path.
3. Access `XedatsSingleton.instance()` from code when you want the runtime to initialize.

The singleton lazily creates itself and attaches to the active scene tree root on first access.

## Scope

This package contains the runtime audio system itself.

Package-specific setup and usage details are documented in `Xedats.md` and `Getting_Started.md`.

## Project bundle

If you want the pre-bundled setup with the wider tool stack already wired together, use the project bundle linked from the repository root README.