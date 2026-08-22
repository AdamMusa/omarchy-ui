# Omarchy UI

> **Experimental:** the API and packaging format are being validated with real Omarchy apps.
> Pin the gem version for production projects and review release notes before upgrading.

Omarchy UI is a Ruby framework for building native Omarchy applications. It provides reactive
state, components, events, animation, tasks, commands, standalone windows, and shell plugin
integration through one compact API.

```ruby
require "omarchy_ui" unless Object.const_defined?(:OmarchyUI)

OmarchyUI.plugin do
  state :count, 0

  app :main, title: "Counter", width: 640, height: 420 do
    column spacing: 12 do
      text "Official Omarchy UI", style: :heading
      text { "Count: #{state.count}" }
      button("Increment") { state.count += 1 }
    end
  end
end
```

## Install

On Omarchy x86-64, install the gem and start building:

```bash
gem install omarchy-ui
omarchy_ui new MyApp
```

The gem contains everything required to create, launch, and bundle an application. Developers do
not need to install a separate runtime or copy framework files. Bundled applications require only
an Omarchy computer to run.

## Create and run an application

```bash
omarchy_ui new MyApp
cd myapp
omarchy_ui launch main.rb
```

The standalone generator creates no plugin manifest or copied runtime files:

```text
myapp/
├── Components/
│   └── Welcome.qml
├── README.md
└── main.rb
```

`launch` opens a compositor-managed window. Drag its title bar or use Super+drag, and close it
with Super+W. For protocol debugging without a window, use `omarchy_ui run main.rb`.

## Bundle for another Omarchy computer

From an application directory:

```bash
omarchy_ui bundle
./dist/myapp/run
```

`bundle` creates a self-contained application under `dist/<project-name>/`. The generated `run`
launcher works on another Omarchy computer without Ruby or the `omarchy-ui` gem.

An Omarchy Shell plugin is a separate packaging mode. It requires `manifest.json` so the shell
can discover its ID, entry points, bar placement, and lifecycle. For a project that intentionally
contains a manifest:

```bash
omarchy_ui validate path/to/plugin
omarchy_ui push path/to/plugin
```

`push` stages and validates the project, adds the framework support files, backs up an existing
installation, installs atomically, optionally enables it, and restarts Omarchy Shell. Use
`--no-enable` or `--no-restart` when needed.

## Surfaces and windows

```ruby
bar_widget do
  text "Weather"
  on_click { open_panel :weather }
end

panel :weather do
  text "Panel content"
end

app :main,
    title: "Weather",
    width: 900,
    height: 600,
    min_width: 480,
    min_height: 320,
    max_width: 1600,
    max_height: 1200,
    color: "#101713",
    visible: true,
    maximized: false,
    fullscreen: false do
  text "Application content"
end
```

`app` supports `title`, `width`, `height`, `min_width`, `min_height`, `max_width`, `max_height`,
`color`, `visible`, `maximized`, and `fullscreen`.

## State and reactivity

```ruby
state :enabled, false
state :profile, { "name" => "Ada" }

toggle_control = toggle "Enabled", checked: state.enabled do |event|
  state.enabled = event.fetch("value")
end
bind(toggle_control, :checked) { state.enabled }

text { state.enabled ? "Enabled" : "Disabled" }

transaction do
  state.enabled = true
  state.profile = { "name" => "Grace" }
end
```

State accepts protocol-safe values: `nil`, booleans, finite numbers, strings, arrays, and hashes
with string/symbol keys. Bindings are reevaluated after changes and emit small property patches.
Ruby blocks passed to `text`, `property`, or `bind` are reactive; no wrapper is required.
`transaction` batches related state writes.

## Common properties

Every component supports `visible`, `enabled`, `opacity`, `scale`, `rotation`, `z`, `width`, and
`height`. Component-specific properties are listed below. Property names use Ruby `snake_case`.

## Built-in component reference

### Layout and display

