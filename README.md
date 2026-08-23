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

On Omarchy x86-64, install the gem:

```bash
gem install omarchy-ui
```

The gem contains everything required to launch and bundle an application. Developers do
not need to install a separate runtime or copy framework files. Bundled applications require only
an Omarchy computer to run.

## Start an application

```bash
omarchy_ui new MyApp
cd myapp
omarchy_ui launch main.rb
```

A new standalone project contains only application-owned files:

```text
myapp/
├── components/
│   └── welcome.rb
├── README.md
└── main.rb
```

The generated application UI is entirely Ruby. `main.rb` loads reusable Ruby components from
`components/`; no QML source is generated into the application project. The framework creates the
required native bridge files only when launching or bundling the app.

`launch` opens a compositor-managed window. Drag its title bar or use Super+drag, and close it
with Super+W. For protocol debugging without a window, use `omarchy_ui run main.rb`.

## Bundle for another Omarchy computer

From an application directory:

```bash
omarchy_ui bundle
./dist/myapp/run
```

`bundle` creates a self-contained application under `dist/<project-name>/`. Its `run`
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

The versioned [component coverage matrix](docs/component-coverage.md) tracks the complete built-in
catalog. Generic custom adapters are intentionally excluded from its completion count.

### Layout and display

| Ruby component | Component-specific properties | Events | Container |
| --- | --- | --- | --- |
| `container` | `spacing`, `padding`, `bordered` | `click` | yes |
| `row` | `spacing`, `alignment` (`start`, `center`, `end`) | `click` | yes |
| `column` | `spacing`, `alignment` (`start`, `center`, `end`) | `click` | yes |
| `grid` | `columns`, `rows`, `spacing`, `row_spacing`, `column_spacing` | `click` | yes |
| `row_layout` | `spacing`, `alignment`; children support fill/preferred/min/max sizing | `click` | yes |
| `column_layout` | `spacing`, `alignment`; children support fill/preferred/min/max sizing | `click` | yes |
| `grid_layout` | `columns`, `rows`, spacing and alignment; children support layout sizing | `click` | yes |
| `flow` | `spacing`, `orientation`, `width`, `height`; wraps children automatically | `click` | yes |
| `center` | `padding`, `spacing` | `click` | yes |
| `card` | `padding`, `spacing`, `color`, `radius`, `border_color`, `accent` | `click` | yes |
| `stack` | — | `click` | yes |
| `scroll` | `clip` | `click` | yes |
| `rectangle` | `color`, `radius`, `border_color`, `border_width`, `padding` | `click` | yes |
| `border_overlay` | `color`, `width_spec`, `gradient_colors`, `gradient_angle`, `radius` | — | no |
| `aspect_ratio` | `ratio`, optional `width`/`height`, `clip` | `click` | yes |
| `constrained_box` | dimensions plus `min_width`, `min_height`, `max_width`, `max_height`, `clip` | `click` | yes |
| `fitted_box` | dimensions, `fit` (`contain`, `cover`, `fill`, `none`, `scale_down`), `alignment`, `clip` | `click` | yes |
| `wrap` | dimensions, `spacing`, horizontal/vertical `orientation`, `layout_direction` | `click` | yes |
| `split_view` | dimensions and horizontal/vertical `orientation`; children accept preferred/min/fill sizing | `click`, `resize` | yes |
| `stack_layout` | `current_index` and dimensions; displays one child page at a time | `click`, `change` | yes |
| `layout_item_proxy` | target control ID or node, dimensions, fill/preferred/min/max sizing, alignment and margins | `target_change` | no |
| `loader` | `active`, `asynchronous`, optional dimensions; lazily creates its first child | `click`, `loaded`, `status` | yes |
| `flickable` | viewport/content dimensions, direction, bounds behavior, interaction and clipping | `click`, `scroll`, `flick_start`, `flick_end` | yes |
| `focus_scope` | `focus`, `active_focus`, optional dimensions; establishes a keyboard-focus boundary | `click`, `focus`, `blur` | yes |
| `flipable` | `flipped`, horizontal/vertical axis, duration, easing, interaction and dimensions; first two children are front/back | `click`, `change` | yes |
| `border_image` | source, dimensions, four border slices, horizontal/vertical tiling, loading/cache/mirror/smoothing | `click`, `loaded`, `error`, `status` | yes |
| `window` | title, geometry limits, color, visibility, modality, flags, opacity and content orientation | `close`, visibility/active changes, `move`, `resize` | yes |
| `application_window` | native Controls window with background, font/layout direction, geometry, visibility, modality and flags | window events plus `focus_change` | yes |
| `text` | `text`, `style`, `size`, `bold`, `color`, `wrap` | — | no |
| `label` | text, typography, dimensions, wrapping, elision, alignment, line limit and plain/styled/rich/Markdown format | `link` | no |
| `rich_text` | explicit rich markup, typography, width/wrapping, line limit and link color | `link` | no |
| `markdown` | Markdown source, typography, width/wrapping, line limit, link color and base URL | `link` | no |
| `selectable_text` | read-only selectable text, typography, width/wrapping, format and selection colors | `selection`, `link` | no |
| `icon` | `name`, `text`, `size`, `color` | — | no |
| `tooltip` | `text`, `delay`, `timeout`, foreground/background/border colors, font family/size | — | no |
| `image` | `source`, `fill_mode` | — | no |
| `vector_image` | source, dimensions/fill, geometry/curve renderer, trust policy, async shapes and animation controls | `source_change` | no |
| `font_loader` | local or remote font source | `loaded`, `error`, `status` with resolved family name | no |
| `text_metrics` | text/font settings, spacing, elision and elision width | `metrics` with native bounds, advance width and elided text | no |
| `animated_image` | source, dimensions/fill, playback, pause, speed, async/cache/mirror/smoothing | `frame`, `loaded`, `error`, `status` | no |
| `video` | source, dimensions/fill, autoplay, loops, volume/mute, rate, orientation and mirroring | `play`, `pause`, `stop`, `error`, `position`, `duration` | no |
| `audio` | source, autoplay/reactive playback command, loops, volume/mute and playback rate | `play`, `pause`, `stop`, `error`, `position`, `duration` | no |
| `avatar` | optional image source, initials name, size/radius, colors, font size and loading/cache | `click`, `loaded`, `error` | no |
| `badge` | value, maximum-count formatting, dot mode, sizing/padding and colors | `click` | no |
| `chip` | label/icon, selected and deletable states, enabled state, dimensions, spacing and colors | `click`, `change`, `delete` | no |
| `spacer` | — | — | no |
| `progress` | `value`, `minimum`, `maximum`, `color` | — | no |
| `line_chart` | `values`, `labels`, dimensions, line/fill/grid colors, bounds, point and grid options | `select`, `hover` | no |
| `area_chart` | `values`, `labels`, dimensions, line/fill/grid colors, bounds and grid options | `select`, `hover` | no |
| `bar_chart` | `values`, `labels`, dimensions, colors, bounds, grid and spacing | `select`, `hover` | no |
| `separator` | `strength` | — | no |
| `divider` | orientation, length, thickness, leading/trailing indentation, color and opacity | — | no |
| `section_header` | `text` | — | no |
| `panel_hero` | `title`, `meta`, `detail`, `foreground`, `font_family`, `icon_size`, `icon_opacity`, `meta_opacity` | — | no |
| `optical_glyph` | `text`, `size`, `color`, `debug_bounds` | — | no |

