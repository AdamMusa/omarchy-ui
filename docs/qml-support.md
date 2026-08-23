# QML support matrix

The framework has two support levels. The built-in list is deliberately not a list of every
QML type: QML is an extensible language, and several Omarchy `Ui` files require shell-owned
windows or controllers that cannot be safely instantiated as ordinary tree controls.

- **Built-in adapter:** Ruby can use the component immediately through `component`.
- **Native adapter:** any QML type can be registered from `Components/`, including QtQuick,
  QtQuick.Controls, Quickshell, `qs.Ui`, third-party modules, shaders, Canvas, and particles.

Native adapters are universal rather than hand-wired: declared properties are assigned to the
QML root object, declared signals are forwarded to Ruby, mapped names support Ruby snake_case,
and every declared property can participate in bindings and animations. A native container can
expose an `Item` property named `contentHost`; framework children are parented there automatically.

## Qt Quick Layouts

`layout_item_proxy(target, ...)` is backed by the native `LayoutItemProxy`. It accepts either a
Ruby node returned by another component method or that node's ID, resolves the rendered QML item,
and mirrors it into another Qt Quick Layout. Fill, preferred, minimum, maximum, alignment, and
per-edge margin properties remain reactive. The `target_change` event reports whether the target
is currently resolved.

`window(title, ...) { ... }` creates an independent native `QtQuick.Window`. Geometry, size
constraints, visibility, modality, flags, opacity, color, and content orientation are reactive,
while its Ruby children render in the window's content scene. Native close, activation,
visibility, move, and resize changes are delivered as Ruby events.

`application_window(title, ...) { ... }` uses `QtQuick.Controls.ApplicationWindow` for secondary
windows that need the Controls content/background model, inherited font and layout direction,
and active-focus-control reporting in addition to the native window lifecycle.

## Native dialogs

`color_picker(color, ...)` opens Qt's native `ColorDialog` from a styled Ruby-controlled button.
Its color, label, title, opened state, alpha-channel mode, button mode, native-dialog preference,
dimensions, and visual styling remain reactive. Preview changes emit `input`; completion and
lifecycle changes emit `change`, `accept`, `reject`, `open`, and `close`.

`date_picker(date, ...)` renders a button and an interactive Qt `MonthGrid` popup. Ruby dates use
the stable `YYYY-MM-DD` form while the visible text can use any `Qt.formatDate` format. Minimum and
maximum dates, popup state and sizing, close-on-select behavior, and styling are reactive. Selection
emits `input` and `change`; popup lifecycle and month navigation emit `open`, `close`, and `navigate`.

`time_picker(time, ...)` uses Qt spin controls in a confirmation popup. It accepts `HH:MM` or
`HH:MM:SS`, supports 12- and 24-hour display, optional seconds, configurable minute/second steps,
reactive popup state and styling, and customizable action labels. Partial edits emit `input`; the
actions emit `change` plus `accept`, or `reject`, followed by the popup lifecycle event.

`file_picker(path, ...)` presents Qt's native `FileDialog` or `FolderDialog`. Open, multiple-open,
save, and folder modes accept ordinary Ruby filesystem strings and return strings (or a `values`
array for multiple selection), never QML URL objects. Filters, initial folder/path, default suffix,
dialog state and labels, native-dialog preference, and button styling are reactive. The adapter emits
`input`, `change`, `accept`, `reject`, `open`, `close`, and `folder_change` where applicable.

`folder_picker(path, ...)` is the dedicated directory-only API. It uses Qt's `FolderDialog`, keeps
the selected and current directories reactive as Ruby strings, and exposes dialog lifecycle,
selection, rejection, and folder-navigation events without requiring `file_picker` mode options.

`font_picker(family, ...)` opens Qt's native `FontDialog` while keeping its value Ruby-friendly.
Family, point or pixel size, weight, italic, underline, and strikeout properties are reactive, and
the same fields are returned in `input`, `change`, and `accept` payloads. The dialog also reports
`reject`, `open`, and `close` and supports the shared native-dialog and button styling options.