| Ruby component | Component-specific properties | Events | Container |
| --- | --- | --- | --- |
| `container` | `spacing`, `padding`, `bordered` | `click` | yes |
| `row` | `spacing`, `alignment` (`start`, `center`, `end`) | `click` | yes |
| `column` | `spacing`, `alignment` (`start`, `center`, `end`) | `click` | yes |
| `grid` | `columns`, `rows`, `spacing`, `row_spacing`, `column_spacing` | `click` | yes |
| `stack` | — | `click` | yes |
| `scroll` | `clip` | `click` | yes |
| `rectangle` | `color`, `radius`, `border_color`, `border_width`, `padding` | `click` | yes |
| `text` | `text`, `style`, `size`, `bold`, `color`, `wrap` | — | no |
| `icon` | `name`, `text`, `size`, `color` | — | no |
| `image` | `source`, `fill_mode` | — | no |
| `spacer` | — | — | no |
| `progress` | `value`, `minimum`, `maximum`, `color` | — | no |
| `separator` | `strength` | — | no |
| `section_header` | `text` | — | no |
| `panel_hero` | `title`, `meta`, `detail`, `foreground`, `font_family`, `icon_size`, `icon_opacity`, `meta_opacity` | — | no |
| `optical_glyph` | `text`, `size`, `color`, `debug_bounds` | — | no |

### Inputs and actions

| Ruby component | Component-specific properties | Events |
| --- | --- | --- |
| `button` | `text`, `icon`, `tooltip`, `selected`, `active`, `cursor`, `focusable`, `bordered`, colors, font/icon sizes, padding, `left_align` | `click`, `right_click`, `hover` |
| `action_button` | `icon`, `tooltip`, `foreground`, `hover_color`, font/size, `focusable`, `cursor`, `bordered` | `click`, `hover` |
| `toggle` | `label`, `description`, `checked`, `cursor`, `rounded`, colors, font/title/description sizes | `change`, `hover` |
| `toggle_switch` | `checked`, `busy`, `interactive`, `cursor`, `cursor_ring`, `cursor_pad`, `rounded`, colors, track/knob geometry | `change`, `hover` |
| `text_field` | `text`, `placeholder`, `password`, colors, selection tint, padding, `cursor` | `input`, `change`, `submit`, `focus`, `blur` |
| `number_field` | `label`, `value`, `from`, `to`, `step`, colors, font/field width, `cursor` | `change`, `hover` |
| `slider` | `value`, `minimum`, `maximum`, `step`, `integer`, track/fill/knob colors and sizes, `ticks`, `tick_color` | `input`, `change`, `right_click` |
| `dropdown` | `label`, `value`, `options`, colors, font, row sizes, `show_label`, `cursor` | `change`, `hover` |
| `searchable_dropdown` | dropdown fields plus `placeholder`, `empty_text`, `trigger_label`, popup sizing | `change`, `hover` |
| `multi_select` | `label`, `values`, `options`, command options, placeholder/empty labels, popup sizing, colors | `change`, `hover` |
| `button_group` | `value`, `options`, colors, font, `focusable`, `cursor_index` | `change`, `hover` |
| `confirm_dialog` | `opened`, `message`, cancel/confirm labels, `selected_index`, colors, font, `corner_radius` | `cancel`, `confirm` |
| `cursor_surface` | `cursor`, `current`, `outline`, `bordered`, `foreground`, `accent`, `fill`, `current_fill` | `click` |
| `widget_button` | text/font/colors, active state, dimensions, rotation, visibility states, interaction flags, tooltip | `click`, `right_click`, `middle_click`, `wheel` |
| `list_view` | `items`, key/label/description/icon fields, `selected`, `orientation`, `spacing`, `empty_text` | `change`, `activate`, `scroll` |

Convenience methods return their node, so it can be bound, animated, or passed to `on`:

```ruby
field = text_field "", id: :query, placeholder: "Search" do |event|
  state.query = event.fetch("value")
end

on(field, :submit) { |event| state.query = event.fetch("value") }
```

Typical event payloads are:

- `click`, `right_click`, `confirm`, `cancel`: `{}`
- `change`, `input`, `submit`, `hover`: `{ "value" => ... }`
- `wheel`: `{ "delta" => number }`
- `list_view` change/activate: value, index, and original item
- `list_view` scroll: x and y offsets