Layout children can use `fill_width`, `fill_height`, `preferred_width`, `preferred_height`,
`minimum_width`, `minimum_height`, `maximum_width`, `maximum_height`, and `layout_alignment`.
For example:

```ruby
card padding: 20 do
  column_layout spacing: 14 do
    row_layout fill_width: true, spacing: 10 do
      icon :phone, size: 22, color: "#7aa2f7"
      text "Connected devices", style: :heading, fill_width: true
      button "Refresh", icon: :refresh
    end

    flow width: 520, spacing: 10 do
      button "Android", icon: :android
      button "iPhone", icon: :apple
      button "Network", icon: :wifi
    end
  end
end
```

### Built-in icons

`icon`, `button`, and `action_button` accept icon names as Ruby symbols. The built-in catalog is:

`ruby`, `phone`, `plus`, `minus`, `reset`, `refresh`, `house`, `gear`, `search`, `xmark`,
`check`, `menu`, `user`, `bell`, `wifi`, `bluetooth`, `volume_high`, `volume_low`, `volume_off`,
`play`, `pause`, `stop`, `trash`, `edit`, `folder`, `file`, `download`, `upload`, `link`, `lock`,
`unlock`, `eye`, `eye_slash`, `star`, `heart`, `info`, `warning`, `circle_info`, `circle_check`,
`circle_xmark`, `arrow_left`, `arrow_right`, `arrow_up`, `arrow_down`, `chevron_left`,
`chevron_right`, `chevron_up`, `chevron_down`, `calendar`, `clock`, `camera`, `image`, `music`,
`terminal`, `code`, `copy`, `save`, `power`, `globe`, `location`, `pin`, `android`, and `apple`.