`dialog_button_box(buttons, ...)` maps Ruby button names such as `:ok`, `:save`, and `:cancel` to
Qt's native standard buttons. `custom_buttons` accepts `{ text:, role: }` hashes for application
actions. Orientation, alignment, header/footer position, centering, spacing, and styling are reactive;
`click`, `accept`, `reject`, and `help` report native button roles and standard-button identities.

`action(text, ...)` owns a nonvisual native Qt `Action`. Text, icon metadata, enabled/checkable/
checked state, shortcut, and visibility are reactive. A Ruby block handles `trigger`; explicit
`trigger`, `toggle`, and `change` handlers receive the current text and checked state. The returned
node can be referenced by action-aware components such as `action_group`.

`action_group([save_action, cancel_action], ...)` accepts the nodes returned by `action` (or their
IDs), resolves their native actions after rendering, and owns a native Qt `ActionGroup`. Exclusive
selection, enabled state, checked action, membership, and visibility are reactive. `trigger` and
`change` return the originating action ID; `actions_change` reports the resolved membership list.

## Navigation containers

`page(title, ...) { ... }` is backed by a native Qt Controls `Page`. It lays out ordinary Ruby
children as a column, row, or stack and supports reactive spacing, padding, dimensions, background,
typography, layout direction, and optional styled title/header and footer regions. Visibility,
focus, title mutation, and page clicks emit `show`, `hide`, `focus`, `blur`, `title_change`, and `click`.

`pane(...) { ... }` provides a native Qt Controls `Pane` for grouping related Ruby UI without a
title region. Its row, column, or stack content layout; per-edge padding; dimensions; background;
border; radius; direction; visibility; and clipping are reactive. It emits `click`, `show`, `hide`,
`focus`, and `blur` when those handlers are subscribed.

`frame(...) { ... }` is the bordered native Qt Controls counterpart to `pane`. It accepts the same
reactive content layouts and per-edge padding, while exposing its border width/color, background,
radius, direction, clipping, and geometry directly to Ruby. It emits the same pointer, visibility,
and focus events as `pane`.

`group_box(title, ...) { ... }` adds a reactive native Qt Controls `GroupBox` title to a bordered
container. Ruby controls its title typography/alignment, row/column/stack child layout, padding,
geometry, background, border, radius, direction, and clipping. Title changes, pointer clicks,
visibility, and focus transitions are emitted as events.

`tabs(labels, current_index: ...) { ... }` combines a native Qt Controls `TabBar` with a
`StackLayout`; each Ruby child is one tab page. Labels may be supplied explicitly or inherited from
each child's `title`. Selection is reactive in both directions and emits `input`, `change`, and
`tab_click`, while bar position, sizing, colors, typography, direction, and visibility remain Ruby
properties.

`tab_bar(items, current_index: ...)` exposes a standalone native Qt Controls `TabBar`. Items may be
labels or hashes containing `label`, `enabled`, and `icon`; the selected index is reactive and
emits `input`, committed `change`, and `tab_click` payloads. Position, spacing, sizing, colors,
typography, direction, visibility, and focus are independently configurable.

`tab_button(label, ...)` is an individually usable native Qt Controls `TabButton`. Checked and
enabled state, auto-exclusivity, icon/shortcut, geometry, typography, colors, border, radius, and
visibility are reactive. Ruby receives click, checked-state, press/release, hover, and focus events.

`page_indicator(count, current_index: ..., interactive: ...)` maps directly to native Qt Controls
`PageIndicator`. Count, selection, interactivity, dot sizing/spacing, geometry, colors, radius,
enabled state, and visibility are reactive; user selection emits `input` and `change`.

`stack_view(current_index: ...) { ... }` maps Ruby child pages into a native Qt Controls
`StackView`. Moving the reactive index forward pushes pages and moving it backward pops them;
single-step navigation can use native transitions while larger synchronization jumps remain
deterministic. Ruby receives `change`, `push`, `pop`, depth, busy, visibility, and focus events.

