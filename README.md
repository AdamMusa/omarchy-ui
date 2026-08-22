# Omarchy UI for Ruby

This is a reusable Ruby application framework for Omarchy. Ruby remains alive, owns state and callbacks, and sends a typed control tree plus incremental patches to a reusable QML renderer. Application authors use Ruby; the framework owns QML integration, process lifecycle, validation, rendering, and events.

The proof of concept implements the requested counter:

```ruby
state :count, 0

panel :counter do
  column spacing: 12 do
    text(id: :count) { "Count: #{state.count}" }

    row spacing: 8 do
      button "Increment", id: :increment do
        state.count += 1
      end

      button "Reset", id: :reset do
        state.count = 0
      end
    end
  end
end
```

## What the Omarchy inspection found

The prototype is based on Omarchy's `quattro` branch at commit `ed7bae4ac5a570e9df307486e0202fdafcc6ee24` from August 21, 2026.

- Omarchy runs one long-lived Quickshell instance from `shell/shell.qml`. Third-party plugins are loaded into that process from `~/.config/omarchy/plugins/<id>/`.
- A schema-version-1 manifest can declare `service`, `bar-widget`, and `panel` entry points. Entry points are `Item`s; the shell injects `shell`, `manifest`, and related properties.
- Plugin services are created once while the plugin is enabled. On-demand panels are created when summoned and may be destroyed when hidden. Therefore the persistent Ruby owner belongs in `Service.qml`, not `Panel.qml`.
- A panel that declares `property var service` receives the matching plugin service automatically. A bar widget can resolve it through `bar.shell.serviceFor(moduleName)`.
- `omarchy-shell` wraps Quickshell's named IPC handlers. It is excellent for `summon`, `hide`, `toggle`, enable/disable, and CLI calls, but it is string-oriented request/response IPC rather than a streaming transport.
- Quickshell's existing `Process` type already supports a tracked long-running child, writable stdin, line-parsed stdout/stderr, SIGTERM via `running = false`, and automatic termination when Quickshell dies. Omarchy already uses `Process`, `stdinEnabled`, `write()`, and `SplitParser` in its own QML.
- The earlier Omarchy Phone plugin in this workspace independently uses the same `service` + `bar-widget` ownership pattern. It was inspected read-only and was not modified.

## Chosen architecture

```text
main.rb and omarchy_ui.rb
  Ruby state, callbacks, bindings, control tree
                  │
                  │ versioned NDJSON over stdin/stdout
                  ▼
Service.qml
  process lifecycle, protocol validation, node index, patches
                  │
                  ├───────────────┐
                  ▼               ▼
BarWidget.qml                 Panel.qml
                  \             /
                   ControlNode.qml
               generic recursive renderer
                          │
                          ▼
                 QtQuick + Omarchy Ui
```

This uses stdio instead of a Unix socket because Quickshell already owns and supervises the Ruby child and exposes both directions directly. A socket would add naming, cleanup, permissions, reconnect, and stale-socket handling without improving this one-parent/one-child topology. Omarchy shell IPC remains the right mechanism for external CLI calls and for the service to summon or hide the panel through the injected shell object.

## Project structure

```text
omarchy-ui-poc/
├── manifest.json
├── Service.qml
├── BarWidget.qml
├── Panel.qml
├── ControlNode.qml
├── main.rb
├── lib/
│   └── omarchy_ui.rb
├── benchmark/
│   └── results.json
├── script/
│   └── benchmark.rb
├── scripts/
│   ├── install-local.sh
│   └── test.sh
├── test/
│   ├── manifest_test.rb
│   ├── omarchy_ui_test.rb
│   └── qml_contract_test.rb
├── LICENSE
└── README.md
```

Normal plugin code is only `main.rb`. The QML files and `lib/omarchy_ui.rb` are framework infrastructure in this prototype.

## Ruby framework API

The stable framework primitive is `component(type, **properties)`. The named helpers below are a small compatibility/convenience facade; control definitions, allowed properties, events, and QML adapters live in the component registry rather than being hard-coded into the builder.

`lib/omarchy_ui.rb` provides:

- `state :name, initial` and `state.name` / `state.name=`
- `bar_widget` and `panel :name`
- surfaces: `bar_widget`, `panel`, and `app`
- layout: `row`, `column`, `grid`, `stack`, `scroll`, `container`, `rectangle`, and `spacer`
- display: `text`, `icon`, `image`, `progress`, `separator`, and `section_header`
- actions: `button` and `action_button`
- input: `toggle`, `toggle_switch`, `text_field`, `number_field`, `slider`, `dropdown`, `multi_select`, and `button_group`
- events: click, change, submit, focus, and blur with typed payloads
- reactive properties through `bind(control, :property) { ... }`
- effects: `open_panel` and `close_panel`

