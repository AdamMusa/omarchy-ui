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