`swipe_view(current_index: ...) { ... }` renders each Ruby child as a page in a native Qt Controls
`SwipeView`. Horizontal or vertical touch/trackpad navigation and programmatic selection stay in
sync; interaction, geometry, clipping, direction, styling, and visibility are reactive. Selection
emits `input` and `change`, and structural updates emit `count_change`.

`drawer(opened: ...) { ... }` creates a native Qt Controls `Drawer` on the requested screen edge.
Opening, modal/dim behavior, edge dragging, drag margin, outside/escape close policy, child layout,
geometry, padding, and styling are reactive. Ruby receives open/close, about-to-show/hide,
position, visibility, and focus lifecycle events.

`navigation_rail(items, current_index: ...)` provides a dedicated vertical navigation surface built
from native Qt Controls. String destinations and hashes with `label`, `icon`, `icon_source`, and
`enabled` are supported. Compact/extended presentation, alignment, spacing, dimensions, colors,
typography, and selection are reactive; activation emits `input`, `change`, and `select`.

`breadcrumb(items, current_index: ...)` renders a native button trail. Items may be labels or hashes
with `label`, `value`, `icon`, `icon_source`, and `enabled`; the separator, current destination,
spacing, geometry, typography, colors, and visibility are reactive. Segment activation emits
`input`, `change`, and `select` with index, label, and value.

`pagination(count, page: ...)` provides one-based page navigation built from native Qt Controls.
It clamps selection to the available count, renders a sibling window with ellipses for large data
sets, and optionally exposes previous/next and first/last controls. Labels, spacing, geometry,
typography, colors, and visibility are reactive; navigation emits directional and selection events.

`expansion_panel(title, expanded: ...) { ... }` provides a native clickable header and a Ruby child
content region. Title/subtitle typography, expanded state, reveal animation duration/easing,
spacing, padding, dimensions, colors, border, radius, enabled state, and visibility are reactive.
User activation emits `toggle`/`change` plus the directional `expand` or `collapse` event.

`accordion(titles, expanded_indices: ...) { ... }` pairs each title with one Ruby child body. It can
enforce single-section expansion or allow multiple sections, synchronizes the complete expanded
index set, and animates independent native headers/content regions. Subtitles, timing, spacing,
padding, geometry, typography, colors, and visibility are reactive; every toggle reports its index
and the resulting expanded set.

`tool_bar(...) { ... }` is a native Qt Controls `ToolBar` containing arbitrary Ruby controls. It
supports header/footer position, row or column child layout, spacing, padding, geometry, colors,
border, radius, layout direction, enabled state, and visibility. Click, position, visibility, and
focus changes are available as Ruby events.

`tool_separator(...)` maps to native Qt Controls `ToolSeparator`, independently of the generic
`divider`. Orientation, line thickness/length, control padding, color, opacity, enabled state, and
visibility are reactive; visibility transitions emit `show` and `hide` when subscribed.

## Menus, dialogs, and feedback

`menu(items, opened: ...)` creates a native Qt Controls `Menu`. Ruby items may be labels, option
hashes (`label`, `value`, `icon`, `icon_source`, `enabled`, `checkable`, `checked`), or separator
hashes. Entries are rebuilt reactively, popup position/open state and close policy are controlled
from Ruby, and trigger/toggle/highlight plus the full popup lifecycle are emitted with item data.

`menu_item(label, value: ...)` exposes an independently usable native Qt Controls `MenuItem`.
Enabled/checkable/checked/highlighted state, icon, keyboard shortcut, geometry, typography, colors,
border, radius, and visibility are reactive. Trigger, toggle/change, pointer, hover, highlight, and
focus events include the Ruby value and current checked state.

`menu_separator(...)` is the native Qt Controls menu-specific separator. Its line thickness,
available width/height, padding, color, opacity, enabled state, and visibility are reactive, and
visibility transitions emit `show` or `hide` when subscribed.

`menu_bar(menus, ...)` constructs a native Qt Controls `MenuBar`; each Ruby menu hash supplies a
title and an `items` array using the same item/separator schema as `menu`. Both hierarchy levels are
instantiated with native ownership, and trigger/toggle/highlight payloads include menu and item
indices. Dimensions, spacing, padding, typography, colors, enabled state, visibility, and per-menu
open/close lifecycle are reactive.

