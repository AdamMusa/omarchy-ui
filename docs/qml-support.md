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

At bundle, validation, or push time, Omarchy UI invokes Zui's tree shaker against
the application-owned Ruby source. Zui generates `ControlNode.qml`, only the
referenced built-in component adapters, and their renderer dependencies. Omarchy
UI then overlays its four host files (`App.qml`, `Service.qml`, `Panel.qml`, and
`BarWidget.qml`) and AOT-compiles the complete generated graph into a
content-addressed Qt module. The generated component, control, theme, and font
source tree is discarded after compilation. `zui-tree-shake.json` records the
selected component set for review and deterministic regeneration.

Omarchy currently requires filesystem entry-point names. The distributable
therefore retains four minimal QML loader shims that instantiate the compiled
host types; application UI source is not shipped as QML files.

`omarchy-ui-qml-bundle.json` records the module URI, source fingerprint, exact Qt
version, source counts, artifact sizes, and SHA-256 digests. The adjacent
`omarchy-ui-qml-bundle.sha256` file can be checked with `sha256sum --check`.
`QML_PROVENANCE.md` presents the same build identity in a reviewer-friendly form.
Omarchy UI generates the CMake project and invokes the Qt toolchain internally;
application repositories do not maintain build scripts or QML packaging rules.

This separation lets the same Ruby component tree run through a conventional
Qt host on Linux/macOS or through the Omarchy/Quickshell host without placing
desktop-environment checks in the core framework.
