# Xedats Console Module

Runtime command bridge module for installing package-owned commands into a host command console.

## Purpose

This package contains a concrete command set and a registration layer for exposing it through a host command console.

## Commands owned by this module

- `xd.panel <on|off|toggle>`
- `xd.overlay <on|off|toggle>`
- `xd.trace <on|off|toggle>`
- `xd.status`
- `xd.refresh`
- `xd.feed <subcommand...>`
- `audio <list_buses|list_events|toggle_category|inspect_player|route_test> [args]`

## Lifecycle

- Instantiate `XedatsConsoleModule` after the host command console is available.
- The module registers commands in `_ready()`.
- The module unregisters its commands in `_exit_tree()`.

## Notes

This is a runtime bridge module, not a generic console package.