`context_menu(items, target: ...)` attaches a native right-click `TapHandler` to a Ruby node/ID, or
uses its own configurable activation area when no target is supplied. It also supports reactive
programmatic opening and the complete `menu` item schema, position, close policy, and styling.
`request` reports the pointer coordinates before opening; trigger/toggle/highlight and popup
lifecycle events retain the selected item data.

`popup(opened: ...) { ... }` exposes native Qt Controls `Popup` ownership for arbitrary Ruby child
controls. Position, size, modal/dim/focus behavior, escape/outside close policy, row/column/stack
layout, spacing, padding, styling, and enter/exit animation are reactive. Ruby receives open/close,
about-to-show/hide, visibility, focus, and position events.

`dialog(title, standard_buttons: ...) { ... }` maps to native Qt Controls `Dialog` and contains
arbitrary Ruby controls. Ruby selects native standard button roles (`ok`, `cancel`, `yes`, `no`,
`apply`, `reset`, `discard`, `help`, and others) and receives their distinct semantic events.
Dialogs are centered in the application window by default; `centered: false` or explicit `x:`/`y:`
supports intentional placement. Opening, geometry, modal/dim/focus behavior, close policy, layout, spacing, padding, typography,
styling, visibility, and the complete popup lifecycle are reactive.

`alert_dialog(title, message, severity: ...)` is a dedicated Omarchy-themed dialog for
informational, success, warning, and error alerts. Its icon and message share a vertically centered
layout, and `image:`/`image_source:` can add an app-relative, absolute, or URL image with reactive
width, height, fill mode, radius, async loading, and caching. Semantic standard-button roles render
with Omarchy `Button` controls instead of the host platform's gray dialog footer. Header/footer and
button colors, labels, alignment, padding, typography, spacing, window-centered placement, geometry, modal behavior, and the
complete popup lifecycle are reactive.

`message_dialog(title, message, ...)` uses Qt Quick Dialogs’ platform-native message box rather
than an in-scene styled control. Informative/detailed text, native standard-button flags, window or
application modality, and opening are reactive. `button` returns the native button and role names;
accept/reject and open/close lifecycle events remain available to Ruby.

`bottom_sheet(...) { ... }` is a bottom-anchored native popup surface for arbitrary Ruby content.
It provides a modal scrim, constrained responsive width, a configurable drag handle,
swipe-to-dismiss threshold, animated entry/exit, close policies, and reactive opening. Ruby can
observe popup lifecycle, drag progress, drag completion, and explicit gesture dismissal.

`modal_sheet(title, ...) { ... }` presents arbitrary Ruby content in a modal sheet attached to any
window edge. Its responsive dimensions, edge, header, close affordance, styling, animation, and
opening state are reactive. Escape, outside-click, and close-button dismissal are configurable;
Ruby receives both lifecycle events and a reason-bearing `dismiss` event.

`snackbar(message, ...)` displays short-lived feedback in a native popup with optional action text.
Placement, timeout, persistent mode, hover pausing, action-close behavior, responsive width,
styling, and transitions are reactive. Ruby receives separate `action`, `timeout`, `dismiss`,
open/close, visibility, and hover events.

`banner(message, ...)` is an in-layout notice with optional title, severity-derived icon and accent,
action button, and dismiss control. Its content, explicit icon/color overrides, typography, sizing,
and styling react to Ruby state. It emits action, dismissal, click, hover, focus, and visibility
events without creating a window or popup.

`toast(message, ...)` presents compact transient feedback with optional title and severity icon.
Corner/edge placement, timeout, persistent mode, hover pausing, click dismissal, responsive width,
colors, typography, and transitions are reactive. Timeout, dismissal, click, hover, visibility, and
popup lifecycle are exposed as Ruby events.

`busy_indicator(running = true, ...)` maps directly to Qt Quick Controls’ native indeterminate busy
indicator. Running state, dimensions, palette color, opacity, enabled/visible state, and accessible
name are reactive; Ruby can observe running and visibility changes.

