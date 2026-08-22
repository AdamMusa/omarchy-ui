# Omarchy UI for Ruby

Omarchy UI is a Ruby-first application framework for native Omarchy plugins and apps. Ruby
owns state, events, tasks, commands, models, and lifecycle; the packaged QML runtime renders
the component tree inside Omarchy. Application code stays ordinary, readable Ruby—there is no
generated Ruby source and no attempt to reproduce QML syntax as a giant DSL.

```ruby
require "omarchy_ui"

OmarchyUI.plugin do
  state :count, 0

  bar_widget do
    text { "Count: #{state.count}" }
    on_click { open_panel :counter }
  end

  panel :counter do
    column spacing: 12 do
      label = text "", style: :heading
      bind(label, :text, animation: animation(duration: 180)) { "Count: #{state.count}" }
      button("Increment") { state.count += 1 }
    end
  end
end
```

## Run, create, validate, and push

From this checkout, both supported execution forms work:

```bash
ruby main.rb
bin/omarchy_ui run main.rb
```

When installed as a gem, use `omarchy_ui` instead of `bin/omarchy_ui`.

```bash
omarchy_ui new "My Plugin" --id local.my-plugin
omarchy_ui validate my-plugin
omarchy_ui push my-plugin
```

`push` copies into a staging directory, vendors the Ruby library and QML runtime, runs
Omarchy's validator, backs up an existing installation under
`~/.local/state/omarchy-ui/backups`, installs atomically, enables the plugin, and restarts the
shell. `--no-enable` and `--no-restart` are available for controlled deployments.

## Framework capabilities

- Surfaces: bar widgets, panels, and application surfaces.
- Layout/display: rows, columns, grids, stacks, scrolling, containers, rectangles, text,
  icons, images, progress, separators, and spacers.
- Inputs/actions: buttons, action buttons, toggles, text and number fields, sliders,
  dropdowns, searchable dropdowns, multi-select, button groups, dialogs, and list views.
- State: validated values, atomic transactions, reactive properties, dynamic conditional and
  repeated subtrees, and incremental child reconciliation.
- Events: typed built-in events and arbitrary declared adapter events, with surface ownership
  checks and acknowledgements.
- Models: primitive or object list models, selection, activation, and scroll events.
- Motion: easing, delay, reactive transitions, direct animation, parallel tracks, and
  sequential animation steps.
- Runtime: `async`, cancellable `after`/`every` tasks, safe argv commands with timeouts,
  lifecycle supervision, crash restart, and structured errors.

The canonical escape hatch is a native component adapter. It makes the framework capable of
using any QML component—QtQuick, QtQuick.Controls, Quickshell, Omarchy `qs.Ui`, Canvas,
shaders, particles, or a third-party module—without adding every QML class name to Ruby:

```ruby
register_component :sparkline,
  qml: "Sparkline.qml",
  properties: %i[values color line_width],
  events: %i[click point_hover],
  container: false

chart = component :sparkline, values: [2, 8, 5], color: "#ff6655"
on(chart, :point_hover) { |event| state.hovered = event.fetch("index") }
```

Adapters live in `Components/`. Explicit property and event contracts preserve validation and
prevent executable QML from crossing the JSON bridge. See [QML support](docs/qml-support.md)
and `Components/Sparkline.qml`.

## Architecture

`Service.qml` supervises one long-lived Ruby process and exchanges versioned NDJSON over its
stdin/stdout. `ControlNode.qml` recursively renders registered nodes. `Panel.qml` and
`BarWidget.qml` reuse the same persistent service, so closing a panel does not reset Ruby
state. Property changes send small patches; dynamic branches replace only the affected
children; animations execute in QML.

Incoming protocol values are never evaluated. Component types, properties, events, IDs,
effects, and value shapes are validated on both sides. Commands are argv arrays and never use
a shell. Plugins still run with the user's permissions, as all third-party Omarchy plugins do.

## Omarchy Phone in Ruby

`examples/omarchy-phone` is a framework application replacing the earlier Python/QML phone
plugin. It supports ADB USB and mDNS discovery, wireless pairing, connect/disconnect/forget,
scrcpy control and media options, trusted iPhone discovery, libimobiledevice pairing, and
UxPlay AirPlay mirroring.

```bash
ruby examples/omarchy-phone/main.rb
omarchy_ui run examples/omarchy-phone/main.rb
omarchy_ui push examples/omarchy-phone
```

## Verification

```bash
./scripts/test.sh
./scripts/smoke-test.sh   # inside a live Omarchy session
ruby script/benchmark.rb
```

The suite covers the protocol, registry, state, events, models, dynamic reconciliation,
animation composition, scheduling, safe commands, project generation, staged deployment,
manifest/QML contracts, the phone backend, Ruby syntax, `qmllint`, and Omarchy validation.
The live smoke test verifies the supervised process, summons a panel, and scans the shell
journal for QML/runtime failures.
