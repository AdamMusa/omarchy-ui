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
Opening, geometry, modal/dim/focus behavior, close policy, layout, spacing, padding, typography,
styling, visibility, and the complete popup lifecycle are reactive.

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