`progress_ring(value = nil, ...)` renders circular determinate progress for an arbitrary
minimum/maximum range; omitting the value selects an indeterminate rotating arc. Thickness, track
and progress colors, start angle, direction, dimensions, animation, center label/format,
accessibility, and visibility are reactive. Ruby receives normalized value and visibility changes.

`skeleton(...)` renders reactive loading placeholders as rectangles, circles, or multiline text.
Line count/height/spacing, final-line width, radius, dimensions, base/highlight colors, shimmer
direction/speed, opacity, accessibility, and visibility are configurable. Animation and visibility
changes are observable from Ruby.

`item_delegate(text, value: ...) { |event| ... }` maps to Qt Quick Controls’ native item delegate.
It supports leading icons/images, primary and secondary text, trailing text or disclosure indicator,
selection/highlight styling, checkable state, responsive sizing, accessibility, and keyboard/pointer
activation. Ruby receives value-bearing activation, toggle/change, press/release, hover, focus, and
visibility events.

`check_delegate(text, checked: ..., value: ...) { |event| ... }` maps to the native Qt Quick
`CheckDelegate`. It supports two-state or true tri-state values (`unchecked`, `partial`, `checked`),
secondary text, selection/highlight styling, custom indicator colors and geometry, accessibility,
and keyboard/pointer input. Change payloads include boolean compatibility and the exact state name.

`radio_delegate(text, checked: ..., value: ...) { |event| ... }` maps to Qt Quick Controls’ native
`RadioDelegate`. Sibling delegates are auto-exclusive by default, with reactive checked,
selection/highlight, secondary text, indicator geometry/colors, accessibility, and enabled/visible
state. Ruby receives value-bearing selection, activation, change/toggle, pointer, focus, and
visibility events.

`switch_delegate(text, checked: ..., value: ...) { |event| ... }` maps to the native Qt Quick
`SwitchDelegate`. It combines primary/secondary row content with an animated track/thumb indicator,
reactive checked and selection/highlight state, fully configurable colors/geometry, accessibility,
and keyboard/pointer semantics. Ruby receives value-bearing activation, toggle/change, pointer,
focus, and visibility events.

`swipe_delegate(text, value: ...) { |event| ... }` maps to Qt Quick Controls’ native
`SwipeDelegate`. It supports optional leading content, secondary text, independently configured
left/right action lanes, programmatic side opening, animated native swipe transitions, optional
close-after-action, and accessibility. Ruby receives activation, side-action, swipe
position/completion/open/close, pointer, focus, and visibility events.

`grid_view(items, ...) { |event| ... }` maps Ruby arrays directly to a native QML `GridView`.
Object key/label/description/icon fields, selected value or current index, cell geometry, spacing,
padding, flow, RTL direction, snapping, bounds behavior, keyboard wrapping, highlight animation,
styling, and empty state are reactive. Ruby receives item activation/selection, current/count and
highlight changes, scroll/movement lifecycle, focus, and visibility events.

`table_view(rows, columns: ...) { |event| ... }` builds an arbitrary-width native QML `TableView`
and a real `Qt.labs.qmlmodels.TableModel` from Ruby array or object rows. Columns may be names or
metadata hashes with keys, labels, widths, alignment, and editability; omitted columns are inferred.
Headers, dimensions, spacing, row/cell/column selection, editing triggers, alternating rows,
virtualized item reuse, animation, keyboard/pointer navigation, styling, accessibility, and empty
state are reactive. Ruby receives cell click/activation, selection/current/edit, row/column count,
scroll/movement, focus, and visibility events.

`tree_view(rows, columns: ..., children_field: :children) { |event| ... }` recursively maps Ruby
trees into a native QML `TreeView` backed by `Qt.labs.qmlmodels.TreeModel`. Columns accept the same
key, label, width, alignment, and editability metadata as `table_view`; child collections may use any
Ruby field name and are normalized to Qt's reserved `rows` relationship. Selected and expanded index
paths, initial expansion depth, headers, selection modes, editing, indentation, virtualization,
navigation, styling, accessibility, and empty state are reactive. Ruby receives original source nodes
and stable tree paths with cell, selection, edit, expand/collapse, count, scroll, movement, focus, and
visibility events.

