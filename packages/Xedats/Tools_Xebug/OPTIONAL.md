# Xebug Tooling — Optional

This subfolder contains Xebug-based companion tools for runtime Xedats inspection, debugging, and testing.

## Dependencies (required to exist)

- `Nodes/` — `XedatsSingleton`
- `Core/` — `AudioEventSystem`
- **Xebug** — `XebugModule`, `XebugConsole` (must be installed in the project as `addons/xebug_command_console/`)
- **XedatsConsoleModule** — `xedats_console_module.gd` (optional; tools are independent)

## What it provides

| Tool | Class | Commands |
|------|-------|----------|
| **Pool Monitor** | `XedatsPoolMonitor` | `xedats.pool`, `xedats.pool.snapshot`, `xedats.pool.watch` |
| **Bus Inspector** | `XedatsBusInspector` | `xedats.bus`, `xedats.bus.inspect`, `xedats.bus.volume`, `xedats.bus.routes` |
| **Event Monitor** | `XedatsEventMonitor` | `xedats.event`, `xedats.event.history`, `xedats.event.inspect` |
| **Runtime Validator** | `XedatsRuntimeValidator` | `xedats.test.smoke`, `xedats.test.leak`, `xedats.test.buses`, `xedats.test.health` |

## Installation

1. Copy the `.gd` files into any project that has Xedats + Xebug installed
2. Place them in Xebug's `modules/` directory for auto-discovery, OR
3. Instantiate manually: `get_tree().root.add_child(XedatsPoolMonitor.new())`
4. Commands are available in the Xebug console immediately

## Deletion

This entire folder can be deleted without affecting Xedats or Xebug core functionality. No other directory references these classes.
