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

At launch, bundle, validation, or push time, `OmarchyUI::Runtime` installs the
versioned QML package from `Zui::Runtime`, removes Zui's ordinary desktop entry
point, and overlays these four Omarchy host files. The adapter does not copy or
fork Zui's component implementations in source control.

This separation lets the same Ruby component tree run through a conventional
Qt host on Linux/macOS or through the Omarchy/Quickshell host without placing
desktop-environment checks in the core framework.