## Data, calendars, and navigation views

The remaining Qt model/view catalog is exposed through named builders. `data_table` adds Ruby-side
filter, sort, and paging properties to the arbitrary-column `table_view` contract. `horizontal_header`
and `vertical_header` render independently controlled header sections; their matching delegate
builders plus `table_view_delegate` and `tree_view_delegate` are reusable styled native delegates.

`reorderable_list` keeps a typed Ruby `items` array and reports drag lifecycle plus the reordered
array. `carousel` uses a native curved `PathView`; `tumbler` uses the native Controls picker.
`calendar`, `month_grid`, `week_number_column`, and `day_of_week_row` accept Ruby date strings and
locale names, and return date/week/day payloads without exposing QML date objects.

| Ruby builders | Main events |
| --- | --- |
| `data_table` | cell, activation, selection, edit, sort, filter, page, count, scroll, movement |
| `horizontal_header`, `vertical_header` | click, move, sort where applicable |
| `table_view_delegate`, `tree_view_delegate` | click, activation, edit or expand/collapse |
| `horizontal_header_delegate`, `vertical_header_delegate` | click and sort |
| `reorderable_list` | reorder, activate, change, drag lifecycle |
| `carousel`, `tumbler` | input, change, activate, movement lifecycle |
| `calendar`, `month_grid`, `week_number_column`, `day_of_week_row` | input/change/navigation and date-part clicks |

## Charts and visualization

All chart builders consume only arrays/hashes/numbers/strings and render through a native Qt Canvas
backend. The common chart properties cover dimensions, labels, series colors, explicit ranges,
grid styling, typography, and visibility; `select` and `hover` payloads identify the visual datum.

| Family | Ruby builders |
| --- | --- |
| Cartesian | `line_chart`, `area_chart`, `bar_chart`, `stacked_bar_chart`, `scatter_chart`, `bubble_chart` |
| Circular | `pie_chart`, `donut_chart`, `radar_chart`, `gauge`, `radial_gauge` |
| Dense/specialized | `heatmap`, `sparkline`, `histogram`, `candlestick_chart` |
| Annotation | `legend` |

## Drawing, shaders, particles, and effects

`canvas(commands, ...)` is a structured 2D drawing API: Ruby supplies command hashes instead of
JavaScript. It supports paths, lines, Bézier/quadratic curves, arcs, rectangles/rounded rectangles,
fill/stroke/clip, text, transforms, compositing, shadows, and linear/radial gradient styles. Canvas
paint and pointer lifecycle are ordinary Ruby events, and continuous repainting is controlled by
`continuous` plus `fps`.

`shape`, `path`, `line`, `circle`, and `gradient` use Qt Quick Shapes. They expose stroke/fill,
caps/joins/dashes, fill rules, antialiasing, geometry, and arbitrary gradient color stops. Linear,
radial, and conical gradients are selected with `type`.

`shader_effect(:wave) { ... }` turns its first Ruby child into a texture and applies a native
`ShaderEffect`. Built-in cross-backend shader packs are `passthrough`, `grayscale`, `wave`,
`pixelate`, and `vignette`; a project-relative or absolute `.qsb` path selects a custom trusted
shader. Standard uniforms include `source`, `time`, `resolution`, `mouse`, `intensity`, `amount`,
`radius`, `progress`, `frequency`, `amplitude`, two colors, and a four-number `parameters` vector.
Qt 6 shader source is never evaluated from a Ruby string: custom shaders must be precompiled QSB.
`shader_effect_source { ... }` exposes native texture size, format, samples, wrapping, mirroring,
mipmap, live/recursive capture, and source hiding as Ruby properties.

`model_view_3d("assets/model.glb", ...)` loads actual GLB/glTF geometry through Qt Quick 3D's
runtime asset loader. Mesh bounds are centered and fitted when available; explicit `model_scale`
and center coordinates cover assets whose importer does not publish bounds. Camera, antialiasing,
key/fill lights, rotation, wheel/pinch/double-click zoom, drag orbit, automatic rotation, and
geometry-scale pulse animation are Ruby properties and events. This optional surface requires the
`qt6-quick3d` system module; `assimp` enables the broad runtime import path.

