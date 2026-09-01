import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: window

  required property var renderer

  visible: renderer.prop("pinned", false) === true
  anchors { top: true; right: true; bottom: true; left: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: renderer.bridge && renderer.bridge.manifest && renderer.bridge.manifest.id
    ? String(renderer.bridge.manifest.id) + "-desktop"
    : "omarchy-ui-desktop"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  // The rest of the full-screen surface remains click-through.
  mask: Region { item: stage }

  Item {
    id: stage
    x: Math.max(0, Math.min(parent.width - width, Number(renderer.prop("stage_x", 48))))
    y: Math.max(0, Math.min(parent.height - height, Number(renderer.prop("stage_y", 220))))
    width: Math.max(1, Number(renderer.prop("stage_width", 420)))
    height: Math.max(1, Number(renderer.prop("stage_height", 420)))

    Repeater {
      model: renderer.node && Array.isArray(renderer.node.children) ? renderer.node.children : []
      delegate: renderer.childDelegateComponent
    }
  }
}
