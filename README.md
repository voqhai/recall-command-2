# Curic Recall Command

A SketchUp extension that lets you instantly re-invoke the last used command with a single keyboard shortcut.

## Features

- Re-runs the last used **SketchUp native tool** (Move, Push/Pull, Rotate, etc.) or **Ruby extension command**
- Tracks `UI::Command` executions automatically via TracePoint — no monkey-patching required
- Works with commands registered by any extension, including those loaded after startup
- Graceful fallback on SketchUp versions older than 2022 (TracePoint `target:` not supported)

## Requirements

- SketchUp 2022 or later (Ruby 2.7+)
- TracePoint `target:` — available from Ruby 2.6, shipped with SketchUp 2021 - Ruby 2.7

## Installation

1. Download the `.rbz` file from the [Releases](../../releases) page
2. In SketchUp, go to **Extensions → Extension Manager → Install Extension**
3. Select the downloaded `.rbz` file
4. Restart SketchUp if prompted

## Usage

1. Assign `Space` (or any key) to **Curic Recall Command → Call Last** via **Preferences → Shortcuts**
2. Use any tool or command normally
3. Press the shortcut **twice in quick succession** to re-invoke the last command

This mimics the **double-Space** workflow in AutoCAD / BricsCAD:

| Press | Action |
|---|---|
| First press | Returns to the Selection tool (escape current tool) |
| Second press (within 0.3 s) | Re-runs the last command |

> Tip: Assign `Space` as the shortcut to get the closest feel to CAD software.

## How It Works

| Source | Mechanism |
|---|---|
| Native SketchUp tools | `Sketchup::ToolsObserver` (`onActiveToolChanged`) |
| Ruby `UI::Command` objects | `TracePoint` (`:b_call`) attached to each command's proc |

Commands are discovered via periodic `ObjectSpace` scans with exponential back-off, so extensions that load late are still tracked automatically.

## Changelog

### v2.0.0 — TracePoint rewrite

v2 is a ground-up rewrite of the command tracking engine.

**v1.x** tracked `UI::Command` executions by monkey-patching core SketchUp classes at runtime:
- `Sketchup::Menu#add_item` — wrapped each menu item's proc to intercept calls
- `Sketchup::Menu#add_submenu` — tracked the menu tree for display names
- `UI.menu` — intercepted top-level menu registration

This approach was fragile: load order mattered, extensions that registered commands before the plugin loaded were missed, and overriding core classes risked compatibility issues with other plugins.

**v2.0** replaces all of that with `TracePoint#enable(target: proc)` (Ruby 2.6+):
- No core classes are patched
- Each `UI::Command`'s proc gets a dedicated `TracePoint` that fires exactly when that proc is called, regardless of how or from where
- A background `ObjectSpace` scanner with exponential back-off picks up commands from extensions that load after startup
- Cleaner, safer, and more reliable across the entire SketchUp extension ecosystem

## License

MIT © 2021–2026 Vo Quoc Hai — [voqhai@curic.io](mailto:voqhai@curic.io)

For support: [support@curic.io](mailto:support@curic.io)

## Disclaimer

This plugin uses `TracePoint` and `ObjectSpace` to monitor Ruby proc execution across the entire SketchUp environment. While it is designed to be non-intrusive, it may interact unexpectedly with other extensions — particularly those that share proc objects, use heavy metaprogramming, or are sensitive to execution timing.

**Use at your own risk.** The authors are not responsible for any unintended behavior, data loss, or conflicts with other plugins that may arise from using this extension.