`particle_system` owns a native particle system, emitter, image particle, velocity/acceleration,
gravity, and turbulence. Emission, lifetime, size, texture/color/alpha/rotation variation, bounds,
pause/running state, and revision-triggered bursts are reactive; Ruby can observe start/stop,
pause/resume, empty, and burst events.

The effect containers `multi_effect`, `rectangular_shadow`, `opacity_mask`, `blur`, `drop_shadow`,
`colorize`, and `glow` accept ordinary Ruby child content. They are backed by Qt Quick Effects and
cover brightness/contrast/saturation/colorization, blur, shadows, masks, offsets, scale, padding,
cache, and antialiasing without application-owned QML.

## Pointer and scrolling interaction

`drag_area`, `drop_area`, `pinch_area`, and `hover_area` are child containers backed by native Qt
pointer handlers. A target may be the Ruby node returned by another builder or its ID. Axis and
position/scale/rotation constraints remain reactive, and event payloads report coordinates,
translation, scale, rotation, centroids, keys, and dropped data as applicable. `drag_area` also
emits `click` and `double_click`, so direct-manipulation surfaces can zoom or activate without
layering application-owned QML pointer handlers over the draggable content.

`selection_rectangle(target, ...)` attaches native table selection UI. `scroll_bar(target, ...)`
and `scroll_indicator(target, ...)` attach to a Flickable-like node or operate from explicit
position/size properties. Their input, committed change, active-state, and selection-state events
are forwarded to Ruby.

## Animation, state, and timing

The declarative animation catalog is available independently of patch animations. Every target
argument accepts a returned Ruby node or ID.

| Family | Ruby builders |
| --- | --- |
| Property animation | `animation`, `property_animation`, `number_animation`, `color_animation`, `rotation_animation`, `vector_animation`, `path_animation` |
| Physical/smoothed | `spring_animation`, `smoothed_animation` |
| Geometry | `anchor_animation`, `parent_animation` |
| Render-thread animators | `opacity_animator`, `rotation_animator`, `scale_animator`, `x_animator`, `y_animator`, `uniform_animator` |
| Composition/actions | `pause_animation`, `script_action`, `property_action`, `parallel_animation`, `sequential_animation` |
| Control | `frame_animation`, `animation_controller`, `behavior`, `transition`, `timer` |
| State | `state`, `state_group`, `property_changes`, `anchor_changes`, `parent_change` |

Animations expose running/paused state, loops, duration/delay/easing, start/stop/finish, and running
changes. Parallel/sequential definitions are safe Ruby hashes and can contain Ruby node targets.
`frame_animation` reports frame timing; `animation_controller` scrubs progress. State/change
builders apply validated property/anchor/parent hashes on a `revision`, and `timer` provides native
interval, repeat, running, triggered-on-start, and restart semantics.

The name `state` remains backward compatible: `state :count, 0` defines reactive Ruby application
state, while `state :active, target: card, properties: { opacity: 1 }` builds a native UI state.
Likewise `animation(duration: 180)` creates the existing patch-animation value, while
`animation(target: card, property: :opacity, ...)` creates a declarative animation component.

## Multimedia and capture

The compact `audio` builder resolves app-relative assets, drives native play/pause/stop commands,
supports revisioned millisecond seeking, and reports loading/status/error, position/duration, and
end-of-media events. It is suitable for a fully state-driven Ruby transport rather than a simulated
playback timer.

`media_player`, `video_output`, and `sound_effect` cover playback source, loops, rate, position,
volume/mute, output routing, commands, status, buffering, tracks, duration, and errors.
`camera` exposes device selection, focus/flash/torch/exposure/white-balance modes, ISO, shutter,
color temperature, zoom, and lifecycle events.

