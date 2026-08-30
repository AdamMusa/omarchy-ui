# QML ownership and adapter boundary

Application developers write Ruby. QML is an internal rendering and host
implementation split across two repositories with a strict dependency
direction.

## Zui owns

- `ControlNode.qml`, the generic protocol-to-component router;
- the complete `Components/Builtins` catalog;
- neutral `Theme` and `Controls` modules;
- the standard Qt desktop window and process transport;
- component schemas, Ruby builder methods, reactive properties, and events.

The source and full support matrix live in
[Zui](https://github.com/AdamMusa/zui). Components render as their declared
type or report an explicit error. Images are images, Quick 3D models are Quick
3D models, and no generic fallback silently changes application intent.

## Omarchy UI owns

- `App.qml`, the Quickshell application entry point;
- `Service.qml`, the Omarchy process and surface bridge;
- `Panel.qml` and `BarWidget.qml`, shell-owned plugin surfaces;
- lifecycle commands for Omarchy validation, activation, and restart.

At launch, the Omarchy service resolves the exact compatible `zui` Ruby gem and
loads `ControlNode.qml`, the component catalog, controls, theme, and fonts from
`Zui::FRAMEWORK_ROOT`. Bundle, validation, and push copy only the five Omarchy
host files (`App.qml`, `Service.qml`, `Panel.qml`, `BarWidget.qml`, and
`ZuiRenderer.qml`). They never copy Zui's shared QML package into an application
or plugin.

This separation lets the same Ruby component tree run through a conventional
Qt host on Linux/macOS or through the Omarchy/Quickshell host without placing
desktop-environment checks in the core framework.