Unknown icon values are rendered literally, so a Nerd Font glyph can also be passed directly.

### Inputs and actions

| Ruby component | Component-specific properties | Events |
| --- | --- | --- |
| `button` | `text`, `icon`, `tooltip`, `selected`, `active`, `cursor`, `focusable`, `bordered`, colors, font/icon sizes, padding, `left_align` | `click`, `right_click`, `hover` |
| `round_button` | text/icon, checked/checkable/enabled state, diameter, colors and typography | `click`, `change`, `press`, `release`, `hover` |
| `tool_button` | compact text/icon, checked/checkable/enabled state, dimensions, colors and typography | `click`, `change`, `press`, `release`, `hover` |
| `delay_button` | label, activation delay, enabled state, dimensions, colors and typography | `activate`, `progress`, `press`, `release`, `cancel` |
| `action_button` | `icon`, `tooltip`, `foreground`, `hover_color`, font/size, `focusable`, `cursor`, `bordered` | `click`, `hover` |
| `bar_icon_button` | `icon`, `tooltip`, active/colors, optical/slot/font sizing, rotation and reveal states | `click`, `right_click`, `middle_click`, `wheel` |
| `bar_indicator` | `active`, active/inactive icons and tooltips, `indicator_block`, colors and font sizing | `click`, `right_click`, `middle_click`, `wheel` |
| `toggle` | `label`, `description`, `checked`, `cursor`, `rounded`, colors, font/title/description sizes | `change`, `hover` |
| `checkbox` | `label`, `checked`, colors, font/indicator sizing, spacing and `cursor` | `change`, `hover` |
| `radio_button` | label/value, checked/enabled state, colors, typography, indicator size and spacing | `click`, `change`, `hover` |
| `radio_group` | selected value, string or label/value options, orientation, spacing, enabled state, colors and typography | `change`, `hover` |
| `toggle_switch` | `checked`, `busy`, `interactive`, `cursor`, `cursor_ring`, `cursor_pad`, `rounded`, colors, track/knob geometry | `change`, `hover` |
| `text_field` | `text`, `placeholder`, `password`, colors, selection tint, padding, `cursor` | `input`, `change`, `submit`, `focus`, `blur` |
| `text_area` | multiline text, placeholder, dimensions, wrapping, read-only/length limits, colors, typography and padding | `input`, `change`, `focus`, `blur`, `selection` |
| `search_field` | text, suggestion model/role, live mode, current index, width/enabled state, colors and typography | `input`, `change`, `search`, `submit`, `activate`, `highlight`, `clear`, `focus`, `blur` |
| `password_field` | masked text, placeholder, optional reveal control/state, width, colors, selection tint and padding | `input`, `change`, `submit`, `focus`, `blur`, `reveal` |
| `number_field` | `label`, `value`, `from`, `to`, `step`, colors, font/field width, `cursor` | `change`, `hover` |
| `slider` | `value`, `minimum`, `maximum`, `step`, `integer`, track/fill/knob colors and sizes, `ticks`, `tick_color` | `input`, `change`, `right_click` |
| `range_slider` | lower/upper values, bounds, step, orientation, snapping/live behavior, dimensions and colors | `input`, `change` |
| `dial` | value/bounds/step, angular limits, snapping, wrapping, live mode, input mode, size and colors | `input`, `change`, `press`, `release` |
| `spin_box` | integer value/bounds/step, editable/wrap modes, prefix/suffix, width/enabled state, colors and typography | `change`, `increase`, `decrease` |
| `double_spin_box` | floating value/bounds/step, decimal precision, editable/wrap modes, prefix/suffix, width/enabled state and styling | `change`, `increase`, `decrease` |
| `color_picker` | selected color, label/title, opened state, alpha/button/native-dialog options, dimensions and styling | `input`, `change`, `accept`, `reject`, `open`, `close` |
| `date_picker` | ISO date, label/placeholder/format, bounds, popup state and sizing, close-on-select behavior and styling | `input`, `change`, `open`, `close`, `navigate` |
| `time_picker` | `HH:MM[:SS]` time, 12/24-hour mode, seconds visibility, minute/second steps, popup state and labels | `input`, `change`, `accept`, `reject`, `open`, `close` |
| `file_picker` | selected path(s), open/save/folder mode, multiple selection, filters, current folder, suffix, dialog labels and styling | `input`, `change`, `accept`, `reject`, `open`, `close`, `folder_change` |
| `folder_picker` | selected directory, initial directory, title, dialog state and labels, native-dialog preference and button styling | `input`, `change`, `accept`, `reject`, `open`, `close`, `folder_change` |
| `font_picker` | family, point/pixel size, weight, italic/underline/strikeout state, dialog state, native preference and styling | `input`, `change`, `accept`, `reject`, `open`, `close` |
| `dialog_button_box` | standard button names, custom label/role buttons, orientation, alignment, header/footer position, spacing and styling | `click`, `accept`, `reject`, `help` |
| `action` | text, icon name/source/color/size, enabled/checkable/checked state, keyboard shortcut and visibility | `trigger`, `toggle`, `change` |
| `action_group` | action nodes/IDs, exclusive and enabled state, checked action and visibility | `trigger`, `change`, `actions_change` |
| `page` | title, optional header/footer text and geometry, row/column/stack content layout, spacing/padding, dimensions and styling; contains Ruby children | `click`, `show`, `hide`, `focus`, `blur`, `title_change` |
| `pane` | native untitled content surface with row/column/stack layout, per-edge padding, dimensions, background, border, radius, direction and clipping; contains Ruby children | `click`, `show`, `hide`, `focus`, `blur` |
| `frame` | native bordered content surface with row/column/stack layout, per-edge padding, dimensions, background, border, radius, direction and clipping; contains Ruby children | `click`, `show`, `hide`, `focus`, `blur` |
| `group_box` | titled native bordered container with reactive typography/alignment, row/column/stack layout, per-edge padding, dimensions and styling; contains Ruby children | `click`, `show`, `hide`, `focus`, `blur`, `title_change` |
| `tabs` | native tab bar and stacked child pages; labels or child titles, reactive selected index, top/bottom bar position, dimensions and styling | `input`, `change`, `tab_click`, `show`, `hide`, `focus`, `blur` |
| `tab_bar` | standalone native tab selection bar accepting label or option-hash items, with reactive index, top/bottom position, spacing, dimensions and styling | `input`, `change`, `tab_click`, `show`, `hide`, `focus`, `blur` |
| `tab_button` | standalone native tab button with checked/auto-exclusive state, icon, shortcut, dimensions, typography, colors and border styling | `click`, `change`, `toggle`, `press`, `release`, `hover`, `focus`, `blur` |
| `page_indicator` | native page dots with reactive count/index, optional interaction, spacing, dot sizing, dimensions and colors | `input`, `change`, `show`, `hide`, `focus`, `blur` |
| `stack_view` | native push/pop stack over Ruby child pages, driven by a reactive index with optional transitions, dimensions and styling | `change`, `push`, `pop`, `depth_change`, `busy_change`, `show`, `hide`, `focus`, `blur` |
| `swipe_view` | native horizontal/vertical swipe navigation over Ruby child pages with reactive index, interaction, dimensions, direction and styling | `input`, `change`, `count_change`, `show`, `hide`, `focus`, `blur` |
| `drawer` | native edge drawer with reactive opening, edge gestures, modal/dim behavior, close policy, child layout, dimensions and styling | `open`, `close`, `about_to_show`, `about_to_hide`, `position_change`, `show`, `hide`, `focus`, `blur` |
| `navigation_rail` | compact or extended vertical destination rail accepting label/icon item hashes, with reactive selection, alignment, dimensions and styling | `input`, `change`, `select`, `show`, `hide`, `focus`, `blur` |
| `breadcrumb` | native clickable destination trail accepting label/value/icon item hashes, with reactive current segment, separator, spacing and styling | `input`, `change`, `select`, `show`, `hide`, `focus`, `blur` |
| `pagination` | one-based native page navigation with bounded selection, sibling window, ellipses, optional previous/next and first/last controls, labels and styling | `input`, `change`, `select`, `previous`, `next`, `first`, `last`, `show`, `hide`, `focus`, `blur` |
| `expansion_panel` | native header and animated Ruby child-content reveal with title/subtitle, reactive expanded state, timing, dimensions and styling | `toggle`, `change`, `expand`, `collapse`, `show`, `hide`, `focus`, `blur` |
| `dropdown` | `label`, `value`, `options`, colors, font, row sizes, `show_label`, `cursor` | `change`, `hover` |
| `searchable_dropdown` | dropdown fields plus `placeholder`, `empty_text`, `trigger_label`, popup sizing | `change`, `hover` |
| `multi_select` | `label`, `values`, `options`, command options, placeholder/empty labels, popup sizing, colors | `change`, `hover` |
| `button_group` | `value`, `options`, colors, font, `focusable`, `cursor_index` | `change`, `hover` |
| `confirm_dialog` | `opened`, `message`, cancel/confirm labels, `selected_index`, colors, font, `corner_radius` | `cancel`, `confirm` |
| `cursor_surface` | `cursor`, `current`, `outline`, `bordered`, `foreground`, `accent`, `fill`, `current_fill` | `click` |
| `widget_button` | text/font/colors, active state, dimensions, rotation, visibility states, interaction flags, tooltip | `click`, `right_click`, `middle_click`, `wheel` |
| `list_view` | `items`, key/label/description/icon fields, `selected`, `orientation`, `spacing`, `empty_text` | `change`, `activate`, `scroll` |
| `key_catcher` | `blocked`; contains keyboard-driven panel content | `move`, `activate`, `return`, `close`, `delete`, `tab`, `text` |

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
[the QML support matrix](docs/qml-support.md) for the adapter contract and supported APIs.

## Safety

Component names, files, properties, events, IDs, effects, values, message sizes, and animation
limits are validated. Commands use argv arrays without a shell. Applications and plugins run with
the current user's permissions, so review third-party code before installing it.

## Development and verification

```bash
./scripts/test.sh
ruby script/benchmark.rb
./scripts/smoke-test.sh  # live Omarchy session
```

The suite covers state, bindings, repeated structures, event persistence, component schemas,
animation tracks and sequences, tasks, command safety, standalone projects, packaging,
manifests, component contracts, linting, and the phone backend.

## License

MIT. See [LICENSE](LICENSE).