`capture_session { ... }` owns a native camera, audio input/output, image capture, recorder, and
video preview while also accepting Ruby overlay children. `image_capture` and `media_recorder`
reference that session by returned node or ID. `audio_input`, `audio_output`, and `media_devices`
provide device enumeration/routing. `screen_capture` and `window_capture` expose the native desktop
capture sources and command/error lifecycle.

`web_view` wraps `QtWebEngine.WebEngineView` with URL or HTML loading, zoom, background, storage,
JavaScript/image settings, navigation commands, progress, title/URL changes, fullscreen,
permissions, and new-window events. Qt WebEngine must be initialized by the host before QML loads;
stock Quickshell builds that do not enable Qt WebEngine cannot safely instantiate this component.

## Models, persistence, and platform utilities

| Ruby builder | Native responsibility |
| --- | --- |
| `list_model` | mutable typed rows and count/change events |
| `delegate_model`, `delegate_model_group` | native delegate grouping/filter membership |
| `sort_filter_proxy_model` | native value filtering and sorting over Ruby rows |
| `folder_list_model` | folder entries, filters, visibility/sort options, status and folder changes |
| `settings` | Qt settings category/file persistence and explicit synchronization |
| `standard_paths` | standard locations, file lookup, and executable lookup |
| `clipboard` | read/write/watch the Quickshell clipboard as Ruby text |

## Portable `qs.Ui` controls

| Omarchy QML | Ruby component | Properties | Events |
| --- | --- | --- | --- |
| `Button` | `button` | text, icon, tooltip, enabled, selected, bordered | click, right_click, hover |
| `PanelActionButton` | `action_button` | icon, tooltip, enabled, bordered, size | click, hover |
| `Toggle` | `toggle` | label, description, checked, enabled | change, hover |
| `ToggleSwitch` | `toggle_switch` | checked, busy, enabled | change, hover |
| `TextField` | `text_field` | text, placeholder, password, enabled, width | change, submit, focus, blur |
| `NumberField` | `number_field` | label, value, from, to, step, enabled | change |
| `PanelSlider` | `slider` | value, minimum, maximum, step, integer, ticks | input, change, right_click |
| `Dropdown` | `dropdown` | label, value, options, placeholder, enabled, width | change, hover |
| `SearchableDropdown` | `searchable_dropdown` | label, value, options, placeholder, empty_text, trigger_label | change, hover |
| `MultiSelect` | `multi_select` | label, values, options, placeholder and empty labels | change, hover |
| `ButtonGroup` | `button_group` | value, options, enabled | change, hover |
| `ConfirmDialog` | `confirm_dialog` | opened, message, button labels, selected index | cancel, confirm |
| `PanelHero` | `panel_hero` | title, meta, detail, icon size/opacity | — |
| `PanelSectionHeader` | `section_header` | text | — |
| `PanelSeparator` | `separator` | strength | — |
| `OpticalGlyph` | `optical_glyph` | text, size, color, debug bounds | — |
| `CursorSurface` | `cursor_surface` | size, selection/border state, children | click |
| `WidgetButton` | `widget_button` | text, tooltip, state, size, rotation | click variants, wheel |

## Models

`list_view` accepts typed primitive or object arrays and supports configurable key, label,
description, and icon fields. Its `items` and `selected` properties can be reactive bindings;
updates are incremental property patches rather than complete surface renders. It emits
`change`, `activate`, and scroll-position payloads containing the row value, index,
and original typed item. A native adapter can provide an entirely custom delegate while using
the same array/hash protocol.

## Shell-owned infrastructure

`BarWidget`, `BarIndicator`, `Panel`, `PanelController`, `KeyboardPanel`, `PopupCard`,
`ScreenMoveRemap`, `SpeedTestOverlay`, `PanelKeyCatcher`, `PanelToolTip`,
`PointerMoveGate`, `BorderSurface`, and `BorderOverlay` depend on shell-owned objects,
windows, anchors, or imperative controller lifecycles. They are supported through the native
adapter API rather than pretending they are portable tree controls. Framework surfaces already
provide the corresponding bar, panel, border, focus, popup, and lifecycle ownership.

This distinction is about ownership, not capability: native adapters can import and instantiate
all of these components when their required shell objects are available.