Only declared and subscribed events are delivered to application handlers.

## Bindings and properties

```ruby
label = text "", id: :status
bind(label, :text) { state.message }

container do
  property :opacity, 0.8
end
```

`text { ... }` is shorthand for a reactive text binding. `property` binds or sets a property on
the current component. Explicit IDs are recommended for controls targeted by tests or external
effects; generated IDs are stable for the lifetime of one render.

## Animation

Reactive binding transition:

```ruby
card = rectangle width: 240, height: 120, opacity: 1.0
bind(card, :opacity, animation: animation(duration: 180, easing: :out_cubic)) do
  state.visible ? 1.0 : 0.0
end
```

Animate one or several properties immediately:

```ruby
animate card,
  { opacity: 0.25, scale: 1.08, rotation: 2 },
  duration: 220,
  easing: :in_out_quad,
  delay: 40
```

Sequential animation:

```ruby
animate_sequence card, [
  { to: { scale: 1.12 }, duration: 120, easing: :out_back },
  { to: { scale: 1.0 }, duration: 160, easing: :out_cubic, pause: 30 }
]
```

Animation durations and delays are milliseconds from `0` to `60_000`. Supported easing names:

```text
linear
in_quad, out_quad, in_out_quad
in_cubic, out_cubic, in_out_cubic
in_back, out_back, in_out_back
in_elastic, out_elastic, in_out_elastic
in_bounce, out_bounce, in_out_bounce
```

All common numeric visual properties and declared numeric custom-adapter properties can be
animated. Properties in the same hash animate in parallel.

## Tasks and commands

```ruby
after(0.5) { state.message = "Ready" }
every(5, immediate: true) { state.updated_at = Time.now.to_i }
async { state.result = run_command(["uname", "-r"], timeout: 2).stdout.strip }
```

`after`, `every`, and `async` return cancellable task objects. Command execution always takes an
argv array and does not invoke a shell. Results expose `stdout`, `stderr`, `exitstatus`, and
`success?`; timeout raises `OmarchyUI::CommandTimeout`.

## Custom QML components

Any QtQuick, QtQuick.Controls, Quickshell, Omarchy `qs.Ui`, Canvas, shader, particle, or
third-party QML component can be exposed through a validated adapter contract:

```ruby
register_component :sparkline,
  qml: "Sparkline.qml",
  properties: %i[values color line_width],
  property_map: { color: :strokeColor, line_width: :lineWidth },
  events: %i[click point_hover],
  event_map: { point_hover: :pointHovered },
  container: false,
  auto_bind: true

chart = component :sparkline, values: [2, 8, 5], color: "#ff6655"
on(chart, :point_hover) { |event| state.hovered = event.fetch("index") }
```

Place adapter files under `Components/`. Declared properties are assigned to the QML root and
declared signals are forwarded to Ruby. A container adapter can expose an `Item` property named
`contentHost`; framework children are parented into it automatically. See
[the QML support matrix](docs/qml-support.md) and [Sparkline.qml](Components/Sparkline.qml).

## Safety

Component names, files, properties, events, IDs, effects, values, message sizes, and animation
limits are validated. Commands use argv arrays without a shell. Applications and plugins run with
the current user's permissions, so review third-party code before installing it.

## Omarchy Phone example

`examples/omarchy-phone` demonstrates reactive controls, background discovery, safe commands,
ADB pairing and connection, scrcpy launching, iPhone discovery, and UxPlay AirPlay mirroring.

```bash
omarchy_ui launch examples/omarchy-phone/main.rb
```

## Development and verification

```bash
./scripts/test.sh
ruby script/benchmark.rb
./scripts/smoke-test.sh  # live Omarchy session
```

The suite covers state, bindings, repeated structures, event persistence, component schemas,
animation tracks and sequences, tasks, command safety, standalone project generation, packaging,
manifests, component contracts, linting, and the phone backend.

## License

MIT. See [LICENSE](LICENSE).
