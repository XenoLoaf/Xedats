# Xedats — Xebug Companion Modules

Companion modules for [Xedats](https://github.com/XenoLoaf/Xedats-Standalone) that integrate with [Xebug](https://github.com/XenoLoaf/Xebug).

## Modules

### Xebug_Modules (Runtime Inspector Modules)

| Module | Purpose |
|--------|---------|
| `xedats_pool_monitor.gd` | Inspect 3D/2D player pool usage in Xebug |
| `xedats_bus_inspector.gd` | Browse active bus routes and effect chains |
| `xedats_event_monitor.gd` | Monitor registered events and recent triggers |
| `xedats_runtime_validator.gd` | Runtime sanity checks on pool, buses, and crossfade state |

### XedatsConsoleModule (Command Bridge)

| File | Purpose |
|------|---------|
| `xedats_console_module.gd` | Registers `audio`, `xd.panel`, `xd.overlay`, `xd.trace`, `xd.status`, `xd.refresh`, `xd.feed` commands in Xebug |

## Usage

Copy the folders into your project alongside Xedats. Modules auto-discover when Xebug is present at runtime.

```gdscript
# Register the console bridge
var bridge: XedatsConsoleModule = XedatsConsoleModule.new()
add_child(bridge)
```

## Requirements

- [Xedats](https://github.com/XenoLoaf/Xedats-Standalone) (main branch)
- [Xebug](https://github.com/XenoLoaf/Xebug) (compatible host console)

## Repository

This branch contains only the Xebug companion modules. For the full Xedats audio system, see the [main branch](https://github.com/XenoLoaf/Xedats-Standalone).