### Extending with any QML component

Custom QML is supported through validated local adapters, so applications are not limited to the built-in DSL vocabulary:

```ruby
register_component :sparkline,
  qml: "Sparkline.qml",
  properties: %i[values color],
  events: %i[click]

app do
  component :sparkline, values: [2, 8, 5, 12], color: "#f44"
end
```

Adapters live in `Components/` and receive the bridge, surface name, control id, and typed node model. See `Components/Sparkline.qml` for a complete example. Registration uses basename-only QML paths and explicit property/event schemas; arbitrary executable QML is never transported over JSON.
- deterministic generated ids and explicit ids such as `id: :count`

Every state write reevaluates registered reactive property blocks. Only changed values produce patches. Assigning the current value again produces no patch.

Ordinary Ruby conditionals and iteration can be made reactive with a structural container:

```ruby
dynamic id: :results do
  if state.items.empty?
    text "No results", id: :empty
  else
    state.items.each do |item|
      button item.fetch(:label), id: "result.#{item.fetch(:id)}"
    end
  end
end
```

State changes reconcile only that container's descendants. Removed nodes lose their bindings
and handlers, new nodes are validated and indexed, and the bridge applies a
`replace_children` patch without recreating the panel, surface, service, or Ruby process.

The current conditional story is intentionally limited: ordinary Ruby `if` executes while the initial tree is built. Reactively adding or removing a branch requires structural diffing, which is listed under next steps rather than hidden behind a full rerender.

## Generic QML renderer

`ControlNode.qml` recursively maps the whitelisted tree to Omarchy/QtQuick components.

| Ruby control | QML mapping |
| --- | --- |
| `text` | QtQuick `Text` using Omarchy `Style` and `Color` |
| `icon` | QtQuick `Text` with a small named Nerd Font glyph map |
| `button` | `qs.Ui.Button` |
| `row` | QtQuick `Row` + `Repeater` |
| `column` | QtQuick `Column` + `Repeater` |
| `container` | Omarchy `BorderSurface` + vertical content host |
| `image` | QtQuick `Image` |
| `spacer` | QtQuick `Item` |

The renderer looks controls up by stable id in `Service.qml`'s node index. A `set` patch replaces only that indexed node and increments a revision. The existing panel, process, window, and unrelated controls are not rebuilt or relaunched.

## Protocol

The transport is newline-delimited JSON. Every envelope has `v: 1`; both sides reject unknown versions, oversized lines, malformed ids, unknown types, invalid properties, and non-whitelisted effects.

Ruby startup:

```json
{"v":1,"type":"ready","pid":1234,"surfaces":["bar","counter"]}
{"v":1,"type":"render","surfaces":{"counter":{"type":"container","id":"panel.counter","children":[]}}}
```

Button click from QML:

```json
{"v":1,"type":"event","surface":"counter","id":"increment","event":"click","seq":7,"payload":{}}
```

Ruby state patch and acknowledgement:

```json
{"v":1,"type":"patch","op":"set","id":"count","property":"text","value":"Count: 1"}
{"v":1,"type":"ack","seq":7,"id":"increment","event":"click"}
```

The event path is `MouseArea / qs.Ui.Button → Service.sendEvent → Process.write → Ruby handler lookup → Proc execution`. The state path is `state.count= → reactive binding comparison → set patch → Service.applyPatch → node revision → existing ControlNode text binding`.

No incoming value is evaluated as code. `Process.command` is an argv array (`["ruby", rubyProgram]`) and does not invoke a shell. QML accepts only declared control types, properties, primitive property values, ids, and effects. The Ruby side verifies that an event's control id belongs to the named surface before dispatching it.

## Lifecycle

- Enabling the plugin creates `Service.qml`; once `manifest.__sourceDir` is injected, it starts `ruby main.rb` exactly once.
- Closing the panel may destroy `Panel.qml`, but the separate service and Ruby process stay alive.
- Disabling or reloading the plugin destroys the service. Its destruction handler stops the tracked `Process`, which sends SIGTERM.
- If Quickshell exits, Quickshell terminates tracked child processes. The prototype never uses detached process launch, so Ruby is not intentionally orphaned.
- If Ruby exits unexpectedly, the service reports an error and restarts it with exponential backoff from 500 ms to 30 seconds. Ruby sends a fresh complete tree after restart.
- If Quickshell restarts, the enabled service is recreated and starts a fresh Ruby runtime. No reconnect protocol or stale socket is necessary.
- Ruby stdout is reserved for protocol messages. Ruby stderr is forwarded to Quickshell warnings. QML protocol failures and runtime crashes update `lastError`, which the UI displays.

