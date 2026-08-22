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