## Tests and measurements

Run:

```bash
./scripts/test.sh
ruby script/benchmark.rb
```

Inside a live Omarchy session, deploy and verify the supervised Ruby process, panel summon,
and QML journal with:

```bash
./scripts/smoke-test.sh
```

The test suite verifies the initial tree, callbacks, a single incremental count patch, no-op state assignments, malformed and cross-surface event rejection, effects, duplicate-id rejection, the manifest contract, no symlinks, and the QML process/renderer contract. The plugin also passes Omarchy's current `omarchy-plugin-validate` implementation.

Measured on the work container with Ruby 3.3.8 and 500 sequential increment events:

| Metric | Result |
| --- | ---: |
| Ruby process start to `ready` | 50.441 ms |
| Initial render after `ready` | 0.032 ms |
| Ruby → stdout patch, median / p95 | 0.032 / 0.075 ms |
| Event round trip, median / p95 | 0.035 / 0.091 ms |
| Sequential event throughput | 20,592.7 events/s |
| Ruby RSS after 500 updates | 21,476 KiB |

These are bridge measurements, not end-to-end visual measurements. This work container is Ubuntu and does not contain Quickshell, an Omarchy session, Wayland, or a compositor, so the QML scene could not be opened here. A real Omarchy smoke test still needs to measure physical click-to-frame latency and inspect the final layout. The code was tested through the real Ruby subprocess protocol and validated against the exact current Omarchy manifest validator; `benchmark/results.json` records the environment and scope.

## Install in an Omarchy session

Ruby must be available as `ruby` on `PATH`. From this repository:

```bash
./scripts/install-local.sh
```

The installer refuses to overwrite an existing plugin directory, copies the repository to `~/.config/omarchy/plugins/izeesoft.omarchy-ui-poc`, runs Omarchy's validator, rescans plugins, and enables it. The bar widget should appear on the right. It can also be summoned directly:

```bash
omarchy-shell shell summon izeesoft.omarchy-ui-poc '{"surface":"counter"}'
```

After QML changes, use `omarchy restart shell`. Ruby-only edits currently require a plugin rescan or shell restart because this proof of concept does not yet implement Ruby hot reload.

## Current limitations

- No real Omarchy/Wayland visual smoke test has run in this container.
- Only `set` property patches are implemented. Insert, remove, move, replace, and list reconciliation are not.
- Arbitrary reactive properties are implemented, but bindings currently reevaluate on every state write rather than tracking dependencies.
- Reactive conditional rendering is not implemented. Ordinary Ruby `if` is initial-render-only.
- The renderer covers the core Omarchy application controls; specialized shell-owned widgets such as the system tray and workspace switcher intentionally remain shell integrations rather than portable app controls.
- Layout is implicit-size `Row`/`Column`, not a complete constraints or responsive layout system.
- No background-thread scheduler, async task API, cancellation API, persistence, accessibility metadata, focus traversal model, or developer inspector exists yet.
- Crash restart restores the tree from `main.rb`; state is in memory and resets unless plugin code persists it.
- Third-party Omarchy plugins, including this one, run unsandboxed with the user's permissions. Protocol validation reduces accidental bridge abuse but does not sandbox malicious plugin code.

## Turning this into a reusable gem/framework

1. Extract `lib/omarchy_ui.rb` into an `omarchy_ui` gem with a versioned protocol package and public DSL tests.
2. Ship the generic QML runtime as gem templates and add `omarchy-ui new`, `omarchy-ui validate`, and `omarchy-ui install` commands.
3. Add keyed tree reconciliation and structural operations: `insert`, `remove`, `move`, and `replace`.
4. Track binding dependencies per state key so one state write reevaluates only dependent bindings.
5. Add reactive conditionals and lists with stable keys rather than silently rebuilding a surface.
6. Define typed property schemas, event payload schemas, accessibility fields, focus/keyboard behavior, image-source policy, and protocol conformance tests shared by Ruby and QML.
7. Add an async runtime, timers, task cancellation, service APIs, structured logging, crash reports, and optional state persistence.
8. Add Ruby hot reload that preserves the QML service, restarts Ruby predictably, and either restores state or declares reset semantics.
9. Run graphical acceptance tests in Omarchy's disposable VM and capture cold start, click-to-patch, patch-to-frame, multi-monitor, disable/re-enable, shell restart, Ruby crash, and rapid-event behavior.
10. Once the protocol stabilizes, decide whether the QML runtime should stay copied into every plugin or become one separately versioned Omarchy plugin dependency. The copied runtime is simpler and avoids an undeclared cross-plugin dependency today.
